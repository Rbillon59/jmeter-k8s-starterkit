#!/bin/bash

helpFunction()
{
   echo ""
   echo "Usage: $0 -s stack -r region -p profile"
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

bucket_name=$(aws sts get-caller-identity --query "Account" --output text)-${stack}-cloudform
changeset_name=${stack}-changeset
aws cloudformation create-change-set \
	--change-set-name ${changeset_name} \
	--stack-name ${stack} \
	--template-url https://${bucket_name}.s3.${region}.amazonaws.com/main.yml \
	--parameters ParameterKey=StackName,ParameterValue=${stack} \
	--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
	--profile ${profile}
aws cloudformation wait change-set-create-complete \
	--change-set-name ${changeset_name} \
	--stack-name ${stack} \
	--profile ${profile}
aws cloudformation execute-change-set \
	--change-set-name ${changeset_name} \
	--stack-name ${stack} \
	--profile ${profile}
