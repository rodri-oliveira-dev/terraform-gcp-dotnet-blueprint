# Event-driven Pub/Sub worker pattern

Issue #6 intentionally separates two execution models:

1. **event-driven processing** uses Pub/Sub push delivery to a request-serving Cloud Run Service;
2. **finite batch processing** uses a Cloud Run Job that is started explicitly through a supported execution mechanism.

This document covers the first model only. Cloud Run Job/Scheduler composition is implemented in issue #6 part 2.

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
- ingress and deletion protection.

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
- decides names, sizing, labels, secrets, and environment policy.

This keeps reusable modules cohesive and prevents either module from reaching into the other implicitly.

## Identity model

The pattern uses three distinct identities:

| Identity | Responsibility | Example permission |
| --- | --- | --- |
| Worker runtime service account | Credentials used by .NET application code | Resource-specific runtime permissions such as secret access, added elsewhere |
| Push-auth service account | Identity carried in the OIDC token sent to Cloud Run | `roles/run.invoker` on the target service |
| Google-managed Pub/Sub service agent | Creates OIDC tokens and forwards dead-letter messages | Token Creator on the push-auth SA; publisher on DLQ topic; subscriber on source subscription |

Keeping the identities separate avoids granting application permissions to the transport identity or invocation permissions to the application runtime identity.

## Delivery semantics

A worker must be idempotent. The transport can retry a message when the endpoint returns a failure or does not acknowledge within the deadline. Dead-letter forwarding is also best-effort, including the configured maximum delivery-attempt count.

The reference defaults are intentionally bounded:

- 60-second acknowledgement deadline;
- 10-600 second retry window in the reusable module;
- 7-day message retention;
- 10 dead-letter delivery attempts;
- no subscription expiration from inactivity.

Environment roots can tune these values for the processing latency and failure modes of a concrete workload.

## Authentication prerequisites

Authenticated push requires all of the following:

- push-auth service account in the same project as the subscription;
- deployment identity with `iam.serviceAccounts.actAs` on that account;
- Pub/Sub service agent allowed to mint OIDC tokens for that account;
- push-auth account granted permission to invoke the target Cloud Run service.

The module uses additive, resource-scoped IAM members where the target resource supports them rather than project-wide authoritative policies.

## Failure handling

The dead-letter topic has its own inspection subscription so failed messages are retained for operator inspection or explicit reprocessing. Reprocessing is deliberately not automated by this module because retrying a poison message without remediation can create an infinite failure loop.

Monitoring, alerting, and environment-level operational policy are added in later roadmap work.
