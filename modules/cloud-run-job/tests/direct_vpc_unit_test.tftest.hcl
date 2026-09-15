mock_provider "google" {
  override_during = plan
}

variables {
  project_id      = "example-project"
  name            = "example-batch"
  location        = "us-central1"
  container_image = "us-docker.pkg.dev/example-project/apps/batch:1.0.0"
  service_account = "batch-runtime@example-project.iam.gserviceaccount.com"
}

run "keeps_networking_disabled_by_default" {
  command = plan

  assert {
    condition     = length(google_cloud_run_v2_job.this.template[0].template[0].vpc_access) == 0
    error_message = "Direct VPC egress must remain disabled unless explicitly configured."
  }
}

run "configures_direct_vpc_egress" {
  command = plan

  variables {
    direct_vpc = {
      network    = "blueprint-vpc"
      subnetwork = "blueprint-us-central1"
      tags       = ["batch", "serverless"]
    }
  }

  assert {
    condition = (
      google_cloud_run_v2_job.this.template[0].template[0].vpc_access[0].egress == "PRIVATE_RANGES_ONLY" &&
      google_cloud_run_v2_job.this.template[0].template[0].vpc_access[0].network_interfaces[0].network == "blueprint-vpc" &&
      google_cloud_run_v2_job.this.template[0].template[0].vpc_access[0].network_interfaces[0].subnetwork == "blueprint-us-central1" &&
      toset(google_cloud_run_v2_job.this.template[0].template[0].vpc_access[0].network_interfaces[0].tags) == toset(["batch", "serverless"])
    )
    error_message = "Direct VPC configuration must map network, subnetwork, safe egress default, and tags into the Cloud Run task template."
  }
}

run "supports_all_traffic_egress" {
  command = plan

  variables {
    direct_vpc = {
      network    = "blueprint-vpc"
      subnetwork = "blueprint-us-central1"
      egress     = "ALL_TRAFFIC"
    }
  }

  assert {
    condition     = google_cloud_run_v2_job.this.template[0].template[0].vpc_access[0].egress == "ALL_TRAFFIC"
    error_message = "Explicit ALL_TRAFFIC egress must be forwarded to Cloud Run."
  }
}

run "rejects_invalid_direct_vpc_egress" {
  command = plan

  variables {
    direct_vpc = {
      network    = "blueprint-vpc"
      subnetwork = "blueprint-us-central1"
      egress     = "INTERNET_ONLY"
    }
  }

  expect_failures = [
    var.direct_vpc,
  ]
}

run "rejects_invalid_network_tag" {
  command = plan

  variables {
    direct_vpc = {
      network    = "blueprint-vpc"
      subnetwork = "blueprint-us-central1"
      tags       = ["Invalid_Tag"]
    }
  }

  expect_failures = [
    var.direct_vpc,
  ]
}
