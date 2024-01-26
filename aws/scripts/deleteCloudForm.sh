#!/bin/bash

helpFunction()
{
   echo ""
   echo "Usage: $0 -s stack -p profile -r region"
   echo -e "\t-s stack"
   echo -e "\t-p profile"
   echo -e "\t-r region "
   exit 1 # Exit script after printing help
}

logit()
{
   if [ $# -eq 1 ]
   then 
      echo -e " [\e[94m INFO \e[0m] [ $(date '+%d-%m-%y %H:%M:%S') ] $1 \e[0m"
   else
      echo -e " $1 [ $(date '+%d-%m-%y %H:%M:%S') ] $2 \e[0m"
   fi
}

while getopts "s:r:p:" opt
do
   case "$opt" in
      s ) stack="$OPTARG" ;;
      p ) profile="$OPTARG" ;;
      r ) region="$OPTARG" ;;
      ? ) helpFunction ;;
   esac
done

if [ -z "${stack}" ] || [ -z "${profile}" ] || [ -z "${region}" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi

# Delete the stack-eks and it's dependencies
logit "Check if ${stack}-eks exists"
objects=($(aws eks list-clusters --query "clusters" --output yaml --profile ${profile} | awk '{print $2}' | grep -w "${stack}-eks"))
if [ ${#objects[@]} -eq 0 ]; then
   logit "No cluster found"
else
   logit "Getting nodegroup ${stack}-eks-nodegroup..."
   objects=($(aws eks describe-nodegroup --cluster-name ${stack}-eks --nodegroup-name ${stack}-eks-nodegroup --query nodegroup.version --output text --profile ${profile}))
   if [ ${#objects[@]} -eq 0 ]; then
      logit "No nodegroup found"
   else 
      logit "Deleting nodegroup ${stack}-eks-nodegroup..."
      aws eks delete-nodegroup --cluster-name ${stack}-eks --nodegroup-name ${stack}-eks-nodegroup --profile ${profile} > /dev/null
      aws eks wait nodegroup-deleted --cluster-name ${stack}-eks --nodegroup-name ${stack}-eks-nodegroup --profile ${profile}
      logit "Deleted nodegroup ${stack}-eks-nodegroup !"
   fi 
   logit "Getting cluster ${stack}-eks..."
   objects=($(aws eks describe-cluster --name ${stack}-eks --query cluster.version --profile ${profile}))
   if [ ${#objects[@]} -eq 0 ]; then
      logit "No cluster found"
   else 
      logit "Deleting cluster ${stack}-eks..."
      aws eks delete-cluster --name ${stack}-eks --profile ${profile} > /dev/null
      aws eks wait cluster-deleted --name ${stack}-eks --profile ${profile}
      logit "Deleted cluster ${stack}-eks !"
   fi
fi

# Delete the dependencies of stack-vpc
# required to delete the stack
logit "Getting vpcId of ${stack}-VPC..."
vpc_Id=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=${stack}-VPC --query "Vpcs[].VpcId" --output text --profile ${profile})
if [ -z "${vpc_id}" ]; then
   logit "No vpc found"
else
   # Delete the load balancer
   logit "Getting the load balancer..."
   objects=($(aws elb describe-load-balancers --query "LoadBalancerDescriptions[?VPCId=='${vpc_id}'].LoadBalancerName" --output text --profile ${profile}))
   if [ ${#objects[@]} -eq 0 ]; then
      logit "No load balancer found"
   else
      logit "Deleting load balancer ${objects[0]}..."
      aws elb delete-load-balancer --load-balancer-name ${objects[0]} --profile ${profile}
      while [ ${#objects[@]} -gt 0 ]; do 
         objects=($(aws elb describe-load-balancers --query "LoadBalancerDescriptions[?VPCId=='${vpc_id}'].LoadBalancerName" --output text --profile ${profile}))
         sleep 1
      done 
      logit "Deleted load balancer ${objects[0]} !"
   fi

   # Delete the security groups
   logit "Getting security groups of ${stack}-vpc"
   objects=($(aws ec2 describe-security-groups --filters "Name=tag-key,Values=kubernetes.io/cluster/${stack}-eks" --query "SecurityGroups[].GroupId" --output text --profile ${profile}))
   objects+=($(aws ec2 describe-security-groups --filters Name=tag:Name,Values=${stack}-* --query "SecurityGroups[].GroupId" --output text --profile ${profile}))
   if [ ${#objects[@]} -eq 0 ]; then
      logit "No security groups found"
   else
      # For each security group, detach the network interfaces and delete the network interfaces
      for i in ${objects[@]}; do
         id=($(aws ec2 describe-network-interfaces --filter Name=group-id,Values=$i --query "NetworkInterfaces[].NetworkInterfaceId" --output text --profile ${profile}))
         for j in ${id[@]}; do
            attach_id=($(aws ec2 describe-network-interfaces --network-interface-ids $j --query NetworkInterfaces[].Attachment.AttachmentId --output text --profile ${profile}))
            for k in ${attach_id[@]}; do
               aws ec2 detach-network-interface --attachment-id $k --profile ${profile}
               logit "Detached network interface $k !"
            done
            aws ec2 delete-network-interface --network-interface-id $j --profile ${profile}
            logit "Deleted network interface $j !"
         done
         aws ec2 delete-security-group --group-id $i --profile ${profile}
         logit "Deleted security group $i !"
      done
      logit "Deleted security groups of ${stack}-vpc !"
   fi

   # Delete the public subnets
   logit "Getting the public subnets..."
   objects=($(aws ec2 describe-subnets --filters Name=tag:Name,Values=${stack}-PublicSubnet* --query "Subnets[].SubnetId" --output text --profile ${profile}))
   if [ ${#objects[@]} -eq 0 ]; then
      logit "No public subnet found"
   else 
      for i in ${objects[@]}; do
         aws ec2 delete-subnet --subnet-id ${objects[0]} --profile ${profile}
         logit "Deleted subnet ${objects[0]} !"
      done 
   fi
fi

# Delete the storage buckets 
logit "Getting s3 buckets..."
stack_name=$(aws sts get-caller-identity --query "Account" --output text --profile ${profile})-${stack}
objects=($(aws s3 ls  --profile ${profile} | grep ${stack_name} | awk '{print $3}'))
if [ ${#objects[@]} -eq 0 ]; then
   logit "No s3 bucket found"
else 
   for i in ${objects[@]}; do
      aws s3 rb s3://$i --force --profile ${profile}
      logit "Deleted s3 bucket $i !"
   done
fi

# Check whether the stack exists and delete it
logit "Getting stack ${stack} infos..."
objects=($(aws cloudformation list-stacks --query "StackSummaries[?contains(stack_name,'${stack}')].stack_name" --stack-status-filter CREATE_COMPLETE ROLLBACK_COMPLETE UPDATE_COMPLETE UPDATE_ROLLBACK_COMPLETE DELETE_FAILED --output text --profile ${profile}))
if [ ${#objects[@]} -eq 0 ]; then
   logit "No stack found"
else
   logit "Deleting stack ${stack}..."
   aws cloudformation delete-stack --stack-name ${stack} --profile ${profile}
   logit "Waiting for stack ${stack} to be completely deleted..."
   aws cloudformation wait stack-delete-complete --stack-name ${stack} --profile ${profile}
   if [ $? -ne 0 ]
   then
      logit "[\e[91m ERROR \e[0m]" "Stack ${stack} deletion failed !"
   else 
      logit "Stack ${stack} successfully deleted !"
   fi
fi

# Delete the keypairs associated to the stack
if [ $(aws ec2 delete-key-pair --key-name ${stack}-eks-keypair --query "Return" --region ${region} --profile ${profile}) ]; then
   echo -e "\033[0;32mSuccessfully deleted keypairs !\033[0m"
else
   echo -e "\033[0;31mFailed to delete keypairs !\033[0m"
fi