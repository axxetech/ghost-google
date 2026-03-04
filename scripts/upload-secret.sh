#!/bin/bash
# Upload .env file to Secret Manager for a client

set -e

CLIENT_NAME=${1:-}
ENV_FILE=${2:-.env}

if [ -z "$CLIENT_NAME" ]; then
    echo "Usage: $0 <client-name> [env-file]"
    echo ""
    echo "Examples:"
    echo "  $0 testclient                    # Uses .env in current directory"
    echo "  $0 acme clients/acme.env         # Uses specific env file"
    exit 1
fi

PROJECT_ID="axxe-${CLIENT_NAME}"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file '$ENV_FILE' not found"
    echo ""
    echo "Create one from the example:"
    echo "  cp .env.example $ENV_FILE"
    echo "  # Edit $ENV_FILE with client-specific values"
    exit 1
fi

echo "Uploading $ENV_FILE to Secret Manager..."
echo "  Client: $CLIENT_NAME"
echo "  Project: $PROJECT_ID"
echo "  Secret: ghost-env"
echo ""

# Check if secret exists
if ! gcloud secrets describe ghost-env --project="$PROJECT_ID" &>/dev/null; then
    echo "Error: Secret 'ghost-env' not found in project $PROJECT_ID"
    echo "Make sure you've run 'terraform apply' for this client first."
    exit 1
fi

# Upload new version
gcloud secrets versions add ghost-env \
    --project="$PROJECT_ID" \
    --data-file="$ENV_FILE"

echo ""
echo "Secret uploaded successfully!"
echo ""
echo "Next steps:"
echo "  1. SSH into the VM:"
echo "     gcloud compute ssh ${CLIENT_NAME}-ghost --project=$PROJECT_ID --zone=europe-west1-b"
echo ""
echo "  2. Restart Ghost to pick up new config:"
echo "     sudo docker compose -f /opt/ghost/compose.yml restart"
