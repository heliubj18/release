#!/bin/bash

set -xeuo pipefail

export AWS_SHARED_CREDENTIALS_FILE="${CLUSTER_PROFILE_DIR}/.awscred"
export AWS_REGION=${HYPERSHIFT_AWS_REGION}
export AWS_PAGER=""

# use an existing ocp as management cluster for test
aws s3 cp s3://heli-test-02/mgmt_kubeconfig ${SHARED_DIR}/mgmt_kubeconfig

# download clusterctl and clusterawsadm
mkdir -p /tmp/bin
export PATH=/tmp/bin:$PATH
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.6.2/clusterctl-linux-amd64 -o /tmp/bin/clusterctl && \
    chmod +x /tmp/bin/clusterctl

curl -L https://github.com/kubernetes-sigs/cluster-api-provider-aws/releases/download/v2.4.0/clusterawsadm-linux-amd64 -o /tmp/bin/clusterawsadm && \
    chmod +x /tmp/bin/clusterawsadm

export KUBECONFIG="${SHARED_DIR}/kubeconfig"
if [[ -f "${SHARED_DIR}/mgmt_kubeconfig" ]]; then
  export KUBECONFIG="${SHARED_DIR}/mgmt_kubeconfig"
fi

cvo=$(oc get clusterversion --ignore-not-found)
if [[ -n "$cvo" ]] ; then
  echo "management cluster is an OpenShift cluster"
  oc adm policy add-scc-to-user privileged system:serviceaccount:capi-system:capi-manager
  oc adm policy add-scc-to-user privileged system:serviceaccount:capa-system:capa-controller-manager
  oc adm policy add-scc-to-user privileged system:serviceaccount:capi-kubeadm-control-plane-system:capi-kubeadm-control-plane-manager
  oc adm policy add-scc-to-user privileged system:serviceaccount:capi-kubeadm-bootstrap-system:capi-kubeadm-bootstrap-manager
fi

clusterawsadm bootstrap iam create-cloudformation-stack
AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm bootstrap credentials encode-as-profile)
export AWS_B64ENCODED_CREDENTIALS=${AWS_B64ENCODED_CREDENTIALS}

if [[ "$EXP_ROSA" == "true" ]] ; then
  export EXP_ROSA="true"
fi

if [[ "$EXP_MACHINE_POOL" == "true" ]] ; then
  export EXP_MACHINE_POOL="true"
fi

# init capi/capa controllers
clusterctl init --infrastructure aws

oc wait --for=condition=Ready pod -n capi-system --all --timeout=2m
oc wait --for=condition=Ready pod -n capi-kubeadm-bootstrap-system --all --timeout=2m
oc wait --for=condition=Ready pod -n capi-kubeadm-control-plane-system --all --timeout=2m

## use custom capa image to fix some existing failures
#oc -n capa-system patch deploy capa-controller-manager --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value":"quay.io/heli/cluster-api-aws-controller:dev"}]'

oc wait --for=condition=Ready pod -n capa-system --all --timeout=5m