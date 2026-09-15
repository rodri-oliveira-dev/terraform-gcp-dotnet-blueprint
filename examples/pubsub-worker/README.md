# Pub/Sub push worker example

This root demonstrates the event-driven half of issue #6:

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

The target is deliberately a **Cloud Run Service**, not a Cloud Run Job. Pub/Sub push delivery requires a request-serving HTTP endpoint; finite batch execution is modeled separately in issue #6 part 2.

## Identity separation

The example requires two pre-existing user-managed service accounts:

- `worker_runtime_service_account` is attached to the Cloud Run revision and represents application code at runtime;
- `push_service_account` is used by Pub/Sub to authenticate push requests and receives only `roles/run.invoker` on this worker service.

The Pub/Sub module separately uses the Google-managed Pub/Sub service agent for OIDC token minting and dead-letter forwarding. It grants that service agent only the resource-scoped permissions required for those transport operations.

## Prerequisites

- Terraform 1.16.x;
- `run.googleapis.com` and `pubsub.googleapis.com` enabled;
- an existing worker runtime service account;
- an existing push-auth service account in the same project;
- a deployer allowed to create Cloud Run/Pub/Sub resources, attach the push-auth service account (`iam.serviceAccounts.actAs`), and manage the narrow IAM bindings demonstrated here;
- a container image whose HTTP endpoint understands the standard Pub/Sub push envelope and returns a success status only after processing succeeds.

The example does not create service accounts because runtime identity lifecycle belongs to the IAM foundation rather than to workload modules.

## Usage

Create a local, ignored `.tfvars` file or provide variables through another secure mechanism:

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

Applying this example would create billable Google Cloud resources and IAM changes. Agents and CI must not run `terraform apply` unless explicitly authorized.

## Reliability behavior

The example uses:

- a 60-second acknowledgement deadline;
- retry backoff from 10 to 300 seconds;
- 7-day subscription retention;
- dead-letter forwarding after approximately 10 delivery attempts;
- a dead-letter inspection subscription;
- no subscription expiration from inactivity.

The worker must be idempotent. Pub/Sub push and dead-letter delivery are not an exactly-once processing contract, and the configured maximum delivery attempts is best-effort.

## Cloud Run ingress

The reused Cloud Run service module defaults to internal ingress. Pub/Sub push is intended to stay in the same Google Cloud project as this worker so the service can remain non-public while still using authenticated delivery. The push identity is additionally constrained by `roles/run.invoker` on only this service.

## What this example does not model

- publishers or publisher IAM;
- application secrets;
- VPC/Redis integration;
- Cloud Run Jobs;
- Cloud Scheduler;
- environment state/backends.

Those concerns are composed in later roadmap steps.
