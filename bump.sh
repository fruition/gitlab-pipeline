#!/bin/bash

# This script is used to deploy the staging environment
# Exit on any error

echo "Verifying environment variables..."
if [ -z "${cluster}" ]; then
  echo "Cluster name is not set"
  exit 1
fi
if [ -z "${project}" ]; then
  echo "Project name is not set"
  exit 1
fi
if [ -z "${namespace}" ]; then
  echo "Namespace name is not set"
  exit 1
fi

echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
mkdir ~/.kube/

echo "Installing jq..."
apt-get update -y && apt-get install -y jq
jq --version

echo "Installing rancher-projects..."
wget -O ./rancher-projects.sh https://raw.githubusercontent.com/SupportTools/rancher-projects/main/rancher-projects.sh
chmod +x ./rancher-projects.sh

echo "Settings up project, namespace, and kubeconfig"
./rancher-projects.sh \
--cluster-name ${cluster} \
--project-name ${project} \
--namespace ${namespace} \
--create-project true \
--create-namespace true \
--create-kubeconfig true \
--kubeconfig ~/.kube/config

export KUBECONFIG=~/.kube/config

if ! ./kubectl cluster-info
then
  echo "Problem connecting to the cluster"
  exit 1
fi

echo "Bumping the deployment..."
./kubectl -n ${namespace} rollout restart deployment web

echo "Waiting for the deployment to complete..."
./kubectl -n ${namespace} rollout status deployment web

echo "Deployment complete"
