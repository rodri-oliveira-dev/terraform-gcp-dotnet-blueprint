# Memorystore for Redis module

Reusable Terraform child module for a secure, private Memorystore for Redis instance used by the reference .NET workloads.

The module owns only the Redis instance. VPC creation, Private Service Access, Cloud Run Direct VPC egress, runtime identities, Secret Manager payloads, and environment composition remain outside this module.

## Secure defaults

The module deliberately overrides several permissive provider defaults:

- `connect_mode = "PRIVATE_SERVICE_ACCESS"` is fixed by the module;
- an explicit fully qualified VPC network is required, so the Google Cloud default network is never selected implicitly;
- `tier = "STANDARD_HA"` by default;
- `redis_version = "REDIS_7_2"` by default;
- Redis AUTH is enabled by default;
- in-transit encryption defaults to `SERVER_AUTHENTICATION`;
- `deletion_policy = "PREVENT"` by default.

`BASIC` remains available for explicitly lower-cost environments, but selecting it does not disable AUTH or TLS.

## Networking contract

The instance uses Private Service Access rather than direct VPC peering. The caller must establish the Service Networking connection before the Redis instance is created.

With the repository network module, compose the dependency explicitly:

```hcl
module "cache" {
  source = "../../modules/memorystore-redis"

  project_id         = var.project_id
  name               = "orders-cache"
  region             = var.region
  authorized_network = module.network.network_id

  depends_on = [module.network]
}
```

The `depends_on` is intentional: `authorized_network` creates a data-flow dependency on the VPC, but the Redis API also requires the separate Private Service Access connection to be established first.

The module does not create a dedicated `reserved_ip_range`. With Private Service Access, Memorystore selects an available instance range from the service networking allocation established by `modules/vpc-network`.

## AUTH, TLS, and sensitive state

Redis AUTH and TLS solve different problems. AUTH requires clients to authenticate; TLS protects client/server traffic in transit. Both are enabled by default.

Memorystore generates the AUTH string. This module intentionally does **not** expose `google_redis_instance.auth_string` as an output and does not create a Secret Manager version from it. A trusted operator or delivery process should retrieve and distribute the AUTH material according to the application's secret lifecycle.

The Google provider can still persist provider-computed sensitive Redis attributes in Terraform state. Treat the state as sensitive even though the module outputs only non-secret endpoint metadata. The repository's remote-state bootstrap is the security boundary for that state.

When TLS is enabled, clients must support TLS 1.2 or later and trust the Memorystore server CA. CA retrieval/installation is an application/operator concern and certificate payloads are intentionally not emitted as module outputs.

## Usage

```hcl
module "cache" {
  source = "../../modules/memorystore-redis"

  project_id         = "my-project"
  name               = "orders-cache"
  region             = "us-central1"
  authorized_network = "projects/my-project/global/networks/orders-vpc"

  memory_size_gb = 2

  labels = {
    component  = "cache"
    managed-by = "terraform"
  }
}
```

For deterministic zonal placement on `STANDARD_HA`, callers may set different `location_id` and `alternative_location_id` values. If they are omitted, Google Cloud selects zones.

## Inputs

| Name | Default | Description |
| --- | --- | --- |
| `project_id` | required | Google Cloud project containing the Redis instance. |
| `name` | required | Redis instance ID, validated against the 1-40 character service contract. |
| `region` | required | Redis region. |
| `display_name` | `null` | Optional human-readable name. |
| `authorized_network` | required | Fully qualified VPC network resource ID. |
| `memory_size_gb` | `1` | Redis capacity from 1 through 300 GiB. |
| `tier` | `STANDARD_HA` | `STANDARD_HA` or explicitly `BASIC`. |
| `redis_version` | `REDIS_7_2` | Modern Redis version: 6.x, 7.0, or 7.2. |
| `auth_enabled` | `true` | Enables Redis AUTH. |
| `transit_encryption_mode` | `SERVER_AUTHENTICATION` | TLS mode. |
| `location_id` | `null` | Optional primary zone. |
| `alternative_location_id` | `null` | Optional secondary zone for `STANDARD_HA`. |
| `redis_configs` | `{}` | Supported Memorystore Redis configuration values. |
| `labels` | `{}` | Resource labels. |
| `deletion_policy` | `PREVENT` | Destructive lifecycle guard; `DELETE` is allowed only by explicit caller choice. |

## Outputs

The module exposes only non-secret integration metadata:

- `id`;
- `name`;
- `host`;
- `port`;
- `region`;
- `tier`;
- `redis_version`;
- `authorized_network`;
- `connection = { host, port, tls_enabled, auth_required }`.

It intentionally does not output the Redis AUTH string or server CA certificate payloads.

## Testing

Tests under `tests/` use Terraform provider mocks and plan mode. They require no Google Cloud credentials and create no infrastructure.

```bash
terraform init -backend=false
terraform validate
terraform test
```

## Out of scope

- Memorystore for Redis Cluster or Valkey;
- IAM authentication for Redis Cluster;
- read-replica scaling;
- persistence configuration;
- Secret Manager versions containing the generated AUTH string;
- CA certificate distribution;
- application/client configuration;
- VPC, Private Service Access, NAT, or firewall creation;
- environment-specific provider/backend configuration.
