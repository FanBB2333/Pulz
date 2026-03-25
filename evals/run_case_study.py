#!/usr/bin/env python3
"""Run an execution-based Pulz vs baseline case study using the current Claude config."""

from __future__ import annotations

import argparse
import contextlib
import importlib.util
import io
import json
import re
import subprocess
import sys
import tempfile
import textwrap
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Callable


ROOT = Path(__file__).resolve().parent.parent
EVALS_DIR = ROOT / "evals"
SCENARIOS_DIR = EVALS_DIR / "bug-scenarios"
FIXTURES_DIR = EVALS_DIR / "fixtures"
RESULTS_DIR = EVALS_DIR / "results"
SETTINGS_PATH = Path.home() / ".claude" / "settings.json"
SKILL_PATH = ROOT / "pulz" / "SKILL.md"
TREATMENT_MODE = "append_system_prompt"
MAX_RETRIES = 2

JSON_SCHEMA = {
    "type": "object",
    "properties": {
        "root_cause": {"type": "string"},
        "corrected_file": {"type": "string"},
    },
    "required": ["root_cause", "corrected_file"],
    "additionalProperties": False,
}


@dataclass
class RunResult:
    repeat_index: int
    mode: str
    scenario_id: str
    scenario_name: str
    prompt: str
    root_cause: str
    corrected_file: str
    pass_fix: bool
    validation_message: str
    response_words: int
    raw_result: str


def read_current_config() -> dict:
    if not SETTINGS_PATH.exists():
        return {}
    raw = json.loads(SETTINGS_PATH.read_text())
    env = raw.get("env", {})
    return {
        "anthropic_model": env.get("ANTHROPIC_MODEL"),
        "anthropic_default_sonnet_model": env.get("ANTHROPIC_DEFAULT_SONNET_MODEL"),
        "anthropic_default_opus_model": env.get("ANTHROPIC_DEFAULT_OPUS_MODEL"),
        "anthropic_default_haiku_model": env.get("ANTHROPIC_DEFAULT_HAIKU_MODEL"),
        "anthropic_base_url": env.get("ANTHROPIC_BASE_URL"),
    }


def read_claude_version() -> str | None:
    completed = subprocess.run(
        ["claude", "--version"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=30,
    )
    if completed.returncode != 0:
        return None
    return completed.stdout.strip()


def load_scenarios() -> list[dict]:
    scenarios: list[dict] = []
    for path in sorted(SCENARIOS_DIR.glob("*/scenario.json")):
        scenario = json.loads(path.read_text())
        scenario["_path"] = path
        scenarios.append(scenario)
    return scenarios


def build_prompt(scenario: dict, fixture_text: str) -> str:
    filename = Path(scenario["fixture"]).name
    return textwrap.dedent(
        f"""
        You are fixing a single-file bug.

        Return JSON matching the provided schema.
        Requirements:
        - `root_cause`: one concise paragraph explaining the real bug.
        - `corrected_file`: the full corrected contents of `{filename}`.
        - Preserve the file's public API unless a minimal bug fix absolutely requires otherwise.
        - Do not omit imports, module exports, or runnable demo code.

        Bug report:
        {scenario['prompt']}

        File `{filename}`:
        ```{scenario['language']}
        {fixture_text}
        ```
        """
    ).strip()


def extract_json_object(text: str) -> dict | None:
    text = text.strip()
    if not text:
        return None
    fenced = re.search(r"```json\s*(\{.*\})\s*```", text, re.DOTALL)
    if fenced:
        text = fenced.group(1)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    match = re.search(r"(\{.*\})", text, re.DOTALL)
    if not match:
        return None
    try:
        return json.loads(match.group(1))
    except json.JSONDecodeError:
        return None


def parse_structured_output(stdout: str) -> tuple[dict, dict]:
    outer = json.loads(stdout)
    structured = outer.get("structured_output")
    if isinstance(structured, dict):
        return outer, structured

    raw_result = outer.get("result", "")
    fallback = extract_json_object(raw_result)
    if isinstance(fallback, dict):
        return outer, fallback

    raise RuntimeError("Claude response did not contain valid structured output")


def run_claude(prompt: str, *, use_skill: bool) -> dict:
    cmd = [
        "claude",
        "-p",
        "--output-format",
        "json",
        "--permission-mode",
        "bypassPermissions",
        "--max-turns",
        "3",
        "--json-schema",
        json.dumps(JSON_SCHEMA),
    ]
    if use_skill:
        if TREATMENT_MODE == "append_system_prompt":
            cmd.extend(["--append-system-prompt", SKILL_PATH.read_text()])
        elif TREATMENT_MODE == "add_dir":
            cmd.extend(["--add-dir", str(SKILL_PATH.parent)])
        else:
            raise RuntimeError(f"Unsupported treatment mode: {TREATMENT_MODE}")
    cmd.append(prompt)

    completed = subprocess.run(
        cmd,
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=420,
    )
    if completed.returncode != 0:
        raise RuntimeError(
            f"Claude call failed with code {completed.returncode}: {completed.stderr.strip()}"
        )

    outer, structured = parse_structured_output(completed.stdout)
    structured["_raw_result"] = outer.get("result", "")
    structured["_outer"] = outer
    return structured


def run_claude_with_retries(prompt: str, *, use_skill: bool) -> dict:
    last_error: Exception | None = None
    for _ in range(MAX_RETRIES + 1):
        try:
            return run_claude(prompt, use_skill=use_skill)
        except Exception as exc:  # noqa: BLE001
            last_error = exc
    if last_error is None:
        raise RuntimeError("Claude call failed without an explicit error")
    raise last_error


def load_python_module(path: Path, module_name: str):
    spec = importlib.util.spec_from_file_location(module_name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load module from {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def validate_null_deref(path: Path) -> tuple[bool, str]:
    mod = load_python_module(path, "case_null_deref")
    repo = mod.UserRepository()
    svc = mod.UserService(repo)
    if svc.get_user_display_name(1) != "ALICE":
        return False, "happy path broke for get_user_display_name(1)"
    for name in ("get_user_display_name", "get_user_email"):
        fn = getattr(svc, name)
        try:
            value = fn(999)
        except TypeError:
            return False, f"{name}(999) still raises TypeError"
        except Exception:
            continue
        if value is not None and not isinstance(value, str):
            return False, f"{name}(999) returned unexpected value: {value!r}"
    return True, "missing-user path no longer leaks TypeError"


def validate_resource_leak(path: Path) -> tuple[bool, str]:
    mod = load_python_module(path, "case_resource_leak")
    pool = mod.ConnectionPool(max_size=2)
    try:
        for _ in range(5):
            mod.process_queries(pool, ["SELECT 1", "SELECT 2"])
    except RuntimeError as exc:
        return False, f"pool still exhausts: {exc}"
    return True, "sequential batches reuse connections without exhaustion"


def validate_race_condition(path: Path) -> tuple[bool, str]:
    mod = load_python_module(path, "case_race_condition")
    for _ in range(3):
        counter = mod.Counter()
        threads = [
            mod.threading.Thread(target=mod.worker, args=(counter, 25))
            for _ in range(4)
        ]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join(timeout=1)
        if any(thread.is_alive() for thread in threads):
            return False, "threads failed to complete"
        if counter.get() != 100:
            return False, f"counter ended at {counter.get()} instead of 100"
    return True, "counter reaches 100 reliably"


def validate_checkpoint_ordering(path: Path) -> tuple[bool, str]:
    mod = load_python_module(path, "case_checkpoint_ordering")
    checkpoint = mod.CheckpointStore()
    handler = mod.EventHandler()
    consumer = mod.OrderEventConsumer(checkpoint, handler)
    events = [
        {"id": "evt-1", "offset": 1, "kind": "created", "amount": 50},
        {"id": "evt-2", "offset": 2, "kind": "invoice", "amount": -20},
        {"id": "evt-3", "offset": 3, "kind": "shipped", "amount": 0},
    ]
    try:
        consumer.process_batch(events)
    except RuntimeError:
        pass
    else:
        return False, "initial batch no longer reproduces failure"
    events[1]["amount"] = 20
    consumer.process_batch(events)
    if checkpoint.load() != 3:
        return False, f"checkpoint ended at {checkpoint.load()} instead of 3"
    if handler.processed_ids != ["evt-1", "evt-2", "evt-3"]:
        return False, f"processed ids were {handler.processed_ids!r}"
    return True, "retry reprocesses failed event before moving on"


def validate_deadlock_transfer(path: Path) -> tuple[bool, str]:
    mod = load_python_module(path, "case_deadlock_transfer")
    for _ in range(5):
        checking = mod.Account("checking", 100)
        savings = mod.Account("savings", 100)
        service = mod.TransferService()
        t1 = mod.threading.Thread(target=service.transfer, args=(checking, savings, 10))
        t2 = mod.threading.Thread(target=service.transfer, args=(savings, checking, 20))
        t1.start()
        t2.start()
        t1.join(timeout=0.5)
        t2.join(timeout=0.5)
        if t1.is_alive() or t2.is_alive():
            return False, "opposing transfers still deadlock"
        if checking.balance + savings.balance != 200:
            return False, "total balance changed"
    return True, "opposing transfers complete without deadlock"


def run_node_validation(path: Path, script: str) -> tuple[bool, str]:
    completed = subprocess.run(
        ["node", "-e", script, str(path)],
        capture_output=True,
        text=True,
        timeout=30,
    )
    if completed.returncode == 0:
        return True, completed.stdout.strip() or "node validation passed"
    return False, completed.stderr.strip() or completed.stdout.strip() or "node validation failed"


def validate_off_by_one(path: Path) -> tuple[bool, str]:
    script = r"""
const target = process.argv[1];
const mod = require(target);
const items = [1,2,3,4,5,6,7,8,9,10];
const page1 = mod.paginate(items, 1, 3).data;
const page2 = mod.paginate(items, 2, 3).data;
const page3 = mod.paginate(items, 3, 3).data;
function same(a, b) { return JSON.stringify(a) === JSON.stringify(b); }
if (!same(page1, [1,2,3])) throw new Error(`page1=${JSON.stringify(page1)}`);
if (!same(page2, [4,5,6])) throw new Error(`page2=${JSON.stringify(page2)}`);
if (!same(page3, [7,8,9])) throw new Error(`page3=${JSON.stringify(page3)}`);
console.log("pagination offsets are correct");
"""
    return run_node_validation(path, script)


def validate_type_coercion(path: Path) -> tuple[bool, str]:
    script = r"""
const target = process.argv[1];
const mod = require(target);
const cart = new mod.ShoppingCart();
cart.addItem("Widget", "19.99", 2);
cart.addItem("Gadget", "9.50", "3");
const total = cart.getTotal();
if (Math.abs(total - 68.48) > 1e-9) throw new Error(`total=${total}`);
const receipt = mod.formatReceipt(cart);
if (!receipt.includes("Widget: 39.98")) throw new Error(receipt);
console.log("numeric coercion and receipt formatting are correct");
"""
    return run_node_validation(path, script)


def validate_tenant_cache_leak(path: Path) -> tuple[bool, str]:
    mod = load_python_module(path, "case_tenant_cache_leak")
    repo = mod.FlagRepository()
    service = mod.FeatureFlagService(repo)
    alpha = service.get_flags("alpha", 42)
    beta = service.get_flags("beta", 42)
    if alpha == beta:
        return False, "cross-tenant cache collision still present"
    if beta["beta_checkout"] is not True or beta["new_nav"] is not True:
        return False, f"beta flags were wrong: {beta!r}"
    service.update_flags("beta", 42, {"beta_checkout": False, "new_nav": True})
    updated = service.get_flags("beta", 42)
    if updated["beta_checkout"] is not False:
        return False, f"beta invalidation failed: {updated!r}"
    alpha_again = service.get_flags("alpha", 42)
    if alpha_again["beta_checkout"] is not False:
        return False, f"alpha flags corrupted: {alpha_again!r}"
    return True, "cache keys are tenant-aware and invalidation matches"


VALIDATORS: dict[str, Callable[[Path], tuple[bool, str]]] = {
    "01-null-deref": validate_null_deref,
    "02-off-by-one": validate_off_by_one,
    "03-resource-leak": validate_resource_leak,
    "04-race-condition": validate_race_condition,
    "05-type-coercion": validate_type_coercion,
    "06-checkpoint-ordering": validate_checkpoint_ordering,
    "07-tenant-cache-leak": validate_tenant_cache_leak,
    "08-deadlock-transfer": validate_deadlock_transfer,
}


def validate_corrected_file(scenario: dict, corrected_file: str) -> tuple[bool, str]:
    fixture_name = Path(scenario["fixture"]).name
    with tempfile.TemporaryDirectory(prefix="pulz_case_study_") as tmp:
        path = Path(tmp) / fixture_name
        path.write_text(corrected_file)
        validator = VALIDATORS[scenario["id"]]
        with contextlib.redirect_stdout(io.StringIO()):
            return validator(path)


def run_case_study(*, repeats: int) -> dict:
    config = read_current_config()
    claude_version = read_claude_version()
    scenarios = load_scenarios()
    runs: list[RunResult] = []

    for repeat_index in range(1, repeats + 1):
        for scenario in scenarios:
            fixture_path = FIXTURES_DIR / Path(scenario["fixture"]).name
            fixture_text = fixture_path.read_text()
            prompt = build_prompt(scenario, fixture_text)

            for mode in ("baseline", "pulz"):
                try:
                    structured = run_claude_with_retries(
                        prompt,
                        use_skill=(mode == "pulz"),
                    )
                    corrected_file = structured["corrected_file"]
                    passed, message = validate_corrected_file(scenario, corrected_file)
                    raw_result = structured["_raw_result"]
                except Exception as exc:  # noqa: BLE001
                    structured = {"root_cause": "", "corrected_file": ""}
                    corrected_file = ""
                    passed = False
                    message = f"runner error: {exc}"
                    raw_result = ""
                runs.append(
                    RunResult(
                        repeat_index=repeat_index,
                        mode=mode,
                        scenario_id=scenario["id"],
                        scenario_name=scenario["name"],
                        prompt=scenario["prompt"],
                        root_cause=structured["root_cause"],
                        corrected_file=corrected_file,
                        pass_fix=passed,
                        validation_message=message,
                        response_words=len(raw_result.split()),
                        raw_result=raw_result,
                    )
                )

    totals = {
        mode: sum(1 for item in runs if item.mode == mode and item.pass_fix)
        for mode in ("baseline", "pulz")
    }
    hard_ids = {"06-checkpoint-ordering", "07-tenant-cache-leak", "08-deadlock-transfer"}
    hard_totals = {
        mode: sum(
            1
            for item in runs
            if item.mode == mode and item.scenario_id in hard_ids and item.pass_fix
        )
        for mode in ("baseline", "pulz")
    }
    payload = {
        "timestamp": datetime.now().isoformat(timespec="seconds"),
        "config": config,
        "claude_version": claude_version,
        "skill_version": "0.1.0",
        "treatment_mode": TREATMENT_MODE,
        "repeats": repeats,
        "cases": [item.__dict__ for item in runs],
        "summary": {
            "scenario_count": len(scenarios),
            "attempt_count_per_mode": len(scenarios) * repeats,
            "baseline_passes": totals["baseline"],
            "pulz_passes": totals["pulz"],
            "baseline_fix_rate": totals["baseline"] / (len(scenarios) * repeats),
            "pulz_fix_rate": totals["pulz"] / (len(scenarios) * repeats),
            "hard_case_count": len(hard_ids),
            "hard_attempt_count_per_mode": len(hard_ids) * repeats,
            "baseline_hard_passes": hard_totals["baseline"],
            "pulz_hard_passes": hard_totals["pulz"],
            "baseline_hard_fix_rate": hard_totals["baseline"] / (len(hard_ids) * repeats),
            "pulz_hard_fix_rate": hard_totals["pulz"] / (len(hard_ids) * repeats),
        },
    }
    return payload


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repeats", type=int, default=1)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    payload = run_case_study(repeats=args.repeats)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_path = RESULTS_DIR / f"case_study_glm47_{timestamp}.json"
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2))
    print(json.dumps(payload["summary"], ensure_ascii=False, indent=2))
    print(f"saved: {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
