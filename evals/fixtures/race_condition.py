"""Counter with a race condition bug."""

import threading
import time


class Counter:
    def __init__(self):
        self.value = 0

    def increment(self):
        # BUG: read-modify-write without synchronization
        current = self.value
        time.sleep(0.001)  # Simulates some processing, exposes the race
        self.value = current + 1

    def get(self):
        return self.value


def worker(counter, iterations):
    for _ in range(iterations):
        counter.increment()


if __name__ == "__main__":
    counter = Counter()
    threads = []
    num_threads = 4
    iterations_per_thread = 25

    for _ in range(num_threads):
        t = threading.Thread(target=worker, args=(counter, iterations_per_thread))
        threads.append(t)
        t.start()

    for t in threads:
        t.join()

    expected = num_threads * iterations_per_thread  # 100
    actual = counter.get()
    print(f"Expected: {expected}, Actual: {actual}")
    # Actual will be much less than 100 due to race condition
