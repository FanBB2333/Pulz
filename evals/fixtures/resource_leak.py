"""Database connection pool with a resource leak bug."""

import threading


class Connection:
    _id_counter = 0

    def __init__(self):
        Connection._id_counter += 1
        self.id = Connection._id_counter
        self.closed = False

    def execute(self, query):
        if self.closed:
            raise RuntimeError(f"Connection {self.id} is already closed")
        return f"Result of '{query}' on conn-{self.id}"

    def close(self):
        self.closed = True


class ConnectionPool:
    def __init__(self, max_size=5):
        self.max_size = max_size
        self._pool = []
        self._in_use = set()
        self._lock = threading.Lock()

    def acquire(self):
        with self._lock:
            if self._pool:
                conn = self._pool.pop()
                self._in_use.add(conn)
                return conn
            if len(self._in_use) < self.max_size:
                conn = Connection()
                self._in_use.add(conn)
                return conn
            raise RuntimeError("Pool exhausted")

    def release(self, conn):
        with self._lock:
            # BUG: connection is removed from _in_use but NOT added back to _pool
            # This means connections are leaked -- pool will exhaust after max_size uses
            self._in_use.discard(conn)
            # Missing: self._pool.append(conn)


def process_queries(pool, queries):
    """Process a batch of queries. Leaks connections."""
    for q in queries:
        conn = pool.acquire()
        try:
            result = conn.execute(q)
            print(result)
        finally:
            pool.release(conn)  # Connection leaked here


if __name__ == "__main__":
    pool = ConnectionPool(max_size=2)
    # First batch works
    process_queries(pool, ["SELECT 1", "SELECT 2"])
    # Second batch fails: RuntimeError: Pool exhausted
    process_queries(pool, ["SELECT 3", "SELECT 4"])
