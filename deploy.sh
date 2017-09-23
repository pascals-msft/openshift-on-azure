#!/bin/bash

# Source: https://aka.ms/openshift
# Demo: OpenShift Origin
#
# Prerequisites:
# generate a SSH key
#   ssh-keygen -N "" -f <ssh key file>
# install jq:
#   sudo apt install jq
# install Azure CLI 2.0:
#   https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest
# login and select the subscription:
#   az login
#   az account set --subscription <subscription name>

#### Edit variables here
DEMO_NAME=demo-3
LOCATION=westeurope
SSH_KEY_FILE=~/.ssh/demo_id_rsa
USER_NAME=azureuser
USER_PASSWORD=OpenShift..1

# Other variables
LOG_FILE=$DEMO_NAME.log
echo $(date) - $0 > $LOG_FILE
RG_NAME=$DEMO_NAME
KV_NAME=${DEMO_NAME}-kv
SSH_SECRET=demosshkey
SSH_PUBLIC_KEY=$(ssh-keygen -y -f $SSH_KEY_FILE)
PARAMETERS_FILE=azuredeploy.parameters.${DEMO_NAME}.json

tee -a $LOG_FILE <<EOF
DEMO_NAME=$DEMO_NAME
LOG_FILE=$LOG_FILE
LOCATION=$LOCATION
RG_NAME=$RG_NAME
KV_NAME=$KV_NAME
SSH_SECRET=$SSH_SECRET
SSH_KEY_FILE=$SSH_KEY_FILE
SSH_PUBLIC_KEY=$SSH_PUBLIC_KEY
PARAMETERS_FILE=$PARAMETERS_FILE
USER_NAME=$USER_NAME
USER_PASSWORD=$USER_PASSWORD
EOF

# Subscription id
echo ---Subscription ID | tee -a $LOG_FILE
ARM_SUBSCRIPTION_ID=$(az account show -o json | jq -r .id)
echo ARM_SUBSCRIPTION_ID=$ARM_SUBSCRIPTION_ID | tee -a $LOG_FILE

# Resource group
echo ---Resource group | tee -a $LOG_FILE
RG_JSON=$(az group create -n $RG_NAME -l $LOCATION -o json)
RG_ID=$(echo $RG_JSON | jq -r .id)
echo RG_ID=$RG_ID | tee -a $LOG_FILE

# Key Vault and SSH Key
echo ---Key vault | tee -a $LOG_FILE
az keyvault create -n $KV_NAME -g $RG_NAME -l $LOCATION --enabled-for-template-deployment true | tee -a $LOG_FILE
echo ---Secret | tee -a $LOG_FILE
az keyvault secret set --vault-name $KV_NAME -n $SSH_SECRET --file $SSH_KEY_FILE | tee -a $LOG_FILE

# Service principal
echo ---Service Principal | tee -a $LOG_FILE
ARM_SERVICE_PRINCIPAL=$(az ad sp create-for-rbac --role Contributor --scopes $RG_ID -o json)

# Example:
# {
#   "appId": "4f6525e2-9bee-4de0-90e2-be5121d5e060",
#   "displayName": "azure-cli-2017-04-24-16-47-01",
#   "name": "http://azure-cli-2017-04-24-16-47-01",
#   "password": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
#   "tenant": "72f988bf-86f1-41af-91ab-2d7cd011db47"
# }

SP_APP_ID=$(echo $ARM_SERVICE_PRINCIPAL | jq -r .appId)
SP_PASSWORD=$(echo $ARM_SERVICE_PRINCIPAL | jq -r .password)

tee -a $LOG_FILE <<EOF
ARM_SERVICE_PRINCIPAL=$ARM_SERVICE_PRINCIPAL
SP_APP_ID=$SP_APP_ID
SP_PASSWORD=$SP_PASSWORD
EOF

# Parameters file
# Source:
# https://raw.githubusercontent.com/Microsoft/openshift-origin/master/azuredeploy.parameters.json
# https://raw.githubusercontent.com/Microsoft/openshift-origin/master/azuredeploy.parameters.sample.local.json

echo ---Parameters file | tee -a $LOG_FILE

### Edit parameters here
cat > $PARAMETERS_FILE <<EOF
{
	"\$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
	"contentVersion": "1.0.0.0",
	"parameters": {
		"_artifactsLocation": {
			"value": "https://raw.githubusercontent.com/Microsoft/openshift-origin/master/"
		},
		"masterVmSize": {
			"value": "Standard_DS2_v2"
		},
		"infraVmSize": {
			"value": "Standard_DS2_v2"
		},
		"nodeVmSize": {
			"value": "Standard_DS2_v2"
		},
		"openshiftClusterPrefix": {
			"value": "$DEMO_NAME"
		},
		"masterInstanceCount": {
			"value": 3
		},
		"infraInstanceCount": {
			"value": 2
		},
		"nodeInstanceCount": {
			"value": 3
		},
		"dataDiskSize": {
			"value": 128
		},
		"adminUsername": {
			"value": "$USER_NAME"
		},
		"openshiftPassword": {
			"value": "$USER_PASSWORD"
		},
		"sshPublicKey": {
			"value": "$SSH_PUBLIC_KEY"
		},
		"keyVaultResourceGroup": {
			"value": "$RG_NAME"
		},
		"keyVaultName": {
			"value": "$KV_NAME"
		},
		"keyVaultSecret": {
			"value": "$SSH_SECRET"
		},
		"aadClientId": {
			"value": "$SP_APP_ID"
		},
		"aadClientSecret": {
			"value": "$SP_PASSWORD"
		},
		"defaultSubDomainType": {
			"value": "xipio"
		},
		"defaultSubDomain": {
			"value": "xxxx"
		}
	}
}
EOF

echo ---Deployment | tee -a $LOG_FILE

az group deployment create -g $RG_NAME --template-uri https://raw.githubusercontent.com/Microsoft/openshift-origin/master/azuredeploy.json --parameters @azuredeploy.parameters.demo.json -o json | tee -a $LOG_FILE

# The end
tee -a $LOG_FILE <<EOF
----------
To watch the deployment:
$ watch az group deployment list -g $RG_NAME

Once the deployment is completed, get the outputs like this:
$ az group deployment show -n azuredeploy -g $RG_NAME -o json | jq -r .properties.outputs

If you need to cleanup the whole demo,
delete the Resource group and the service principal:
$ az group delete -n $RG_NAME --no-wait -y
$ az ad app delete --id $SP_APP_ID
EOF
