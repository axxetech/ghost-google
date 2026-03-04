terraform {
  backend "gcs" {
    bucket = "axxe-agency-tf-state"
    prefix = "clients"
  }
}
