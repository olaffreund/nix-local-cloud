# NixOS on Google Cloud Platform (GCP)

This directory contains the necessary configurations to build a NixOS image for Google Cloud Platform and deploy it using Terraform.

## Prerequisites

- [Nix](https://nixos.org/download.html) with [flakes](https://nixos.wiki/wiki/Flakes) enabled
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- [Terraform](https://www.terraform.io/downloads.html) (>= 1.0.0)
- A Google Cloud Platform account with a project and enough permissions to create resources

## Setup

1. Make sure you're authenticated with Google Cloud:

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

2. Enable the necessary APIs for your project:

```bash
gcloud services enable compute.googleapis.com
```

## Building the NixOS GCP Image

To build the NixOS image for GCP, run:

```bash
nix build .#gcp-image
```

This will create a disk image in `./result/disk.raw.tar.gz`.

## Uploading the Image to GCP

Upload the built image to your GCP project:

```bash
# Set your project ID and preferred image name
PROJECT_ID=$(gcloud config get-value project)
IMAGE_NAME="nixos-$(date +%Y%m%d)"

# Create a GCP bucket if you don't have one
BUCKET_NAME="${PROJECT_ID}-nixos-images"
gcloud storage buckets create gs://${BUCKET_NAME} --location=us-central1

# Upload the image to the bucket
gcloud storage cp ./result/disk.raw.tar.gz gs://${BUCKET_NAME}/${IMAGE_NAME}.tar.gz

# Import the disk image into GCP
gcloud compute images create ${IMAGE_NAME} \
  --source-uri=gs://${BUCKET_NAME}/${IMAGE_NAME}.tar.gz \
  --project=${PROJECT_ID}
```

## Deploying with Terraform

Once your image is uploaded to GCP, you can deploy it using the included Terraform configuration:

```bash
# Using the app in the flake
nix run .#deploy-to-gcp -- ${IMAGE_NAME}

# Or manually with Terraform
cd terraform
terraform init
terraform apply \
  -var="nixos_image_name=${IMAGE_NAME}" \
  -var="project_id=${PROJECT_ID}" \
  -var="my_ip=$(curl -s https://checkip.amazonaws.com)"
```

## Terraform Configuration

The Terraform configuration creates:

- A VPC network with a subnet
- A firewall rule allowing SSH, HTTP/HTTPS, and other application traffic from your IP address
- A Compute Engine VM instance running your NixOS image

## SSH Access

After deployment, you can SSH into your NixOS instance using:

```bash
ssh nixos@$(terraform -chdir=terraform output -raw public_ip)
```

## Customization

### Adding Services

Add new services by creating modules in the `../hosts/<service-name>/default.nix` directory. These will be automatically included in the GCP configuration.

### Modifying VM Configuration

To modify the VM configuration, you can edit the following files:

- `flake.nix` - Update the NixOS configuration for GCP
- `terraform/main.tf` - Update the Terraform configuration for GCP resources
- `terraform/variables.tf` - Add or modify input variables

## Cleanup

To destroy the deployed resources:

```bash
cd terraform
terraform destroy
```

To delete the uploaded image:

```bash
gcloud compute images delete ${IMAGE_NAME}
```