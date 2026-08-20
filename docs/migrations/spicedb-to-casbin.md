# SpiceDB-to-Casbin chart upgrade

The first chart release with Casbin removes the SpiceDB workload and operator,
but deliberately retains the legacy `orchestrator-spicedb` PostgreSQL database,
database owner, and credentials. They are rollback data, not runtime
dependencies of the new IAM service.

Do not perform this release as an unattended rolling Helm upgrade. IAM schema
30 needs a short maintenance window in which the new image's migration utility
reconciles project and environment ancestry from the control plane before IAM
serves authorization traffic.

Follow the IAM image's `docs/migrate-spicedb-to-casbin.md` runbook in this order:

1. Scale the existing IAM Deployment to zero and verify all pods stopped.
2. Run `/opt/server/authorization-migrate preflight` from the new IAM image and
   save the JSON report outside the Pod.
3. Back up the `orchestrator-iam` database and verify the archive.
4. Upgrade this chart with `iam.replicaCount=0`. Leave
   `global.legacySpiceDB.preserveDatabase=true`, which is the default.
5. Run `/opt/server/authorization-migrate apply` from the new IAM image using
   the preflight policy SHA-256 and the in-cluster control-plane URL.
6. Upgrade the release again with the intended IAM replica count, run
   `authorization-migrate verify`, and complete the authorization smoke tests.

The migration container needs the same `platform-orchestrator-iam-config`
ConfigMap and `iam-db-secret` keys used by the IAM Deployment. Its Kubernetes
container command must be `/opt/server/authorization-migrate`; passing the
binary path as an argument does not override the image entrypoint.

Keep `global.legacySpiceDB.preserveDatabase=true` for the rollback window. If a
rollback is required, stop Casbin IAM, follow the runbook's guarded schema
downgrade or database-restore path, and install the previous chart release.

After the rollback window ends, take a fresh IAM backup and explicitly set:

```yaml
global:
  legacySpiceDB:
    preserveDatabase: false
```

The retained Database and Secret carry Helm's `keep` policy, so changing this
value stops chart management but does not delete them. Delete the orphaned
CloudNativePG `Database`, Secret, and database role explicitly when ready.
Deleting the Database resource may drop the legacy SpiceDB database; treat that
cleanup as irreversible unless its own database backup has been retained.
