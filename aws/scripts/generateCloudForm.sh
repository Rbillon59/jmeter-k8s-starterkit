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

if [[ $1 == "?" ]]
then
   helpFunction
elif [ -z "$stack" ] || [ -z "$region" ] || [ -z "$profile" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi

stack_name=`aws sts get-caller-identity --query "Account" --output text --profile $profile`-$stack
bucket_name=$stack_name-cloudform
if [[ $(aws ec2 describe-key-pairs --query "KeyPairs[?starts_with(KeyName, '$stack')]") == "[]" ]]; then
   aws ec2 create-key-pair --key-name $stack-eks-keypair --query "KeyMaterial" --output text --region $region --profile $profile> $stack_name-eks-keypair.pem
fi
aws s3 mb s3://$bucket_name && aws s3 sync ./templates s3://$bucket_name --exclude .git --profile $profile
aws cloudformation create-stack \
	--stack-name $stack \
	--template-url https://$bucket_name.s3.$region.amazonaws.com/main.yml \
	--parameters ParameterKey=StackName,ParameterValue=$stack \
	--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
	--profile $profile
aws cloudformation wait stack-create-complete --stack-name $stack --profile $profile
./connectToEKS.sh -s $stack -r $region -p $profile
cd ../../
kubectl create -R -f k8s/
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver
helm repo add jmeter-k8s-starterkit-helm-charts https://rbillon59.github.io/jmeter-k8s-starterkit-helm-chart/
helm repo update
helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver
helm install jmeter-k8s-starterkit-helm-charts/jmeter-k8s-starterkit --generate-name
cd aws/scripts