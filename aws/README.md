
You can follow the full tutorial here : https://romain-billon.medium.com/ultimate-jmeter-kubernetes-starter-kit-7eb1a823649b

If you enjoy and want to support my work :

<a href="https://www.buymeacoffee.com/rbill" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png" alt="Buy Me A Coffee" style="height: 41px !important;width: 174px !important;box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;-webkit-box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;" ></a>

# JMeter k8s starterkit for Amazon Web Services

This is a template repository from which you can start load testing faster when injecting load from a kubernetes cluster.

You will find inside it the necessary to organize and run your performance scenario. There is also a node monitoring tool which will monitor all your injection nodes. As well an embeded live monitoring with InfluxDB and Grafana

Thanks to [Kubernauts](https://github.com/kubernauts/jmeter-kubernetes) for the inspiration !

## Getting started
Prerequisites :
- An active AWS account
- Functional cli requirements: 
    <table>
    <tr>
    <th>CLI</th> <th>Test Command</th> <th>Description</th>
    </tr>
    <tr>
    <td>bash</td>
    <td>

    ```bash
    bash --version
    ```

    </td>
    <td>Scripts are written in Shell, so make sure bash is installed</td>
    </tr>
    <tr>
    <td>aws</td>
    <td>

    ```bash
    aws --version
    ```

    </td>
    <td>AWS cli allows you to send commands without using aws console. It permits to completely automate stack creation and deletion</td>
    </tr>
    <tr>
    <td>kubernetes</td>
    <td>

    ```bash
    kubectl version --client
    ```

    </td>
    <td>Kubernetes cli allows you to manage the k8s stack that will be created in aws. Note that jmeter-k8s-starterkit cannot work without `kubectl`</td>
    </tr>
    <tr>
    <td>helm</td>
    <td>
    
    ```bash
    helm version
    ```
    
    </td>
    <td>Helm is a package manager for Kubernetes applications. It simplifies the process of defining, installing, and managing Kubernetes applications and their dependencies. Helm enables you to package Kubernetes resources, such as deployments, services, and ConfigMaps, into a single deployable unit called a "chart.", used to deploy the tools for tests</td>
    </tr>
    </table>
- Functional and valid scenario (see [scenario explanation](../README.md#1-preparing-the-repository))

### 1. Deploy the aws stack

Go inside the `scripts` folder and execute `./generateCloudForm.sh`
Provide the following parameters:
- `-s`: The name of stack that will be deployed, for example `jmeter-k8s-stack`
- `-r`: Region to deploy for example `eu-west-1`
- `-p`: Profile to use for commands that will be sent by aws cli

Now wait for your stack to be successfully deployed.

### 2. Start the scenarii

When the stack is fully deployed and ready to use, you can execute the script `./start_test.sh`
Provide the following parameters:

| Argument | Description | Example |
|----------|-------------|---------|
| `-c` | Flag to split and copy csv if you use csv in your test | `-c` |
| `-i` | Number of injectors to scale slaves pods to the desired number of JMeter injectors | `2` |
| `-j` | The scenario file name, it has to end with `.jmx` | `my-scenario.jmx` |
| `-m` | Flag to copy fragmented jmx present in scenario/project/module if you use include controller and external test fragment | `-m` |
| `-n` | The Kubernetes namespace that will be used | `default` |
| `-r` | Flag to enable report generation at the end of the test | `-r` |

### 3. Access the panel: 
While the script is running you can access to the grafana dashboard.
Feel free to execute this command if it didn't work, you can modify `3000` by the local port you want
`kubectl port-forward $(kubectl get pod | grep grafana |awk '{print $1}') 3000`
> Warning, this command is already executed in the script `start_test.sh`  
#### And then access to the address [localhost:3000](http://localhost:3000) with the following credentials:  

| username | password |     
| :-------------: | :-------------: |
| admin | XhXUdmQ576H6e7 |



### 4. Gethering results from the master pod

After the test have been executed, the master pod job is in completed state and then, is deleted by the cleaner cronjob.

To be able to get your result, a jmeter master pod must be in ***running state*** (because the pod is mounting the persistantVolume with the reports inside).

*The master pod default behaviour is to wait until the load_test script is present in the pod*

You can run   

```sh
# If a master pod is not available, create one
kubectl apply -f k8s/jmeter/jmeter-master.yaml
# Wait for the pod is Running, then
kubectl cp -n <namespace> <master-pod-id>:/report/<result> ${PWD}/<local-result-name>
# To copy the content of the report from the pod to your local
```

For example:
```bash
kubectl cp $(kubectl get pod | grep master | awk '{print $1}'):/report ./report/
```
This will copy all the test results in a `report` folder.

You can do this for the generated report and the JTL for example.

So, if you want to test the deployment you can run in the `scripts` folder:

```bash 
# Provision the stack  
./generateCloudForm.sh -s example-stack -r eu-west-1 -p default

# Start the JMeter scenario  
./start_test.sh  -cmri 2 -n default -j my-scenario.jmx

# Free resources  
./deleteCloudForm.sh -s example-stack -r eu-west-1 -p default  
```