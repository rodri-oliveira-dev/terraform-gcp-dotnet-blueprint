mock_provider "google" {}

variables {
  project_id = "example-project"
  secret_id  = "orders-database-url"
}

run "reject_secret_id_with_spaces" {
  command = plan

  variables {
    secret_id = "orders database url"
  }

  expect_failures = [
    var.secret_id,
  ]
}

run "reject_secret_id_over_platform_limit" {
  command = plan

  variables {
    secret_id = join("", [for i in range(256) : "a"])
  }

  expect_failures = [
    var.secret_id,
  ]
}

run "reject_non_service_account_accessor" {
  command = plan

  variables {
    accessor_service_accounts = {
      api_runtime = "user@example.com"
    }
  }

  expect_failures = [
    var.accessor_service_accounts,
  ]
}

run "reject_empty_accessor_key" {
  command = plan

  variables {
    accessor_service_accounts = {
      "" = "orders-api@example-project.iam.gserviceaccount.com"
    }
  }

  expect_failures = [
    var.accessor_service_accounts,
  ]
}

run "reject_empty_replication_location" {
  command = plan

  variables {
    replication_locations = [""]
  }

  expect_failures = [
    var.replication_locations,
  ]
}

run "reject_empty_reference_version" {
  command = plan

  variables {
    reference_version = ""
  }

  expect_failures = [
    var.reference_version,
  ]
}
