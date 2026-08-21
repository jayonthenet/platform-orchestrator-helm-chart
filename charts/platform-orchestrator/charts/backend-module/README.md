# backend-module

A Helm chart for deploying Platform Orchestrator backend module

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Pod affinity rules |
| config | object | `{}` | Environment variables included in the ConfigMap |
| env | list | `[]` | Additional environment variables (typically secret references) |
| envFromSecrets | list | `[]` | Names of secrets to load as environment variables via envFrom |
| gatewayApi | object | `{"route":{}}` | Gateway API HTTPRoute configuration (created when global Gateway API is enabled) |
| gatewayApiOidc | object | `{"route":{}}` | Gateway API HTTPRoute for OIDC provider (created when global Gateway API is enabled) |
| image | object | `{"pullPolicy":"IfNotPresent","repository":"docker.io/library/busybox","tag":"latest"}` | Container image configuration |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| image.repository | string | `"docker.io/library/busybox"` | Image repository |
| image.tag | string | `"latest"` | Image tag |
| nodeSelector | object | `{}` | Node selector constraints |
| otel | object | `{"enabled":false,"env":"production"}` | OpenTelemetry configuration |
| otel.enabled | bool | `false` | Enable OpenTelemetry instrumentation |
| otel.env | string | `"production"` | OTEL environment name (used in resource attributes) |
| podAnnotations | object | `{}` | Additional pod annotations |
| podLabels | object | `{}` | Additional pod labels |
| podSecurityContext | object | `{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}}` | Pod-level security context |
| replicaCount | int | `1` | Number of replicas |
| resources | object | `{}` | CPU/memory resource requests and limits |
| securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}` | Container-level security context |
| service | object | `{"createHeadless":false,"port":8080,"type":"ClusterIP"}` | Service configuration |
| service.createHeadless | bool | `false` | Create a headless service (required for data plane internal communication) |
| service.port | int | `8080` | Service port |
| service.type | string | `"ClusterIP"` | Service type |
| serviceAccount | object | `{"allowCreateToken":false,"annotations":{},"create":true,"name":""}` | Service account configuration |
| serviceAccount.allowCreateToken | bool | `false` | Allow the service account to create tokens (needed for Vault auth) |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.create | bool | `true` | Create a dedicated service account |
| serviceAccount.name | string | `""` | Override the service account name (defaults to fullname) |
| strategy | object | `{}` | Deployment update strategy |
| tolerations | list | `[]` | Pod tolerations |
