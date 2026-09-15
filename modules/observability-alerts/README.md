# Cloud Monitoring alert defaults module

This module owns a focused set of Cloud Monitoring alert policies for the reference .NET runtime architecture. It consumes identifiers for infrastructure that already exists and creates no application workloads, notification destinations, dashboards, log-based metrics, or SLO resources.

## What it monitors

When the corresponding target is supplied, the module creates policies for:

- **Cloud Run services** — sustained HTTP 5xx ratio using `run.googleapis.com/request_count`, with a 5% default threshold over five minutes;
- **Pub/Sub primary subscription** — oldest unacknowledged message age using `pubsub.googleapis.com/subscription/oldest_unacked_message_age`;
- **Pub/Sub dead-letter forwarding** — any forwarded undeliverable message using `pubsub.googleapis.com/subscription/dead_letter_message_count`;
- **Cloud Run Job** — completed executions whose `result` label is `failed` using `run.googleapis.com/job/completed_execution_count`;
- **Memorystore for Redis** — data-memory and system-memory pressure plus rejected client connections.

The defaults are intentionally infrastructure-oriented signals. They are not universal application SLOs and should be tuned using real traffic, workload behavior, and error budgets.

## Notification boundary

The module never creates `google_monitoring_notification_channel` resources and never accepts e-mail addresses, Slack tokens, webhook secrets, PagerDuty keys, or similar destination configuration.

Callers may supply existing channel resource names:

```hcl
notification_channels = [
  "projects/example-project/notificationChannels/1234567890",
]
```

An empty set is valid. Policies still exist and produce incidents in Cloud Monitoring, but no external channel is notified until a caller attaches one.

## Example

```hcl
module "alerts" {
  source = "../../modules/observability-alerts"

  project_id  = "example-project"
  environment = "prod"
  location    = "us-central1"

  cloud_run_services = {
    api    = "blueprint-prod-api"
    worker = "blueprint-prod-worker"
  }

  cloud_run_job_name       = "blueprint-prod-batch"
  pubsub_subscription_name = "blueprint-prod-worker"
  redis_instance_id        = "blueprint-prod-cache"

  notification_channels = var.notification_channels
}
```

## Thresholds

The portable defaults are:

| Signal | Default | Evaluation |
| --- | ---: | --- |
| Cloud Run 5xx ratio | 5% | sustained for 5 minutes |
| Pub/Sub oldest unacked message | 300 seconds | sustained for 5 minutes |
| Redis data memory usage | 80% | sustained for 5 minutes |
| Redis system memory usage | 80% | sustained for 5 minutes |
| Pub/Sub dead-letter forwarding | any message | event-oriented |
| Cloud Run Job failed execution | any failed execution | event-oriented |
| Redis rejected connections | any rejected connection | event-oriented |

Only the portable capacity/ratio thresholds are configurable through the `thresholds` object. Event-oriented policies intentionally trigger on the first observed event because each event represents a concrete failure path worth investigation in this reference architecture.

## Missing data

Metric-threshold conditions use `EVALUATION_MISSING_DATA_INACTIVE`. Lack of telemetry by itself does not create an incident. This avoids turning an idle Cloud Run service, a quiet Pub/Sub subscription, or an unused Redis instance into a false positive. Availability of telemetry itself belongs to broader operational policy and can be added by callers when the workload requires it.

## Lifecycle

Alert policies use `deletion_policy = "DELETE"`. They are operational configuration, not durable data-plane resources, so deleting the module should remove the policies instead of blocking an environment teardown or abandoning unmanaged policies.

## Security and state

- notification destination secrets are outside this module;
- no application secret values are accepted or emitted;
- policy documentation contains only resource identifiers and responder guidance;
- Terraform state contains policy configuration and notification channel resource names, but not notification-channel secret material created elsewhere;
- enabling or disabling policies does not mutate the monitored workloads.

## Testing

Native Terraform tests use the mocked Google provider and plan mode. They verify target selection, metric/filter contracts, defaults, channel wiring, and input validation without Google Cloud credentials or billable resources.

## Environment composition and operating guidance

The module is already attached to both production roots:

- `environments/dev/observability.tf` applies development-oriented thresholds and optional notification channels;
- `environments/prod/observability.tf` applies production-oriented thresholds and optional notification channels.

See [`docs/observability.md`](../../docs/observability.md) for the completed operating guidance, including structured logging expectations, telemetry ownership, SLI/SLO selection, error budgets, and the dashboard policy used by this blueprint.
