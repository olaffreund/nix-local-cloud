# nix-local-cloud
Create a NixOS VM and run it locally for testing or push to AWS or Azure


## How to Use This Setup

1. **Set up your development environment**:
   ```bash
   nix develop
   ```

2. **For AWS deployment**:
   ```bash
   # Build the AWS AMI
   build-ami
   
   # Deploy to AWS
   cd terraform/AWS
   terraform init
   terraform plan
   terraform apply
   ```

3. **For Azure deployment**:
   ```bash
   # Build the Azure VHD
   build-azure-vhd
   
   # Upload the VHD to your Azure Storage Account
   upload-azure-vhd your-storage-account your-container your-resource-group
   
   # Deploy to Azure using Terraform
   cd terraform/AZ
   terraform init
   terraform plan
   terraform apply
   ```

4. **Test locally**:
   ```bash
   run-local
   ```
   This will start a MicroVM with the same base configuration.

## Key Components

1. **Common Configuration**: The local VM, AWS instance, and Azure VM all use the same base NixOS configuration, ensuring consistency.

2. **NixOS Generators**: Used to build the AWS AMI and Azure VHD.

3. **MicroVM**: Used to run a local VM with the same configuration.

4. **Terraform**: Used to deploy the infrastructure to AWS and Azure.

5. **Development Shell**: Provides all the necessary tools to build and deploy.

This approach gives you a consistent environment between local development and cloud deployment, which is ideal for testing and development workflows.

## Cloud-Specific Notes

### AWS
- The AMI is built using the amazon format in nixos-generators
- The AMI is automatically configured for EC2 initialization

### Azure
- The VHD is built using the azure format in nixos-generators
- Cloud-init is configured for Azure compatibility
- The VHD needs to be uploaded to an Azure Storage Account and converted to a managed image before deployment

Remember to:
1. Replace the SSH public key with your own (in the flake.nix and Azure Terraform config)
2. Update the resource group and storage settings in the Azure Terraform configuration
3. Customize the NixOS configuration according to your needs

Similar code found with 2 license types
