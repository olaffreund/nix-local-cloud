#!/bin/bash

# This script generates all the required encrypted secret files for the project

# Ensure we're in the secrets directory
cd "$(dirname "$0")" || exit 1

# Set environment variable to use our recipients file
export RULES="./recipients.nix"

# Generate user password
echo "Generating user password secret..."
echo "nixos-password" | nix run github:ryantm/agenix -- -e user-password.age

# Generate database password
echo "Generating database password secret..."
echo "database-secure-password" | nix run github:ryantm/agenix -- -e database-password.age

# Generate Prometheus password
echo "Generating Prometheus password secret..."
echo "prometheus-secure-password" | nix run github:ryantm/agenix -- -e prometheus-password.age

# Generate Grafana admin password
echo "Generating Grafana admin password secret..."
echo "grafana-admin-secure-password" | nix run github:ryantm/agenix -- -e grafana-admin-password.age

# Generate Nginx htpasswd
echo "Generating Nginx htpasswd secret..."
echo "admin:$(openssl passwd -apr1 'nginx-secure-password')" | nix run github:ryantm/agenix -- -e nginx-htpasswd.age

echo "All secrets have been generated!"