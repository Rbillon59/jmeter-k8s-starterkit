
# JMeter k8s startekit

This is a template repository from which you can start load testing faster when injecting load from a kubernetes cluster.

You will find inside it the necessary to organize and run your performance scenario.

Thanks to [Kubernauts](https://github.com/kubernauts/jmeter-kubernetes) for the inspiration !



## Features

| Feature     | Supported    | Comment    |
|-------------|:------------:|-------------
| Flexibility at run time      | Yes | With .env file (threads, duration, host) |
| Distributed testing      | Yes | Virtually unlimited with auto-scaling     |
| Plugin support | Yes | Modules are installed at run time by scanning the JMX needs      |
| Module support | Yes | JMeter include controller are supported if path is just name of file
| CSV splitting | Yes | CSV files are splitted prior to launch the test|
| Node auto-scaling | Yes | By requesting ressources at deployment time, the cluster will scale automatically if needed |
| Reporting | Yes | The JMeter report is generated at the end of the test inside the master pod if the -f flag is used in the start_test.sh|
| Live monitoring | Barely | Only on the JMeter master pod logs. If you want live monitoring, deploy your own |
| Report persistance | No | At pods destruction, all the pods filesystems are lost |
| Multi thread group support | Not really | You can add multi thread groups, but if you want to use JMeter properties (like threads etc..) you need to add them in the .env and update the start_test.sh to update the "user_param" variable to add the desired variables |


Why do not include the Live reporting tools like InfluxDB and Grafana ?  

Because most of the time there is a already established live monitoring system inside your infrastructure that you can use.   
It complexify a lot the repository template that I want to keep simple and generic.   
Managing statefulness and file persistance in Kubernetes bring it complexity too.  

Here you have the necessary tools to run a performance test correctly through Kubernetes and it's the goal of the repository !


## Getting started

Prerequisites : 
- A kubernetes cluster (of course)
- kubectl installed and a usable context to work with
- (Optionnal) A JMeter scenario (the default one attack Google.com)
- (Optionnal) An external JMeter live reporting solution (like InfluxDB with Grafana).

### 1. Preparing the repository

You need to put your JMeter project inside the `scenario` folder, inside a folder named after the JMX (without the extension).
Put your CSV file inside the `dataset` folder, child of `scenario`
Put your JMeter modules (include controlers) inside the `module` folder, child of `scenario`

`dataset`and `module`are in `scenario` and not below inside the `<project>` folder because, in some cases, you can have multiple JMeter projects that are sharing the JMeter modules (that's the goal of using modules after all).


*Below a visual representation of the file structure*

```bash
+-- scenario
|   +-- dataset
|   +-- module
|   +-- my-scenario
|       +-- my-scenario.jmx
|       +-- .env
```

### 2. Deploying JMeter

`kubectl apply -f deploy_master.yaml -f deploy_slaves.yaml`

This will deploy services, and pods. That's it. The containers inside the pods are told to sleep until receiving an order.


### 3. Starting the test

`./start_test.sh -j my-scenario.jmx -n default -c -m -i 20 -r`

Usage :
```sh
   -j <filename.jmx>
   -n <namespace >for namespace previously created (default the last created with the deploy script)
   -c flag to split and copy csv if you use csv in your test
   -m flag to copy fragmented jmx present in scenario/project/module if you use include controller and external test fragment
   -i <injectorNumber> to scale slaves pods to the desired number of JMeter injectors
   -r flag to enable report generation at the end of the test
```


**The script will :**
- Scale the JMeter slave deployment to 0 to delete all remaining pods from a previous. (Needed because if not recreated, the slave pods have already launched the jmeter-server process and done the plugin installation. And if you launch another with different plugins needs, the plugin installation step is not triggered)
- Scale the JMeter slave deployment to the desired number of injectors
- Wait to all the slaves pods to be available. Here, available means that the filesystem is reacheable (liveness probe that cat a file inside the fs)
- If needed will split the CSV locally then copy them inside the slave pods
- If needed will upload the JMeter modules inside the slave pods
- Send the JMX file to each slave pods
- Generate and send a shell script to the slaves pods to download the necessary plugins and launch the JMeter server.
- Send the JMX to the controller 
- Generate a shell script and send it to the controller to wait for all pods to have their JMeter slave port listening (TCP 1099) and launch the performance test.

*Pro tip : Even if the process is launched with `kubectl exec`, JMeter will write it logs to stdout. So a `kubectl -n <namespace> logs jmeter-master-<podId>` will give you the JMeter controller logs*


### 4. Gethering results from the master pod

You can run `kubectl cp -n <namespace> <master-pod-id>:/opt/jmeter/apache-jmeter/bin/<result> $PWD/<local-result-name>`
You can do this for the generated report and the JTL for example.
