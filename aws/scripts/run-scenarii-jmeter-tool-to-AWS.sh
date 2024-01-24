#!/bin/bash

helpFunction()
{
   echo ""
   echo "Usage: $0 -s stack -r region -p profile -i injectors -j scenario"
   echo -e "\t-s stack"
   echo -e "\t-r region"
   echo -e "\t-p profile"
   echo -e "\t-i number of injectors"
   echo -e "\t-n namespace"
   echo -e "\t-j scenario name (.jmx)"
   exit 1 # Exit script after printing help
}

while getopts "s:r:p:n:" opt
do
   case "$opt" in
      s ) stack="$OPTARG" ;;
      r ) region="$OPTARG" ;;
      p ) profile="$OPTARG" ;;
	   i ) injectors="$OPTARG" ;;
      n ) namespace="$OPTARG" ;;
      j ) scenario="$OPTARG" ;; 
      ? ) helpFunction ;;
   esac
done

if [[ $1 == "?" ]]
then
   helpFunction
elif [ -z "$stack" ] || [ -z "$region" ] || [ -z "$profile" ] || [ -z "$injectors" ] || [ -z "$namespace" ] || [ -z "$scenario" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi
./connectToEKS.sh -s $stack -r $region -p $profile
cp ../aws-files/grafana/* ../../k8s/tool/grafana
cp ../aws-files/jmeter/* ../../k8s/jmeter
volumes=(`aws ec2 describe-volumes --query 'Volumes[?Tags && Size >= \`5\`].VolumeId' --output text`)
sed -i "s/##VolumeId##/${volumes[0]}/g" ../../k8s/jmeter/jmeter-pv.yaml
cd ../../
kubectl apply -R -f k8s/
./start_test.sh -j $scenario -n $namespace -c -m -i $injectors -r
cd aws/scripts