#!/bin/sh
set -eu

chart=${1:-charts/platform-orchestrator}
rendered=$(mktemp)
without_rollback=$(mktemp)
trap 'rm -f "$rendered" "$without_rollback"' EXIT

helm template platform-orchestrator "$chart" >"$rendered"

# The old IAM Pods must be gone before a Casbin binary migrates the shared
# database, and the chart must point at the qualified IAM release.
grep -q 'type: Recreate' "$rendered"
grep -q 'image: "ghcr.io/stellwerk-labs/platform-orchestrator-iam:v2.3.0"' "$rendered"

# SpiceDB runtime resources and configuration must not return accidentally.
if grep -Eq '# Source: .*/spicedb/|authzed/spicedb|SPICEDB_(URL|PRE_SHARED_KEY)' "$rendered"; then
  echo "SpiceDB runtime resources or configuration were rendered" >&2
  exit 1
fi

# The default rollout retains only the legacy database and credentials needed
# for guarded rollback. Both resources must carry Helm's keep policy.
grep -q 'name: spicedb-db-secret' "$rendered"
grep -q 'name: platform-orchestrator-cnpg-databases-orchestrator-spicedb' "$rendered"
rollback_keep_policies=$(grep -c 'helm.sh/resource-policy: keep' "$rendered")
test "$rollback_keep_policies" -ge 2

# Operators can explicitly stop managing those rollback resources after their
# retention window; disabling preservation must remove every SpiceDB artifact.
helm template platform-orchestrator "$chart" \
  --set global.legacySpiceDB.preserveDatabase=false >"$without_rollback"
if grep -qi 'spicedb\|authzed' "$without_rollback"; then
  echo "SpiceDB rollback artifacts remained after preservation was disabled" >&2
  exit 1
fi
