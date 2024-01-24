#!/bin/bash
if [ $# == 0 ]
then
    kubectl edit configmap aws-auth -n kube-system
else
    echo './addRoleToEKS.sh'
fi