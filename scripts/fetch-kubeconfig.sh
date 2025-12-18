#!/bin/bash
# Fetch kubeconfig from Kubernetes control plane and extract certificates
# This script is called by Terraform's external data source
# Input: JSON object with control_plane_ip, ssh_user, ssh_private_key
# Output: JSON object with kubeconfig components

set -e

# Read JSON input from stdin (external data source sends query as JSON)
INPUT=$(cat)

CONTROL_PLANE_IP=$(echo "$INPUT" | jq -r '.control_plane_ip')
SSH_USER=$(echo "$INPUT" | jq -r '.ssh_user')
SSH_PRIVATE_KEY=$(echo "$INPUT" | jq -r '.ssh_private_key')

# Create temp file for SSH key
SSH_KEY_FILE=$(mktemp)
trap "rm -f $SSH_KEY_FILE" EXIT

# Write SSH key to temp file
echo "$SSH_PRIVATE_KEY" > "$SSH_KEY_FILE"
chmod 600 "$SSH_KEY_FILE"

# Fetch kubeconfig from control plane
KUBECONFIG_RAW=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -o ConnectTimeout=30 \
  -i "$SSH_KEY_FILE" \
  "$SSH_USER@$CONTROL_PLANE_IP" \
  "sudo cat /etc/kubernetes/admin.conf" 2>/dev/null) || true

# If kubeconfig fetch failed, return empty values
if [ -z "$KUBECONFIG_RAW" ]; then
  echo '{"kubeconfig_ca_certificate":"","kubeconfig_client_certificate":"","kubeconfig_client_key":"","kubernetes_api_endpoint":""}'
  exit 0
fi

# Extract certificates using Python (more portable than yq)
python3 << PYTHONSCRIPT
import sys
import yaml
import json

kubeconfig_raw = '''$KUBECONFIG_RAW'''

try:
    kubeconfig = yaml.safe_load(kubeconfig_raw)

    # Extract cluster CA certificate (already base64 encoded in kubeconfig)
    ca_cert_b64 = kubeconfig['clusters'][0]['cluster']['certificate-authority-data']

    # Extract user client certificate (already base64 encoded)
    client_cert_b64 = kubeconfig['users'][0]['user']['client-certificate-data']

    # Extract user client key (already base64 encoded)
    client_key_b64 = kubeconfig['users'][0]['user']['client-key-data']

    # Get the server URL
    server_url = kubeconfig['clusters'][0]['cluster']['server']

    result = {
        "kubeconfig_ca_certificate": ca_cert_b64,
        "kubeconfig_client_certificate": client_cert_b64,
        "kubeconfig_client_key": client_key_b64,
        "kubernetes_api_endpoint": server_url
    }

    print(json.dumps(result))
except Exception as e:
    # Return empty values on error
    result = {
        "kubeconfig_ca_certificate": "",
        "kubeconfig_client_certificate": "",
        "kubeconfig_client_key": "",
        "kubernetes_api_endpoint": ""
    }
    print(json.dumps(result))
PYTHONSCRIPT
