#!/bin/sh
set -eu

chart=${1:-charts/platform-orchestrator}
rendered=$(mktemp)
trap 'rm -f "$rendered"' EXIT

helm template platform-orchestrator "$chart" \
  --set-string global.config.NATS_URL=nats://contract-nats:4222 \
  --set-string data-plane.config.RUNNER_GATEWAY_URL=https://public.example.test/runner-gateway \
  --set-string data-plane.config.RUNNER_GATEWAY_INTERNAL_URL=http://internal-gateway:8080/runner-gateway \
  >"$rendered"

grep -q 'RUNNER_GATEWAY_URL: https://public.example.test/runner-gateway' "$rendered"
grep -q 'RUNNER_GATEWAY_INTERNAL_URL: http://internal-gateway:8080/runner-gateway' "$rendered"
grep -q 'name: platform-orchestrator-runner-gateway' "$rendered"
grep -q 'value: "nats://contract-nats:4222"' "$rendered"
grep -q 'value: /runner-gateway' "$rendered"
grep -q 'defaultAction: Allow' "$rendered"

gateway_deployments=$(grep -c 'app.kubernetes.io/component: runner-gateway' "$rendered")
if [ "$gateway_deployments" -lt 2 ]; then
  echo "runner gateway Deployment and Service were not rendered" >&2
  exit 1
fi
