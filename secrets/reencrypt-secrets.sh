#!/bin/bash

# reencrypt-secrets.sh - Re-encrypts all secrets with updated recipients
# This should be run after modifying the recipients.nix file

# Ensure we're in the secrets directory
cd "$(dirname "$0")"

# Set environment variable to use our recipients file
export RULES="./recipients.nix"

echo "Re-encrypting all secrets with updated recipient keys..."
nix run github:ryantm/agenix -- -r -i keys/agenix-host-key

echo "Re-encryption complete!"
echo ""
echo "Note: After first boot of each VM, you should:"
echo "1. Extract the VM's actual SSH host public key from /etc/ssh/ssh_host_ed25519_key.pub"
echo "2. Update the placeholder in recipients.nix with the actual key"
echo "3. Run this script again to re-encrypt with the actual VM keys"