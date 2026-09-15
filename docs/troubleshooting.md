# Troubleshooting

This guide covers common failure modes for the blueprint. Use it with the component-specific documentation rather than treating it as a substitute for provider/service diagnostics.

## Remote backend and state

### `terraform init` cannot access the GCS backend

Check:

- `GCP_TERRAFORM_STATE_BUCKET` matches the bucket created by `bootstrap/state`;
- the deployment/operator identity has object access on that bucket;
- the selected root uses the expected fixed prefix (`environments/dev` or `environments/prod`);
- Application Default Credentials/WIF are actually active in the execution context;
- organization policy does not block the bucket/project access path.

Do not work around backend authorization by copying state into the repository or switching the environment root back to local state.

### State lock or generation problems

A failed/interrupted run can leave an operation requiring investigation. Do not automate `force-unlock` as a generic fix.

1. Confirm no Terraform operation is still running.
2. Identify the environment/root and current GCS state generation.
3. Preserve evidence before modifying state.
4. Use `force-unlock` only when the lock is proven stale and the lock ID is understood.

For suspected corruption, follow the recovery sequence in `docs/production-readiness.md` and `bootstrap/state/README.md`.

### Unexpected create/delete/replacement actions

Stop before apply. Common causes include:

- wrong project or state bucket/prefix;
- repository variables pointing to the wrong environment;
- provider/version changes;
- manually changed resources (drift);
- renamed Terraform addresses/resources;
- deletion-protection or one-way activation changes.

Compare the current state, selected project, Git commit and configuration before continuing.

## Workload Identity Federation

### `google-github-actions/auth` cannot exchange the token

Verify:

- the workflow runs from `refs/heads/main` when using the default trust condition;
- `GCP_WORKLOAD_IDENTITY_PROVIDER` is the full provider resource name;
- `GCP_SERVICE_ACCOUNT` is the intended deployment service account;
- immutable `repository_owner_id` and `repository_id` in the bootstrap match the current repository;
- the principal still has `roles/iam.workloadIdentityUser` on the deployment service account;
- IAM Credentials and STS APIs are enabled in the WIF project.

Immediately after creating/changing the pool/provider, allow for eventual consistency before assuming the trust expression is wrong.

### Authentication succeeds but Terraform gets `403`

WIF proves identity, not authorization. Inspect the exact permission in the provider/API error and compare it with the deployment capability map in `docs/terraform-deployment.md`.

Do not solve this by adding `roles/owner` or `roles/editor`. Add the narrow capability/resource permission required by the operation.

## Provider and API errors

### API is disabled

The environment roots declare required services using `google_project_service`. A plan can therefore show API enablement as part of the desired state.

If Terraform cannot even inspect/manage Service Usage, ensure the deployment identity has the required Service Usage permissions and that organization policy permits enablement.

`gcp-integration-preflight.sh` can be used in a trusted read-only operator context to compare the required API catalog with the selected dev project.

### Provider schema/version mismatch

Check:

- `.terraform-version` and the Terraform version used by the runner;
- `required_providers` constraints;
- the committed `.terraform.lock.hcl` for executable roots;
- whether Dependabot/provider changes updated lock files consistently.

Run the same offline gates as CI before attributing the failure to GCP.

## VPC and Private Service Access

### PSA connection cannot be created

Check:

- `servicenetworking.googleapis.com` is available/enabled as planned;
- the allocated PSA CIDR does not overlap the workload subnet or routed networks;
- the deployment identity can manage the network and Service Networking relationship;
- the VPC identifier passed to Redis is the expected environment network.

Do not use the workload subnet as the PSA allocation. They are separate address-management concerns.

### Cloud Run cannot reach Redis

Check:

- Direct VPC egress is configured on the service/job;
- service/job and subnet are in compatible regions/configuration;
- Redis uses the expected VPC/Private Service Access connection;
- application configuration uses the Terraform-provided Redis host/port;
- TLS and AUTH settings match the Redis instance and the external secret-bootstrap values.

The blueprint does not create a Serverless VPC Access connector, so troubleshooting should not assume one exists.

## Memorystore for Redis

### Redis creation fails

Typical causes:

- PSA connection/range not ready or invalid;
- unsupported region/tier/version combination;
- insufficient IAM;
- quota/capacity constraints;
- deletion-protection/update constraints on an existing instance.

Review the exact provider/API error before changing network topology.

### Application cannot authenticate or validate TLS

Terraform does not deliver Redis AUTH or server CA payloads to the application. Verify the trusted external bootstrap process populated the expected Secret Manager versions and that runtime identities have `secretAccessor` on the correct secret.

Never print AUTH/CA secret payloads in CI logs while diagnosing connectivity.

## Secret Manager

### Cloud Run revision fails because a secret version is missing

This usually indicates the environment was activated before the external secret-bootstrap phase completed.

1. Inspect `terraform output secret_bootstrap` for the environment.
2. Verify each referenced secret has the expected current version.
3. Verify the workload runtime identity has secret-level accessor permission.
4. Run a new plan before apply.

Do not add `google_secret_manager_secret_version` with plaintext payloads simply to bypass the lifecycle boundary.

## Cloud Run services

### Service is deployed but not publicly reachable

This is expected. The reference roots do not grant unauthenticated invocation and the default service ingress is restrictive.

If public access is a product requirement, design an explicit edge/authentication solution (for example an external load balancer/API gateway pattern) rather than silently adding `allUsers` to the blueprint baseline.

### Revision does not become ready

Investigate:

- container image URI/accessibility;
- startup behavior and port contract;
- missing/invalid secret references;
- runtime service-account permissions;
- VPC/Redis dependencies;
- CPU/memory configuration and application logs.

Terraform can create the service resource but cannot prove the business application is healthy.

## Pub/Sub worker flow

### Push delivery receives 401/403

Check:

- the push subscription uses the dedicated push service account;
- the worker has a resource-scoped `roles/run.invoker` binding for that identity;
- the OIDC audience matches the worker URI;
- Pub/Sub service-agent token-creation permissions are intact where managed by the module.

Do not grant public invocation to make authenticated push delivery work.

### Messages accumulate or go to DLQ

Review:

- worker readiness/errors;
- ack deadline and processing time;
- retry policy;
- idempotency behavior;
- DLQ max delivery attempts;
- `oldest_unacked_message_age` and dead-letter alerts.

A DLQ is evidence of exhausted delivery, not a substitute for a replay/repair process.

## Cloud Run Job and Scheduler

### Scheduler cannot start the job

The Scheduler target is the Cloud Run Admin API execution URI, not a request endpoint on the job.

Check:

- the dedicated Scheduler identity has `roles/run.invoker` on the job;
- OAuth token configuration uses that identity;
- the job name/location/URI are from the selected environment;
- Scheduler and Cloud Run APIs are enabled/authorized.

### Job starts but fails

Inspect execution logs and verify image, secret references, runtime IAM, Redis connectivity, task/parallelism assumptions and application idempotency. The monitoring baseline alerts on failed completed executions but does not diagnose application logic.

## Cloud Monitoring

### Alert policy exists but never fires

Confirm:

- the target resource actually emits the selected metric;
- traffic/executions exist during the evaluation window;
- threshold/duration are appropriate;
- missing-data behavior is understood;
- resource names/region in the environment match the monitored resource labels.

Infrastructure alerts are not universal SLOs.

### Alert fires but no notification arrives

The blueprint does not create notification destinations. Verify the supplied `observability_notification_channels` resource names exist and that their organization-owned destinations/integration credentials are valid.

## GitHub deployment workflows

### Manual plan refuses to run from a feature branch

Expected behavior. Credentialed workflows are restricted to `main` to match the WIF trust boundary.

### Apply stops because the plan fingerprint changed

The environment/state/data sources changed between pre-approval plan and apply-time replan. This is a safety stop. Start a new deployment run and review the new plan instead of bypassing the fingerprint check.

### Apply blocks delete/replacement actions

`allow_destroy` defaults to `false`. A replacement includes a delete action and is intentionally blocked unless the dispatcher explicitly opts in after review. Lifecycle/provider deletion protections can still block the operation even with `allow_destroy=true`.

### Workload activation cannot be changed back to `false`

Expected after an applied activation. The activation lock prevents a partial teardown path. To intentionally decommission an environment, design and review a dedicated decommission procedure instead of using the bootstrap flag as a destroy switch.

## When to stop and escalate

Stop before apply when:

- the selected project/state prefix is uncertain;
- a plan contains unexpected deletes/replacements;
- state recovery or force-unlock is being considered;
- IAM requires broadening beyond the documented capability boundary;
- secret payloads appear in logs/plans/configuration;
- network changes could overlap existing enterprise CIDRs;
- a production deployment needs protections removed.

The blueprint intentionally favors explicit operator review over automated recovery in these cases.
