#!/bin/bash
set -e

# Check for AWS CLI and required env vars
if ! command -v aws &>/dev/null; then
  echo "AWS CLI not found. Please install it first."
  exit 1
fi

if [[ -z $AWS_ACCESS_KEY_ID || -z $AWS_SECRET_ACCESS_KEY ]]; then
  echo "AWS credentials not found in environment. Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY."
  exit 1
fi

REGION="${1:-us-west-2}"
NAME="nixos-cloud-$(date +%Y%m%d-%H%M%S)"
BUCKET="nixos-amis-${REGION}"

# Get the image path
if [[ -z "$2" ]]; then
  echo "Using default image path from nix build result"
  IMAGE_PATH=$(readlink -f ./result/nixos.img)
else
  IMAGE_PATH="$2"
fi

# Check if the S3 bucket exists, if not create it
if ! aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "Creating S3 bucket $BUCKET..."
  aws s3 mb "s3://$BUCKET" --region "$REGION"
fi

echo "Uploading NixOS image to S3..."
aws s3 cp "$IMAGE_PATH" "s3://$BUCKET/$NAME.img" --region "$REGION"

echo "Importing as AMI..."
IMPORT_TASK=$(aws ec2 import-snapshot \
  --description "NixOS Cloud AMI" \
  --disk-container "Format=raw,UserBucket={S3Bucket=$BUCKET,S3Key=$NAME.img}" \
  --region "$REGION" \
  --output json)

TASK_ID=$(echo "$IMPORT_TASK" | grep -o 'import-snap-[a-zA-Z0-9]*')

echo "Waiting for snapshot import to complete (Task ID: $TASK_ID)..."
aws ec2 wait snapshot-imported --import-task-ids "$TASK_ID" --region "$REGION"

SNAPSHOT_ID=$(aws ec2 describe-import-snapshot-tasks \
  --import-task-ids "$TASK_ID" \
  --region "$REGION" \
  --query 'ImportSnapshotTasks[0].SnapshotTaskDetail.SnapshotId' \
  --output text)

echo "Creating AMI from snapshot $SNAPSHOT_ID..."
AMI_ID=$(aws ec2 register-image \
  --name "$NAME" \
  --description "NixOS Cloud AMI" \
  --architecture x86_64 \
  --root-device-name "/dev/xvda" \
  --virtualization-type hvm \
  --ena-support \
  --block-device-mappings "DeviceName=/dev/xvda,Ebs={SnapshotId=$SNAPSHOT_ID,DeleteOnTermination=true,VolumeType=gp3}" \
  --region "$REGION" \
  --output text)

echo "Successfully created AMI: $AMI_ID"
echo "AMI_ID=$AMI_ID" > ami-id.txt

# Clean up
echo "Cleaning up S3 object..."
aws s3 rm "s3://$BUCKET/$NAME.img" --region "$REGION"

echo "Done! Your AMI ID is: $AMI_ID"
echo "You can use this AMI ID in your Terraform configuration"