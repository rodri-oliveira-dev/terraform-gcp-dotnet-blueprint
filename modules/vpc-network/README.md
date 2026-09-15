# VPC network module

Creates the private networking foundation used by Cloud Run Direct VPC egress and managed services that rely on Private Service Access.

The module owns one custom-mode VPC, one regional IPv4 workload subnet, one allocated VPC peering range, and one Service Networking connection. It deliberately does not create Serverless VPC Access connectors, Cloud NAT, Cloud Router, workload firewall rules, or managed service instances.

## Security and lifecycle defaults

- auto-created subnets are disabled;
- the workload subnet is IPv4-only;
- Private Google Access is enabled on the workload subnet by default;
- the Service Networking connection uses `deletion_policy = "PREVENT"` by default;
- no firewall rule opens inbound access;
- no public IP, NAT gateway, or internet-egress path is created;
- Service Networking API enablement remains a root/project prerequisite instead of being owned by this child module.

`PREVENT` makes accidental deletion of the Private Service Access connection fail early. For an explicitly disposable environment, callers can set `private_service_access_deletion_policy = "DELETE"` after reviewing whether producer services still depend on the connection.

## Private Service Access

Private Service Access requires an allocated internal range with `purpose = "VPC_PEERING"`, followed by a connection to `servicenetworking.googleapis.com`.

The module requires an explicit CIDR for that allocated range instead of asking Google Cloud to choose one. This keeps address planning visible in code and lets later environment roots coordinate non-overlapping ranges.

For the reference architecture, `private_service_access_cidr` accepts IPv4 prefixes from `/8` through `/24`. Memorystore for Redis documents `/24` or a larger range for establishing Private Service Access. The caller remains responsible for ensuring that the range does not overlap workload subnets, peer networks, VPN/Interconnect routes, or other allocated ranges; Google Cloud performs the authoritative overlap validation.

## API prerequisites

Before applying a root that consumes this module, enable at least:

- `compute.googleapis.com`;
- `servicenetworking.googleapis.com`.

The module intentionally does not manage these project-wide APIs because their lifecycle is shared by other infrastructure.

## Example

```hcl
module "network" {
  source = "../../modules/vpc-network"

  project_id   = "my-project"
  network_name = "blueprint-vpc"

  subnet_name          = "blueprint-us-central1"
  subnet_region        = "us-central1"
  subnet_ip_cidr_range = "10.20.0.0/24"

  private_service_access_range_name = "blueprint-managed-services"
  private_service_access_cidr       = "10.30.0.0/16"
}
```

The `direct_vpc` output exposes exactly the network and subnet names expected by the optional `direct_vpc` inputs of both Cloud Run modules:

```hcl
module "api" {
  source = "../../modules/cloud-run-service"

  # ...
  direct_vpc = module.network.direct_vpc
}

module "batch" {
  source = "../../modules/cloud-run-job"

  # ...
  direct_vpc = module.network.direct_vpc
}
```

The workload modules default that connection to `PRIVATE_RANGES_ONLY` and no network tags. This module remains responsible only for the VPC/subnet lifecycle.

## Inputs

| Name | Default | Description |
| --- | --- | --- |
| `project_id` | required | Project containing the network. |
| `network_name` | required | Custom-mode VPC name. |
| `routing_mode` | `REGIONAL` | Dynamic routing mode: `REGIONAL` or `GLOBAL`. |
| `mtu` | `1460` | VPC MTU, 1300-8896 bytes. |
| `subnet_name` | required | Regional workload subnet name. |
| `subnet_region` | required | Workload subnet region. |
| `subnet_ip_cidr_range` | required | IPv4 subnet CIDR with prefix `/4` through `/29`. |
| `private_ip_google_access` | `true` | Enable Private Google Access on the workload subnet. |
| `private_service_access_range_name` | required | Name of the allocated VPC peering range. |
| `private_service_access_cidr` | required | Explicit IPv4 range reserved for Private Service Access, `/8` through `/24`. |
| `private_service_access_deletion_policy` | `PREVENT` | Safe lifecycle policy; explicitly set `DELETE` only for disposable networks. |

## Outputs

The module exposes network/subnet IDs and names, subnet region/CIDR, a `direct_vpc` composition object, the allocated Private Service Access range name/CIDR, and the resulting Service Networking peering name.

## Testing

Tests under `tests/` run with a mocked Google provider and `command = plan`. They do not create networking resources or require Google Cloud credentials.

```bash
terraform init -backend=false
terraform validate
terraform test
```

## Out of scope

- Cloud Run workload lifecycle beyond the typed `direct_vpc` output contract;
- Serverless VPC Access connectors;
- Memorystore/Redis resources;
- Cloud NAT or Cloud Router;
- workload-specific firewall rules;
- Shared VPC host/service-project orchestration;
- environment-specific provider/backend configuration.
