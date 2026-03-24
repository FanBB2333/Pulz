"""User service with a null dereference bug."""


class UserRepository:
    def __init__(self):
        self._users = {
            1: {"id": 1, "name": "Alice", "email": "alice@example.com"},
            2: {"id": 2, "name": "Bob", "email": "bob@example.com"},
        }

    def find_by_id(self, user_id):
        return self._users.get(user_id)  # Returns None if not found


class UserService:
    def __init__(self, repo):
        self.repo = repo

    def get_user_display_name(self, user_id):
        # BUG: No null check on find_by_id result
        user = self.repo.find_by_id(user_id)
        return user["name"].upper()  # Crashes when user is None

    def get_user_email(self, user_id):
        user = self.repo.find_by_id(user_id)
        return user["email"]  # Same bug pattern


if __name__ == "__main__":
    svc = UserService(UserRepository())
    print(svc.get_user_display_name(1))   # Works
    print(svc.get_user_display_name(999)) # TypeError: 'NoneType' is not subscriptable
