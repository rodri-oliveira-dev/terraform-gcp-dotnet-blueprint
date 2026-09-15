# Observability architecture

Issue #24 adds Google Cloud observability as a separate architectural capability rather than embedding alert resources inside workload modules.

## Boundary

`modules/observability-alerts` consumes resource names from a root module and owns Cloud Monitoring alert policies only. `environments/dev` and `environments/prod` attach that capability to the resources they already own.

The module does not own:

- Cloud Run, Pub/Sub, Cloud Run Jobs, Redis, or their IAM;
- notification channels or their destinations/secrets;
- application logging libraries or OpenTelemetry SDK configuration;
- log-based metrics;
- workload-specific SLO targets.

Notification channels are injected as existing Cloud Monitoring resource names. E-mail addresses, Slack webhooks, PagerDuty integration keys, and other escalation destinations stay outside this repository and can be managed by an organization-owned Terraform state.

## Environment composition

Both environment roots enable `monitoring.googleapis.com` as part of their shared API dependency set. Alert policies are created only after `enable_workloads = true`, because the policies target the API, worker, Pub/Sub subscription, batch job, and Redis instance that belong to that environment.

The environments deliberately use different operational thresholds:

| Signal | Development | Production |
| --- | ---: | ---: |
| Cloud Run HTTP 5xx ratio | 10% | 5% |
| Pub/Sub oldest unacked age | 600 s | 300 s |
| Redis data-memory usage | 90% | 80% |
| Redis system-memory usage | 90% | 80% |

Dead-letter forwarding, failed Cloud Run Job executions, and rejected Redis connections trigger on any observed event in both environments.

These values are blueprint operating defaults. They are not contractual SLOs and should be adjusted from observed traffic, capacity, incident history, and product requirements.

## Selected platform signals

### Cloud Run services

The baseline availability signal is the ratio of HTTP 5xx responses to all requests using `run.googleapis.com/request_count` on the `cloud_run_revision` monitored resource. The policy aggregates across revisions of one named service before calculating the ratio so a rollout does not fragment the signal by revision.

### Pub/Sub

Two different failure modes are monitored on the primary subscription:

- `pubsub.googleapis.com/subscription/oldest_unacked_message_age` identifies a persistently stale backlog, which can indicate subscriber failure or insufficient processing throughput;
- `pubsub.googleapis.com/subscription/dead_letter_message_count` reports messages Pub/Sub forwards to dead-letter handling after delivery attempts are exhausted.

Using the direct dead-letter forwarding metric avoids depending on a specific backlog shape in the optional dead-letter inspection subscription.

### Cloud Run Jobs

`run.googleapis.com/job/completed_execution_count` is filtered to `result="failed"` for the configured job. A failed finite execution is treated as an event-oriented operational failure instead of averaging it away over a longer window.

### Memorystore for Redis

The baseline cache signals are:

- `redis.googleapis.com/stats/memory/usage_ratio` for Redis data-memory pressure;
- `redis.googleapis.com/stats/memory/system_memory_usage_ratio` for system-memory pressure;
- `redis.googleapis.com/stats/reject_connections_count` for clients rejected by the instance.

Redis is supporting infrastructure rather than the user-facing SLO itself. Redis alerts should inform diagnosis and capacity planning, while API or workflow SLIs describe customer impact.

## Structured logging expectations for .NET

Cloud Logging automatically receives stdout/stderr from Cloud Run. The application should therefore emit structured JSON rather than relying on unstructured multi-line text.

Recommended fields include:

- a concise message plus mapped severity level;
- stable application/component and environment identifiers;
- trace/span identifiers when distributed tracing is enabled;
- request or operation correlation identifiers;
- event/category identifiers suitable for aggregation;
- duration and outcome fields for important business operations;
- exception type and stack trace for failures.

Do not log credentials, authorization headers, cookies, Secret Manager payloads, Redis AUTH strings, personal data that is not operationally necessary, or entire request bodies by default.

Application telemetry ownership stays outside Terraform. The .NET application may use `Microsoft.Extensions.Logging`, OpenTelemetry, or another supported logging/tracing stack, but this repository does not force a library choice. Terraform owns the cloud resources and platform alert policy; application code owns semantic events, traces, custom metrics, and redaction.

## SLI and SLO guidance

An SLI should describe behavior users or upstream systems experience, not simply the health of one infrastructure component.

Reasonable starting points are:

- **API availability:** successful eligible requests / total eligible requests;
- **API latency:** proportion of eligible requests below a product-defined latency threshold;
- **asynchronous freshness:** messages completed before a product-defined age target;
- **batch reliability:** successful scheduled executions / expected executions in the measurement window.

DLQ volume, Redis memory, CPU, instance counts, and rejected connections are valuable diagnostic or leading indicators, but they should not automatically be promoted to product SLOs.

Choose SLO targets from business requirements and observed baseline behavior. For an SLO expressed as a success percentage, the error budget for a window is `1 - SLO target`; for example, a 99.9% target permits 0.1% unsuccessful eligible events in that window. This repository intentionally does not prescribe 99.9%, 99.95%, or another universal target.

Alert policies in this module are operational symptom/capacity alerts. Burn-rate alerting should be added only after a workload has a real SLO and a trustworthy SLI measurement source.

## Missing telemetry

The baseline metric conditions treat missing data as inactive. This is appropriate for services that can be intentionally idle and where absence of traffic is not automatically equivalent to an outage.

A workload that requires heartbeat or telemetry-absence detection should add that as an explicit environment policy rather than changing the meaning of the shared baseline alerts.

## Dashboards

No custom dashboard is created by this issue. Cloud Run, Pub/Sub, Cloud Run Jobs, Memorystore, and Cloud Monitoring already expose service-native metric views, and a generic dashboard that simply repeats those charts would add maintenance without a clear incident-response workflow.

A custom dashboard becomes justified when operators can name a durable question it answers, such as correlating API error rate, Pub/Sub backlog age, and Redis pressure during one incident. Such a dashboard should be added with that operational purpose documented rather than as decorative coverage.

## Operator workflow

1. Create notification channels in an organization-controlled process if notifications are required.
2. Put only their Cloud Monitoring resource names in `observability_notification_channels`.
3. Review the environment defaults in `observability_thresholds` and tune them when evidence supports a change.
4. Complete the normal two-phase workload bootstrap.
5. When `enable_workloads = true`, review the alert policies in the Terraform plan alongside the workload resources.
6. Use `terraform output observability_alert_policy_ids` to locate the policies managed by the environment.

Pull-request CI validates configuration without Google Cloud credentials and never applies alert policies.
