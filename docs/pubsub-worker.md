# Event-driven Pub/Sub worker pattern

The blueprint separates two execution models:

1. **event-driven processing** uses Pub/Sub push delivery to a request-serving Cloud Run Service;
2. **finite batch processing** uses a Cloud Run Job started explicitly through a supported execution mechanism.

This document covers the first model. Batch/Scheduler behavior is documented separately in `docs/batch-processing.md`.

## Request flow

```text
Publisher
   |
   v
Primary Pub/Sub topic
   |
   v
Push subscription
   |  OIDC token: push-auth service account
   v
Cloud Run Service (.NET worker)
   |
   +--> 2xx: message acknowledged
   |
   +--> failure / ack deadline exceeded
             |
             v
          retry policy
             |
             +--> repeated failure --> dead-letter topic --> inspection subscription
```

Pub/Sub is not modeled as directly invoking a Cloud Run Job. A push subscription requires an HTTP endpoint that can acknowledge delivery through its response status.

## Module boundaries

### `modules/cloud-run-service`

Owns the request-serving worker runtime:

- container image and resources;
- scaling and concurrency;
- runtime service account;
- environment variables and Secret Manager references;
- ingress and deletion protection;
- optional Direct VPC egress.

### `modules/pubsub`

Owns transport and delivery behavior:

- primary topic and subscription;
- authenticated push configuration;
- acknowledgement deadline and message retention;
- retry policy;
- dead-letter topic and inspection subscription;
- transport-specific IAM for the Pub/Sub service agent.

### Root/environment composition

Owns relationships between capabilities:

- grants the push-auth service account `roles/run.invoker` on the target Cloud Run Service;
- supplies the Cloud Run URI to the Pub/Sub module;
- supplies existing runtime and push-auth service accounts;
- grants publisher permission to the API runtime identity on its environment topic;
- composes secrets, Direct VPC egress, Redis connectivity and observability;
- decides names, sizing, labels and environment policy.

This keeps reusable modules cohesive and prevents either module from reaching into the other implicitly.

## Identity model

The pattern uses three distinct identities:

| Identity | Responsibility | Example permission |
| --- | --- | --- |
| Worker runtime service account | Credentials used by .NET application code | Resource-specific runtime permissions such as secret access |
| Push-auth service account | Identity carried in the OIDC token sent to Cloud Run | `roles/run.invoker` on the target service |
| Google-managed Pub/Sub service agent | Creates OIDC tokens and forwards dead-letter messages | Token Creator on the push-auth SA; publisher on DLQ topic; subscriber on source subscription |

Keeping the identities separate avoids granting application permissions to the transport identity or invocation permissions to the application runtime identity.

## Delivery semantics

A worker must be idempotent. The transport can retry a message when the endpoint returns a failure or does not acknowledge within the deadline. Dead-letter forwarding and the maximum delivery-attempt count are best-effort behaviors rather than exactly-once processing guarantees.

The reusable module provides bounded retry/retention inputs; environment roots choose actual values. The current reference environments use different DLQ thresholds to demonstrate environment policy.

## Authentication prerequisites

Authenticated push requires:

- push-auth service account in the same project as the subscription;
- deployment identity allowed to attach/manage the required service-account relationships;
- Pub/Sub service agent allowed to mint OIDC tokens for the push-auth account;
- push-auth account granted permission to invoke the target Cloud Run service.

The module uses additive, resource-scoped IAM members where supported rather than project-wide authoritative policies.

## Failure handling and observability

The dead-letter topic has an inspection subscription so failed messages are retained for operator inspection or explicit reprocessing. Reprocessing is deliberately not automated because retrying a poison message without remediation can create an infinite failure loop.

Environment roots compose Cloud Monitoring alert policies for stale backlog age and dead-letter forwarding through `modules/observability-alerts`. Operational thresholds differ between `dev` and `prod`; product-specific retry/replay procedures remain an application/operations responsibility.

See `docs/observability.md`, `docs/environments.md` and `docs/troubleshooting.md`.
