# Scheduled Cloud Run Job example

This root composes `modules/cloud-run-job` with Cloud Scheduler to demonstrate a supported finite-batch execution path:

```text
Cloud Scheduler
      |
      | OAuth 2.0 access token
      v
Cloud Run Admin API
      |
      | POST .../jobs/JOB:run
      v
Cloud Run Job
      |
      v
.NET batch container runs to completion
```

It intentionally does **not** use Pub/Sub to launch the job. Pub/Sub push delivery requires a request-serving endpoint and is demonstrated separately by `examples/pubsub-worker`.

## Identity separation

The example expects two pre-existing service accounts:

- `runtime_service_account` — attached to Cloud Run Job tasks and used by the .NET batch process when accessing Google Cloud APIs;
- `scheduler_service_account` — used only by Cloud Scheduler to authenticate the Cloud Run Admin API request.

The example grants the scheduler identity `roles/run.invoker` on the specific Cloud Run Job through the additive `google_cloud_run_v2_job_iam_member` resource. It does not grant Cloud Run permissions at project scope.

The two identities must be different so runtime permissions and trigger permissions remain independently scoped.

## Authentication choice

The Scheduler target is a Google API endpoint (`run.googleapis.com`), so the example uses an OAuth access token rather than an OIDC token.

The target URI is produced by the job module:

```text
https://run.googleapis.com/v2/projects/PROJECT/locations/REGION/jobs/JOB:run
```

The HTTP request is `POST` with an empty JSON object. Cloud Scheduler authenticates as `scheduler_service_account` using the `cloud-platform` OAuth scope.

## Prerequisites

Before applying the example:

1. enable the Cloud Run and Cloud Scheduler APIs in the target project;
2. create the runtime and scheduler service accounts;
3. grant the runtime service account only the workload permissions required by the batch code;
4. ensure the Terraform deployer can attach the runtime identity and configure the Scheduler OAuth identity;
5. provide an existing container image;
6. authenticate Terraform using ADC or Workload Identity Federation.

No service account key is required or expected.

## Example variables

```hcl
project_id                = "my-project"
location                  = "us-central1"
container_image           = "us-central1-docker.pkg.dev/my-project/apps/reconciliation:1.0.0"
runtime_service_account   = "batch-runtime@my-project.iam.gserviceaccount.com"
scheduler_service_account = "batch-scheduler@my-project.iam.gserviceaccount.com"
schedule                  = "0 2 * * *"
time_zone                 = "America/Sao_Paulo"
```

Do not commit real `.tfvars` files.

## Validation

This is an example root, not an environment deployment root. CI initializes it with the backend disabled and validates it without authenticating to Google Cloud or creating resources.

```bash
terraform init -backend=false -lockfile=readonly
terraform validate
```

The reusable job module is additionally exercised by native Terraform tests under `modules/cloud-run-job/tests/`.

## Production considerations

- Batch tasks should be idempotent because retries can re-run a failed task.
- Use workload-specific runtime IAM rather than broad project roles.
- Grant Secret Manager access at the narrowest practical resource scope.
- Choose task count and parallelism according to workload partitioning and regional Cloud Run quotas.
- Treat Scheduler retries separately from Cloud Run task retries: Scheduler retries the **execution request**, while `max_retries` retries a failed **task inside an execution**.
- Use observability/alerting for failed Scheduler attempts and failed Cloud Run executions before adopting the pattern in production.
