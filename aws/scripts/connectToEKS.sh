#!/bin/bash

helpFunction()
{
   echo ""
   echo "Usage: $0 -s stack [-r region] [-p profile]"
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

if [ -z "$stack" ] || [ -z "$region" ] || [ -z "$profile" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi
aws eks --region $region update-kubeconfig --name $stack-eks --profile $profile