#!/bin/bash

echo "Defining variables..."
export RESOURCE_GROUP_NAME=github-cd-poc-$RANDOM
export AKS_NAME=aks-vote-app
export ACR_NAME=VoteAppContainerRegistry$RANDOM

echo "Searching for resource group..."
az group create -n $RESOURCE_GROUP_NAME -l eastus

echo "Creating cluster..."
az aks create \
  --resource-group $RESOURCE_GROUP_NAME \
  --name $AKS_NAME \
  --node-count 1 \
  --enable-addons http_application_routing \
  --dns-name-prefix $AKS_NAME \
  --enable-managed-identity \
  --generate-ssh-keys \
  --node-vm-size Standard_B4ms

echo "Obtaining credentials..."
az aks get-credentials -n $AKS_NAME -g $RESOURCE_GROUP_NAME

echo "Creating ACR..."
az acr create -n $ACR_NAME -g $RESOURCE_GROUP_NAME --sku basic
az acr update -n $ACR_NAME --admin-enabled true

export ACR_USERNAME=$(az acr credential show -n $ACR_NAME --query "username" -o tsv)
export ACR_PASSWORD=$(az acr credential show -n $ACR_NAME --query "passwords[0].value" -o tsv)

az aks update \
    --name $AKS_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --attach-acr $ACR_NAME

export DNS_NAME=$(az network dns zone list -o json --query "[?contains(resourceGroup,'$RESOURCE_GROUP_NAME')].name" -o tsv)
export ACR_URL=$(az acr list --query "[?contains(resourceGroup, 'github-cd-poc')].loginServer" -o tsv)

echo "Adding ACR_NAME to deployment yaml file..."
sed -i '' 's+!IMAGE!+'"$ACR_URL"'/vote-frontend-app+g' manifests/frontend-deployment.yml

echo "Adding DNS to ingress yaml files..."
sed -i '' 's+!DNS!+'"$DNS_NAME"'+g' manifests/rollout-ingress.yml
sed -i '' 's+!DNS!+'"$DNS_NAME"'+g' manifests/canary-ingress.yml
sed -i '' 's+!DNS!+'"$DNS_NAME"'+g' manifests/blue-green-ingress.yml

echo "Creating GitHub Workflows..."

mkdir -p .github/workflows

# Create rollout-deployment workflow
echo "Creating rollout-deployment Workflow..."
sed -i '' 's+!AKS-NAME!+'"$AKS_NAME"'+g' workflow-templates/rollout-deployment.yml
sed -i '' 's+!RG-NAME!+'"$RESOURCE_GROUP_NAME"'+g' workflow-templates/rollout-deployment.yml

# Create canary-deployment workflow
echo "Creating canary-deployment Workflow..."
sed -i '' 's+!AKS-NAME!+'"$AKS_NAME"'+g' workflow-templates/canary-deployment.yml
sed -i '' 's+!RG-NAME!+'"$RESOURCE_GROUP_NAME"'+g' workflow-templates/canary-deployment.yml

# Create canary-promote-or-reject workflow
echo "Creating canary-promote-or-reject Workflow..."
sed -i '' 's+!AKS-NAME!+'"$AKS_NAME"'+g' workflow-templates/canary-promote-or-reject.yml
sed -i '' 's+!RG-NAME!+'"$RESOURCE_GROUP_NAME"'+g' workflow-templates/canary-promote-or-reject.yml

# Create blue-green-deployment workflow
echo "Creating blue-green-deployment Workflow..."
sed -i '' 's+!AKS-NAME!+'"$AKS_NAME"'+g' workflow-templates/blue-green-deployment.yml
sed -i '' 's+!RG-NAME!+'"$RESOURCE_GROUP_NAME"'+g' workflow-templates/blue-green-deployment.yml

# Create blue-green-promote-or-reject workflow
echo "Creating blue-green-promote-or-reject Workflow..."
sed -i '' 's+!AKS-NAME!+'"$AKS_NAME"'+g' workflow-templates/blue-green-promote-or-reject.yml
sed -i '' 's+!RG-NAME!+'"$RESOURCE_GROUP_NAME"'+g' workflow-templates/blue-green-promote-or-reject.yml

# Copy workflows under .github/workflows folder
echo "Created GitHub Workflows under .github/workflows folder..."
cp workflow-templates/* .github/workflows/

echo "Installation concluded, copy these values and store them"
echo "-> Resource Group Name: $RESOURCE_GROUP_NAME"
echo "-> ACR URL: $ACR_URL"
echo "-> ACR Name: $ACR_NAME"
echo "-> ACR Login Username: $ACR_USERNAME"
echo "-> ACR Password: $ACR_PASSWORD"
echo "-> AKS Cluster Name: $AKS_NAME"
echo "-> AKS DNS Zone Name: $DNS_NAME"
