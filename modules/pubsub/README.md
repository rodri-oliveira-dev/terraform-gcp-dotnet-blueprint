# Pub/Sub module

Reusable Terraform child module for Google Cloud Pub/Sub topics and subscriptions, including authenticated push delivery, retry policy, dead-letter forwarding, and a dead-letter inspection subscription.

The module is transport-focused. It does not create Cloud Run services, application runtime identities, publisher identities, or Cloud Run invocation IAM. Root modules compose those capabilities explicitly.

## Supported delivery modes

- **Pull:** leave `push_config = null`.
- **Authenticated push:** provide an HTTPS endpoint and a user-managed service account. Pub/Sub sends an OIDC token with each push request.

For the reference architecture, authenticated push targets a request-serving Cloud Run service. Pub/Sub is never modeled as directly executing a Cloud Run Job.

## Reliability defaults

- acknowledgement deadline: 60 seconds;
- message retention: 7 days;
- subscriptions never expire from inactivity;
- retry backoff: 10 to 600 seconds;
- dead lettering enabled;
- maximum delivery attempts: 10;
- a pull subscription is created on the dead-letter topic for inspection/reprocessing;
- acknowledged-message retention and message ordering are disabled unless explicitly enabled.

Pub/Sub dead-letter delivery attempts are best-effort. Consumers must remain idempotent and should not treat the configured attempt count as an exactly-once guarantee.

When dead-letter names are omitted, the module derives them by appending `-dead-letter` to the primary topic/subscription names. The resulting names are validated against Pub/Sub's 255-character limit during planning; callers with long primary names must provide explicit valid dead-letter names.

Subscription filters are deliberately restricted to printable ASCII and at most 256 characters. Because printable ASCII is one byte per character in UTF-8, this enforces Pub/Sub's 256-byte filter limit locally and avoids Unicode strings that would pass a character-count check but fail at provisioning time.

## IAM model

When `manage_service_agent_iam = true` (default), the module grants only the permissions Pub/Sub itself needs:

1. `roles/iam.serviceAccountTokenCreator` to the Google-managed Pub/Sub service agent **on the configured push-auth service account**, allowing it to mint OIDC tokens;
2. `roles/pubsub.publisher` to the Pub/Sub service agent **on the dead-letter topic**;
3. `roles/pubsub.subscriber` to the Pub/Sub service agent **on the primary subscription**, allowing dead-letter forwarding to acknowledge source messages.

The module intentionally does **not** grant `roles/run.invoker`. The root that composes Pub/Sub with a Cloud Run service owns that cross-module IAM relationship.

Three identities therefore remain distinct:

- **worker runtime service account** — attached to Cloud Run and used by application code;
- **push-auth service account** — represented in the Pub/Sub OIDC token and granted permission to invoke the target service;
- **Pub/Sub service agent** — Google-managed identity used to mint push tokens and forward dead-letter messages.

## Prerequisites

Before applying a root that consumes this module:

- `pubsub.googleapis.com` must be enabled;
- the push-auth service account must already exist and, for authenticated push, must be in the same project as the subscription;
- the Terraform deployment identity must have `iam.serviceAccounts.actAs` on the push-auth service account to attach it to the subscription;
- if this module manages service-agent IAM, the deployment identity also needs permission to update IAM on the push-auth service account, dead-letter topic, and primary subscription;
- the root must grant the push-auth service account permission to invoke its target, for example `roles/run.invoker` on a Cloud Run service.

These permissions should be granted at resource scope where the Google Cloud resource supports it.

## Example

```hcl
module "events" {
  source = "../../modules/pubsub"

  project_id        = "my-project"
  topic_name        = "orders-events"
  subscription_name = "orders-worker"

  push_config = {
    endpoint              = module.worker.uri
    service_account_email = "orders-push@my-project.iam.gserviceaccount.com"
    audience              = module.worker.uri
  }

  retry_policy = {
    minimum_backoff_seconds = 10
    maximum_backoff_seconds = 300
  }

  dead_letter = {
    max_delivery_attempts = 10
  }
}
```

See `examples/pubsub-worker` for composition with `modules/cloud-run-service` and resource-scoped Cloud Run invoker IAM.

## Inputs

| Name | Default | Description |
| --- | --- | --- |
| `project_id` | required | Google Cloud project ID. |
| `topic_name` | required | Primary topic name. |
| `subscription_name` | required | Primary subscription name. |
| `ack_deadline_seconds` | `60` | Initial acknowledgement deadline, 10-600 seconds. |
| `message_retention_seconds` | `604800` | Subscription retention, 10 minutes through 31 days. |
| `retain_acked_messages` | `false` | Retain acknowledged messages for replay. |
| `enable_message_ordering` | `false` | Preserve ordering for messages sharing an ordering key. |
| `filter` | `null` | Optional printable-ASCII subscription filter, maximum 256 bytes. |
| `retry_policy` | `10..600s` | Minimum and maximum redelivery backoff. |
| `dead_letter` | enabled | DLQ names, inspection subscription, and max attempts. Derived names are validated against Pub/Sub's 255-character limit. |
| `push_config` | `null` | HTTPS endpoint, push-auth service account, optional audience and payload-unwrapping settings. |
| `manage_service_agent_iam` | `true` | Manage narrowly scoped IAM required by Pub/Sub transport. |
| `labels` | `{}` | Labels applied to Pub/Sub resources. |

## Outputs

The module exposes primary topic/subscription IDs and names, optional dead-letter resource names, the Pub/Sub service-agent email, and the configured push-auth service-account email.

## Testing

Tests under `tests/` use Terraform's mock-provider support and `command = plan`; they do not create Google Cloud resources or require credentials.

```bash
terraform init -backend=false
terraform validate
terraform test
```

## Out of scope

This module does not create or manage:

- Cloud Run services or jobs;
- Cloud Run `roles/run.invoker` bindings;
- application runtime service accounts;
- publisher IAM;
- application secrets;
- Cloud Scheduler or batch-job execution;
- environment-specific provider/backend configuration.
