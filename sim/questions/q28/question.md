# Debug NetworkPolicy access across namespaces

Namespaces: `hydrus`, `hydrus-monitoring`

Team Hydrus protects its cache with NetworkPolicies. Since the last change, the `web`
Pods can no longer reach the cache.

1. Make the Pods of Deployment `web` (Namespace `hydrus`) able to reach the Service
   `cache` on port 80 again. **Don't modify or add any NetworkPolicy** for this. Fix it
   on the `web` side, according to what the existing policies expect. The fix must
   survive Pods being recreated.

2. The Pods labelled `app=metrics` in Namespace `hydrus-monitoring` must also be able
   to reach `cache` on port 80. Change the existing NetworkPolicy `cache-access` to allow
   this. All other Pods in `hydrus-monitoring` must still be blocked.

Keep the NetworkPolicy `default-deny` as it is.
