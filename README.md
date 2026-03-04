# Ghost CMS on Google Cloud

One-command deployment of Ghost CMS to Google Cloud Platform for agency client management.

## Architecture

Each client gets:
- Dedicated GCP project (`axxe-{client-name}`)
- Compute Engine VM (e2-small, ~€15/month)
- 50GB persistent data disk
- Static IP address
- Automatic HTTPS via Caddy (for real domains)

## Quick Start: Deploy a New Client

```bash
# 1. Create client environment file
./scripts/create-client-env.sh clientname

# 2. Review/edit the generated file
nano clients/clientname.env

# 3. Deploy infrastructure
cd terraform
terraform workspace new clientname
terraform apply -var="client_name=clientname"

# 4. Note the static IP from output, update GHOST_URL in env file
# For IP access: GHOST_URL=http://STATIC_IP
# For domain: GHOST_URL=https://blog.clientdomain.com

# 5. Upload secrets
cd ..
./scripts/upload-secret.sh clientname clients/clientname.env

# 6. Wait 3-5 minutes for VM startup, then access:
# http://STATIC_IP (immediate)
# http://STATIC_IP/ghost (admin setup)
```

## Project Structure

```
.
├── terraform/              # Infrastructure as Code
│   ├── providers.tf        # GCP provider config
│   ├── variables.tf        # Input variables
│   ├── project.tf          # Creates GCP project
│   ├── compute.tf          # VM, disk, service account
│   ├── network.tf          # Firewall, static IP
│   ├── secrets.tf          # Secret Manager
│   ├── outputs.tf          # Deployment outputs
│   ├── backend.tf          # State storage
│   └── startup.sh          # VM initialization script
├── caddy/                  # Reverse proxy config
│   └── Caddyfile
├── scripts/                # Helper scripts
│   ├── create-client-env.sh
│   └── upload-secret.sh
├── clients/                # Client env files (gitignored)
├── compose.yml             # Docker Compose config
└── .env.example            # Environment template
```

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `GHOST_URL` | Full URL for Ghost | `http://1.2.3.4` or `https://blog.example.com` |
| `DOMAIN` | Caddy domain | `localhost` (for IP) or `blog.example.com` |
| `MYSQL_ROOT_PASSWORD` | MySQL root password | Auto-generated |
| `MYSQL_PASSWORD` | Ghost MySQL password | Auto-generated |
| `ADMIN_EMAIL` | Email for SSL certs | `admin@agency.com` |

## Custom Domain Setup

1. Deploy with IP-based access first (works immediately)
2. Get static IP from Terraform output
3. Client creates DNS A record: `blog.clientdomain.com` → `STATIC_IP`
4. Update client's `.env`:
   ```
   GHOST_URL=https://blog.clientdomain.com
   DOMAIN=blog.clientdomain.com
   ```
5. Re-upload secret: `./scripts/upload-secret.sh clientname clients/clientname.env`
6. SSH and restart: `sudo docker compose -f /opt/ghost/compose.yml restart`

## Management Commands

```bash
# SSH into client VM
gcloud compute ssh clientname-ghost --project=axxe-clientname --zone=europe-west1-b

# View logs
sudo docker compose -f /opt/ghost/compose.yml logs -f

# Restart services
sudo docker compose -f /opt/ghost/compose.yml restart

# Update code (on VM)
cd /opt/ghost && git pull && docker compose restart
```

## Client Handoff

To transfer a client's project to their own billing:

```bash
# 1. Transfer billing
gcloud billing projects link axxe-clientname --billing-account=CLIENT_BILLING_ACCOUNT

# 2. Remove from Terraform management
cd terraform
terraform workspace select clientname
terraform state rm google_project.client

# Project is now fully owned by client
```

## Costs

| Resource | Monthly Cost |
|----------|--------------|
| e2-small VM | ~€12 |
| 50GB standard disk | ~€2 |
| Static IP | Free |
| Egress (moderate) | ~€1-3 |
| **Total** | **~€15-17/month** |

## Troubleshooting

### Can't SSH into VM
```bash
# Check OS Login is disabled
gcloud compute project-info add-metadata --project=axxe-clientname --metadata enable-oslogin=FALSE

# Or use browser-based SSH from GCP Console
```

### Ghost not starting
```bash
# Check startup script log
sudo tail -100 /var/log/startup-script.log

# Check container status
sudo docker compose -f /opt/ghost/compose.yml ps
sudo docker compose -f /opt/ghost/compose.yml logs ghost
```

### HTTPS not working
- Ensure `DOMAIN` is set to actual domain (not IP)
- Ensure DNS is pointing to static IP
- Wait for Let's Encrypt cert provisioning (~1-2 min)
- Check Caddy logs: `sudo docker compose -f /opt/ghost/compose.yml logs caddy`
