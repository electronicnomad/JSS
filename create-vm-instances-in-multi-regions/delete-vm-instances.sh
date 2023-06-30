#!/bin/bash
source ./main.env

for zoneName in "${targetZones[@]}"
do
  gcloud compute instances delete $zoneName-vm \
  --project=$projectName \
  --zone=$zoneName 
done
