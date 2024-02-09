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
if [ -z "${deployment}" ]; then
  echo "Deployment name is not set, defaulting to 'web'"
  deployment="web"
fi

echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
mkdir ~/.kube/

echo "Downloading jq 1.6 binary to the home directory..."
wget -O ~/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
chmod +x ~/jq

echo "Adding jq to the PATH for the current session..."
export PATH=$PATH:~/jq

echo "jq 1.6 installed and added to PATH."
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

./kubectl --insecure-skip-tls-verify get nodes -o wide

if ! ./kubectl --insecure-skip-tls-verify get namespace ${namespace}
then
  echo "Namespace not found"
  exit 1
fi

if ! ./kubectl --insecure-skip-tls-verify get deployment ${deployment} -n ${namespace}
then
  echo "Deployment not found"
  exit 1
fi

if [ -z "${image}" ]; then
  echo "Bumping the deployment..."
  ./kubectl --insecure-skip-tls-verify -n ${namespace} rollout restart deployment ${deployment}
else
  echo "Bumping the deployment with the image: ${image}..."
  ./kubectl --insecure-skip-tls-verify -n ${namespace} set image deployment/${deployment} ${deployment}=${image}
fi

echo "Waiting for the deployment to complete..."
./kubectl --insecure-skip-tls-verify -n ${namespace} rollout status deployment ${deployment}

echo "Deployment complete"
