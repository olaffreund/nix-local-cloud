# nix-local-cloud justfile
# Simple commands for building and deploying NixOS cloud images
# Requires: just (https://github.com/casey/just)
# Requires: nix with flakes enabled

# Default recipe - show available commands
default:
    @just --list

# Check if nix is installed
check-nix:
    @if ! command -v nix &> /dev/null; then \
        echo "Nix is required but not installed. Please install:"; \
        echo "https://nixos.org/download.html"; \
        exit 1; \
    fi

# Check if terraform is installed
check-terraform:
    @if ! command -v terraform &> /dev/null; then \
        echo "Terraform is required but not installed. Please install:"; \
        echo "https://www.terraform.io/downloads"; \
        exit 1; \
    fi

# Build AWS image
build-aws:
    @echo "Building AWS image..."
    @just check-nix
    @cd AWS && nix build .#aws-ami
    @if [ -e "./AWS/result" ]; then \
        echo -e "\033[32m✓ AWS image built!\033[0m"; \
        echo "Output: $$(realpath ./AWS/result)"; \
    fi

# Build Azure image
build-azure:
    @echo "Building Azure image..."
    @just check-nix
    @cd Azure && nix build .#azure-image
    @if [ -e "./Azure/result" ]; then \
        echo -e "\033[32m✓ Azure image built!\033[0m"; \
        echo "Output: $$(realpath ./Azure/result)"; \
    fi

# Build GCP image
build-gcp:
    @echo "Building GCP image..."
    @just check-nix
    @cd GCP && nix build .#gcp-image
    @if [ -e "./GCP/result" ]; then \
        echo -e "\033[32m✓ GCP image built!\033[0m"; \
        echo "Output: $$(realpath ./GCP/result)"; \
    fi

# Build local VM image
build-vm:
    @echo "Building local VM image..."
    @just check-nix
    @nix build .#vm-image
    @if [ -e "./result" ]; then \
        echo -e "\033[32m✓ Local VM image built!\033[0m"; \
        echo "Output: $$(realpath ./result)"; \
    fi

# Build all images
build-all: build-aws build-azure build-gcp
    @echo -e "\033[32m✓ All images built!\033[0m"

# Deploy to AWS
deploy-aws ami_id env="dev" region="us-west-2":
    @echo "Deploying to AWS..."
    @just check-nix
    @just check-terraform
    @echo "AMI ID: {{ami_id}}"
    @echo "Environment: {{env}}"
    @echo "Region: {{region}}"
    @cd AWS && nix run .#deploy-to-aws -- "{{ami_id}}" "{{env}}" "{{region}}"
    @echo -e "\033[32m✓ AWS deployment completed\033[0m"

# Deploy to Azure
deploy-azure image_uri env="dev" location="eastus":
    @echo "Deploying to Azure..."
    @just check-nix
    @just check-terraform
    @echo "Image URI: {{image_uri}}"
    @echo "Environment: {{env}}"
    @echo "Location: {{location}}"
    @cd Azure && nix run .#deploy-to-azure -- "{{image_uri}}" "{{env}}" "{{location}}"
    @echo -e "\033[32m✓ Azure deployment completed\033[0m"

# Deploy to GCP
deploy-gcp image_name project_id="" zone="us-central1-a":
    @echo "Deploying to GCP..."
    @just check-nix
    @just check-terraform
    @PROJECT="{{project_id}}"
    @if [ -z "$$PROJECT" ]; then \
        PROJECT=$$(gcloud config get-value project 2>/dev/null || echo ''); \
        echo "Using project from gcloud config: $$PROJECT"; \
    fi
    @echo "Image Name: {{image_name}}"
    @echo "Project ID: $$PROJECT"
    @echo "Zone: {{zone}}"
    @cd GCP && nix run .#deploy-to-gcp -- "{{image_name}}" "$$PROJECT" "{{zone}}"
    @echo -e "\033[32m✓ GCP deployment completed\033[0m"

# Run local VM
run-vm: check-nix
    @echo "Starting local VM..."
    @if [ ! -e ./result/bin/run-nixos-vm ]; then \
        echo -e "\033[33mVM image not found. Building first...\033[0m"; \
        just build-vm; \
    fi
    @echo -e "\033[32mLaunching VM...\033[0m"
    @echo -e "\033[33mPress Ctrl+A, X to exit QEMU\033[0m"
    @./result/bin/run-nixos-vm

# Clean up AWS resources
cleanup-aws:
    @echo "Cleaning up AWS resources..."
    @just check-terraform
    @cd AWS/terraform && terraform destroy
    @echo -e "\033[32m✓ AWS resources cleaned up\033[0m"

# Clean up Azure resources
cleanup-azure:
    @echo "Cleaning up Azure resources..."
    @just check-terraform
    @cd Azure/terraform && terraform destroy
    @echo -e "\033[32m✓ Azure resources cleaned up\033[0m"

# Clean up GCP resources
cleanup-gcp:
    @echo "Cleaning up GCP resources..."
    @just check-terraform
    @cd GCP/terraform && terraform destroy
    @echo -e "\033[32m✓ GCP resources cleaned up\033[0m"

# Clean build artifacts
clean-artifacts:
    @echo "Cleaning build artifacts..."
    @rm -f result*
    @echo -e "\033[32m✓ Build artifacts cleaned\033[0m"

# Upload GCP image
upload-gcp-image project_id="" image_name="nixos-$(date +%Y%m%d)":
    @echo "Uploading GCP image..."
    @just check-nix
    @PROJECT="{{project_id}}"
    @if [ -z "$$PROJECT" ]; then \
        PROJECT=$$(gcloud config get-value project 2>/dev/null || echo ''); \
        echo "Using project from gcloud config: $$PROJECT"; \
    fi
    @IMAGE_PATH="GCP/result/disk.raw.tar.gz"
    @if [ ! -f "$$IMAGE_PATH" ]; then \
        IMAGE_PATH="result/disk.raw.tar.gz"; \
        if [ ! -f "$$IMAGE_PATH" ]; then \
            echo -e "\033[31mNo GCP image found. Build an image first with 'just build-gcp'\033[0m"; \
            exit 1; \
        fi; \
    fi
    @BUCKET_NAME="$$PROJECT-nixos-images"
    @echo "Project ID: $$PROJECT"
    @echo "Image Name: {{image_name}}"
    @echo "Bucket: $$BUCKET_NAME"
    @echo "Creating bucket if not exists..."
    @gcloud storage buckets create gs://$$BUCKET_NAME --location=us-central1 --project=$$PROJECT 2>/dev/null || true
    @echo "Uploading image to GCP Storage..."
    @gcloud storage cp $$IMAGE_PATH gs://$$BUCKET_NAME/{{image_name}}.tar.gz --project=$$PROJECT
    @echo "Importing disk image..."
    @gcloud compute images create {{image_name}} --source-uri=gs://$$BUCKET_NAME/{{image_name}}.tar.gz --project=$$PROJECT
    @echo -e "\033[32m✓ GCP image uploaded: {{image_name}}\033[0m"