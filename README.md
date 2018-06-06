# openshift-on-azure

`deploy.sh` is a Bash script for deploying OpenShift Origin in Azure, using the template provided by Microsoft, with a little more automation and repeatability.

The ARM templates for deploying OpenShift Origin and OpenShift Container Platform on Azure are available on http://aka.ms/OpenShift.

## Prerequisites

You will need a Linux system (tested on Ubuntu 16.04 LTS) or Bash on [Windows Subsystem for Linux](https://msdn.microsoft.com/en-us/commandline/wsl/about "Windows Subsystem for Linux Documentation"), or a Mac. You also need [Python](https://www.python.org/), at least 2.6, but it should already be in your system: the `which python` command should return something.

Then you need an SSH Key. Remember that the private key will be uploaded some of the VMs, so don't use your own key. You can generate a new key with:
```
ssh-keygen -N "" -f <new ssh key file>
```
For instance:
```
ssh-keygen -N "" -f ~/.ssh/demo_id_rsa
```

And if not already done, install [Azure CLI 2.0](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest "Install Azure CLI 2.0"), login and select the subscription:
```
az login
az account set --subscription <subscription name>
```

## Preparation

Before running the script:
- edit the variables at the top of the script
- edit the parameters in the JSON portion of the script

Variables:
- `DEMO_NAME`: name used for the log file, the resource group, the Key Vault and the parameters file. Since the Key Vault name must be unique, the use of `$RANDOM` in this name is convenient.
- `LOCATION`: Azure region (full list: `az account list-locations`)
- `SSH_KEY_FILE`: SSH private key file name (the one from above)
- `USER_NAME`: a user name for the VMs and for OpenShift
- `USER_PASSWORD`: the user password for OpenShift

Parameters for the JSON parameters file: the most likely to be changed are VM sizes and the numbers of VM.
- `masterVmSize`, `nodeVmSize`, `infraVmSize`: for instance, `Standard_DS2_v2`. These parameters are case sensitive.
- `masterInstanceCount`: 1, 3 or 5
- `infraInstanceCount`: 1, 2 or 3
- `nodeInstanceCount`: 1 to 30

## Deployment

Just run `./deploy.sh` to run the deployment. The script will automatically:
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
$ az group deployment list -g demo-13673
Name                 Timestamp                         State
-------------------  --------------------------------  ---------
azuredeploy          2018-06-06T05:54:46.983440+00:00  Running
masterVmDeployment2  2018-06-06T05:57:27.241508+00:00  Succeeded
nodeVmDeployment0    2018-06-06T05:57:32.606050+00:00  Succeeded
infraVmDeployment1   2018-06-06T05:57:37.151068+00:00  Succeeded
nodeVmDeployment1    2018-06-06T05:57:42.147226+00:00  Succeeded
masterVmDeployment0  2018-06-06T05:57:42.240062+00:00  Succeeded
infraVmDeployment0   2018-06-06T05:57:42.328470+00:00  Succeeded
masterVmDeployment1  2018-06-06T05:57:56.275798+00:00  Succeeded
OpenShiftDeployment  2018-06-06T06:05:21.514135+00:00  Running
```

When the deployment is completely finished (it may take 50 minutes to complete), you can get the deployment outputs with this command:
```
az group deployment show -n azuredeploy -g <resource group name> --query [properties.outputs] -o json
```
Example:
```
$ az group deployment show -n azuredeploy -g demo-13673 --query [properties.outputs] -o json
[
  {
    "openshift Console Url": {
      "type": "String",
      "value": "https://masterdnsoyhfumycvo434.francecentral.cloudapp.azure.com/console"
    },
    "openshift Infra Load Balancer FQDN": {
      "type": "String",
      "value": "infradnsfh6ox5zd36h3m.francecentral.cloudapp.azure.com"
    },
    "openshift Master SSH": {
      "type": "String",
      "value": "ssh -p 2200 openshift@masterdnsoyhfumycvo434.francecentral.cloudapp.azure.com"
    }
  }
]
```

Two interesting outputs are the OpenShift Console URL, and the OpenShift Master SSH command. When connecting with SSH, don't forget to specify the SSH key from before, with the `-i` parameter:
```
ssh -i <SSH key file> <username>@<master FQDN> -p 2200
```
For instance:
```
$ ssh -i ~/.ssh/demo_id_rsa -p 2200 openshift@masterdnsoyhfumycvo434.francecentral.cloudapp.azure.com 
The authenticity of host '[masterdnsoyhfumycvo434.francecentral.cloudapp.azure.com]:2200 ([40.89.128.111]:2200)' can't be established.
ECDSA key fingerprint is SHA256:021MalmaKLFaPZfYJKSEhxKKLgLVbZJpcSLC1vJ6b5I.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '[masterdnsoyhfumycvo434.francecentral.cloudapp.azure.com]:2200,[40.89.128.111]:2200' (ECDSA) to the list of known hosts.
Last login: Wed Jun  6 07:01:16 2018 from demo-13673-master-0
[openshift@demo-13673-master-0 ~]$ 
[openshift@demo-13673-master-0 ~]$ oc status
In project default on server https://masterdnsoyhfumycvo434.francecentral.cloudapp.azure.com

https://docker-registry-default.40.89.131.11.nip.io (passthrough) (svc/docker-registry)
  dc/docker-registry deploys docker.io/openshift/origin-docker-registry:v3.9.0 
    deployment #2 deployed 34 minutes ago - 1 pod
    deployment #1 deployed 37 minutes ago

svc/kubernetes - 172.30.0.1 ports 443, 53->8053, 53->8053

https://registry-console-default.40.89.131.11.nip.io (passthrough) (svc/registry-console)
  dc/registry-console deploys docker.io/cockpit/kubernetes:latest 
    deployment #1 deployed 36 minutes ago - 1 pod

svc/router - 172.30.109.164 ports 80, 443, 1936
  dc/router deploys docker.io/openshift/origin-haproxy-router:v3.9.0 
    deployment #1 deployed 38 minutes ago - 2 pods

View details with 'oc describe <resource>/<name>' or list everything with 'oc get all'.
[openshift@demo-13673-master-0 ~]$
```

Finaly, the log file contains the commands you can use to completely delete the demo, by deleting the resource group and the service principal.
