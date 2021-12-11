
You can follow the full tutorial here : https://romain-billon.medium.com/ultimate-jmeter-kubernetes-starter-kit-7eb1a823649b

If you enjoy and want to support my work :

<a href="https://www.buymeacoffee.com/rbill" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png" alt="Buy Me A Coffee" style="height: 41px !important;width: 174px !important;box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;-webkit-box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;" ></a>

# JMeter k8s startekit

This is a template repository from which you can start load testing faster when injecting load from a kubernetes cluster.

You will find inside it the necessary to organize and run your performance scenario. There is also a node monitoring tool which will monitor all your injection nodes. As well an embeded live monitoring with InfluxDB and Grafana

Thanks to [Kubernauts](https://github.com/kubernauts/jmeter-kubernetes) for the inspiration !



## Features

<p align="center"><a href="https://ibb.co/ccM9RJp"><img src="https://i.ibb.co/0j8L1qW/jmeter-starterkit.jpg" alt="jmeter-starterkit" border="0" /></a></p>

| Feature     | Supported    | Comment    |
|-------------|:------------:|-------------
| Flexibility at run time      | Yes | With .env file (threads, duration, host) |
| Distributed testing      | Yes | Virtually unlimited with auto-scaling     |
| JMeter Plugin support | Yes | Modules are installed at run time by scanning the JMX needs      |
| JMeter Module support | Yes | JMeter include controller are supported if *path* is just the name of the file in the *Include Controler*
| JMeter CSV support | Yes | CSV files are splitted prior to launch the test and unique pieces copied to each pods, in the JMeter scenario, just put the name of the file in the *path* field |
| Node auto-scaling | Yes | By requesting ressources at deployment time, the cluster will scale automatically if needed |
| Reporting | Yes | The JMeter report is generated at the end of the test inside the master pod if the -r flag is used in the start_test.sh|
| Live monitoring | Yes | An InfluxDB instance and a Grafana are available in the stack |
| Report persistance | Yes | A persistence volume is used to store the reports and results |
| Injector nodes monitoring | Yes | Even if autoscaling, a Daemon Set will deploy a telegraf instance and persist the monitoring data to InfluxDB. A board is available in Grafana to show the Telegraf monitoring
| Multi thread group support | Not really | You can add multi thread groups, but if you want to use JMeter properties (like threads etc..) you need to add them in the .env and update the start_test.sh to update the "user_param" variable to add the desired variables |
| Mocking service | Yes | A deployment of Wiremock is done inside the cluster, the mappings are done inside the wiremock configmap. Also an horizontal pod autoscaler have been added
| JVM Monitoring | Yes | JMeter and Wiremock are both Java application. They have been packaged with Jolokia and Telegraf and are monitored
| Pre built Grafana Dashboards | Yes | 4 Grafana dashboards are shipped with the starter kit. Node monitoring, Kubernetes ressources monitoring, JVM monitoring and JMeter result dashboard.
| Ressource friendly | Yes | JMeter is deployed as batch job inside the cluster. Thus at the end  of the execution, pods are deleted and ressources freed



## Getting started

Prerequisites : 
- A kubernetes cluster (of course)
- kubectl installed and a usable context to work with
- (Optionnal) A JMeter scenario (the default one attack Google.com)

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

### 2. Deploying the Stack

`kubectl create -R -f k8s/`

This will deploy all the needed applications :

- JMeter master and slaves
- Telegraf operator to automatically monitor the specified applications
- Telegraf as a DaemonSet on all the nodes
- InfluxDB to store the date (with a 5GB volume in a PVC)
- Grafana with a LB services and 4 included dashboard
- Wiremock

### 3. Starting the test

`./start_test.sh -j my-scenario.jmx -n default -c -m -i 20 -r`

Usage :
```sh
   -j <filename.jmx>
   -n <namespace>
   -c flag to split and copy csv if you use csv in your test
   -m flag to copy fragmented jmx present in scenario/project/module if you use include controller and external test fragment
   -i <injectorNumber> to scale slaves pods to the desired number of JMeter injectors
   -r flag to enable report generation at the end of the test
```


**The script will :**

- Delete and create again the JMeter jobs.
- Scale the JMeter slave deployment to the desired number of injectors
- Wait to all the slaves pods to be available. Here, available means that the filesystem is reacheable (liveness probe that cat a file inside the fs)
- If needed will split the CSV locally then copy them inside the slave pods
- If needed will upload the JMeter modules inside the slave pods
- Send the JMX file to each slave pods
- Generate and send a shell script to the slaves pods to download the necessary plugins and launch the JMeter server.
- Send the JMX to the controller 
- Generate a shell script and send it to the controller to wait for all pods to have their JMeter slave port listening (TCP 1099) and launch the performance test.



### 4. Gethering results from the master pod

After the test have been executed, the master pod job is in completed state and then, is deleted by the cleaner cronjob.

To be able to get your result, a jmeter master pod must be in ***running state*** (because the pod is mounting the persistantVolume with the reports inside).

*The master pod default behaviour is to wait indefinetly*

You can run   

```sh
# If a master pod is not available, create one
kubectl apply -f k8s/jmeter/jmeter-master.yaml
# Wait for the pod is Running, then
kubectl cp -n <namespace> <master-pod-id>:/report/<result> ${PWD}/<local-result-name>
# To copy the content of the report from the pod to your local
```
You can do this for the generated report and the JTL for example.  
