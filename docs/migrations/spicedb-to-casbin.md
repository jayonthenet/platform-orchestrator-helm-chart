# SpiceDB-to-Casbin chart upgrade

Chart `0.4.0` and later replace the external SpiceDB authorization service with
Casbin embedded in IAM. An ordinary Helm upgrade performs the database migration
and authorization reconciliation automatically. No migration Job or SpiceDB
export is required.

PostgreSQL remains the source of truth for roles and assignments. The chart
retains the former `orchestrator-spicedb` database, owner, and credentials for
the rollback window, but the new IAM service does not connect to SpiceDB.

## Before upgrading

1. Confirm the current IAM database is at schema version 29. IAM `v2.0.1` is the
   qualified source release; upgrade to it first if the installation is older.
2. Take and verify a PostgreSQL backup of the IAM database. Keep the previous
   IAM image and chart configuration for the rollback window.
3. Confirm IAM can reach both PostgreSQL and the control-plane service. The
   first start reads the complete project and environment hierarchy from the
   control plane.
4. Keep `global.legacySpiceDB.preserveDatabase=true`, which is the default.
5. Plan for a short IAM outage. The chart uses the `Recreate` deployment
   strategy so every SpiceDB-based IAM pod stops before a Casbin-based pod can
   change the shared database.

## Upgrade

Use the same release name, namespace, and values file as the existing
installation:

```bash
helm upgrade platform-orchestrator \
  oci://ghcr.io/stellwerk-labs/charts/platform-orchestrator \
  --version 0.4.3 \
  --namespace platform-orchestrator \
  --values my-values.yaml \
  --wait \
  --timeout 15m
```

On its first start, IAM:

1. obtains a PostgreSQL advisory lock so only one replica can migrate;
2. validates schema 29 and fingerprints the existing RBAC records;
3. applies schemas 30 and 31;
4. reconstructs organization, project, and environment ancestry from the
   control plane;
5. verifies resource coverage, parentage, and the unchanged RBAC fingerprint;
6. marks the upgrade complete and only then becomes ready.

Other IAM replicas wait for the same database lock and start after the verified
result is visible. If PostgreSQL or the control plane is unavailable, or a
verification fails, IAM exits without becoming ready. Kubernetes retries the
Pod, and the idempotent migration resumes from its recorded state. Helm
therefore fails closed instead of serving from a partially reconciled policy.

After Helm succeeds, smoke-test an organization-level role, a project-scoped
role, an environment-scoped role, and a service user. The optional diagnostic
command below independently verifies the database:

```bash
kubectl exec --namespace platform-orchestrator \
  deployment/platform-orchestrator-iam -- \
  /opt/server/authorization-migrate verify
```

## Rollback

Keep SpiceDB and its database intact but stopped until the new release has been
stable and a fresh IAM backup has been taken. Before rolling back, stop every
Casbin IAM replica.

If no role, membership, or service-user role data changed after the upgrade,
use the new IAM image's guarded `authorization-migrate rollback` command, then
restore the previous chart. If the command detects RBAC changes, restore the
pre-upgrade IAM backup instead. The detailed commands and legacy reconciliation
steps are in the IAM image's `docs/migrate-spicedb-to-casbin.md` runbook.

After the rollback window ends, take a fresh IAM backup and set:

```yaml
global:
  legacySpiceDB:
    preserveDatabase: false
```

The retained Database and Secret carry Helm's `keep` policy, so this setting
stops chart management but does not delete them. Delete the orphaned
CloudNativePG `Database`, Secret, and database role explicitly when ready.
Deleting the Database resource may drop the legacy SpiceDB database; treat that
cleanup as irreversible unless its own database backup has been retained.
