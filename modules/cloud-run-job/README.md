# Cloud Run v2 job module

Reusable Terraform child module for finite .NET batch workloads that run to completion on Google Cloud Run Jobs.

The module owns only the Cloud Run Job configuration. Scheduling, invocation IAM, runtime IAM grants, Secret Manager resources, networking, and environment composition remain outside the module so callers can compose those policies explicitly.

## Job versus service

A Cloud Run Job does not expose a request-serving endpoint. It executes one or more tasks and exits. It must therefore be started explicitly through a supported mechanism such as the Cloud Run Admin API, Cloud Scheduler, Workflows, or an operator command.

Do not connect a Pub/Sub push subscription directly to this module. Event-driven Pub/Sub consumption belongs on a request-serving Cloud Run Service.

## Safe defaults

- explicit runtime service account is required;
- deletion protection defaults to `true`;
- one task and parallelism one by default;
- task timeout defaults to 600 seconds;
- failed tasks retry up to three times by default;
- CPU is deliberately limited to 1, 2, or 4 whole vCPU so the module does not silently depend on Gen2-only configurations;
- secret values are never module inputs; only Secret Manager identifiers and versions are accepted.

## Execution configuration

Cloud Run supports up to 10,000 tasks per job execution. Each task gets Cloud Run-managed `CLOUD_RUN_*` metadata such as task index, task count, and retry attempt. The module prevents callers from overriding those reserved variables.

`parallelism` must be a positive integer no greater than `task_count`. The platform may impose a lower regional concurrency quota at runtime.

`max_retries` accepts 0 through 10. A value of 0 means a failed task is not retried.

`task_timeout` uses whole seconds and is capped at 604800 seconds (7 days). GPU-specific limits are outside this module's current contract.

## Example

```hcl
module "batch" {
  source = "../../modules/cloud-run-job"

  project_id      = "my-project"
  name            = "nightly-reconciliation"
  location        = "us-central1"
  container_image = "us-central1-docker.pkg.dev/my-project/apps/reconciliation:1.0.0"
  service_account = "reconciliation-runtime@my-project.iam.gserviceaccount.com"

  task_count  = 4
  parallelism = 2
  max_retries = 3
  task_timeout = "1800s"

  environment_variables = {
    DOTNET_ENVIRONMENT = "Production"
  }

  secret_environment_variables = {
    DATABASE_PASSWORD = {
      secret  = "reconciliation-database-password"
      version = "latest"
    }
  }
}
```

The output `execution_uri` exposes the Cloud Run Admin API endpoint used to start the job:

```text
https://run.googleapis.com/v2/projects/PROJECT/locations/REGION/jobs/JOB:run
```

A caller may use that URI with Cloud Scheduler and an OAuth token from a dedicated scheduler service account.

## IAM boundaries

The runtime service account is the identity used by the .NET process while tasks run. This module does not grant that identity any permissions.

The identity that starts a job is separate. A scheduler or operator service account should receive an additive `roles/run.invoker` binding on the specific Cloud Run Job, not broad project-level Cloud Run permissions.

Secret Manager access also remains outside this module. Grant the runtime identity access only to the secrets it actually consumes.

## Inputs

| Name | Default | Purpose |
| --- | --- | --- |
| `project_id` | required | Google Cloud project. |
| `name` | required | Cloud Run Job name. |
| `location` | required | Job region. |
| `container_image` | required | Batch container image. |
| `service_account` | required | Existing runtime service account. |
| `task_count` | `1` | Number of tasks, 1–10000. |
| `parallelism` | `1` | Maximum concurrent tasks, not greater than task count. |
| `max_retries` | `3` | Retries per failed task, 0–10. |
| `task_timeout` | `600s` | Per-task timeout up to 7 days. |
| `resources` | `1` vCPU / `512Mi` | CPU and memory limits. |
| `environment_variables` | `{}` | Literal non-secret configuration. |
| `secret_environment_variables` | `{}` | Secret Manager references only. |
| `labels` | `{}` | Job labels. |
| `deletion_protection` | `true` | Provider-level deletion protection. |

## Outputs

- `id`
- `name`
- `location`
- `project`
- `service_account`
- `execution_uri`

## Testing

Tests use Terraform's mocked Google provider and `command = plan`, so they require no Google Cloud credentials and create no infrastructure.

```bash
terraform init -backend=false
terraform validate
terraform test
```

## Out of scope

- creating service accounts;
- runtime IAM grants;
- scheduler creation;
- invocation IAM;
- Secret Manager resources or payloads;
- Direct VPC egress;
- GPUs;
- explicit Gen2-only CPU configurations;
- immediate execution during `terraform apply`.
