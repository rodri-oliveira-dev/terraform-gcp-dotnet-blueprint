# Development environment

This root composes the reusable modules into the complete development environment.

It uses development-oriented sizing and observability thresholds while preserving the same architectural boundaries as production.

## What this root creates

Foundation resources are always declared:

- required Google Cloud APIs, including Cloud Monitoring, without disabling shared APIs on destroy;
- one custom-mode VPC, workload subnet, and Private Service Access connection;
- one Memorystore for Redis instance using `PRIVATE_SERVICE_ACCESS`, Redis AUTH, and TLS;
- separate runtime service accounts for API, Pub/Sub worker, and batch workloads;
- separate transport identities for Pub/Sub push and Cloud Scheduler;
- Secret Manager metadata and secret-scoped accessor IAM for workload config, Redis AUTH, and the Redis server CA.

When `enable_workloads = true`, the root additionally creates:

- a private/authenticated Cloud Run API;
- a private/authenticated Cloud Run worker service;
- Pub/Sub topic/subscription, retry policy, dead-letter topic, and authenticated push delivery;
- `roles/pubsub.publisher` for the API runtime identity on the application topic only;
- a finite Cloud Run Job;
- a Cloud Scheduler job that invokes the Cloud Run Admin API with a dedicated trigger identity;
- resource-scoped `roles/run.invoker` grants for Pub/Sub and Scheduler identities;
- Cloud Monitoring alert policies for Cloud Run 5xx ratio, Pub/Sub backlog/DLQ, failed batch executions, and Redis pressure/rejected connections.

All three workloads use Direct VPC egress to reach Redis. No Serverless VPC Access connector is created.

## Why deployment is intentionally two-phase

The repository keeps application secret payloads outside Terraform. Memorystore also generates its Redis AUTH string and TLS server CA after the instance exists. Cloud Run, however, requires referenced Secret Manager versions to exist when a revision is deployed.

To avoid `terraform -target` as the normal workflow, this root uses `enable_workloads`:

1. **Foundation phase** — keep `enable_workloads = false`. Terraform can create APIs, network, Redis, identities, secret containers, and IAM without creating Cloud Run workloads that reference missing secret versions.
2. **Secret bootstrap** — a trusted operator or delivery process creates versions for every secret reported by the `secret_bootstrap` output. Redis AUTH and CA material must be retrieved from Memorystore and transferred without logging or committing the payloads.
3. **Workload phase** — set `enable_workloads = true`, review the plan, and apply. Cloud Run services/job, Pub/Sub delivery, Scheduler, and alert policies are then created against existing secret versions.

Terraform never receives those secret payloads as variables or outputs. Once workload activation has been applied in this state, changing `enable_workloads` back to false is intentionally rejected by the activation lock.

## Observability

Development uses the same signal set as production with more tolerant defaults:

- Cloud Run HTTP 5xx ratio: 10%;
- oldest unacknowledged Pub/Sub message: 600 seconds;
- Redis data-memory and system-memory usage: 90%;
- any dead-letter forwarding, failed Cloud Run Job execution, or rejected Redis connection remains alertable.

`observability_notification_channels` accepts only existing Cloud Monitoring notification channel resource names. Channel destinations and their sensitive configuration remain outside this state. An empty set creates alert policies without notification destinations.

See `../../docs/observability.md` for structured logging expectations, SLI/SLO guidance, telemetry ownership, and the rationale for not creating a generic dashboard.

## Remote state

The backend uses a fixed environment-specific prefix:

```hcl
prefix = "environments/dev"
```

The state bucket is intentionally supplied at initialization time rather than hard-coded:

```bash
terraform init \
  -backend-config="bucket=YOUR_TERRAFORM_STATE_BUCKET"
```

For validation without backend access, use:

```bash
terraform init -backend=false
terraform validate
```

## Configuration

Copy the example file locally and keep the real file uncommitted:

```bash
cp terraform.tfvars.example terraform.tfvars
```

At minimum, replace the project/image placeholders, review CIDRs, ownership labels, alert thresholds, and optional notification-channel resource names.

The development environment intentionally uses a 1 GiB `BASIC` Redis instance to reduce cost while retaining AUTH and TLS.

## Security boundaries

- The API is **not public**. This root does not grant `allUsers` or create an external load balancer/API gateway.
- API, worker, and batch use different runtime identities.
- Pub/Sub push and Cloud Scheduler use different transport identities from the workloads they invoke.
- Secret access is granted at individual-secret scope.
- The API receives publisher permission only on the application Pub/Sub topic.
- Notification-channel destinations are not stored in this environment configuration.
- Redis AUTH and CA payloads are not Terraform outputs.
- Terraform state remains sensitive because providers can persist computed sensitive attributes. Use the protected GCS state bucket created by `bootstrap/state`.
- `terraform apply` and secret population are operator-controlled actions; pull-request CI remains credential-free.

## Expected secret versions

After the foundation phase, inspect `terraform output secret_bootstrap` and create one current version for each returned secret ID. The exact payload format is an application contract and intentionally remains outside this infrastructure repository.

## Validation

Repository CI initializes this root with `-backend=false`, uses the committed provider lock file, and runs Terraform format/validate/test, TFLint, and Trivy gates. No CI step should create billable Google Cloud resources.
