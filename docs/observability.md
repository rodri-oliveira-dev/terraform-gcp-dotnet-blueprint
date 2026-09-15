# Observability architecture

Issue #24 adds Google Cloud observability as a separate architectural capability rather than embedding alert resources inside workload modules.

This document currently describes **part 1: reusable infrastructure alert defaults**. Environment attachment, dashboards, structured-logging expectations, and SLI/SLO guidance are intentionally completed in part 2.

## Boundary

`modules/observability-alerts` consumes resource names from a root module and owns Cloud Monitoring alert policies only.

It does not own:

- Cloud Run, Pub/Sub, Cloud Run Jobs, Redis, or their IAM;
- notification channels or their destinations/secrets;
- application logging libraries or OpenTelemetry SDK configuration;
- log-based metrics;
- dashboards;
- workload-specific SLO targets.

This keeps runtime infrastructure independent from operational escalation policy and lets dev/prod attach the same monitoring capability with environment-specific thresholds or notification channels.

## Selected platform signals

### Cloud Run services

The baseline availability signal is the ratio of HTTP 5xx responses to all requests using `run.googleapis.com/request_count` on the `cloud_run_revision` monitored resource. The policy aggregates across revisions of one named service before calculating the ratio so a rollout does not fragment the signal by revision.

The default threshold is 5% sustained for five minutes. This is an operational default for the blueprint, not an SLO declaration.

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

Memory thresholds default to 80% sustained for five minutes. Rejected connections trigger on any observed event because they represent an explicit refusal of workload traffic.

## Notification channels

Notification channels are deliberately injected as existing resource names. The reusable module never creates e-mail, Slack, webhook, SMS, PagerDuty, or other channel resources because those destinations are organization-specific and can contain sensitive configuration.

A root may initially attach no channel and still create the alert policies. This is useful for development or for organizations where channel ownership lives in a separate Terraform state/project.

## Missing telemetry

The baseline metric conditions treat missing data as inactive. This is appropriate for a blueprint where services can be intentionally idle and where absence of traffic is not automatically equivalent to an outage.

A production workload that requires heartbeat or telemetry-absence detection should add that as an explicit environment policy rather than changing the meaning of these shared signal defaults.

## Part 2

The remaining issue #24 work will:

- attach the alert module to `environments/dev` and `environments/prod` without duplicating policy resources;
- ensure the Monitoring API is part of each environment dependency set;
- define environment-specific notification-channel and threshold inputs;
- document structured JSON logging expectations for .NET and the boundary between platform logs and application telemetry;
- document practical SLI/SLO selection and error-budget guidance without prescribing universal targets;
- add dashboards only where they improve incident response and routine operations.
