# NixOS Local Cloud

This project provides a NixOS VM configuration that can be run locally using QEMU and deployed to AWS, Azure, and GCP cloud environments.

## Project Structure

- `flake.nix`: Main Nix Flake for running the local VM
- `hosts/`: Service-specific configurations (database, Grafana, Nginx, Prometheus)
- `AWS/`: Configuration files for building and deploying a NixOS AWS AMI
- `Azure/`: Configuration files for building and deploying a NixOS Azure VM image
- `GCP/`: Configuration files for building and deploying a NixOS GCP instance image
- `terraform/`: Infrastructure as code for cloud deployments

## Requirements

- Nix with flakes enabled
- QEMU (for local VM)
- AWS CLI (for AWS deployment)
- Azure CLI (for Azure deployment)
- Google Cloud SDK (for GCP deployment)

## Running the Local VM

To run the VM locally:

```bash
nix run
```

The VM will be available with:
- SSH access on port 2222 (connect with `ssh nixos@localhost -p 2222`)
- Username: `nixos`, password: `nixos` (or use SSH key)

## Deploying to AWS

AWS deployment is handled in the separate `AWS/` directory:

```bash
cd AWS

# Build the AWS image only
nix build

# Build and upload the image to AWS (creates an AMI)
nix run
```

The upload script will:
1. Build a NixOS image using the AWS-specific configuration
2. Upload it to an S3 bucket
3. Import it as an EBS snapshot
4. Register it as an AMI
5. Output the AMI ID for use with Terraform

### Deploying with Terraform

After creating the AMI, use Terraform to deploy your infrastructure:

```bash
cd terraform/AWS

# Initialize Terraform
terraform init

# Create a terraform.tfvars file with your configuration
cat > terraform.tfvars << EOF
aws_region = "us-west-2"  # Change to your preferred region
nixos_ami_id = "ami-01234567890abcdef"  # Use the AMI ID from the previous step
EOF

# Plan and apply
terraform plan
terraform apply
```

## Deploying to Azure

Azure deployment is handled in the separate `Azure/` directory:

```bash
cd Azure

# Build the Azure image only
nix build .#azure-image

# Build and upload the image to Azure
nix run
```

The upload script will:
1. Build a NixOS image using the Azure-specific configuration
2. Upload it to Azure Blob Storage
3. Create a managed image from the uploaded VHD
4. Output the Image URI for use with Terraform

### Deploying with Terraform on Azure

After creating the Azure image, use Terraform to deploy your infrastructure:

```bash
cd terraform/Azure

# Initialize Terraform
terraform init

# Create a terraform.tfvars file with your configuration
cat > terraform.tfvars << EOF
location = "eastus"  # Change to your preferred Azure region
image_uri = "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RG/providers/Microsoft.Compute/images/nixos-image"  # Use the Image URI from the previous step
environment = "dev"
EOF

# Plan and apply
terraform plan
terraform apply
```

## Deploying to GCP

GCP deployment is handled in the separate `GCP/` directory:

```bash
cd GCP

# Build the GCP image only
nix build .#gcp-image

# Build and upload the image to GCP
nix run
```

The upload script will:
1. Build a NixOS image using the GCP-specific configuration
2. Upload it to Google Cloud Storage
3. Create a Compute Engine image from the uploaded disk
4. Output the Image Name for use with Terraform

### Deploying with Terraform on GCP

After creating the GCP image, use Terraform to deploy your infrastructure:

```bash
cd terraform/GCP

# Initialize Terraform
terraform init

# Create a terraform.tfvars file with your configuration
cat > terraform.tfvars << EOF
project_id = "your-gcp-project-id"  # Your GCP project ID
zone = "us-central1-a"  # Change to your preferred GCP zone
nixos_image_name = "nixos-image"  # Use the Image Name from the previous step
environment = "dev"
EOF

# Plan and apply
terraform plan
terraform apply
```

## Remote Building and Deployment using Flakes

You can build and deploy using flakes from any machine with Nix installed, even if the target architecture differs from your local machine.

### Remote Building

To build for a remote system:

```bash
# Build AWS image on a remote machine
nix build .#aws-ami --system x86_64-linux --builders "ssh://user@remote-builder x86_64-linux"

# Build Azure image on a remote machine
nix build .#azure-image --system x86_64-linux --builders "ssh://user@remote-builder x86_64-linux"

# Build GCP image on a remote machine
nix build .#gcp-image --system x86_64-linux --builders "ssh://user@remote-builder x86_64-linux"
```

This requires SSH access to a remote builder with Nix installed and properly configured.

### Using the justfile with Remote Building

You can also use the provided justfile for more convenient remote building:

```bash
# Set up your remote builder
export NIX_REMOTE_SYSTEMS="ssh://user@remote-builder x86_64-linux"

# Then use the justfile commands
just build-aws
just build-azure
just build-gcp
```

### Cross-Architecture Development

For cross-architecture development (e.g., building on macOS for Linux):

1. Add a remote Linux builder in your `~/.config/nix/nix.conf`:
   ```
   builders = ssh://user@remote-linux-machine x86_64-linux
   ```

2. Set up SSH keys for passwordless authentication:
   ```bash
   ssh-copy-id user@remote-linux-machine
   ```

3. Ensure the remote machine has Nix installed with flakes enabled

4. Build and deploy using the flake commands above

## Accessing Services

Once the VM is running (locally or in any cloud provider), you can access the services:

- **Grafana**: Port 3000 (default credentials: admin/admin)
- **Nginx**: Port 80
- **PostgreSQL Database**: Port 5432
- **Prometheus**: Port 9090

## Cloud Provider Specific Features

### AWS Features
- EC2 instance with EBS volumes
- Security groups for firewall settings
- Elastic IP option for static addressing

### Azure Features
- Azure Virtual Machine deployment
- Network Security Groups for firewall settings
- Managed Disks for storage
- Virtual Network integration

### GCP Features
- Compute Engine VM instances
- VPC firewall rules
- Cloud Storage integration
- GCP IAM integration

## Adding New Services

To add a new service:

1. Create a new directory under `hosts/` with the service name
2. Add a `default.nix` file in that directory with the service configuration
3. The service will be automatically imported by both the local VM and the AWS image

## Customizing

- Edit `flake.nix` to modify the local VM configuration
- Edit `AWS/flake.nix` to modify the AWS AMI configuration
- Edit `Azure/flake.nix` to modify the Azure VM image configuration
- Edit `GCP/flake.nix` to modify the GCP instance image configuration
- Edit files in `hosts/` to modify specific services

## Security Notes

- Default SSH public key should be replaced with your own
- Firewall settings should be reviewed before production use
- PostgreSQL and other services may have default passwords that should be changed
