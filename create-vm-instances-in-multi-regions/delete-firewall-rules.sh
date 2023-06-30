#!/bin/bash
source ./main.env

gcloud compute firewall-rules list \
 --project $projectName \
 --filter NETWORK=$vpcName \
 --format "get(name)" > ./list

for targets in `cat ./list`
do
  gcloud compute firewall-rules delete $targets \
    --project $projectName
done

rm ./list
