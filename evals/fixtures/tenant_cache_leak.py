"""Feature flag service with a multi-tenant cache key collision bug."""


class FlagRepository:
    def __init__(self):
        self._flags = {
            ("alpha", 42): {"beta_checkout": False, "new_nav": False},
            ("beta", 42): {"beta_checkout": True, "new_nav": True},
        }

    def fetch_flags(self, tenant_id, user_id):
        return dict(self._flags[(tenant_id, user_id)])

    def store_flags(self, tenant_id, user_id, flags):
        self._flags[(tenant_id, user_id)] = dict(flags)


class FeatureFlagService:
    def __init__(self, repo):
        self.repo = repo
        self._cache = {}

    def get_flags(self, tenant_id, user_id):
        # BUG: cache key ignores tenant_id, so tenants collide on the same user_id.
        cache_key = user_id
        if cache_key not in self._cache:
            self._cache[cache_key] = self.repo.fetch_flags(tenant_id, user_id)
        return dict(self._cache[cache_key])

    def update_flags(self, tenant_id, user_id, flags):
        self.repo.store_flags(tenant_id, user_id, flags)
        # Same key-shape bug on invalidation.
        self._cache.pop(user_id, None)


if __name__ == "__main__":
    service = FeatureFlagService(FlagRepository())

    print("alpha flags:", service.get_flags("alpha", 42))
    print("beta flags:", service.get_flags("beta", 42))
    # Expected beta flags: {'beta_checkout': True, 'new_nav': True}
    # Actual with bug after alpha cache warm-up: alpha's flags are returned for beta.
