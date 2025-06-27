#!/bin/bash

VPC_ID="vpc-xxxxxxxxxxx"  # user your vpc ID here
REGION="us-east-2"              # your region

# Get all security groups (ID and Name) in the VPC
SG_INFO=$(aws ec2 describe-security-groups \
  --region $REGION \
  --filters Name=vpc-id,Values=$VPC_ID \
  --query "SecurityGroups[*].[GroupId,GroupName]" \
  --output text)

# Loop through each SG
while read -r SG_ID SG_NAME; do
  echo "Security Group: $SG_NAME ($SG_ID)"
  echo "------------------------------------------------"

  # EC2 Instances
  
  INSTANCES=$(aws ec2 describe-instances \
    --region $REGION \
    --filters Name=instance.group-id,Values=$SG_ID \
    --query "Reservations[*].Instances[*].[InstanceId,PrivateIpAddress,State.Name,Tags[?Key=='Name']|[0].Value]" \
    --output text)

  if [[ -n "$INSTANCES" ]]; then
    echo "  EC2 instances:"
    printf "%-20s %-15s %-10s %-20s\n" "Instance ID" "Private IP" "State" "Name Tag"
    echo "$INSTANCES"
  else
    echo " No EC2 instances using this SG."
  fi

  echo ""

  # Lets loop through ENIs
  echo "finding any security groups attached to ENIs (Later you need to check the ENI whehter its used or not)"
  ENIS=$(aws ec2 describe-network-interfaces \
    --region $REGION \
    --filters Name=group-id,Values=$SG_ID \
    --query "NetworkInterfaces[*].[NetworkInterfaceId,Description,Attachment.InstanceId,PrivateIpAddress]" \
    --output text)

  if [[ -n "$ENIS" ]]; then
    echo "ENIs using this SG:"
    printf "%-20s %-30s %-20s %-15s\n" "ENI ID" "Description" "Attached Instance" "Private IP"
    echo "$ENIS"
  else
    echo " No ENIs using this SG."
  fi

  echo ""

  # Now Application Load Balancers (ALB/NLB)
  echo "Identifying Application Load Balancers associated with any Security Groups in the VPC."
  ALBS=$(aws elbv2 describe-load-balancers \
    --region $REGION \
    --query "LoadBalancers[?SecurityGroups && contains(SecurityGroups, \`$SG_ID\`)].[LoadBalancerName, DNSName]" \
    --output text)

  if [[ -n "$ALBS" ]]; then
    echo "Application/Network Load Balancers:"
    printf "%-30s %-50s\n" "Name" "DNS Name"
    echo "$ALBS"
  else
    echo "No ALBs/NLBs using this SG."
  fi

  # Now Classic ELB
  echo "Now the Classic load balancer"
  ELBS=$(aws elb describe-load-balancers \
    --region $REGION \
    --query "LoadBalancerDescriptions[?contains(SecurityGroups, \`$SG_ID\`)].[LoadBalancerName, DNSName]" \
    --output text)

  if [[ -n "$ELBS" ]]; then
    echo "  Classic Load Balancers:"
    printf "%-30s %-50s\n" "Name" "DNS Name"
    echo "$ELBS"
  fi

  echo ""

  # lets loop through RDS Instances
  echo "finding which security groups attached to RDS instances"
  RDS_INSTANCES=$(aws rds describe-db-instances \
    --region $REGION \
    --query "DBInstances[?VpcSecurityGroups[?VpcSecurityGroupId=='$SG_ID']].[DBInstanceIdentifier,DBInstanceStatus,Engine]" \
    --output text)

  if [[ -n "$RDS_INSTANCES" ]]; then
    echo "  RDS/Aurora DBs using this SG:"
    printf "%-30s %-15s %-15s\n" "DB Identifier" "Status" "Engine"
    echo "$RDS_INSTANCES"
  else
    echo " No RDS or Aurora DBs using this SG."
  fi

  echo "============================================================="
  echo ""
done <<< "$SG_INFO"
