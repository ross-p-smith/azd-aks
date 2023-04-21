#!/bin/sh

azure_deployment=0

usage() {
    echo ""
    echo "usage: ./service-deploy.sh --hostname <HOSTNAME> [--azure]"
    echo ""
    echo "  --hostname    string      The IP address where the service will be deployed"
    echo "  --azure       boolean     Optional. Declare to deploy to Azure Container Registry defined by hostname"
    echo ""
}

failed() {
    printf "💥 Script failed: %s\n\n" "$1"
    exit 1
}

# parse parameters

if [ $# -gt 3 ]; then
    usage
    exit 1
fi

while [ $# -gt 0 ]
do
    name="${1}"
    case "$name"  in
        --hostname) hostname="$2"; shift;;
        --azure) azure_deployment=1;;
        --) shift;;
    esac
    shift;
done

# validate parameters
if [ -z "$hostname" ]; then
    failed "You must supply --hostname"
fi

serviceName="account-service"
version=$(date +%Y.%m.%d.%H.%M.%S)

if [ $azure_deployment -eq 1 ]; then
  # login to Container Registry hosting the image
  az acr login --name "${hostname}"

  # update hostname with full registry name
  hostname="${hostname}.azurecr.io"
fi

printf "\n🛖  Releasing version: %s\n\n" "${version}"

printf "\n☢️  Attempting to delete existing deployment %s\n\n" "${serviceName}"
kubectl delete deployment "${serviceName}" --ignore-not-found=true

printf "\n🏗️  Building docker image\n\n"
docker build -t "${hostname}/${serviceName}":"${version}" .

printf "\n🚚  Pushing docker image to registry\n\n"
docker push "${hostname}/${serviceName}":"${version}"

printf "\n🚀  Deploying to cluster\n\n"
cat <<EOF | kubectl apply -f -

apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${serviceName}
  labels:
    app: ${serviceName}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${serviceName}
  template:
    metadata:
      labels:
        app: ${serviceName}
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-id: "${serviceName}"
        dapr.io/app-port: "8080"
        dapr.io/enable-api-logging: "true"
    spec:
      containers:
      - name: node
        image: ${hostname}/${serviceName}:${version}
        env:
        - name: APP_PORT
          value: "8080"
        - name: APP_VERSION
          value: "${version}"
        ports:
        - containerPort: 80
        imagePullPolicy: Always
EOF


printf "\n🎉  Deployment complete\n\n"