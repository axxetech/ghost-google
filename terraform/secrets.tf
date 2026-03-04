resource "google_secret_manager_secret" "ghost_env" {
  secret_id = "ghost-env"
  project   = google_project.client.project_id

  replication {
    auto {}
  }

  labels = {
    client = var.client_name
  }

  depends_on = [google_project_service.secretmanager]
}

output "secret_add_command" {
  description = "Command to add .env content to the secret"
  value       = "gcloud secrets versions add ghost-env --project=${google_project.client.project_id} --data-file=YOUR_ENV_FILE.env"
}
