# Platform Orchestrator Helm Charts

Helm charts to install and operate Platform Orchestrator in Kubernetes.

Chart `0.3.0` exposes the HTTPS runner gateway while keeping NATS JetStream
internal. Keep the chart, data plane, and runner image versions from the same
compatibility set.

## Charts

All releases are managed via [Helmfile](helmfile.yaml.gotmpl). The main chart
is `platform-orchestrator`; the others are prerequisites (operators, CRDs, and
infrastructure) that it depends on.

| Release | Chart | Type | Description |
|---------|-------|------|-------------|
| `envoy-gateway` | `oci://docker.io/envoyproxy/gateway-helm` | External | Envoy Gateway controller |
| `gatewayclass` | [charts/gatewayclass](charts/gatewayclass) | Local | GatewayClass resource for Envoy Gateway |
| `cnpg` | `cnpg/cloudnative-pg` | External | CloudNativePG operator for PostgreSQL |
| `cert-manager` | `oci://quay.io/jetstack/charts/cert-manager` | External | TLS certificate management |
| `spicedb-operator` | [charts/spicedb-operator](charts/spicedb-operator) | Local | SpiceDB operator |
| `keycloak-operator` | [charts/keycloak-operator](charts/keycloak-operator) | Local | Keycloak operator |
| `openbao` | `openbao/openbao` | External | OpenBao (Vault-compatible secret store) |
| `cluster-issuer` | [charts/cluster-issuer](charts/cluster-issuer) | Local | cert-manager ClusterIssuer resource |
| `opentelemetry-operator` | `opentelemetry-operator/opentelemetry-operator` | External | OpenTelemetry operator |
| `opentelemetry` | [charts/opentelemetry](charts/opentelemetry) | Local | OpenTelemetry Collector configuration |
| **`platform-orchestrator`** | [**charts/platform-orchestrator**](charts/platform-orchestrator) | **Local** | **Platform Orchestrator and its dependencies** ([values reference](charts/platform-orchestrator/README.md)) |

Each release can be toggled on/off via the helmfile environment state values (e.g., `installEnvoyGateway`, `installPostgres`, etc.).

## Installation in the KinD cluster

Run:
```bash
make create-kind
make deploy-local
make add-certs-macos # for MacOS, for other OSes see how to trust self-hosted certs there
```
OR (which is the same):
```bash
make setup-local
````

Add your domains to `/etc/hosts`, e.g.:
```
127.0.0.1 api.example.com
127.0.0.1 console.example.com
127.0.0.1 keycloak.example.com
```
(The domains are configured in `state-values.yaml` in `platformOrchestratorValues.global.[api|console|keycloak].hostname`)

## Installation in a random cluster with default values

Important: you need to switch your kubectl context to the correct cluster before running this command!

### Configure image registry

The default chart values use the public images under `ghcr.io/stellwerk-labs`,
so no registry credentials are required. To use a private mirror, override the
component image repositories and configure `global.imagePullSecrets`.

### Install Platform Orchestrator

```bash
make deploy
```

The chart-generated NATS token is intended for local bootstrap. Before a
production rollout, provision per-service and per-runner subject-scoped NATS
credentials and establish rotation and revocation procedures.

## Releasing the OCI chart

Chart publication is deliberately manual. Updating a component image does not
publish a chart by itself. When a coherent set of image tags is ready, update
the default image tags in `charts/platform-orchestrator/values.yaml`, increment
the chart version in `charts/platform-orchestrator/Chart.yaml`, and commit the
change. Create and push a signed `v<chart-version>` tag on that commit, then run
the **Release Chart** workflow from that tag. The workflow validates the tag and
chart version, lints and packages the chart, pushes it to
`oci://ghcr.io/stellwerk-labs/charts`, and creates the matching GitHub release.

## Organization and user management

### Create organizations with admin API

Get superuser token:
```bash
export SUPERUSER_TOKEN=$(kubectl get secret platform-orchestrator-secrets -n platform-orchestrator -o jsonpath='{.data.superUserToken}' | base64 --decode)
```

List all organizations (take the API URL from `platformOrchestratorValues.global.api.hostname` in `state-values.yaml`):
```bash
export API_URL=https://api.example.com
curl -k -H "Authorization: Bearer ${SUPERUSER_TOKEN}" ${API_URL}/admin/orgs
```

Create new organization:
```bash
curl -k -XPOST \
	 -H "Content-Type: application/json" -H "Authorization: Bearer ${SUPERUSER_TOKEN}" \
	 -d '{"id":"my-org"}' \
	 ${API_URL}/admin/orgs
```

### User management with Keycloak

- Get Keycloak admin credentials:
```bash
make print-keycloak-admin
```
- Login to your Keycloak instance (see the hostname in state-values.yaml, `platformOrchestratorValues.global.keycloak.hostname`), e.g. https://keycloak.example.com/
- Switch realm from `master` to `platform-orchestrator` (the realm is created with the helm installation, you can customize its name with helm values)
- Add a new user under Users and set a password
- Go to Console (see the hostname in state-values.yaml, `platformOrchestratorValues.global.gatewayApi.frontend.hostname`), e.g. https://console.example.com/ and click on SSO Login
- Put in your org name

## Smoke Tests

The `test/` directory contains a smoke test that provisions a minimal Platform Orchestrator setup (project, environment, runner, module) and triggers a deployment to validate the full pipeline end-to-end.

### Prerequisites

- [`terraform`](https://developer.hashicorp.com/terraform/install) installed
- [`octl`](https://docs.stellwerk.dev/platform-orchestrator/docs/integrations/cli/) installed and authenticated
- `kubectl` configured and pointing at the target cluster (used to pull cluster credentials)
- Platform Orchestrator deployed and accessible

### Setup

```bash
cd test/
terraform init
terraform apply
```

> **Note:** All variable defaults are pre-configured for the local KinD cluster set up via `make setup-local`. No variable overrides are needed when running against that cluster.

This provisions:
- A Platform Orchestrator project, environment, and environment type
- A Kubernetes runner registered with Platform Orchestrator
- A test resource type, module, and module rule

### Run the test

```bash
cd test/
bash run-test.sh
```

This deploys `manifest.yaml` using `octl`, which triggers the runner to execute the test module and verify the pipeline is working end-to-end.

### Teardown

```bash
cd test/
terraform destroy
```
