# NixOS Local Cloud

This project provides a NixOS VM configuration that can be run locally using QEMU and deployed to AWS as a custom AMI.

## Project Structure

- `flake.nix`: Main Nix Flake for running the local VM
- `hosts/`: Service-specific configurations (database, Grafana, Nginx, Prometheus)
- `AWS/`: Configuration files for building and deploying a NixOS AWS AMI
- `terraform/`: Infrastructure as code for cloud deployments

## Requirements

- Nix with flakes enabled
- QEMU (for local VM)
- AWS CLI (for AWS deployment)

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

## Accessing Services

Once the VM is running (locally or in AWS), you can access the services:

- **Grafana**: Port 3000 (default credentials: admin/admin)
- **Nginx**: Port 80
- **PostgreSQL Database**: Port 5432
- **Prometheus**: Port 9090

## Adding New Services

To add a new service:

1. Create a new directory under `hosts/` with the service name
2. Add a `default.nix` file in that directory with the service configuration
3. The service will be automatically imported by both the local VM and the AWS image

## Customizing

- Edit `flake.nix` to modify the local VM configuration
- Edit `AWS/configuration.nix` to modify the AWS AMI configuration
- Edit files in `hosts/` to modify specific services

## Security Notes

- Default SSH public key should be replaced with your own
- Firewall settings should be reviewed before production use
- PostgreSQL and other services may have default passwords that should be changed
