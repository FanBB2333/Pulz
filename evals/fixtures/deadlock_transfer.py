"""Transfer service with a deadlock caused by inconsistent lock ordering."""

import threading
import time


class Account:
    def __init__(self, account_id, balance):
        self.account_id = account_id
        self.balance = balance
        self.lock = threading.Lock()


class TransferService:
    def transfer(self, source, destination, amount):
        # BUG: lock acquisition order depends on call order.
        with source.lock:
            time.sleep(0.01)
            with destination.lock:
                if source.balance < amount:
                    raise ValueError("insufficient funds")
                source.balance -= amount
                destination.balance += amount


if __name__ == "__main__":
    checking = Account("checking", 100)
    savings = Account("savings", 100)
    service = TransferService()

    t1 = threading.Thread(target=service.transfer, args=(checking, savings, 10))
    t2 = threading.Thread(target=service.transfer, args=(savings, checking, 20))

    t1.start()
    t2.start()

    t1.join(timeout=0.2)
    t2.join(timeout=0.2)

    print("t1 alive:", t1.is_alive())
    print("t2 alive:", t2.is_alive())
    # If both remain alive here, the opposing transfers deadlocked.
