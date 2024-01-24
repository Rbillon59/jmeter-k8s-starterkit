#!/bin/bash
cd scripts
./generateCloudForm.sh -s rennes -r eu-west-1 -p default
./run-scenarii-jmeter-tool-to-AWS.sh -s rennes -r eu-west-1 -p default -n 2