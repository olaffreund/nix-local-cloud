# NixOS AWS Image Builder

This directory contains the functionality for building NixOS Amazon Machine Images (AMIs) and uploading them to AWS.

## Prerequisites

- AWS CLI installed and configured with appropriate credentials
- AWS account with permissions to create S3 buckets and import images
- Nix package manager

## Building the AWS Image

To build a NixOS image suitable for deployment to AWS:

```bash
nix build
```

This will create a `result` symlink to the built image.

## Uploading to AWS

To build and upload the image to AWS as an AMI:

```bash
nix run
```

This will:
1. Build the NixOS AWS image
2. Create an S3 bucket if it doesn't exist
3. Upload the image to S3
4. Import the image as a snapshot
5. Register the snapshot as an AMI
6. Clean up the S3 object after successful AMI creation
7. Print the AMI ID for use in your infrastructure as code

## Options

You can specify a custom AWS region by passing it as an argument:

```bash
nix run . -- us-east-1
```

The default region is `us-west-2` if not specified.

## Configuration

The AWS image configuration is defined in `configuration.nix`. You can modify this file to customize your AWS image:

- Package selection
- System services
- User accounts
- Network settings
- Other NixOS configuration options

## Integration with Terraform

Once you have created an AMI, the ID is saved to `ami-id.txt` which can be used in your Terraform configurations in the `terraform/AWS` directory.