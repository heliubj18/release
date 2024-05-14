#!/bin/bash

set -euo pipefail

export KUBECONFIG="${SHARED_DIR}/kubeconfig"

# get cluster namesapce
CLUSTER_NAME=$(cat "${SHARED_DIR}/cluster-name")
if [[ -z "${CLUSTER_NAME}" ]] ; then
  echo "Error: cluster name not found"
  exit 1
fi

read -r namespace _ _  <<< "$(oc get cluster -A | grep ${CLUSTER_NAME})"
if [[ -z "${namespace}" ]]; then
  echo "Error: capi cluster name not found, ${CLUSTER_NAME}"
  exit 1
fi

secret_name="${CLUSTER_NAME}-kubeconfig"
if [[ "${ENABLE_EXTERNAL_OIDC}" == "true" ]]; then
  secret_name="${CLUSTER_NAME}-bootstrap-kubeconfig"
fi

secret=$(oc get secret -n ${namespace} ${secret_name} --ignore-not-found -ojsonpath='{.data.value}')
if [[ -z "$secret" ]]; then
  echo "capi kubeconfig not found, exit"
  exit 1
fi

mv $KUBECONFIG "${SHARED_DIR}/mgmt_kubeconfig"
echo "${secret}" | base64 -d > "${SHARED_DIR}/kubeconfig"
echo "hosted cluster kubeconfig is switched"
oc whoami


