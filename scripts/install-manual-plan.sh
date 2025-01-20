#!/usr/bin/bash
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
INSTALL_PLAN_TIMEOUT=100

sleep 10

echo "Waiting for the install plan to be available"
echo "oc get installplans -n openstack-operators"
until oc get installplans -n openstack-operators |grep install- &> /dev/null; do
      sleep 5
      (( INSTALL_PLAN_TIMEOUT-- ))
      [[ "${INSTALL_PLAN_TIMEOUT}" -eq 0 ]] && exit 1
done

plan=$(oc get installplans -n \
          openstack-operators -o jsonpath='{.items[0].metadata.name}')

oc patch installplan "${plan}" --type merge -p '{"spec":{"approved":true}}'

echo "Waiting for the the operators to be installed : oc get csv -n openstack-operators"
oc wait installplan/install-5srn4 -n openstack-operators --for=condition=Installed --timeout 800

oc get csv -n openstack-operators
