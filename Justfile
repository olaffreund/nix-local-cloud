# Justfile for nix-local-cloud
# This file contains commands for setting up and running NixOS VMs locally and deploying to cloud providers

# Default command when just is run without arguments
default:
    @just --list

# Enter the development shell with all required tools
dev:
    nix develop

# Build the AWS AMI
build-aws:
    @echo "Building AWS AMI..."
    nix build .#aws-ami
    @echo "AMI built successfully. Output path: $(readlink -f result)"

# Build the Azure image
build-azure:
    @echo "Building Azure image..."
    nix build .#azure-image
    @echo "Azure image built successfully. Output path: $(readlink -f result)"

# Run the local VM
run-local:
    @echo "Starting local MicroVM..."
    sudo systemd-run --unit=nixos-microvm \
      $(nix build .#nixosConfigurations.local-vm.config.microvm.declaredRunner --print-out-paths --no-link)
    @echo "MicroVM started. You can connect with SSH once it's ready."
    @echo "Checking for VM IP address..."
    sleep 5
    @IP=$(ip -4 addr show vm-tap | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "IP not found yet")
    @if [ "$IP" != "IP not found yet" ]; then \
        echo "Connect with: ssh admin@$IP"; \
    else \
        echo "VM is starting. Try 'just vm-status' in a moment to get connection info."; \
    fi

# Stop the local VM
stop-vm:
    @echo "Stopping the MicroVM..."
    sudo systemctl stop nixos-microvm

# Get the status of the local VM and connection information
vm-status:
    @echo "VM status:"
    sudo systemctl status nixos-microvm --no-pager || true
    @echo ""
    @echo "VM network information:"
    @IP=$(ip -4 addr show vm-tap 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "VM network not found")
    @if [ "$IP" != "VM network not found" ]; then \
        echo "VM IP address: $IP"; \
        echo "Connect with: ssh admin@$IP"; \
    else \
        echo "VM network interface not found. Is the VM running?"; \
    fi

# Initialize Terraform for AWS
init-aws:
    cd terraform/AWS && terraform init

# Plan AWS deployment
plan-aws: init-aws
    cd terraform/AWS && terraform plan

# Apply AWS deployment
deploy-aws: init-aws
    cd terraform/AWS && terraform apply

# Destroy AWS resources
destroy-aws: init-aws
    cd terraform/AWS && terraform destroy

# Initialize Terraform for Azure
init-azure:
    cd terraform/AZ && terraform init

# Plan Azure deployment
plan-azure: init-azure
    cd terraform/AZ && terraform plan

# Apply Azure deployment
deploy-azure: init-azure
    cd terraform/AZ && terraform apply

# Destroy Azure resources
destroy-azure: init-azure
    cd terraform/AZ && terraform destroy

# Get the IP of deployed AWS instance
aws-ip:
    cd terraform/AWS && terraform output public_ip

# SSH into the deployed AWS instance
aws-ssh:
    @IP=$(cd terraform/AWS && terraform output -raw public_ip 2>/dev/null || echo "")
    @if [ -z "$IP" ]; then \
        echo "No AWS instance found. Deploy one with 'just deploy-aws' first."; \
    else \
        echo "Connecting to AWS instance at $IP..."; \
        ssh admin@$IP; \
    fi

# Get the IP of deployed Azure instance
azure-ip:
    cd terraform/AZ && terraform output public_ip

# SSH into the deployed Azure instance
azure-ssh:
    @IP=$(cd terraform/AZ && terraform output -raw public_ip 2>/dev/null || echo "")
    @if [ -z "$IP" ]; then \
        echo "No Azure instance found. Deploy one with 'just deploy-azure' first."; \
    else \
        echo "Connecting to Azure instance at $IP..."; \
        ssh admin@$IP; \
    fi

# Update the AMI ID in Terraform
update-ami ID:
    @echo "Updating AMI ID in Terraform configuration..."
    sed -i "s/ami_id *= *\"[a-zA-Z0-9-]*\"/ami_id = \"{{ID}}\"/" terraform/AWS/main.tf
    @echo "Updated AMI ID to {{ID}}"
    @grep -A 1 "ami_id" terraform/AWS/main.tf

# Full AWS workflow (build AMI, update ID, deploy)
aws-workflow:
    @echo "Running full AWS workflow..."
    @echo "Step 1: Building AWS AMI"
    just build-aws
    @echo "Step 2: Getting AMI ID"
    @echo "NOTE: This is a placeholder. In a real scenario, you would need to:"
    @echo "1. Upload the image to AWS"
    @echo "2. Register it as an AMI"
    @echo "3. Get the AMI ID"
    @echo "For now, update the AMI ID manually with: just update-ami <ID>"
    @echo "Then deploy with: just deploy-aws"

# Full local workflow (build and run VM)
local-workflow:
    @echo "Running full local workflow..."
    @echo "Step 1: Building local VM"
    just build-local
    @echo "Step 2: Running local VM"
    just run-local

# Build the local VM image
build-local:
    @echo "Building local VM image..."
    nix build .#nixosConfigurations.local-vm.config.microvm.declaredRunner
    @echo "Local VM image built successfully"

# Clean up build artifacts
clean:
    @echo "Cleaning build artifacts..."
    rm -rf result*
    @echo "Cleaned build artifacts"

# Format Nix files using nixpkgs-fmt
fmt:
    @echo "Formatting Nix files..."
    find . -name "*.nix" -type f -exec nixpkgs-fmt {} \;
    @echo "Nix files formatted"

# Run a lint check on Nix files
lint:
    @echo "Linting Nix files..."
    find . -name "*.nix" -type f -exec nix-linter {} \;
    @echo "Linting complete"

# Update flake.lock
update:
    @echo "Updating flake.lock..."
    nix flake update
    @echo "flake.lock updated"