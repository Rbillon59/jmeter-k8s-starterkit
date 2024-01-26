#!/bin/bash

helpFunction()
{
   echo ""
   echo "Usage: $0 -s stack -p profile"
   echo -e "\t-s stack"
   echo -e "\t-r region"
   echo -e "\t-p profile"
   exit 1 # Exit script after printing help
}

while getopts "s:r:p:" opt
do
   case "$opt" in
      s ) stack="$OPTARG" ;;
      r ) region="$OPTARG" ;;
      p ) profile="$OPTARG" ;;
      ? ) helpFunction ;;
   esac
done

if [ -z "${stack}" ] || [ -z "${region}" ] || [ -z "${profile}" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi

bucket_name=$(aws sts get-caller-identity --query "Account" --output text --region ${region} --profile ${profile})-${stack}-cloudform
aws s3 sync ../templates s3://${bucket_name} --exclude .git --region ${region} --profile ${profile}
aws eks update-kubeconfig --name ${stack}-eks --region ${region} --profile ${profile}