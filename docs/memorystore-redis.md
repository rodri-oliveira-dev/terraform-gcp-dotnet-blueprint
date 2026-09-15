# Memorystore for Redis

## Purpose

The reference architecture uses Memorystore for Redis as a private managed cache reachable from Cloud Run workloads through Direct VPC egress.

Redis is intentionally modeled as its own capability. The Redis module consumes an existing VPC and assumes Private Service Access already exists; it does not own networking, Cloud Run, identities, or application secrets.

## Network path

The intended path is:

```text
Cloud Run Service / Job
        |
        | Direct VPC egress
        v
Workload subnet / VPC
        |
        +------------------------------+
        |                              |
        v                              v
Private Google APIs             Service Networking peering
                                       |
                                       v
                              Memorystore for Redis
```

`modules/vpc-network` creates the custom-mode VPC, workload subnet, allocated Private Service Access range, and the connection to `servicenetworking.googleapis.com`.

`modules/memorystore-redis` receives only the fully qualified VPC network ID and fixes `connect_mode` to `PRIVATE_SERVICE_ACCESS`. The composition root must also ensure that the Service Networking connection is established before the Redis instance. In the isolated example this is represented with `depends_on = [module.network]`.

Google Cloud recommends Private Service Access over direct peering for Memorystore for Redis. The module therefore does not expose `DIRECT_PEERING` as a supported mode.

## Security defaults

The module defaults to:

- `STANDARD_HA` tier;
- Redis 7.2;
- Redis AUTH enabled;
- TLS in-transit encryption with `SERVER_AUTHENTICATION`;
- explicit authorized VPC network;
- provider-level deletion prevention.

These defaults are production-oriented rather than cost-minimal. A caller may explicitly choose `BASIC`, but AUTH and TLS remain enabled unless the caller independently opts out of them.

## Redis AUTH boundary

When AUTH is enabled, Memorystore generates the AUTH string. The Terraform provider exposes that string as a computed sensitive attribute.

The module does not return the AUTH string through an output and does not write it into a Secret Manager version. This preserves the repository rule that secret payload lifecycle is managed outside Terraform configuration.

A trusted operator or delivery process should retrieve the AUTH string with the narrowly scoped Google Cloud permission required for that operation and place it into the application's secret-delivery mechanism. Rotation should be treated as an operational procedure because toggling Redis AUTH generates a new value.

Terraform state remains sensitive: provider-computed values can be persisted there even when they are not declared as outputs. The GCS remote-state controls from `bootstrap/state` therefore remain part of the Redis security boundary.

## TLS boundary

`SERVER_AUTHENTICATION` encrypts Redis client/server traffic. Memorystore supports TLS 1.2 or later for this feature.

A TLS-enabled client must:

1. connect to the provider-reported Redis host and secure port;
2. authenticate when AUTH is enabled;
3. trust the server CA exposed by Memorystore;
4. handle certificate rotation and transient reconnects.

The module deliberately does not emit CA certificate payloads. CA retrieval and installation belong to application/runtime delivery rather than the infrastructure module interface.

## Availability and sizing

`STANDARD_HA` is the default tier because it provides primary/replica high availability across zones. Callers may optionally provide distinct `location_id` and `alternative_location_id` values; otherwise Google Cloud chooses zones.

`BASIC` remains useful for development or explicitly disposable environments. The module rejects `alternative_location_id` with the BASIC tier because that field has meaning only for `STANDARD_HA`.

Memory is configurable from 1 through 300 GiB. Capacity selection remains an environment-level decision.

## Redis version contract

The module intentionally limits the public contract to:

- `REDIS_6_X`;
- `REDIS_7_0`;
- `REDIS_7_2`.

Older Redis versions supported by the underlying API are excluded from this reference module so new environments do not adopt legacy versions accidentally. Redis 7.2 is the default.

## Lifecycle

The Redis resource defaults to `deletion_policy = "PREVENT"`. A caller must make a deliberate code change to `DELETE` before Terraform can destroy the instance.

In-transit encryption is a creation-time security property in Memorystore and cannot simply be disabled later on an instance created with TLS enabled. Treat changes to transport security as lifecycle-sensitive changes and review the plan before apply.

## API prerequisites

Roots consuming the complete network/cache capability need:

- `compute.googleapis.com`;
- `servicenetworking.googleapis.com`;
- `redis.googleapis.com`.

These project-wide APIs are not enabled by the child modules because API lifecycle is a root/project concern.

## Deliberate exclusions

This implementation does not add:

- Memorystore for Redis Cluster or Valkey;
- IAM authentication for Redis Cluster;
- read-replica scaling;
- Redis persistence configuration;
- CMEK configuration;
- AUTH string replication into Secret Manager;
- firewall/NAT resources;
- application-specific client setup.

Those should be introduced only when a concrete requirement justifies the additional lifecycle and operational complexity.
