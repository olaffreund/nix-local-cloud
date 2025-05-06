# NixOS Azure Deployment

This directory contains the configuration for building a NixOS Azure VM image with pre-configured services and deploying it to Azure using Terraform.

## Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled
- Azure CLI configured with appropriate credentials
- Terraform (installed via Nix or manually)
- An Azure account with permissions to create resources

## Included Services

The following services are included in the Azure VM:

- **PostgreSQL**: Database server running on port 5432
- **Grafana**: Monitoring dashboard accessible on port 3000
- **Nginx**: Web server running on ports 80/443
- **Prometheus**: Monitoring system on port 9090 with Node Exporter on port 9100

## Building the Azure Image

To build the NixOS Azure VHD:

```bash
# Navigate to the Azure directory
cd /path/to/nix-local-cloud/Azure

# Build the Azure VHD
nix build .#azure-image

# This will create a result symlink pointing to the generated VHD image
```

## Uploading the Image to Azure

After building the image, you need to upload it to Azure as a VHD:

```bash
# Make sure Azure CLI is configured
az login

# Create a resource group (if you don't already have one)
az group create --name nixos-images --location eastus

# Create a storage account for the VHD
az storage account create --name nixosstorage --resource-group nixos-images --location eastus --sku Standard_LRS

# Create a container in the storage account
az storage container create --name vhds --account-name nixosstorage

# Upload the VHD (this may take some time)
az storage blob upload --account-name nixosstorage \
  --container-name vhds \
  --name nixos-azure.vhd \
  --file ./result/disk.vhd \
  --type page

# Get the URL of the uploaded VHD
BLOB_URL=$(az storage blob url --account-name nixosstorage \
  --container-name vhds \
  --name nixos-azure.vhd -o tsv)

echo "VHD URL: $BLOB_URL"
```

## Deploying with Terraform

Once you have the VHD URL, you can deploy it using Terraform:

```bash
# Deploy using the Nix flake app
nix run .#deploy-to-azure -- "$BLOB_URL" [environment] [location]

# For example, to deploy to the dev environment in East US
nix run .#deploy-to-azure -- "$BLOB_URL" dev eastus
```

The deployment script will:

1. Automatically detect your current IP address for NSG rules
2. Initialize Terraform if needed
3. Apply the Terraform configuration with the provided VHD URL
4. Output connection information when complete

## Terraform Variables

You can customize the deployment by modifying the Terraform variables:

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `location` | Azure region to deploy resources | eastus |
| `environment` | Environment name (dev, staging, prod) | dev |
| `vm_size` | Azure VM size | Standard_B2s |
| `ssh_public_key` | SSH public key for VM access | (predefined key) |
| `my_ip` | Your IP address for NSG rules | 0.0.0.0 (auto-detected) |
| `nixos_username` | Username for the NixOS VM | nixos |
| `nixos_image_uri` | URI to the blob containing the NixOS VHD | (required) |

## Accessing Deployed Services

After deployment, Terraform will output the URLs and connection strings for all services:

- **SSH**: `ssh nixos@<public-ip>`
- **Nginx**: http://`<public-ip>`
- **Grafana**: http://`<public-ip>`:3000 (default credentials: admin/admin)
- **Prometheus**: http://`<public-ip>`:9090
- **PostgreSQL**: `postgresql://nixos:nixos@<public-ip>:5432/nixos`

## Security Notes

- The deployment automatically configures NSG rules to allow access only from your IP address for most services
- Only HTTP/HTTPS ports (80/443) are open to the world
- SSH is configured to disallow root login
- Default user (`nixos`) has passwordless sudo access

## Troubleshooting

### Common Issues

1. **Authentication Errors**:
   - Ensure your Azure CLI credentials are valid (`az login`)
   - Check that your storage account and container are accessible

2. **VHD Upload Failures**:
   - Verify the VHD format is correct
   - Ensure the storage account has sufficient space

3. **Deployment Issues**:
   - Check that the blob URL is accessible
   - Verify the VM size is available in your selected region
   - Ensure your subscription has sufficient quota

### Getting Help

If you encounter issues, check:
- Azure Portal for resource status and logs
- Terraform logs by running with `TF_LOG=DEBUG`
- SSH into the VM and check system journals with `journalctl`

## Cleanup

To destroy the deployed resources:

```bash
cd ./terraform
terraform destroy -var="nixos_image_uri=$BLOB_URL"
```

This will remove all Azure resources created by this deployment. To delete the VHD from storage:

```bash
az storage blob delete --account-name nixosstorage --container-name vhds --name nixos-azure.vhd
```