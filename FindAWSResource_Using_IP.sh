#!/bin/bash
# Usage: ./find_aws_ip.sh 44.216.143.127

IP_TO_FIND="$1"

if [ -z "$IP_TO_FIND" ]; then
  echo " Usage: $0 <public-ip>"
  exit 1
fi

echo "Searching for IP: $IP_TO_FIND ..."
FOUND=false

# Elastic IPs
echo "Checking Elastic IPs..."
aws ec2 describe-addresses \
  --query "Addresses[?PublicIp=='$IP_TO_FIND']" --output table
if [ $? -eq 0 ]; then FOUND=true; fi

# NAT Gateways
echo " Checking NAT Gateways..."
aws ec2 describe-nat-gateways \
  --query "NatGateways[].NatGatewayAddresses[?PublicIp=='$IP_TO_FIND']" --output table
if [ $? -eq 0 ]; then FOUND=true; fi

# 3️ EC2 Instances public IPs
echo " Checking EC2 Instances..."
aws ec2 describe-instances \
  --query "Reservations[].Instances[?PublicIpAddress=='$IP_TO_FIND'].[InstanceId,PublicIpAddress,PrivateIpAddress]" \
  --output table
if [ $? -eq 0 ]; then FOUND=true; fi

# Network Load Balancers (NLB) & Application Load Balancers (ALB)
echo " Checking Load Balancers (ALB/NLB)..."
for LB_DNS in $(aws elbv2 describe-load-balancers --query "LoadBalancers[].DNSName" --output text 2>/dev/null); do
  LB_IPS=$(dig +short "$LB_DNS" | grep "$IP_TO_FIND")
  if [ ! -z "$LB_IPS" ]; then
    echo "IP found in Load Balancer: $LB_DNS"
    FOUND=true
  fi
done

# 5️Elastic Network Interfaces (ENIs)
echo " Checking Network Interfaces..."
aws ec2 describe-network-interfaces \
  --query "NetworkInterfaces[?Association.PublicIp=='$IP_TO_FIND'].[NetworkInterfaceId,Description,Attachment.InstanceId]" \
  --output table
if [ $? -eq 0 ]; then FOUND=true; fi

if [ "$FOUND" = false ]; then
  echo " No AWS resource found using IP: $IP_TO_FIND"
  echo "It might belong to another account or be released."
fi
