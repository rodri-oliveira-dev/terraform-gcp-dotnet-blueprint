# Environment composition

The repository provides two complete root modules under `environments/`:

- `environments/dev` for cost-conscious development validation;
- `environments/prod` for production-oriented availability and sizing defaults.

Both roots compose the same reusable capabilities and keep environment policy in the root rather than leaking it into child modules.

## Shared architecture

```text
Cloud Run API
    |-- Secret Manager
    |-- Pub/Sub topic
    |-- Direct VPC egress --> Memorystore for Redis

Pub/Sub --> authenticated push --> Cloud Run worker
                                    |-- Secret Manager
                                    `-- Direct VPC egress --> Redis

Cloud Scheduler --> OAuth --> Cloud Run Admin API --> Cloud Run Job
                                                   |-- Secret Manager
                                                   `-- Direct VPC egress --> Redis

Cloud Monitoring alert policies
    |-- Cloud Run 5xx ratio
    |-- Pub/Sub backlog / DLQ
    |-- failed Cloud Run Job executions
    `-- Redis pressure / rejected connections
```

Runtime identities are separate for API, worker and batch. Pub/Sub push and Cloud Scheduler use separate transport/trigger identities. The API receives publisher access only on its environment-specific topic.

## Dev versus prod

| Policy | dev | prod |
| --- | --- | --- |
| State prefix | `environments/dev` | `environments/prod` |
| Workload subnet | `10.40.0.0/24` default | `10.60.0.0/24` default |
| PSA range | `10.50.0.0/16` default | `10.70.0.0/16` default |
| Redis tier | `BASIC` | `STANDARD_HA` |
| Redis memory | 1 GiB | 5 GiB default |
| API | 1 vCPU / 512 MiB, min 0, max 2 | 2 vCPU / 1 GiB, min 1, max 20 |
| Worker | 1 vCPU / 512 MiB, min 0, max 2 | 1 vCPU / 1 GiB, min 1, max 20 |
| Pub/Sub DLQ threshold | 10 attempts | 20 attempts |
| Batch | 1 task, parallelism 1, 1 vCPU / 512 MiB | 4 tasks, parallelism 2, 2 vCPU / 2 GiB |
| Scheduler retries | 3 | 5 |
| Cloud Run 5xx alert | 10% | 5% |
| Pub/Sub oldest unacked age | 600 seconds | 300 seconds |
| Redis memory alerts | 90% | 80% |

These values demonstrate where environment policy belongs. They are reference defaults, not capacity recommendations or contractual SLOs for arbitrary workloads.

## Two-phase secret bootstrap

Both roots default `enable_workloads = false` because application secret payloads are intentionally outside Terraform and Memorystore generates AUTH/CA material only after creation.

The supported sequence is:

1. initialize the environment backend;
2. plan/apply the foundation with workloads disabled;
3. populate versions for the secret IDs returned by `secret_bootstrap` through a trusted process;
4. set `enable_workloads = true`;
5. review the full plan;
6. apply through the controlled delivery path.

Once workload activation has been applied as `true`, changing it back to `false` is intentionally rejected by the activation lock. The flag is a bootstrap transition, not a general destroy switch.

Do not use `terraform -target` as the normal deployment strategy and do not pass secret payloads through Terraform variables.

## State isolation

The same protected GCS bucket may host both roots, but each root has a fixed prefix:

```text
environments/dev
environments/prod
```

This prevents normal state operations in one root from addressing the other environment's state object.

## Deployment workflow

Credential-free pull-request CI uses `terraform init -backend=false` and never authenticates to GCP.

After merge, manual workflows on `main` provide the controlled path:

- **Terraform plan** — WIF-authenticated, initializes the real GCS backend and produces a safe action/address summary without uploading the binary plan;
- **Terraform apply** — requires explicit environment/confirmation, blocks destructive changes by default, uses GitHub Environment protection, replans after approval and applies only when the plan fingerprint matches.

See `docs/terraform-deployment.md`.

## Public ingress

Neither root grants unauthenticated invocation. The API URI may exist, but a public edge, API Gateway, external load balancer, Cloud Armor, DNS/certificate setup or `allUsers` binding is intentionally outside the v1.0 reference architecture.

Public exposure should be a separate explicit architectural decision.

## Observability

Both environment roots enable `monitoring.googleapis.com` and compose `modules/observability-alerts` when workloads are active.

The signal set is shared while thresholds differ by environment. Notification destinations are injected as existing Cloud Monitoring notification channel resource names and remain outside this state.

Application structured logging/tracing semantics, product SLIs/SLOs and burn-rate policy remain workload responsibilities. See `docs/observability.md`.

## Operational guidance

For bootstrap order, IAM/secrets boundaries, state recovery, deletion protection, adoption checklist and release-readiness guidance, see `docs/production-readiness.md`. For common failure modes, see `docs/troubleshooting.md`.
