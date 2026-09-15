mock_provider "google" {}

variables {
  project_id = "example-project"
  account_id = "orders-api"
}

run "reject_short_account_id" {
  command = plan

  variables {
    account_id = "short"
  }

  expect_failures = [
    var.account_id,
  ]
}

run "reject_uppercase_account_id" {
  command = plan

  variables {
    account_id = "Orders-Api"
  }

  expect_failures = [
    var.account_id,
  ]
}

run "reject_account_id_ending_with_hyphen" {
  command = plan

  variables {
    account_id = "orders-api-"
  }

  expect_failures = [
    var.account_id,
  ]
}

run "reject_overlong_description" {
  command = plan

  variables {
    description = join("", [for i in range(257) : "a"])
  }

  expect_failures = [
    var.description,
  ]
}
