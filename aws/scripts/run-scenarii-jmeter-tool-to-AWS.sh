#!/bin/bash

helpFunction()
{
   echo ""
   echo "Usage: $0 -i injectors -n namespace -j scenario"
   echo -e "\t-i number of injectors"
   echo -e "\t-n namespace"
   echo -e "\t-j scenario name (.jmx)"
   exit 1 # Exit script after printing help
}

while getopts "i:n:j:" opt
do
   case "$opt" in
	   i ) injectors="$OPTARG" ;;
      n ) namespace="$OPTARG" ;;
      j ) scenario="$OPTARG" ;; 
      ? ) helpFunction ;;
   esac
done

if [[ $1 == "?" ]]
then
   helpFunction
elif [ -z "$injectors" ] || [ -z "$namespace" ] || [ -z "$scenario" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi
./start_test.sh -j $scenario -n $namespace -c -m -i $injectors -r