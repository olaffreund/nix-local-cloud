#!/usr/bin/env bash

# Script to encrypt a Tailscale auth key with agenix
# Usage: ./encrypt-tailscale-key.sh <tailscale-auth-key>

# Check if argument is provided
if [ "$#" -ne 1 ]; then
    echo "Error: Tailscale auth key not provided."
    echo "Usage: $0 <tailscale-auth-key>"
    exit 1
fi

# Ensure we're in the secrets directory
cd "$(dirname "$0")" || exit 1

# Store auth key in variable
TAILSCALE_KEY="$1"

# Set environment variable to use our recipients file
export RULES="./recipients.nix"

# Create the encrypted file
echo -n "$TAILSCALE_KEY" | nix run github:ryantm/agenix -- -e tailscale-auth-key.age

echo "Tailscale auth key encrypted to tailscale-auth-key.age"
echo "You can now include it in your configuration."