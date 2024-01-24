#!/bin/bash
cd scripts
./connectToEKS.sh -s rennes -r eu-west-1 -p default

cd ../jmeter-k8s-starterkit
kubectl create -R -f k8s/

