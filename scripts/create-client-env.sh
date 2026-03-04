#!/bin/bash
# Create a client-specific .env file from template

set -e

CLIENT_NAME=${1:-}
DOMAIN=${2:-}

if [ -z "$CLIENT_NAME" ]; then
    echo "Usage: $0 <client-name> [domain]"
    echo ""
    echo "Examples:"
    echo "  $0 testclient                   # Domain defaults to IP-based nip.io"
    echo "  $0 acme blog.acme.com           # With custom domain"
    exit 1
fi

OUTPUT_DIR="clients"
OUTPUT_FILE="$OUTPUT_DIR/${CLIENT_NAME}.env"

mkdir -p "$OUTPUT_DIR"

# Generate random passwords
MYSQL_ROOT_PASS=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32)
MYSQL_GHOST_PASS=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32)

# Default domain to localhost (will be updated after deployment)
DOMAIN=${DOMAIN:-localhost}

cat > "$OUTPUT_FILE" << EOF
# Ghost Configuration for: $CLIENT_NAME
# Generated: $(date)

# Ghost URL (update after getting static IP)
# For IP access: http://STATIC_IP
# For custom domain: https://$DOMAIN
GHOST_URL=http://localhost

# Caddy domain (set to 'localhost' for IP access, or real domain for HTTPS)
DOMAIN=localhost

# MySQL Configuration
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASS
MYSQL_DATABASE=ghost
MYSQL_USER=ghost
MYSQL_PASSWORD=$MYSQL_GHOST_PASS

# Email Configuration (optional - uncomment and configure if needed)
# GHOST_MAIL_TRANSPORT=SMTP
# GHOST_MAIL_FROM=noreply@yourdomain.com
# GHOST_MAIL_SERVICE=Mailgun
# GHOST_MAIL_USER=
# GHOST_MAIL_PASS=

# Admin email for SSL certificates
ADMIN_EMAIL=admin@axxetech.com
EOF

chmod 600 "$OUTPUT_FILE"

echo "Created: $OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "  1. Review and edit $OUTPUT_FILE if needed"
echo "  2. Deploy infrastructure: cd terraform && terraform workspace new $CLIENT_NAME && terraform apply -var=\"client_name=$CLIENT_NAME\""
echo "  3. Update DOMAIN in $OUTPUT_FILE with the static IP or nip.io URL"
echo "  4. Upload secret: ./scripts/upload-secret.sh $CLIENT_NAME $OUTPUT_FILE"
