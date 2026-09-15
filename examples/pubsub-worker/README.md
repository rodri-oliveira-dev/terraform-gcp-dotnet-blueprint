# Pub/Sub push worker example

This root demonstrates the event-driven worker pattern in isolation:

```text
Publisher
   |
   v
Pub/Sub topic
   |
   v
Authenticated push subscription
   |
   v
Cloud Run Service (.NET worker)
   |
   +--> success: HTTP 2xx acknowledges the message
   |
   +--> repeated failure: dead-letter topic --> inspection subscription
```

The target is deliberately a **Cloud Run Service**, not a Cloud Run Job. Pub/Sub push delivery requires a request-serving HTTP endpoint; finite batch execution is modeled separately with the Cloud Run Job/Scheduler pattern.

## Identity separation

The example requires two pre-existing user-managed service accounts:

- `worker_runtime_service_account` is attached to the Cloud Run revision and represents application code at runtime;
- `push_service_account` is used by Pub/Sub to authenticate push requests and receives only `roles/run.invoker` on this worker service.

The Pub/Sub module separately uses the Google-managed Pub/Sub service agent for OIDC token minting and dead-letter forwarding. It grants that service agent only the resource-scoped permissions required for those transport operations.

## Prerequisites

- Terraform version from the repository `.terraform-version`;
- `run.googleapis.com` and `pubsub.googleapis.com` enabled;
- an existing worker runtime service account;
- an existing push-auth service account in the same project;
- a deployer allowed to create Cloud Run/Pub/Sub resources, attach the push-auth service account, and manage the narrow IAM relationships demonstrated here;
- a container image whose HTTP endpoint understands the standard Pub/Sub push envelope and returns success only after processing succeeds.

The example does not create service accounts because runtime identity lifecycle belongs to the IAM foundation rather than workload modules.

## Usage

Provide variables through an ignored local `.tfvars` file or another secure mechanism:

```hcl
project_id                     = "my-project"
location                       = "us-central1"
worker_image                   = "us-central1-docker.pkg.dev/my-project/apps/orders-worker:1.0.0"
worker_runtime_service_account = "orders-worker@my-project.iam.gserviceaccount.com"
push_service_account           = "orders-push@my-project.iam.gserviceaccount.com"
```

Validation without a live backend:

```bash
terraform init -backend=false -lockfile=readonly
terraform validate
```

Applying this example creates Google Cloud resources/IAM changes and can incur cost. CI and agents must not run `terraform apply` unless explicitly authorized.

## Reliability behavior

The example uses bounded acknowledgement, retry, retention and dead-letter settings. The worker must be idempotent: Pub/Sub push/dead-letter delivery is not an exactly-once processing contract, and configured delivery-attempt counts are best effort.

## Cloud Run ingress

The reused Cloud Run service module defaults to restrictive ingress. Pub/Sub push is intended to stay in the same Google Cloud project as this worker so the service can remain non-public while using authenticated delivery. The push identity is additionally constrained by `roles/run.invoker` on only this service.

## What this isolated example intentionally omits

- publishers or publisher IAM;
- application secrets;
- VPC/Redis integration;
- Cloud Run Jobs and Cloud Scheduler;
- remote environment state/backends;
- environment-level alert policy composition.

Those capabilities are implemented by the complete roots under `environments/dev` and `environments/prod`. Use this example only to understand the Pub/Sub/worker module boundary; use the environment roots for the full reference architecture.
