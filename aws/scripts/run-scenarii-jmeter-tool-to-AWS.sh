#!/bin/bash

helpFunction()
{
   echo ""
   echo "Usage: $0 -s stack -r region -p profile -n nodes"
   echo -e "\t-s stack"
   echo -e "\t-r region"
   echo -e "\t-p profile"
   echo -e "\t-n number of nodes"
   exit 1 # Exit script after printing help
}

while getopts "s:r:p:n:" opt
do
   case "$opt" in
      s ) stack="$OPTARG" ;;
      r ) region="$OPTARG" ;;
      p ) profile="$OPTARG" ;;
	  n ) nodes="$OPTARG" ;;
      ? ) helpFunction ;;
   esac
done

if [[ $1 == "?" ]]
then
   helpFunction
elif [ -z "$stack" ] || [ -z "$region" ] || [ -z "$profile" ] || [ -z "$nodes" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi
./connectToEKS.sh -s $stack -r $region -p $profile
cd ../jmeter-k8s-starterkit
rm k8s/jmeter/jmeter-pv.yaml
volumes=(`aws ec2 describe-volumes --query 'Volumes[?Tags && Size >= \`5\`].VolumeId' --output text`)
cp jmeter-pv.yaml k8s/jmeter/jmeter-pv.yaml
sed -i "s/##VolumeId##/${volumes[0]}/g" k8s/jmeter/jmeter-pv.yaml
kubectl apply -R -f k8s/
./start_test.sh -j my-scenario.jmx -n default -c -m -i $nodes -r
cd ../scripts