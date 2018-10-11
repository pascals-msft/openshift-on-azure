# openshift-on-azure

`deploy.sh` is a Bash script for deploying OpenShift Origin in Azure, using the template provided by Microsoft, with a little more automation and repeatability.

The ARM templates for deploying OpenShift Origin and OpenShift Container Platform on Azure are available on http://aka.ms/OpenShift.

## Prerequisites

You will need a Linux system (tested on Ubuntu 16.04 LTS) or Bash on [Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/about "Windows Subsystem for Linux Documentation"), or a Mac.

Then you need an SSH Key, but by default the script creates one for you. Remember that the private key will be uploaded some of the VMs, so don't use your own key, the best is to let the script handle that for you.

And if not already done, install [Azure CLI 2.0](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest "Install Azure CLI 2.0"), login and select the subscription:
```
az login
az account set --subscription <subscription name>
```

## Preparation

You don't need to change anything in the script! Only change something if you need to.

You may change:
- the variables at the top of the script
- the parameters in the JSON portion of the script

Variables:
- `DEMO_NAME`: name used by default for the log file, the SSH key file, the resource group, the Key Vault and the parameters file. Since the Key Vault name must be unique, the use of `$RANDOM` in this name is convenient.
- `LOCATION`: Azure region (full list: `az account list-locations`).
- `SSH_KEY_FILE`: SSH private key file name. The script will create a new one if it doesn't exist.
- `USER_NAME`: a user name for the VMs and for OpenShift
- `USER_PASSWORD`: the user password for OpenShift

Parameters for the JSON parameters file: the most likely to be changed are VM sizes and the numbers of VM.
- `masterVmSize`, `nodeVmSize`, `infraVmSize`: for instance, `Standard_DS2_v2`. These parameters are case sensitive.
- `masterInstanceCount`: 1, 3 or 5
- `infraInstanceCount`: 1, 2 or 3
- `nodeInstanceCount`: 1 to 30

## Deployment

Just run `./deploy.sh` to run the deployment. The script will automatically:
- create the new SSH key,
- create the resource group,
- create a Key Vault in the resource group, and store the SSH key as a secret in the vault,
- create a service principal and assign the Contributor role on the resource group,
- generate a parameters file for the ARM template,
- initiate the deployment.

All will be logged in a .log file with the demo name as its base name.

Once the script is finished, the deployment should be in progress. You can track its progress with this command:
```
az group deployment list -g <resource group name>
```
Where the resource group name is the same as the demo name.

Example:
```
$ az group deployment list -g demo-openshift-24843
Name                 Timestamp                         State
-------------------  --------------------------------  ---------
azuredeploy          2018-10-11T19:20:09.324631+00:00  Running
infraVmDeployment2   2018-10-11T19:22:05.764170+00:00  Succeeded
nodeVmDeployment2    2018-10-11T19:22:07.437872+00:00  Succeeded
nodeVmDeployment1    2018-10-11T19:22:08.142167+00:00  Succeeded
infraVmDeployment0   2018-10-11T19:22:11.415120+00:00  Succeeded
nodeVmDeployment0    2018-10-11T19:22:20.528948+00:00  Succeeded
infraVmDeployment1   2018-10-11T19:22:21.930035+00:00  Succeeded
masterVmDeployment1  2018-10-11T19:22:35.780993+00:00  Succeeded
masterVmDeployment0  2018-10-11T19:22:35.881848+00:00  Succeeded
masterVmDeployment2  2018-10-11T19:22:35.933034+00:00  Succeeded
OpenShiftDeployment  2018-10-11T19:30:03.517852+00:00  Running
```

When the deployment is completely finished (it may take 50 minutes to complete), you can get the deployment outputs with this command:
```
az group deployment show -n azuredeploy -g <resource group name> --query [properties.outputs] -o json
```
Example:
```
$ az group deployment show -n azuredeploy -g demo-openshift-24843 --query [properties.outputs] -o json
[
  {
    "openShift Console Url": {
      "type": "String",
      "value": "https://masterdnsbz7f4nm3ld4bg.francecentral.cloudapp.azure.com/console"
    },
    "openShift Infra Load Balancer FQDN": {
      "type": "String",
      "value": "infradnsv3nonlsqjrrb4.francecentral.cloudapp.azure.com"
    },
    "openShift Master SSH": {
      "type": "String",
      "value": "ssh -p 2200 openshift@masterdnsbz7f4nm3ld4bg.francecentral.cloudapp.azure.com"
    }
  }
]

```

Two interesting outputs are the OpenShift Console URL, and the OpenShift Master SSH command. When connecting with SSH, don't forget to specify the SSH key from before, with the `-i` parameter:
```
ssh -i <SSH key file> -p 2200 <username>@<master FQDN>
```
For instance:
```
$ ssh -i ~/.ssh/demo-openshift-24843_rsa -p 2200 openshift@masterdnsbz7f4nm3ld4bg.francecentral.cloudapp.azure.com
The authenticity of host '[masterdnsbz7f4nm3ld4bg.francecentral.cloudapp.azure.com]:2200 ([40.89.139.76]:2200)' can't be established.
ECDSA key fingerprint is SHA256:Ye5YNOjVA3R12z5BFQVizxapAiH9vie5ZqNokva56to.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '[masterdnsbz7f4nm3ld4bg.francecentral.cloudapp.azure.com]:2200,[40.89.139.76]:2200' (ECDSA) to the list of known hosts.
Last login: Thu Oct 11 20:34:00 2018 from demo-openshift-24843-master-0
[openshift@demo-openshift-24843-master-0 ~]$ 
[openshift@demo-openshift-24843-master-0 ~]$ oc status
In project default on server https://masterdnsbz7f4nm3ld4bg.francecentral.cloudapp.azure.com

https://docker-registry-default.40.89.143.131.nip.io (passthrough) (svc/docker-registry)
  dc/docker-registry deploys docker.io/openshift/origin-docker-registry:v3.9.0 
    deployment #2 failed about an hour ago: config change
    deployment #1 deployed about an hour ago - 1 pod

svc/kubernetes - 172.30.0.1 ports 443, 53->8053, 53->8053

https://registry-console-default.40.89.143.131.nip.io (passthrough) (svc/registry-console)
  dc/registry-console deploys docker.io/cockpit/kubernetes:latest 
    deployment #1 deployed about an hour ago - 1 pod

svc/router - 172.30.28.155 ports 80, 443, 1936
  dc/router deploys docker.io/openshift/origin-haproxy-router:v3.9.0 
    deployment #1 deployed about an hour ago - 3 pods


1 info identified, use 'oc status -v' to see details.
[openshift@demo-openshift-24843-master-0 ~]$ 
```

Finally, the log file contains the commands you can use to completely delete the demo, by deleting the resource group and the service principal.
