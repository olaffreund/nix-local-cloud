#!/bin/bash

# decrypt-secret.sh - A script to easily decrypt agenix-encrypted secrets
# Usage: ./decrypt-secret.sh <secret-file.age>
# Example: ./decrypt-secret.sh user-password.age

# Check if an argument was provided
if [ -z "$1" ]; then
  echo "Error: No secret file specified"
  echo "Usage: ./decrypt-secret.sh <secret-file.age>"
  echo ""
  echo "Available secrets:"
  find . -name "*.age" -type f -exec basename {} \; | sort
  exit 1
fi

# Check if the specified file exists
if [ ! -f "$1" ]; then
  echo "Error: File '$1' not found"
  echo ""
  echo "Available secrets:"
  find . -name "*.age" -type f -exec basename {} \; | sort
  exit 1
fi

# Set the path to the recipients file
export RULES=./recipients.nix

# Decrypt the specified file using agenix
echo "Decrypting $1..."
nix run github:ryantm/agenix -- -d "$1" -i keys/agenix-host-key

# Exit with the status of the agenix command
exit $?