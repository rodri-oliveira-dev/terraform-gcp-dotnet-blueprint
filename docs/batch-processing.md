# Scheduled batch processing

## Purpose

Finite batch workloads use Cloud Run Jobs, not request-serving Cloud Run Services. A job starts explicitly, executes one or more tasks to completion, and then stops.

This repository models scheduled execution through Cloud Scheduler calling the authenticated Cloud Run Admin API.

```text
Cloud Scheduler
      |
      | POST + OAuth access token
      v
run.googleapis.com/v2/.../jobs/JOB:run
      |
      v
Cloud Run Job
      |
      +--> task 0
      +--> task 1
      +--> ...
```

## Why Pub/Sub does not execute the job

A Pub/Sub push subscription delivers an HTTP request to a request-serving endpoint. Cloud Run Jobs do not expose such an endpoint; they expose an execution API.

The two runtime patterns therefore remain deliberately separate:

```text
Event-driven
Pub/Sub --> authenticated push --> Cloud Run Service (.NET worker)

Finite / scheduled batch
Cloud Scheduler --> OAuth --> Cloud Run Admin API --> Cloud Run Job
```

Do not model Pub/Sub as directly invoking a Cloud Run Job.

## Cloud Run Job module

`modules/cloud-run-job` owns only the batch workload configuration:

- container image;
- explicit runtime service account;
- task count;
- parallelism;
- retries per task;
- per-task timeout;
- CPU and memory;
- literal environment variables;
- Secret Manager references;
- labels and deletion protection.

It exposes `execution_uri`, the supported Cloud Run Admin API `:run` endpoint. It does not create scheduler resources or invocation IAM.

## Scheduler composition

`examples/scheduled-cloud-run-job` demonstrates the trigger boundary. Cloud Scheduler sends an authenticated HTTP `POST` to `execution_uri` with an OAuth access token generated for a dedicated scheduler service account.

The scheduler identity receives the additive `roles/run.invoker` role on the individual Cloud Run Job. That role contains `run.jobs.run`, so no project-wide Cloud Run role is required for the trigger.

The Scheduler retry policy and Cloud Run task retry policy solve different failures:

- Scheduler retry handles failure to submit/start an execution request;
- Cloud Run `max_retries` handles a task that started but exited unsuccessfully.

Batch code should be designed for idempotency because either boundary can retry work after transient failures.

## Identity model

Use separate identities for separate trust boundaries:

```text
Scheduler service account
  -> roles/run.invoker on one Cloud Run Job
  -> can submit job executions

Batch runtime service account
  -> attached to Cloud Run task template
  -> accesses only APIs/resources needed by the .NET batch workload
```

Neither identity needs a long-lived key. Terraform does not create secret payloads or service-account keys.

## Limits represented by the module

The module validates relevant platform constraints before provider execution:

- `task_count`: 1–10000;
- `parallelism`: positive integer, not greater than task count;
- `max_retries`: 0–10;
- `task_timeout`: positive whole seconds, up to 604800 seconds (7 days);
- CPU: 1, 2, or 4 whole vCPU under the module's current non-Gen2-specific contract;
- compatible CPU/memory ranges;
- reserved `CLOUD_RUN_` and `X_GOOGLE_` environment names are rejected.

Regional quotas may impose a lower practical parallelism ceiling than the configured task count.

## Secret handling

Secret values are not Terraform inputs. The module only accepts Secret Manager secret identifiers and versions. A later IAM/Secret Manager composition grants the runtime identity `secretAccessor` only on the secrets it needs.

## Validation

The job module includes native plan-mode tests using a mocked Google provider, so CI validates defaults and invalid inputs without executing a job or authenticating to Google Cloud.

The example root is initialized with its backend disabled and a committed provider lock file. No infrastructure is created during pull-request validation.
