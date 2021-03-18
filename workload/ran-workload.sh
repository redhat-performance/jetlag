#!/usr/bin/env bash

# kubectl create sa kube-burner
# oc adm policy add-cluster-role-to-user -z kube-burner cluster-admin
# token=$(oc sa get-token kube-burner)
# prom_route=$(oc get routes -n openshift-monitoring prometheus-k8s -o json | jq -r '.status.ingress[0].host')
# kube-burner init -c kb/ran-create.yml -u ${prom_route} -t ${token} --uuid $(uuidgen)

uuid=$(uuidgen)

pushd kb
kube-burner init -c ran-create.yml --uuid ${uuid}
popd
sleep 60
pushd kb
kube-burner init -c ran-delete.yml --uuid ${uuid}
popd
