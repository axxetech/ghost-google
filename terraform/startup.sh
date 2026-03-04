#!/bin/bash
set -e

exec > >(tee /var/log/startup-script.log) 2>&1
echo "=== Ghost VM Startup Script ==="
echo "Client: ${client_name}"
echo "Started at: $(date)"

# Variables from Terraform
CLIENT_NAME="${client_name}"
CLIENT_DOMAIN="${client_domain}"
REPO_URL="${repo_url}"
REPO_BRANCH="${repo_branch}"
PROJECT_ID="${project_id}"

# Paths
DATA_DISK="/dev/disk/by-id/google-ghost-data"
DATA_MOUNT="/mnt/ghost-data"
APP_DIR="/opt/ghost"

# Wait for cloud-init to finish
echo "Waiting for cloud-init..."
cloud-init status --wait || true

# Update and install dependencies
echo "Installing dependencies..."
apt-get update
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    jq

# Install Docker
echo "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
fi

# Install Docker Compose plugin
echo "Installing Docker Compose..."
apt-get install -y docker-compose-plugin

# Start Docker
systemctl enable docker
systemctl start docker

# Install gcloud CLI (for Secret Manager access)
echo "Installing gcloud CLI..."
if ! command -v gcloud &> /dev/null; then
    curl -sSL https://sdk.cloud.google.com | bash -s -- --disable-prompts --install-dir=/opt
    ln -sf /opt/google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud
fi

# Format and mount data disk
echo "Setting up data disk..."
if [ -e "$DATA_DISK" ]; then
    # Check if disk is already formatted
    if ! blkid "$DATA_DISK" | grep -q ext4; then
        echo "Formatting data disk..."
        mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard "$DATA_DISK"
    fi
    
    # Create mount point
    mkdir -p "$DATA_MOUNT"
    
    # Mount if not already mounted
    if ! mountpoint -q "$DATA_MOUNT"; then
        mount -o discard,defaults "$DATA_DISK" "$DATA_MOUNT"
    fi
    
    # Add to fstab for persistence
    if ! grep -q "$DATA_DISK" /etc/fstab; then
        echo "$DATA_DISK $DATA_MOUNT ext4 discard,defaults,nofail 0 2" >> /etc/fstab
    fi
    
    # Create data directories
    mkdir -p "$DATA_MOUNT/ghost"
    mkdir -p "$DATA_MOUNT/mysql"
    chmod 755 "$DATA_MOUNT/ghost" "$DATA_MOUNT/mysql"
else
    echo "WARNING: Data disk not found at $DATA_DISK"
fi

# Clone repository
echo "Cloning repository..."
if [ -d "$APP_DIR" ]; then
    cd "$APP_DIR"
    git fetch origin
    git reset --hard "origin/$REPO_BRANCH"
else
    git clone --branch "$REPO_BRANCH" "$REPO_URL" "$APP_DIR"
fi

cd "$APP_DIR"

# Fetch .env from Secret Manager
echo "Fetching secrets..."
ENV_FILE="$APP_DIR/.env"

# Check if secret exists and has a version
if gcloud secrets versions access latest --secret=ghost-env --project="$PROJECT_ID" > "$ENV_FILE" 2>/dev/null; then
    echo "Loaded .env from Secret Manager"
    chmod 600 "$ENV_FILE"
else
    echo "WARNING: No secret found. Creating placeholder .env"
    cat > "$ENV_FILE" << 'ENVEOF'
# Ghost Configuration
# Upload this to Secret Manager after filling in values:
# gcloud secrets versions add ghost-env --project=${project_id} --data-file=.env

DOMAIN=localhost
MYSQL_ROOT_PASSWORD=changeme
MYSQL_DATABASE=ghost
MYSQL_USER=ghost
MYSQL_PASSWORD=changeme
GHOST_MAIL_TRANSPORT=Direct
ENVEOF
    chmod 600 "$ENV_FILE"
fi

# Create compose override for volume paths
echo "Creating compose override..."
cat > "$APP_DIR/compose.override.yml" << 'OVERRIDE'
services:
  ghost:
    volumes:
      - /mnt/ghost-data/ghost:/var/lib/ghost/content

  mysql:
    volumes:
      - /mnt/ghost-data/mysql:/var/lib/mysql
OVERRIDE

# Pull images and start services
echo "Starting Ghost..."
cd "$APP_DIR"
docker compose pull
docker compose up -d

# Wait for Ghost to be healthy
echo "Waiting for Ghost to start..."
sleep 30

# Show status
echo "=== Startup Complete ==="
echo "Containers:"
docker compose ps
echo ""
echo "Client: $CLIENT_NAME"
echo "Domain: $CLIENT_DOMAIN"
echo "Data mount: $DATA_MOUNT"
echo "Finished at: $(date)"
