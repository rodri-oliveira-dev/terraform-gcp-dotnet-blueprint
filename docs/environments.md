# Environment composition

The repository now provides two complete root modules under `environments/`:

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
```

Runtime identities are separate for API, worker, and batch. Pub/Sub push and Cloud Scheduler use separate transport/trigger identities. The API receives publisher access only on its environment-specific topic.

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

These values demonstrate where environment policy belongs. They are reference defaults, not capacity recommendations for arbitrary workloads.

## Two-phase secret bootstrap

Both roots default `enable_workloads = false` because application secret payloads are intentionally outside Terraform and Memorystore generates AUTH/CA material only after creation.

The supported sequence is:

1. initialize the environment backend;
2. apply the foundation with workloads disabled;
3. populate versions for the secret IDs returned by `secret_bootstrap` through a trusted process;
4. enable workloads;
5. review the full plan;
6. apply through an approved operator/delivery path.

Do not use `terraform -target` as the normal deployment strategy and do not pass secret payloads through Terraform variables.

## State isolation

The same protected GCS bucket may host both roots, but each root has a fixed prefix:

```text
environments/dev
environments/prod
```

This prevents normal state operations in one root from addressing the other environment's state object.

## Deployment walkthrough

From the selected environment directory:

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config="bucket=YOUR_TERRAFORM_STATE_BUCKET"
terraform plan
```

Review the foundation plan, then apply only through an explicitly authorized operator/delivery process. After secret versions exist, set `enable_workloads = true`, generate a new plan, review it, and apply.

Pull-request CI uses `terraform init -backend=false`; it validates configuration without accessing the remote state backend or creating Google Cloud resources.

## Public ingress

Neither root grants unauthenticated invocation. The API URI may exist, but a public edge, API Gateway, external load balancer, or `allUsers` binding is intentionally outside the current reference architecture. Public exposure should be a separate explicit architectural decision.

## Observability

Environment composition deliberately does not create alert policies or dashboards. Cloud Monitoring/Logging defaults, SLO guidance, and alert policy composition are tracked as follow-up observability work so deployment topology and operational policy remain independently reviewable.
