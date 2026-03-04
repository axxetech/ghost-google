resource "google_project" "client" {
  name            = "AXXE ${var.client_name}"
  project_id      = "axxe-${var.client_name}"
  billing_account = var.billing_account_id

  labels = {
    managed-by = "terraform"
    client     = var.client_name
  }
}

resource "google_project_service" "compute" {
  project = google_project.client.project_id
  service = "compute.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "secretmanager" {
  project = google_project.client.project_id
  service = "secretmanager.googleapis.com"

  disable_on_destroy = false
}

resource "time_sleep" "wait_for_apis" {
  depends_on = [
    google_project_service.compute,
    google_project_service.secretmanager,
  ]

  create_duration = "60s"
}
