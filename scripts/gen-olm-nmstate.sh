#!/bin/bash
#
# Copyright 2022 Red Hat Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
set -ex

if [ -z "${OPERATOR_DIR}" ]; then
    echo "Please set OPERATOR_DIR"; exit 1
fi

if [ ! -d ${OPERATOR_DIR} ]; then
    mkdir -p ${OPERATOR_DIR}
fi

if [ -z "${DEPLOY_DIR}" ]; then
    echo "Please set DEPLOY_DIR"; exit 1
fi

if [ ! -d ${DEPLOY_DIR} ]; then
    mkdir -p ${DEPLOY_DIR}
fi

echo OPERATOR_DIR ${OPERATOR_DIR}
echo DEPLOY_DIR ${DEPLOY_DIR}

cat > ${OPERATOR_DIR}/operatorgroup.yaml <<EOF_CAT
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  annotations:
    olm.providedAPIs: NMState.v1.nmstate.io
  generateName: openshift-nmstate-
  name: ${OPERATOR_GROUP}
  namespace: ${NAMESPACE}
spec:
  targetNamespaces:
  - openshift-nmstate
EOF_CAT

# ~/Src/contrib/openstack-k8s-operators/install_yamls/out/openstack-operators/nmstate/op
cat > ${OPERATOR_DIR}/subscription.yaml <<EOF_CAT
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    operators.coreos.com/kubernetes-nmstate-operator.openshift-nmstate: ""
  name: ${SUBSCRIPTION}
  namespace: ${NAMESPACE}
spec:
  channel: stable
  installPlanApproval: Automatic
  name: ${SUBSCRIPTION}
  source: ${OPERATOR_SOURCE}
  sourceNamespace: openshift-marketplace
EOF_CAT

# ~/Src/contrib/openstack-k8s-operators/install_yamls/out/openshift-nmstate/nmstate/cr

cat > ${DEPLOY_DIR}/deploy_operator.yaml <<EOF_CAT
apiVersion: nmstate.io/v1
kind: NMState
metadata:
  name: nmstate
EOF_CAT
