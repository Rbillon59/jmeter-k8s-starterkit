#!/usr/bin/env bash

set -e

#=== FUNCTION ================================================================
#        NAME: logit
# DESCRIPTION: Log into file and screen.
# PARAMETER - 1 : Level (ERROR, INFO)
#           - 2 : Message
#
#===============================================================================
logit()
{
    case "$1" in
        "INFO")
            echo -e " [\e[94m $1 \e[0m] [ $(date '+%d-%m-%y %H:%M:%S') ] $2 \e[0m" ;;
        "WARN")
            echo -e " [\e[93m $1 \e[0m] [ $(date '+%d-%m-%y %H:%M:%S') ]  \e[93m $2 \e[0m " && sleep 2 ;;
        "ERROR")
            echo -e " [\e[91m $1 \e[0m] [ $(date '+%d-%m-%y %H:%M:%S') ]  $2 \e[0m " ;;
    esac
}

#=== FUNCTION ================================================================
#        NAME: usage
# DESCRIPTION: Helper of the function
# PARAMETER - None
#
#===============================================================================
usage()
{
  logit "INFO" "-j <filename.jmx>"
  logit "INFO" "-n <namespace >for namespace previously created (default the last created with the deploy script)"
  logit "INFO" "-c flag to split and copy csv if you use csv in your test"
  logit "INFO" "-m flag to copy fragmented jmx present in scenario/project/module if you use include controller and external test fragment"
  logit "INFO" "-i <injectorNumber> to scale slaves pods to the desired number of JMeter injectors"
  logit "INFO" "-r flag to enable report generation at the end of the test"
  exit 1
}

### Parsing the arguments ###
while getopts 'i:mj:hcrn:' option;
    do
      case $option in
        n	)	namespace=${OPTARG}   ;;
        c   )   csv=1 ;;
        m   )   module=1 ;;
        r   )   enable_report=1 ;;
        j   )   jmx=${OPTARG} ;;
        i   )   nb_injectors=${OPTARG} ;;
        h   )   usage ;;
        ?   )   usage ;;
      esac
done

if [ "$#" -eq 0 ]
  then
    usage
fi

### CHECKING VARS ###
if [ -z "${namespace}" ]; then
    logit "ERROR" "Namespace not provided!"
    usage
    namespace=$(awk '{print $NF}' "${PWD}/namespace_export")
fi

if [ -z "${jmx}" ]; then
    #read -rp 'Enter the name of the jmx file ' jmx
    logit "ERROR" "jmx jmeter project not provided!"
    usage
fi

jmx_dir="${jmx%%.*}"

if [ ! -f "scenario/${jmx_dir}/${jmx}" ]; then
    logit "ERROR" "Test script file was not found in scenario/${jmx_dir}/${jmx}"
    usage
fi

# Recreating each pods
logit "INFO" "Recreating pod set"
kubectl -n "${namespace}" scale --replicas=0 deployment/jmeter-slaves
kubectl -n "${namespace}" rollout status deployment/jmeter-slaves

# Starting jmeter slave pod 
if [ -z "${nb_injectors}" ]; then
    logit "WARNING" "Keeping number of injector to 1"
else
    logit "INFO" "Scaling the number of pods to ${nb_injectors}. "
    kubectl -n "${namespace}" scale --replicas=${nb_injectors} deployment/jmeter-slaves
    kubectl -n "${namespace}" rollout status deployment/jmeter-slaves
    logit "INFO" "Finish scaling the number of pods."
fi

#Get Master pod details
master_pod=$(kubectl get pod -n "${namespace}" | grep jmeter-master | awk '{print $1}')

#Get Slave pod details
slave_pods=($(kubectl get pods -n "${namespace}" | grep jmeter-slave | grep Running | awk '{print $1}'))
slave_num=${#slave_pods[@]}
slave_digit="${#slave_num}"

# jmeter directory in pods
jmeter_directory="/opt/jmeter/apache-jmeter/bin"

# Copying module and config to pods
if [ -n "${module}" ]; then
    logit "INFO" "Using modules (test fragments), uploading them in the pods"
    module_dir="scenario/module"

    j=0
    logit "INFO" "Number of slaves is ${slave_num}"
    logit "INFO" "Processing directory.. ${module_dir}"

    for modulePath in $(ls ${module_dir}/*.jmx)
    do
        module=$(basename "${modulePath}")

        for i in $(seq -f "%0${slave_digit}g" 0 $((slave_num-1)))
            do
                printf "Copy %s to %s on %s\n" "${module}" "${jmeter_directory}/${module}" "${slave_pods[j]}"
                kubectl -n "${namespace}" cp "${modulePath}" "${slave_pods[j]}":"${jmeter_directory}/${module}"
                i=$((i+1))
            done
        kubectl -n "${namespace}" cp "${modulePath}" "${master_pod}":"${jmeter_directory}/${module}"
    done

    logit "INFO" "Finish copying modules in slave pod"
fi

logit "INFO" "Copying ${jmx} to slaves pods"
j=0
logit "INFO" "Number of slaves is ${slave_num}"

for i in $(seq -f "%0${slave_digit}g" 0 $((slave_num-1)))
do
    logit "INFO" "Copying scenario/${jmx_dir}/${jmx} to ${slave_pods[j]}"
    kubectl cp "scenario/${jmx_dir}/${jmx}" -n "${namespace}" "${slave_pods[j]}:/opt/jmeter/apache-jmeter/bin/"
    j=$((j+1))
done # for i in "${slave_pods[@]}"
logit "INFO" "Finish copying scenario in slaves pod"

logit "INFO" "Copying scenario/${jmx_dir}/${jmx} into ${master_pod}"
kubectl cp "scenario/${jmx_dir}/${jmx}" -n "${namespace}" "${master_pod}:/opt/jmeter/apache-jmeter/bin/"


logit "INFO" "Installing needed plugins on slave pods"
## Starting slave pod 

{
    echo "cd ${jmeter_directory}"
    echo "sh PluginsManagerCMD.sh install-for-jmx ${jmx} > plugins-install.out 2> plugins-install.err"
    echo "jmeter-server -Dserver.rmi.localport=50000 -Dserver_port=1099 -Jserver.rmi.ssl.disable=true >> jmeter-injector.out 2>> jmeter-injector.err &"
} > "scenario/${jmx_dir}/jmeter_injector_start.sh"

j=0
for i in $(seq -f "%0${slave_digit}g" 0 $((slave_num-1)))
do
        logit "INFO" "Starting jmeter server on ${slave_pods[j]} in parallel"
        kubectl cp "scenario/${jmx_dir}/jmeter_injector_start.sh" -n "${namespace}" "${slave_pods[j]}:/opt/jmeter/jmeter_injector_start"
        kubectl exec -i -n "${namespace}" "${slave_pods[j]}" -- /bin/bash "/opt/jmeter/jmeter_injector_start" &  
        j=$((j+1))
done # for i in "${slave_pods[@]}"



# Copying dataset on slave pods
if [ -n "${csv}" ]; then
    logit "INFO" "Splitting and uploading csv to pods"
    dataset_dir=./scenario/dataset

    for csvfilefull in $(ls ${dataset_dir}/*.csv)
        do
            logit "INFO" "csvfilefull=${csvfilefull}"
            csvfile="${csvfilefull##*/}"
            logit "INFO" "Processing file.. $csvfile"
            lines_total=$(cat "${csvfilefull}" | wc -l)
            logit "INFO" "split --suffix-length=\"${slave_digit}\" -d -l $((lines_total/slave_num)) \"${csvfilefull}\" \"${dataset_dir}/\""
            split --suffix-length="${slave_digit}" -d -l $((lines_total/slave_num)) "${csvfilefull}" "${dataset_dir}/"

            j=0
            for i in $(seq -f "%0${slave_digit}g" 0 $((slave_num-1)))
            do
                printf "Copy %s to %s on %s\n" "${i}" "${csvfile}" "${slave_pods[j]}"
                kubectl -n "${namespace}" cp "${dataset_dir}/${i}" "${slave_pods[j]}":"${jmeter_directory}/${csvfile}"
                rm -v "./scenario/dataset/${i}"
                j=$((j+1))
            done
    done
fi


slave_list=$(kubectl -n ${namespace} describe endpoints jmeter-slaves-svc | grep ' Addresses' | awk -F" " '{print $2}')
logit "INFO" "JMeter slave list : ${slave_list}"
slave_array=($(echo ${slave_list} | sed 's/,/ /g'))


## Starting Jmeter load test
source "scenario/${jmx_dir}/.env"

param_host="-Ghost=${host} -Gport=${port} -Gprotocol=${protocol}"
param_test="-GtimeoutConnect=${timeoutConnect} -GtimeoutResponse=${timeoutResponse}"
param_user="-Gthreads=${threads} -Gduration=${duration} -Grampup=${rampup}"


if [ -n "${enable_report}" ]; then
    report_command_line="--reportatendofloadtests --reportoutputfolder /report/report-${jmx}-$(date +"%F_%H%M%S")"
fi

echo "slave_array=(${slave_array[@]}); index=${slave_num} && while [ \${index} -gt 0 ]; do for slave in \${slave_array[@]}; do if echo 'test open port' 2>/dev/null > /dev/tcp/\${slave}/1099; then echo \${slave}' ready' && slave_array=(\${slave_array[@]/\${slave}/}); index=\$((index-1)); else echo \${slave}' not ready'; fi; done; echo 'Waiting for slave readiness'; sleep 2; done" > "scenario/${jmx_dir}/load_test.sh"

{ 
    echo "echo \"Installing needed plugins\""
    echo "cd /opt/jmeter/apache-jmeter/bin" 
    echo "sh PluginsManagerCMD.sh install-for-jmx ${jmx}" 
    echo "jmeter ${param_host} ${param_user} ${report_command_line} --logfile ${jmx}_$(date +"%F_%H%M%S").jtl --nongui --testfile ${jmx} -Dserver.rmi.ssl.disable=true --remotestart ${slave_list} >> jmeter-master.out 2>> jmeter-master.err &" 
} >> "scenario/${jmx_dir}/load_test.sh"

logit "INFO" "Copying scenario/${jmx_dir}/load_test.sh into  ${master_pod}:/opt/jmeter/load_test"
kubectl cp "scenario/${jmx_dir}/load_test.sh" -n "${namespace}" "${master_pod}:/opt/jmeter/load_test"

logit "INFO" "Starting the performance test"
kubectl exec -i -n "${namespace}" "${master_pod}" -- /bin/bash "/opt/jmeter/load_test"