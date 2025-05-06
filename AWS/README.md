# NixOS AWS Deployment

This directory contains the configuration for building a NixOS AWS AMI with pre-configured services and deploying it to AWS using Terraform.

## Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled
- AWS CLI configured with appropriate credentials
- Terraform (installed via Nix or manually)
- An AWS account with permissions to create EC2 instances, security groups, etc.

## Included Services

The following services are included in the AWS AMI:

- **PostgreSQL**: Database server running on port 5432
- **Grafana**: Monitoring dashboard accessible on port 3000
- **Nginx**: Web server running on ports 80/443
- **Prometheus**: Monitoring system on port 9090 with Node Exporter on port 9100

## Building the AWS Image

To build the NixOS AWS AMI:

```bash
# Navigate to the AWS directory
cd /path/to/nix-local-cloud/AWS

# Build the AWS AMI
nix build .#aws-ami

# This will create a result symlink pointing to the generated AMI
```

The build process creates a NixOS AMI that can be uploaded to AWS.

## Uploading the Image to AWS

After building the image, you need to upload it to AWS as an AMI:

```bash
# Make sure AWS CLI is configured
aws configure

# Upload the image to S3 and import as AMI
# Replace bucket-name with your S3 bucket
aws s3 cp ./result/nixos.img s3://bucket-name/nixos-ami.img

# Import the snapshot
aws ec2 import-snapshot \
  --disk-container "Format=raw,UserBucket={S3Bucket=bucket-name,S3Key=nixos-ami.img}"

# Monitor the import progress
aws ec2 describe-import-snapshot-tasks --import-task-ids import-snap-XXXXXXXX

# Once the snapshot is created, register it as an AMI
aws ec2 register-image \
  --name "nixos-custom-$(date +%Y%m%d)" \
  --description "Custom NixOS AMI with Postgres, Grafana, Nginx, and Prometheus" \
  --architecture x86_64 \
  --root-device-name "/dev/xvda" \
  --virtualization-type hvm \
  --block-device-mappings "DeviceName=/dev/xvda,Ebs={SnapshotId=snap-XXXXXXXX}"

# Note the AMI ID returned from this command
```

## Deploying with Terraform

Once you have the AMI ID, you can deploy it using Terraform:

```bash
# Deploy using the Nix flake app
nix run .#deploy-to-aws -- ami-XXXXXXXXXX [environment] [region]

# For example, to deploy to the dev environment in us-west-2
nix run .#deploy-to-aws -- ami-XXXXXXXXXX dev us-west-2
```

The deployment script will:

1. Automatically detect your current IP address for security group rules
2. Initialize Terraform if needed
3. Apply the Terraform configuration with the provided AMI ID
4. Output connection information when complete

## Terraform Variables

You can customize the deployment by modifying the Terraform variables:

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `aws_region` | AWS region to deploy resources | us-west-2 |
| `environment` | Environment name (dev, staging, prod) | dev |
| `instance_type` | EC2 instance type | t3.medium |
| `ssh_public_key` | SSH public key for instance access | (predefined key) |
| `my_ip` | Your IP address for security group rules | 0.0.0.0 (auto-detected) |
| `nixos_username` | Username for the NixOS instance | nixos |
| `nixos_ami_id` | ID of the custom NixOS AMI | (required) |

## Accessing Deployed Services

After deployment, Terraform will output the URLs and connection strings for all services:

- **SSH**: `ssh nixos@<public-ip>`
- **Nginx**: http://`<public-ip>`
- **Grafana**: http://`<public-ip>`:3000 (default credentials: admin/admin)
- **Prometheus**: http://`<public-ip>`:9090
- **PostgreSQL**: `postgresql://nixos:nixos@<public-ip>:5432/nixos`

## Security Notes

- The deployment automatically configures security groups to allow access only from your IP address for most services
- Only HTTP/HTTPS ports (80/443) are open to the world
- SSH is configured to disallow root login
- Default user (`nixos`) has passwordless sudo access

## Troubleshooting

### Common Issues

1. **Permissions Errors**:
   - Ensure your AWS CLI credentials have sufficient permissions
   - Check that your SSH key is correctly configured

2. **AMI Import Failures**:
   - Verify S3 bucket permissions
   - Check VM import service role permissions

3. **Connection Issues**:
   - Ensure security group rules are correctly configured
   - Verify your IP hasn't changed since deployment

### Getting Help

If you encounter issues, check:
- AWS CloudWatch logs
- Terraform logs by running with `TF_LOG=DEBUG`
- SSH into the instance and check system journals with `journalctl`

## Cleanup

To destroy the deployed resources:

```bash
cd ./terraform
terraform destroy -var="nixos_ami_id=ami-XXXXXXXXXX"
```

This will remove all AWS resources created by this deployment but won't remove the AMI from your account. To delete the AMI:

```bash
aws ec2 deregister-image --image-id ami-XXXXXXXXXX
```