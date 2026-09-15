# Runtime identities and Secret Manager example

This root demonstrates the identity/secret boundary introduced by issue #7 without deploying Cloud Run workloads.

It creates:

- `orders-api` runtime identity;
- `orders-worker` runtime identity;
- `orders-database-url` secret metadata, readable only by the API identity;
- `orders-webhook-key` secret metadata, readable only by the worker identity.

No secret version or payload is created by Terraform.

## Prerequisites

- the IAM and Secret Manager APIs are enabled in the target project;
- the Terraform deployment identity can create service accounts and Secret Manager secrets;
- the deployment identity can update IAM policy on the specific secrets it creates.

Do not run `terraform apply` from CI or an agent unless explicitly authorized. Applying this example mutates real Google Cloud resources.

## Validate without creating infrastructure

```bash
terraform init -backend=false -input=false -lockfile=readonly
terraform validate
terraform plan -input=false -var='project_id=my-project'
```

The repository CI runs initialization/validation for the example but does not authenticate to Google Cloud or apply resources.

## Supplying secret payloads

After the metadata exists, a trusted operator or delivery system creates secret versions outside Terraform. For example, an operator can add a version with the Google Cloud CLI using stdin rather than committing a value to source control.

The exact secret-value bootstrap/rotation process is organization-specific and intentionally remains outside this reference root.

## Cloud Run integration contract

The outputs mirror the existing workload module inputs:

```hcl
module "api" {
  source = "../../modules/cloud-run-service"

  # ...
  service_account = module.api_identity.email

  secret_environment_variables = {
    DATABASE_URL = module.api_database_secret.secret_reference
  }
}
```

The same `{ secret, version }` object is accepted by `modules/cloud-run-job`.

## Least-privilege result

The API identity cannot read the worker secret and the worker identity cannot read the API secret because the module creates only per-secret `roles/secretmanager.secretAccessor` members. No project-level accessor role is granted.
