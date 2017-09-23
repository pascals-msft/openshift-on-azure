# openshift-on-azure

`deploy.sh` is a Bash script for deploying OpenShift Origin in Azure, using the template provided by Microsoft, with a little more automation and repeatability.

The ARM templates for deploying OpenShift Origin and OpenShift Container Platform on Azure are available on http://aka.ms/OpenShift.

## Prerequisites

You will need a Linux system (tested on Ubuntu 16.04 LTS) or Bash on [Windows Subsystem for Linux](https://msdn.microsoft.com/en-us/commandline/wsl/about "Windows Subsystem for Linux Documentation").

Then you need an SSH Key. Remember that the private key will be uploaded some of the VMs, so don't use your own key. You can generate a new key with:
```
ssh-keygen -N "" -f <ssh key file>
```

You also need [jq](https://stedolan.github.io/jq/):
```
sudo apt install jq
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
- DEMO_NAME: name used for the log file, the resource group, the Key Vault and the parameters file
- LOCATION: Azure region (full list: `az account list-locations`)
- SSH_KEY_FILE: SSH private key file name (the one from above)
- USER_NAME: a user name for the VMs and for OpenShift
- USER_PASSWORD: the user password for OpenShift

Parameters for the JSON parameters file: the most likely to be changed are the numbers of VM.
- masterInstanceCount: 3 or 5
- infraInstanceCount: 2 or 3
- nodeInstanceCount: 1 to 30

## Deployment

Just run `./deploy.sh` to run the deployment. The script will automatically:
- create the resource group,
- create a Key Vault in the resource group, and store the SSH key as a secret in the vault,
- create a service principal and assign the Contributor role on the resource group,
- generate a parameters file for the ARM template,
- initiate the deployment.

Once the script is finished, the deployment should be in progress. You can track its progress with this command:
```
az group deployment list -g <resource group name>
```
Where the resource group name is the same as the demo name.

When the deployment is completely finished (it may take 30 minutes to complete), you can get the deployment outputs with this command:
```
az group deployment show -n azuredeploy -g <resource group name> -o json | jq -r .properties.outputs
```
Two interesting outputs are the OpenShift Console URL, and the OpenShift Master SSH command. When connecting with SSH, don't forget to use the SSH key from before:
```
ssh -i <SSH key file> <username>@<master FQDN>
```


