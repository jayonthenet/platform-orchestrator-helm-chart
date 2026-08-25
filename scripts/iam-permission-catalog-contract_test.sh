#!/bin/sh
set -eu

chart=${1:-charts/platform-orchestrator}
rendered=$(mktemp)
trap 'rm -f "$rendered"' EXIT

helm template platform-orchestrator "$chart" >"$rendered"

# The public IAM route must expose the permission catalog used by the console
# and API clients to construct custom roles.
grep -Fq '(orgs/[^/]+/permissions)' "$rendered"
