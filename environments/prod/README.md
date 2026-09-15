# Production environment

This root composes the reusable modules into the production counterpart of `environments/dev`.

It keeps the same architectural boundaries as development while applying explicit production-oriented sizing, availability, retry, state-isolation, and observability policy.

## Production policy differences

Compared with `dev`, this root uses:

- a separate GCS backend prefix: `environments/prod`;
- separate VPC, subnet, Private Service Access range, service accounts, secrets, messaging resources, and workloads;
- Memorystore `STANDARD_HA` instead of `BASIC`;
- 5 GiB Redis capacity by default, configurable through `redis_memory_size_gb`;
- API: 2 vCPU / 1 GiB, minimum 1 instance, maximum 20;
- worker: 1 vCPU / 1 GiB, minimum 1 instance, maximum 20;
- Pub/Sub dead-letter threshold of 20 attempts and retry backoff up to 600 seconds;
- batch: 4 tasks, parallelism 2, 2 vCPU / 2 GiB, 5 task retries, 30-minute task timeout;
- Scheduler retry count of 5;
- stricter observability thresholds than development.

These are reference defaults rather than universal production requirements. Capacity planning, SLOs, traffic profile, recovery objectives, and budget should drive final values in a real system.

## Two-phase deployment

Application secret payloads and Memorystore-generated AUTH/CA material remain outside Terraform, so production uses the same controlled two-phase process as development:

1. Keep `enable_workloads = false` and apply the foundation: APIs, networking, Redis, identities, Secret Manager metadata, and IAM.
2. Populate the Secret Manager versions listed by `terraform output secret_bootstrap` using a trusted process. Never log or commit Redis AUTH or CA payloads.
3. Set `enable_workloads = true`, review the complete production plan, obtain the required approval, and apply the workloads and alert policies.

This avoids using `terraform -target` as the normal deployment model and prevents Terraform variables/source from carrying application secret payloads. Once production workloads have been activated in this state, changing `enable_workloads` back to false is intentionally rejected by the activation lock.

## Observability

Production defaults are:

- Cloud Run HTTP 5xx ratio: 5%;
- oldest unacknowledged Pub/Sub message: 300 seconds;
- Redis data-memory and system-memory usage: 80%;
- any dead-letter forwarding, failed Cloud Run Job execution, or rejected Redis connection remains alertable.

`observability_notification_channels` accepts only existing Cloud Monitoring channel resource names. E-mail addresses, webhook URLs, PagerDuty integration keys, and similar destination configuration must be owned outside this root.

These alert thresholds are operational baselines, not SLO commitments. Define product SLIs/SLOs independently and use burn-rate alerting only when a trustworthy SLI and target exist. See `../../docs/observability.md` for the full operating model.

## Remote state

Production has a fixed state prefix:

```hcl
prefix = "environments/prod"
```

Initialize the backend with the protected bucket created by `bootstrap/state`:

```bash
terraform init \
  -backend-config="bucket=YOUR_TERRAFORM_STATE_BUCKET"
```

For credential-free validation:

```bash
terraform init -backend=false
terraform validate
```

The `dev` and `prod` prefixes must never be reused for another environment.

## Configuration

Copy the example file locally and keep real tfvars uncommitted:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Review at least:

- production `project_id`;
- immutable image digests or reviewed release tags;
- CIDR allocation and overlap with existing routes;
- `redis_memory_size_gb`;
- batch schedule and time zone;
- production alert thresholds and notification-channel resource names;
- ownership/cost labels.

## Security boundaries

- The API remains authenticated and non-public by default; there is no `allUsers` grant.
- API, worker, and batch use independent runtime identities.
- Pub/Sub push and Scheduler use dedicated transport/trigger identities.
- API publisher access is scoped to the production event topic.
- Secret access is granted on individual Secret Manager resources.
- All workloads use Direct VPC egress to reach the production Redis instance.
- Notification-channel destinations are not stored in this environment configuration.
- Redis AUTH and CA payloads are never exposed as Terraform outputs.
- Provider-computed sensitive values can exist in Terraform state, so the GCS state bucket is part of the security boundary.
- Production apply remains an operator/approved delivery action; pull-request validation is credential-free.

## Validation

Repository CI validates this root with the committed provider lock file and `terraform init -backend=false`, followed by Terraform validation, formatting, tests, TFLint, and Trivy. CI must not create production resources.
