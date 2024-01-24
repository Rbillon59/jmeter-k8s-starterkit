#!/bin/bash

helpFunction()
{
   echo ""
   echo "Usage: $0 [-r region] [-p profile]"
   echo -e "\t-r region, default value: eu-west-1"
   echo -e "\t-p profile, default value: default"
   exit 1 # Exit script after printing help
}

while getopts "r:p:" opt
do
   case "$opt" in
      r ) region="$OPTARG" ;;
      p ) profile="$OPTARG" ;;
      ? ) helpFunction ;;
   esac
done

if [ -z "$region" ]
then
   region=eu-west-1
fi
if [ -z "$profile" ]
then
   profile=default
fi

account_id=`aws sts get-caller-identity --query "Account" --output text`
aws ecr get-login-password --region $region | docker login --username AWS --password-stdin $account_id.dkr.ecr.$region.amazonaws.com