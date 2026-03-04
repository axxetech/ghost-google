output "project_id" {
  description = "Client's GCP project ID"
  value       = google_project.client.project_id
}

output "static_ip" {
  description = "Static IP address for the Ghost server"
  value       = google_compute_address.static_ip.address
}

output "staging_url" {
  description = "Immediate staging URL using nip.io (works without DNS setup)"
  value       = "https://${var.client_name}.${google_compute_address.static_ip.address}.nip.io"
}

output "staging_url_http" {
  description = "HTTP staging URL (use if HTTPS cert not ready yet)"
  value       = "http://${google_compute_address.static_ip.address}"
}

output "ssh_command" {
  description = "Command to SSH into the Ghost server"
  value       = "gcloud compute ssh ${google_compute_instance.ghost.name} --project=${google_project.client.project_id} --zone=${var.zone}"
}

output "custom_domain_instructions" {
  description = "Instructions for setting up the custom domain"
  value       = var.client_domain != "" ? "Point DNS A record for ${var.client_domain} to ${google_compute_address.static_ip.address}" : "No custom domain configured. Add with: terraform apply -var='client_domain=example.com'"
}

output "vm_name" {
  description = "Name of the VM instance"
  value       = google_compute_instance.ghost.name
}

output "next_steps" {
  description = "Next steps after deployment"
  value       = <<-EOT
    
    ========================================
    DEPLOYMENT COMPLETE FOR: ${var.client_name}
    ========================================
    
    1. Add the .env file to Secret Manager:
       gcloud secrets versions add ghost-env \
         --project=axxe-${var.client_name} \
         --data-file=path/to/client.env
    
    2. SSH into the VM to check status:
       gcloud compute ssh ${var.client_name}-ghost --project=axxe-${var.client_name} --zone=${var.zone}
    
    3. View container logs:
       sudo docker compose -f /opt/ghost/compose.yml logs -f
    
    4. Access Ghost (wait a few minutes for startup):
       - Direct IP: http://${google_compute_address.static_ip.address}
       - nip.io: https://${var.client_name}.${google_compute_address.static_ip.address}.nip.io
    
    5. For custom domain (${var.client_domain != "" ? var.client_domain : "not set"}):
       - Point DNS A record to: ${google_compute_address.static_ip.address}
       - Update DOMAIN in .env and re-upload secret
       - Restart: sudo docker compose -f /opt/ghost/compose.yml restart
    
  EOT
}
