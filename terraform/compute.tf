resource "google_service_account" "ghost_vm" {
  account_id   = "${var.client_name}-ghost-vm"
  display_name = "Ghost VM Service Account for ${var.client_name}"
  project      = google_project.client.project_id

  depends_on = [time_sleep.wait_for_apis]
}

resource "google_project_iam_member" "vm_secret_accessor" {
  project = google_project.client.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.ghost_vm.email}"
}

resource "google_project_iam_member" "vm_log_writer" {
  project = google_project.client.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.ghost_vm.email}"
}

resource "google_compute_disk" "data" {
  name    = "${var.client_name}-ghost-data"
  project = google_project.client.project_id
  zone    = var.zone
  size    = var.data_disk_size_gb
  type    = "pd-standard"

  labels = {
    client = var.client_name
  }

  depends_on = [time_sleep.wait_for_apis]
}

resource "google_compute_instance" "ghost" {
  name         = "${var.client_name}-ghost"
  project      = google_project.client.project_id
  zone         = var.zone
  machine_type = var.machine_type

  tags = ["ghost-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.boot_disk_size_gb
      type  = "pd-standard"
    }
  }

  attached_disk {
    source      = google_compute_disk.data.self_link
    device_name = "ghost-data"
  }

  network_interface {
    network = "default"

    access_config {
      nat_ip = google_compute_address.static_ip.address
    }
  }

  service_account {
    email  = google_service_account.ghost_vm.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    client-name   = var.client_name
    client-domain = var.client_domain
    repo-url      = var.repo_url
    repo-branch   = var.repo_branch
  }

  metadata_startup_script = templatefile("${path.module}/startup.sh", {
    client_name   = var.client_name
    client_domain = var.client_domain
    repo_url      = var.repo_url
    repo_branch   = var.repo_branch
    project_id    = google_project.client.project_id
  })

  labels = {
    client     = var.client_name
    managed-by = "terraform"
  }

  depends_on = [
    google_compute_firewall.allow_http,
    google_compute_firewall.allow_https,
    google_compute_firewall.allow_ssh,
    google_project_iam_member.vm_secret_accessor,
  ]
}
