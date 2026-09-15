# VPC network example

This isolated root demonstrates the networking foundation introduced by issue #19.

It creates:

- one custom-mode VPC network;
- one regional IPv4 workload subnet;
- Private Google Access on that subnet;
- one explicitly allocated Private Service Access range;
- one Service Networking connection to `servicenetworking.googleapis.com`.

It does **not** create Cloud Run workloads, Serverless VPC Access connectors, Redis, firewall rules, Cloud NAT, or Cloud Router.

## Prerequisites

Before planning or applying this example, the target project must have these APIs enabled:

- `compute.googleapis.com`;
- `servicenetworking.googleapis.com`.

The deployment identity also needs permissions to create VPC/subnet/global-address resources and manage the private service networking connection.

## Validate without creating infrastructure

```bash
terraform init -backend=false -input=false -lockfile=readonly
terraform validate
terraform plan -input=false -var='project_id=my-project'
```

The example intentionally has no backend because it is not a production environment root.

## Address plan

The example uses:

```text
Workload subnet:        10.20.0.0/24
Private Service Access: 10.30.0.0/16
```

These ranges are examples only. Real environment roots must coordinate CIDRs with existing VPCs, peering, VPN/Interconnect routes, Shared VPC policy, and other allocated ranges.

## Direct VPC workload contract

The root exposes `output.direct_vpc`, which can be passed directly to either Cloud Run module:

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

The output supplies the network and subnetwork names. The workload modules default Direct VPC egress to `PRIVATE_RANGES_ONLY` and no network tags. A caller that intentionally routes all outbound traffic through the VPC can extend the object explicitly:

```hcl
direct_vpc = merge(module.network.direct_vpc, {
  egress = "ALL_TRAFFIC"
  tags   = ["serverless"]
})
```

`ALL_TRAFFIC` may require Cloud NAT or another routed internet-egress design; this example does not create that infrastructure.

## Lifecycle warning

The Service Networking connection defaults to `deletion_policy = "PREVENT"`. This avoids accidental removal of a private-services connection that may later be used by Memorystore or another producer service.

Applying this example creates real Google Cloud networking resources. Agents and CI must not run `terraform apply` or `terraform destroy` unless explicitly authorized.
