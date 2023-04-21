#!/bin/sh
set -o errexit

# This script assumes that you are running it from the make file as it will 
# source environment variables from the .env file.

# Handle Azure login, whether it's a user or SPN normally depends on CI
if ! az account show 1>/dev/null 2>&1; then
  if [ -z "$ARM_CLIENT_ID" ]; then
    az login --tenant $ARM_TENANT_ID
  else
    az login --service-principal -u $ARM_CLIENT_ID -p=$ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID
  fi
fi
az account set --subscription $ARM_SUBSCRIPTION_ID

# checking if AKS is running, otherwise start it
aks_status=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query "powerState.code")
if [ "$aks_status" != "\"Running\"" ]; then
  printf "\n⚓  Starting AKS...\n\n"
  az aks start --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
fi

printf "\n⚓  Getting K8s Context...\n\n"
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME

printf "\n🤖  Starting Azure deployments...\n\n"

printf '\n📀 Deploy Redis\n\n'
helm repo add bitnami https://charts.bitnami.com/bitnami
helm uninstall redis
helm install redis bitnami/redis


printf '\n📀 Init Dapr\n\n'
# TODO: https://docs.dapr.io/operations/hosting/kubernetes/kubernetes-deploy/
dapr uninstall --kubernetes --namespace dapr-system
dapr init --kubernetes --namespace dapr-system --wait --timeout 600

printf '\n📀 Deploy pub-sub broker component backed by Redis\n\n'
kubectl apply -f ./local/components/pubsub.yaml --wait=true

printf '\n📀 Deploy state store component backed Redis\n\n'
kubectl apply -f ./local/components/state.yaml --wait=true

printf '\n🎖️  Deploying Public API Service\n\n'
cd ./src/public-api-service
sh ./service-deploy.sh --hostname ${ACR_NAME} --azure

printf '\n ================================== \n\n'

printf '\n🎖️  Deploying Fraud Service\n\n'
cd ../../src/fraud-service
sh ./service-deploy.sh --hostname ${ACR_NAME} --azure

printf '\n ================================== \n\n'

printf '\n🎖️  Deploying Account Service\n\n'
cd ../../src/account-service
sh ./service-deploy.sh --hostname ${ACR_NAME} --azure

printf '\n ================================== \n\n'

printf '\n🎖️  Notification Service\n\n'
cd ../../src/notification-service
sh ./service-deploy.sh --hostname ${ACR_NAME} --azure

printf "\n🎉 Azure environment setup completed!\n\n"
