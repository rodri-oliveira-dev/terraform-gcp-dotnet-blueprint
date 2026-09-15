terraform {
  backend "gcs" {
    prefix = "environments/prod"
  }
}
