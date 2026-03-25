"""Event consumer with a checkpoint ordering bug that skips failed events on retry."""


class CheckpointStore:
    def __init__(self):
        self._last_offset = 0

    def load(self):
        return self._last_offset

    def save(self, offset):
        self._last_offset = offset


class EventHandler:
    def __init__(self):
        self.processed_ids = []

    def apply(self, event):
        if event["kind"] == "invoice" and event["amount"] < 0:
            raise RuntimeError(f"invalid invoice amount for {event['id']}")
        self.processed_ids.append(event["id"])


class OrderEventConsumer:
    def __init__(self, checkpoint_store, handler):
        self.checkpoint = checkpoint_store
        self.handler = handler

    def process_batch(self, events):
        last_offset = self.checkpoint.load()

        for event in events:
            if event["offset"] <= last_offset:
                continue

            self.handler.apply(event)
            self.checkpoint.save(event["offset"])


if __name__ == "__main__":
    events = [
        {"id": "evt-1", "offset": 1, "kind": "created", "amount": 50},
        {"id": "evt-2", "offset": 2, "kind": "invoice", "amount": -20},
        {"id": "evt-3", "offset": 3, "kind": "shipped", "amount": 0},
    ]

    checkpoint = CheckpointStore()
    handler = EventHandler()
    consumer = OrderEventConsumer(checkpoint, handler)

    try:
        consumer.process_batch(events)
    except RuntimeError as exc:
        print("First run failed:", exc)

    events[1]["amount"] = 20
    consumer.process_batch(events)

    print("Checkpoint:", checkpoint.load())
    print("Processed IDs:", handler.processed_ids)
    # Expected after retry: ['evt-1', 'evt-2', 'evt-3']
    # Actual with bug: ['evt-1', 'evt-3']
