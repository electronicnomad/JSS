#!/bin/bash
source ./main.env

gcloud compute networks delete $vpcName \
  --project=$projectName
