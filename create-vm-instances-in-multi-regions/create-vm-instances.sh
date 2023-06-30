#!/bin/bash
source ./main.env

for zoneName in "${targetZones[@]}"
do
  gcloud compute instances create $zoneName-vm \
  --machine-type=$vmType \
  --network=$vpcName \
  --no-address \
  --project=$projectName \
  --shielded-secure-boot \
  --zone=$zoneName 
done
