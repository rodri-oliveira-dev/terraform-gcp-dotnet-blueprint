# Private networking foundation

## Purpose

The reference architecture uses a dedicated custom-mode VPC as the shared private-network boundary for Cloud Run workloads and managed services. Networking is intentionally modeled separately from workload compute, secrets, messaging, and cache resources so roots can compose those capabilities explicitly.

Issue #19 is split into two parts:

1. **Part 1:** VPC, workload subnet, allocated Private Service Access range, and Service Networking connection.
2. **Part 2:** optional Direct VPC egress for the existing Cloud Run service and Cloud Run Job modules.

This document describes the part 1 contract and the boundary that part 2 will consume.

## VPC and workload subnet

`modules/vpc-network` creates a custom-mode `google_compute_network` and one regional `google_compute_subnetwork`.

The custom-mode network disables Google Cloud's automatic regional subnet creation. Environment roots therefore own the address plan explicitly rather than inheriting the `10.128.0.0/9` auto-mode ranges.

The workload subnet:

- is IPv4-only in the current contract;
- enables Private Google Access by default;
- uses an explicit region and CIDR supplied by the caller;
- does not create firewall rules, NAT, or external IP resources.

Google Cloud allows IPv4 subnet prefixes from `/4` through `/29`, subject to prohibited/overlapping-range checks. The module validates the basic IPv4/prefix contract locally; Google Cloud remains authoritative for conflicts with existing routes, peer networks, and reserved ranges.

## Private Service Access

Private Service Access is separate from the workload subnet. It reserves an address range for a producer network and establishes a VPC peering relationship through the Service Networking API.

The module creates:

```text
google_compute_global_address
  purpose      = VPC_PEERING
  address_type = INTERNAL
        |
        v
google_service_networking_connection
  service = servicenetworking.googleapis.com
```

The allocated range is supplied as an explicit IPv4 CIDR. This keeps address planning visible in Terraform rather than allowing a provider service to select an arbitrary range.

For this blueprint, the accepted prefix range is `/8` through `/24`. The upper bound matches Memorystore for Redis Private Service Access guidance, which requires `/24` or a larger block when establishing the allocated range.

The caller must ensure that the Private Service Access allocation does not overlap:

- workload subnets;
- other allocated service ranges;
- VPC peering ranges;
- VPN or Interconnect routes;
- on-premises networks that may become reachable later.

## Service Networking lifecycle

`google_service_networking_connection` defaults to `deletion_policy = "PREVENT"` in this module.

This is deliberate. Once managed services consume the connection, deleting it can fail or break connectivity. A caller may set the policy to `DELETE` for an explicitly disposable environment, but that is an environment-level lifecycle decision and should be reviewed before apply.

The module does not expose `ABANDON` or `REMOVE_PEERING` as normal configuration options because both can leave the producer-side relationship or connectivity in a surprising state.

## API ownership

The module does not enable project APIs. Before apply, roots must ensure these APIs are enabled:

- `compute.googleapis.com`;
- `servicenetworking.googleapis.com`.

API enablement has a project-wide lifecycle and may be shared by multiple modules. Keeping it outside this child module avoids accidental API disablement or ownership conflicts during module removal.

## Direct VPC egress boundary

Cloud Run Direct VPC egress does not require a Serverless VPC Access connector. Cloud Run v2 supports a `vpc_access.network_interfaces` block containing a network and subnetwork, with an optional egress mode.

Part 1 exposes the future workload contract as:

```hcl
output "direct_vpc" {
  value = {
    network    = google_compute_network.this.name
    subnetwork = google_compute_subnetwork.this.name
  }
}
```

Part 2 will add an optional Direct VPC input to both `modules/cloud-run-service` and `modules/cloud-run-job`. Workloads that do not configure it will remain network-agnostic.

## Deliberate exclusions

The networking foundation does not create:

- Serverless VPC Access connectors;
- Cloud NAT or Cloud Router;
- internet-egress policy;
- workload firewall rules;
- Shared VPC host/service-project wiring;
- Memorystore resources;
- Cloud Run VPC configuration before issue #19 part 2.

Those capabilities should be added only when a concrete workload requires them, rather than broadening the network module preemptively.
