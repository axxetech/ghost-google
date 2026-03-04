resource "google_compute_firewall" "allow_http" {
  name    = "${var.client_name}-allow-http"
  project = google_project.client.project_id
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ghost-server"]

  depends_on = [time_sleep.wait_for_apis]
}

resource "google_compute_firewall" "allow_https" {
  name    = "${var.client_name}-allow-https"
  project = google_project.client.project_id
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ghost-server"]

  depends_on = [time_sleep.wait_for_apis]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.client_name}-allow-ssh"
  project = google_project.client.project_id
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ghost-server"]

  depends_on = [time_sleep.wait_for_apis]
}

resource "google_compute_address" "static_ip" {
  name    = "${var.client_name}-ghost-ip"
  project = google_project.client.project_id
  region  = var.region

  depends_on = [time_sleep.wait_for_apis]
}
