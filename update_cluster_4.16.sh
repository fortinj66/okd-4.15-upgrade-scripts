#/usr/bin/bash

current_cluster=4.15.0-0.okd-2024-03-10-010116
tgt_cluster=4.16.0-okd-scos.1


tgt_digest=`curl -s --no-progress-bar  https://amd64.origin.releases.ci.openshift.org/graph | grep -E "\"version\"|\"payload\""  | awk '{print $1. $2}' | xargs -n 2 | sed -e "s/version://" -e "s/payload://" -e "s/,//" | grep ${tgt_cluster} | awk '{print $2}'`

kube_digest=`oc adm release info --image-for=hyperkube ${tgt_digest}`

kube_api_digest=`oc adm release info --image-for=cluster-kube-apiserver-operator ${tgt_digest}`

patch="{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"kube-apiserver-operator\",\"image\":\"${kube_api_digest}\", \"env\":[{\"name\":\"IMAGE\", \"value\":\"${kube_digest}\"}, {\"name\":\"OPERATOR_IMAGE\", \"value\":\"${kube_api_digest}\"}, {\"name\":\"OPERAND_IMAGE_VERSION\", \"value\":\"1.29.6\"}]}]}}}}"

echo "Current Cluster: ${current_cluster}"
echo "Target Cluster: ${tgt_cluster}"
echo "   Target Cluster Digest: ${tgt_digest}"
echo "Target Kube Digest: ${kube_digest}"
echo "Target Kube API Digest: ${kube_api_digest}"
echo
echo "PATCH:"
echo $patch | jq
echo



read -p "Press enter to begin upgrade to ${tgt_cluster}"
oc adm upgrade --to-image=${tgt_digest} --allow-explicit-upgrade
echo

read -p "Press enter when cluster is stuck upgrading. This will scale cluster-version-operator to 0"
oc scale --replicas=0 deployments/cluster-version-operator -n openshift-cluster-version
echo

read -p "Press enter after cluster-version-operator scaled to 0.  This will apply the patch above to kube-apiserver-operator"
oc patch deployment/kube-apiserver-operator -n openshift-kube-apiserver-operator -p "$patch"
echo

read -p "Press enter after new kube-apiservers have rolled out.  This will scale up cluster-version-operator"
oc scale --replicas=1 deployments/cluster-version-operator -n openshift-cluster-version
echo

echo "Cluster should now finish upgrade"
