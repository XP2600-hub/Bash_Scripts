#!/bin/bash
# Simple script to convert all gp2 EBS volumes in us-east-1 to gp3

REGION="us-east-1"

echo "Finding all gp2 volumes in $REGION..."

VOLUMES=$(aws ec2 describe-volumes \
  --region "$REGION" \
  --filters Name=volume-type,Values=gp2 \
  --query "Volumes[].VolumeId" \
  --output text)

if [ -z "$VOLUMES" ]; then
  echo "No gp2 volumes found in $REGION."
  exit 0
fi

for VOL in $VOLUMES; do
  echo "Converting $VOL to gp3..."
  aws ec2 modify-volume --region "$REGION" --volume-id "$VOL" --volume-type gp3 >/dev/null
  if [ $? -eq 0 ]; then
    echo "Conversion started for $VOL"
  else
    echo "Failed to convert $VOL"
  fi
done

echo "All gp2 volumes have been queued for conversion to gp3 in $REGION."
echo "You can check progress with:"
echo "  aws ec2 describe-volumes-modifications --region $REGION"
