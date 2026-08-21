#!/bin/sh
set -eu

chart=${1:-charts/platform-orchestrator}
rendered=$(mktemp)
trap 'rm -f "$rendered"' EXIT

helm template platform-orchestrator "$chart" >"$rendered"

# The application token may connect and perform JetStream administration, but
# it deliberately has no system-account access. RTT verifies an authenticated
# protocol connection without requiring $SYS request permissions.
grep -q 'until nats \$auth rtt 1; do sleep 2; done' "$rendered"

if grep -q 'server ping' "$rendered"; then
  echo "NATS bootstrap must not require system-account server ping access" >&2
  exit 1
fi

# Verify the command exists in the exact CLI image rendered by the chart. This
# catches incompatible CLI grammar before a Helm install can wait on the Job.
bootstrap_image=$(awk '
  /name: bootstrap/ { bootstrap = 1; next }
  bootstrap && /image:/ { gsub(/[\"[:space:]]/, "", $2); print $2; exit }
' "$rendered")
test -n "$bootstrap_image"
docker run --rm "$bootstrap_image" nats rtt --help 2>&1 | grep -q 'Compute round-trip time to NATS server'
