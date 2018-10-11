#!/usr/bin/env bash

# Source: http://aka.ms/OpenShift
# Demo: OpenShift Origin
#
# Prerequisites:
# python must be present
# generate a SSH key
#   ssh-keygen -N "" -f <ssh key file>
# install Azure CLI 2.0:
#   https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest
# login and select the subscription:
#   az login
#   az account set --subscription <subscription name>

set -x
set -e

#### Edit variables here
DEMO_NAME=demo-openshift-$RANDOM
LOCATION=francecentral
# SSH_KEY_FILE=~/.ssh/demo_id_rsa
SSH_KEY_FILE=~/.ssh/${DEMO_NAME}_rsa
USER_NAME=openshift
USER_PASSWORD=redhat123

# Log file
LOG_FILE=$DEMO_NAME.log
echo $(date) - $0 > $LOG_FILE

# SSH key
if [ ! -f $SSH_KEY_FILE ]; then
	echo ---SSH key | tee -a $LOG_FILE
	echo "Creating new SSH key: $SSH_KEY_FILE" | tee -a $LOG_FILE
	ssh-keygen -N "" -f $SSH_KEY_FILE | tee -a $LOG_FILE
fi

# Other variables
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

# Resource group
echo ---Resource group | tee -a $LOG_FILE
RG_ID=$(az group create -n $RG_NAME -l $LOCATION --query [id] -o tsv)
echo RG_ID=$RG_ID | tee -a $LOG_FILE

# Key Vault and SSH Key
echo ---Key vault | tee -a $LOG_FILE
az keyvault create -n $KV_NAME -g $RG_NAME -l $LOCATION --enabled-for-template-deployment true | tee -a $LOG_FILE
echo ---Secret | tee -a $LOG_FILE
az keyvault secret set --vault-name $KV_NAME -n $SSH_SECRET --file $SSH_KEY_FILE | tee -a $LOG_FILE

# Service principal
echo ---Service Principal | tee -a $LOG_FILE
SP_TSV=$(az ad sp create-for-rbac --role Contributor --scopes $RG_ID -o tsv)
# Example:
# c966217a-a002-4a4b-8fc7-040c574abe44	azure-cli-2018-10-11-16-30-01	http://azure-cli-2018-10-11-16-30-01	3e3bb517-79e4-4d55-870d-6b52a73f93b5	72f988bf-86f1-41af-91ab-2d7cd011db47
# fields: AppId, DisplayName, Name, Password, Tenant
SP_APP_ID=$(echo $SP_TSV | cut -d ' ' -f 1)
SP_PASSWORD=$(echo $SP_TSV | cut -d ' '  -f 4)

tee -a $LOG_FILE <<EOF
SP_TSV=$SP_TSV
SP_APP_ID=$SP_APP_ID
SP_PASSWORD=$SP_PASSWORD
EOF

# Parameters file
# Source:
# https://raw.githubusercontent.com/Microsoft/openshift-origin/master/azuredeploy.parameters.json
# https://raw.githubusercontent.com/Microsoft/openshift-origin/master/azuredeploy.parameters.sample.local.json

echo ---Parameters file

### Edit parameters here
cat > $PARAMETERS_FILE <<EOF
{
	"\$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
	"contentVersion": "1.0.0.0",
	"parameters": {
		"_artifactsLocation": {
			"value": "https://raw.githubusercontent.com/Microsoft/openshift-origin/release-3.9/"
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
		"storageKind": {
			"value": "managed"
		},
		"openshiftClusterPrefix": {
			"value": "$DEMO_NAME"
		},
		"masterInstanceCount": {
			"value": 3
		},
		"infraInstanceCount": {
			"value": 3
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
		"enableMetrics": {
			"value": "true"
		},
		"enableLogging": {
			"value": "true"
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
		"enableAzure": {
			"value": "true"
		},
		"aadClientId": {
			"value": "$SP_APP_ID"
		},
		"aadClientSecret": {
			"value": "$SP_PASSWORD"
		},
		"defaultSubDomainType": {
			"value": "nipio"
		},
		"defaultSubDomain": {
			"value": "xxxx"
		}
	}
}
EOF

echo ---Deployment | tee -a $LOG_FILE

az group deployment create -g $RG_NAME --template-uri https://raw.githubusercontent.com/Microsoft/openshift-origin/master/azuredeploy.json --parameters @$PARAMETERS_FILE --no-wait

# The end
tee -a $LOG_FILE <<EOF
----------
To watch the deployment:
$ watch az group deployment list -g $RG_NAME

Once the deployment is completed, get the outputs like this:
$ az group deployment show -n azuredeploy -g $RG_NAME --query [properties.outputs] -o json

If you need to cleanup the whole demo,
delete the Resource group and the service principal:
$ az group delete -n $RG_NAME --no-wait -y
$ az ad app delete --id $SP_APP_ID
EOF
