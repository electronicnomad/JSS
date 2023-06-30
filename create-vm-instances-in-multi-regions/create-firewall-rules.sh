#!/bin/bash
source ./main.env

gcloud compute firewall-rules create allow-ssh-ingress-from-iap \
  --priority 1000 \
  --direction ingress \
  --source-ranges 35.235.240.0/20 \
  --network $vpcName \
  --project $projectName \
  --action allow \
  --rules tcp:22 

gcloud compute firewall-rules create allow-ssh-in-private \
  --priority 1010 \
  --direction ingress \
  --source-ranges="10.128.0.0/9" \
  --network $vpcName \
  --project $projectName \
  --action allow \
  --rules tcp:22

gcloud compute firewall-rules create allow-pinging-in-private \
  --priority 1011 \
  --direction ingress \
  --source-ranges="10.128.0.0/9" \
  --network $vpcName \
  --project $projectName \
  --action allow \
  --rules icmp
