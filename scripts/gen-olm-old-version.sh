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

if [ -z "${OPERATOR_NAMESPACE}" ]; then
    echo "Please set OPERATOR_NAMESPACE"; exit 1
fi
if [ -z "${OPERATOR_NAME}" ]; then
    echo "Please set OPERATOR_NAME"; exit 1
fi
if [ -z "${IMAGE}" ]; then
    # OPENSTACK_IMG should be set to http://registry.redhat.io/redhat/redhat-operator-index:v4.16
    echo "Please set IMAGE"; exit 1
fi
if [ -z "${OPERATOR_DIR}" ]; then
    echo "Please set OPERATOR_DIR"; exit 1
fi

if [ -z "${VERSION}" ]; then
    echo "Please specify which VERSION"; exit 1
fi

if [ -z "${PODMAN_LOGIN_FILE}" ]; then
    echo "Please specifiy the PODMAN_LOGIN_FILE"
    echo "Format should be <username> <password>"
    echo "${HOME}/.config/redhat/podman_login_file_tmp.txt"
    exit 1
fi

echo "FOOBAR: gen op in ${OPERATOR_DIR}"
if [ ! -d ${OPERATOR_DIR} ]; then
    mkdir -p ${OPERATOR_DIR}
fi

OPERATOR_CHANNEL=${OPERATOR_CHANNEL:-"stable-v1.0"}
OPERATOR_SOURCE="rhoso-testing-operator-catalog"
OPERATOR_SOURCE_NAMESPACE=${OPERATOR_SOURCE_NAMESPACE:-"openshift-marketplace"}

echo OPERATOR_DIR ${OPERATOR_DIR}
echo OPERATOR_CHANNEL ${OPERATOR_CHANNEL}
echo OPERATOR_SOURCE ${OPERATOR_SOURCE}
echo OPERATOR_SOURCE_NAMESPACE ${OPERATOR_SOURCE_NAMESPACE}

# Apply the non-trunk procedure: https://spaces.redhat.com/pages/viewpage.action?spaceKey=PRODCHAIN&title=Consuming+non-trunk+RHOSO+operators
#curl --negotiate -u : https://employee-token-manager.registry.redhat.com/v1/tokens -s | jq -r '.[] | "\(.credentials.username) \(.credentials.password)"' > podman_login.txt


# Add it to the OCP pull secret (replace username and password with the ones for the above token):
# get the current
oc get secret/pull-secret -n openshift-config -o json | \
     jq -r '.data.".dockerconfigjson"' | base64 -d > authfile

read -r username password < "${PODMAN_LOGIN_FILE}"
# Add it
echo "FOOBAR: authenticating"
podman login --authfile authfile \
       --username "${username}" \
       --password "${password}" \
       brew.registry.redhat.io

 # upload it
oc set data secret/pull-secret -n openshift-config \
   --from-file=.dockerconfigjson=authfile

echo "FOBBAR files in $(pwd)"
cat <<EOF > brew-registry-imageContentSourcePolicy.yaml
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: brew-registry
spec:
  repositoryDigestMirrors:
  - mirrors:
    - brew.registry.redhat.io
    source: registry.redhat.io
  - mirrors:
    - brew.registry.redhat.io
    source: registry.stage.redhat.io
  - mirrors:
    - brew.registry.redhat.io
    source: registry-proxy.engineering.redhat.com
EOF

oc apply -f ./brew-registry-imageContentSourcePolicy.yaml
# 
# can share this for all the operators, won't get re-applied if it already exists
cat > ${OPERATOR_DIR}/operatorgroup.yaml <<EOF_CAT
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openstack
  namespace: ${OPERATOR_NAMESPACE}
EOF_CAT

cat > ${OPERATOR_DIR}/catalogsource.yaml <<EOF_CAT
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ${OPERATOR_SOURCE}
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: brew.registry.redhat.io/rh-osbs/iib:892408
  displayName: FOOBAR RHOSO Operator Catalog
  publisher: grpc
EOF_CAT


operators="openstack barbican cinder designate glance heat horizon infra ironic keystone manila mariadb neutron nova octavia openstack-ansibleee openstack-baremetal ovn placement rabbitmq-cluster swift telemetry"

for operator in ${operators}; do
    cat <<EOF > "${OPERATOR_DIR}/${operator}-subscription.yaml"
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${operator}
  namespace: ${OPERATOR_NAMESPACE}
spec:
  channel: ${OPERATOR_CHANNEL}
  installPlanApproval: Manual
  name: ${operator}-operator
  source: ${OPERATOR_SOURCE}
  sourceNamespace: openshift-marketplace
  startingCSV: ${operator}-operator.${VERSION}
EOF
done
