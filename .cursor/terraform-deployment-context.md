# Terraform Deployment Context - Ghost CMS to Google Cloud

## Project Overview

This is a Ghost CMS setup running via Docker Compose that needs to be deployed to Google Cloud Platform using Terraform. The goal is to create a low-cost (~€15/month), easy-to-maintain deployment on Compute Engine.

## Current Setup

### Application Stack
- **Ghost CMS** - Main application (ghost:6-alpine)
- **MySQL** - Database (mysql:8.0.44)
- **Caddy** - Reverse proxy with HTTPS (caddy:2.10.2-alpine)
- **Optional services**: ActivityPub, Tinybird analytics (via profiles)

### Key Files
- `compose.yml` - Main Docker Compose configuration
- `caddy/Caddyfile` - Caddy configuration with custom snippets
- `caddy/snippets/` - Caddy configuration snippets (Logging, SecurityHeaders, ActivityPub, TrafficAnalytics)
- `.env` - Environment variables (not in repo, needs to be managed securely)

### Volume Mounts
- `./caddy:/etc/caddy` - Caddy configuration files
- `./data/ghost:/var/lib/ghost/content` - Ghost content/uploads
- `./data/mysql:/var/lib/mysql` - MySQL data
- Docker volumes for Caddy data/config

## Deployment Decision: Compute Engine VM

**Selected Option**: Compute Engine VM (e2-small)
- **Cost**: ~€15-20/month (e2-small VM + 50GB disk)
- **Why**: Cheapest option, can run docker-compose as-is, no refactoring needed
- **Trade-off**: Always-on (doesn't sleep), but acceptable for this cost

## Deployment Strategy

### No Custom Docker Images Needed
- All images are standard (pulled from Docker Hub/GHCR)
- Custom Caddy configs are files, not baked into images
- Deploy code/configs to VM, run docker-compose exactly as locally

### Code Deployment Approach
**Option 1 (Recommended)**: Git clone on VM
- VM startup script clones repo
- Runs `docker compose up -d`
- Updates via `git pull` + restart

**Option 2**: Cloud Storage
- Upload repo as tarball to Cloud Storage
- VM downloads on startup
- Updates by uploading new version

### Environment Variables
- Store `.env` in Google Secret Manager
- VM retrieves on startup
- Never commit to repo

## Terraform Requirements

### Infrastructure Components
1. **Compute Engine VM** (e2-small)
   - Container-Optimized OS or Ubuntu
   - Boot disk: 20GB
   - Data disk: 50GB+ (attached separately for persistence)

2. **Static External IP**
   - Reserved IP address
   - Attached to VM
   - Free (1 per VM)

3. **Firewall Rules**
   - Allow HTTP (80)
   - Allow HTTPS (443)
   - Optional: SSH (22) for management

4. **Persistent Disk**
   - Separate disk for Ghost/MySQL data
   - Mounted at `/mnt/ghost-data` or similar
   - Survives VM recreation

5. **Service Account**
   - For VM to access Secret Manager
   - Permissions: secretmanager.secretAccessor

6. **Optional: Cloud Storage Bucket**
   - If using Cloud Storage for code deployment
   - Otherwise use Git clone

### Startup Script Responsibilities
1. Install Docker & Docker Compose
2. Format and mount persistent data disk
3. Clone repo OR download from Cloud Storage
4. Retrieve `.env` from Secret Manager
5. Create `compose.override.yml` to use mounted data disk
6. Run `docker compose up -d`

### Volume Mapping on VM
Local paths → VM paths:
- `./data/ghost` → `/mnt/ghost-data/ghost`
- `./data/mysql` → `/mnt/ghost-data/mysql`
- `./caddy` → `/opt/ghost/caddy` (from cloned repo)

## Terraform File Structure

```
terraform/
├── main.tf              # VM, disk, network, firewall, service account
├── variables.tf         # All input variables
├── outputs.tf          # Static IP, VM details, SSH command
├── backend.tf          # GCS backend for state (optional initially)
├── startup-script.sh   # Bash script for VM initialization
└── terraform.tfvars.example  # Example variable values
```

## Key Variables Needed

- `project_id` - GCP Project ID
- `region` - GCP Region (e.g., europe-west1)
- `zone` - GCP Zone (e.g., europe-west1-a)
- `machine_type` - VM size (default: e2-small)
- `repo_url` - Git repository URL (or empty if using Cloud Storage)
- `secret_name` - Secret Manager secret name for .env
- `data_disk_size_gb` - Size of persistent disk (default: 50)

## Important Considerations

### Data Persistence
- Use separate persistent disk (not boot disk)
- Mount at `/mnt/ghost-data`
- Create subdirectories: `ghost/` and `mysql/`
- Add to `/etc/fstab` for auto-mount on reboot

### Docker Compose Override
- Create `compose.override.yml` on VM
- Maps volumes to mounted data disk paths
- Allows using existing `compose.yml` unchanged

### Updates
- Code changes: `git pull` + `docker compose restart [service]`
- Config changes: Edit files, restart affected service
- No need to rebuild images

### Security
- Store `.env` in Secret Manager, never in repo
- Restrict SSH access (firewall rules)
- Use service account with minimal permissions
- Consider using Container-Optimized OS (more secure, less flexible)

## Domain Setup

1. Terraform outputs static IP
2. Point DNS A record at yourhosting to static IP
3. Caddy handles SSL automatically via Let's Encrypt
4. Domain configured via `DOMAIN` environment variable

## Next Steps for Implementation

1. Create Terraform files in separate repo (recommended) or this repo
2. Set up GCS bucket for Terraform state (optional but recommended)
3. Create Secret Manager secret for `.env` file
4. Configure `terraform.tfvars` with your values
5. Run `terraform init` and `terraform plan`
6. Deploy with `terraform apply`
7. Get static IP from outputs
8. Point DNS A record to static IP
9. Access Ghost at your domain

## Repository Structure Decision

**Recommendation**: Separate Terraform repo
- Clean separation of concerns
- Independent versioning
- Easier CI/CD for infrastructure
- Can be shared across multiple projects

But can also live in this repo if preferred.

## Cost Optimization

- Use e2-small (2 vCPU, 2GB RAM) - sufficient for Ghost
- Standard persistent disk (not SSD) - cheaper, adequate performance
- Single zone deployment (no multi-zone redundancy)
- Free static IP (1 per VM)

## Monitoring & Maintenance

- Cloud Monitoring (basic) - free tier
- Logs via `docker compose logs`
- SSH access for troubleshooting
- Automated backups: Consider Cloud Storage snapshots

## Agency Workflow: One-Command Client Onboarding

### Use Case
This setup is for an agency that deploys Ghost sites for multiple clients. The goal is to spin up a complete new client environment with a single command.

### Workflow
1. New client arrives (e.g., wants `sample.com`)
2. Run single deployment command with client identifier/domain as input
3. Infrastructure spins up automatically
4. Site is immediately accessible on a **default/staging domain** (e.g., `sample.agency-domain.com` or `sample.ghost.agency.com`)
5. Get static IP from output
6. Client configures their custom domain DNS to point to the IP
7. Update Ghost config to use custom domain when ready

### Requirements
- **Single command deployment**: One `terraform apply` (or equivalent via n8n/CI pipeline) with minimal inputs
- **Default domain support**: Each client gets a working subdomain immediately (before custom domain DNS propagates)
- **Parameterized**: Client name/identifier drives resource naming and subdomain
- **Isolated environments**: Each client gets their own VM, disk, and data

### Default Domain Strategy
- Agency owns a wildcard domain (e.g., `*.clients.agency.com`)
- DNS wildcard points to a load balancer OR each client subdomain is added dynamically
- **Option A**: Use nip.io/sslip.io (e.g., `client-34.56.78.90.nip.io`) - works immediately with IP
- **Option B**: Agency-managed wildcard subdomain - requires DNS automation
- Caddy handles SSL for both staging and final custom domain

### Inputs for New Client Deployment
- `client_name` - Identifier for the client (used in resource names, subdomain)
- `client_domain` - Final custom domain (optional, can be added later)
- Everything else uses sensible defaults

### Outputs After Deployment
- Static IP address
- Default staging URL (accessible immediately)
- SSH command for management
- Instructions for custom domain setup
