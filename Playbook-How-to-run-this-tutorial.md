### RBAC and Namespace Isolation Playbook

This repository includes a Makefile that turns the RBAC and namespace isolation tutorial into an executable playbook. You can run it end-to-end and watch each layer being applied.

### Prerequisites

Before running this tutorial, make sure the following are available:

- `kubectl` is installed and configured to talk to your cluster.
- A local Kubernetes cluster such as Minikube is running.
- `krew` is installed if you want to use RBAC audit plugins.
- The repository files are in the expected paths under `rbac/` and `quotas/`.

### Notes

- `team-alpha` and `team-beta` are created as isolated tenant namespaces.
- `team-alpha` is used for the sample application and RBAC examples.
- The `default` ServiceAccount in `team-alpha` is hardened to avoid token automount.
- The `deploy-bot` ServiceAccount is only for narrowly scoped API automation.
- 
#### Full walkthrough

```bash
make run-rbac-namespace-isolation-playbook
```

This target walks through:

1. **Namespaces and Pod Security Admission**  
   - Creates `team-alpha` and `team-beta`.  
   - Labels them with `team=alpha|beta` and `pod-security.kubernetes.io/enforce=restricted`.

1.1 ResourceQuota step

The playbook also applies a per-tenant `ResourceQuota` for `team-alpha`:

```bash
make apply-quota-to-namespace-team-alpha
```
This enforces limits on CPU, memory, pod counts, and storage usage for the namespace, so a single workload cannot exhaust shared cluster resources. It complements RBAC, Pod Security Admission, and NetworkPolicies as part of the defense-in-depth model.

2. **Namespace-scoped RBAC for team-alpha**  
   - Applies `Role` and `RoleBinding` so developers in `team-alpha` get exactly the permissions they need and nothing more.

3. **Aggregated ClusterRole for observability**  
   - Applies a `ClusterRole` labeled to aggregate into `view`.  
   - Binds the built-in `view` role to the `team-alpha-sre` group, extending read access with platform observability rules.

4. **ServiceAccount per app, no token by default**  
   - Applies a dedicated `myapp` ServiceAccount with `automountServiceAccountToken: false`.  
   - Deploys `myapp` with `serviceAccountName: myapp`.  
   - Hardens the `default` ServiceAccount in `team-alpha` so any pod that forgets to set `serviceAccountName` still avoids an automatic token mount.

5. **Separate deploy-bot ServiceAccount for API ops**  
   - Applies a `deploy-bot` ServiceAccount, a `deployment-restarter` Role, and a RoleBinding.  
   - Grants only `get/list/patch` on deployments so the bot can trigger rollouts without editing specs.

6. **RBAC audit checklist**  
   - Uses `kubectl auth can-i` and krew plugins (`rbac-lookup`, `who-can`) to prove what identities can actually do:
     - `deploy-bot` cannot delete deployments in `team-alpha`.
     - `deploy-bot` cannot see pods in `team-beta`.
     - Developer groups cannot mint secrets unexpectedly.
     - `rbac-lookup` and `who-can` show who is bound to sensitive actions.

#### Testing individual scenarios

You can also run specific targets:

```bash
# Create and label namespaces
make create-namespaces-for-team-alpha-and-team-beta
make assign-labels-and-pod-security-admission-enforcement-to-namespaces

# Apply namespace-scoped RBAC
make apply-rbac-role-to-namespace-team-alpha
make apply-rbac-viewer-role-to-namespace-team-alpha
make apply-rbac-developer-rolebinding-to-namespace-team-alpha

# Apply aggregated observability RBAC
make apply-rbac-platform-observability

# Apply app ServiceAccount + Deployment, and harden default SA
make apply-myapp-serviceaccount-and-deployment
make apply-a-default-serviceaccount-with-automountserviceaccounttoken-false-in-team-alpha-namespace

# Apply deploy-bot RBAC
make apply-deploy-bot-rbac

# Run RBAC audit checks
make rbac-audit-checklist
```

This playbook shows that the RBAC and namespace isolation design is not just conceptual—it is **codified, repeatable, and testable** via the Makefile.

## RBAC audit tests (allow + deny)

The `rbac-audit-checklist` target is more than a manual checklist — it is an automated test suite for RBAC:

- **Assert-allow**:
  - `deploy-bot` can `get/list/patch` deployments in `team-alpha` so it can trigger rollouts.

- **Assert-deny**:
  - `deploy-bot` cannot delete deployments in `team-alpha`.
  - `deploy-bot` cannot get pods in `team-beta` (namespace isolation).
  - `team-alpha-developers` cannot create secrets.

- **Inspection**:
  - `kubectl auth can-i --list` shows the effective permissions for `deploy-bot`.
  - `rbac-lookup` shows which Roles/RoleBindings are attached to `deploy-bot`.
  - `who-can` shows which identities can delete deployments in `team-alpha`.

You can run all of these tests in one go:

```bash
make rbac-audit-checklist
```

If any assertion fails (for example, if `deploy-bot` suddenly can delete deployments or read pods in `team-beta`), the Make target fails, making RBAC drift visible immediately.