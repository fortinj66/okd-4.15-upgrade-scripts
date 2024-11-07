source ./config.sh

oc login --server=${OKD_API} --token=${OKD_TOKEN}  >/dev/null

MACHINESETS=$(oc get machineset -A --no-headers -o custom-columns=NAME:metadata.name)

echo "Finding vm templates in existing MachineSets"
for machineset in ${MACHINESETS}
do
	TEMPLATES="${TEMPLATES} $(oc get machineset -n openshift-machine-api -o json ${machineset} | jq .spec.template.spec.providerSpec.value.template)"	
done

export TEMPLATES=$(echo ${TEMPLATES} ${TEMPLATE} | xargs -n 1 | sort | uniq)  

echo TEMPLATES=${TEMPLATES}
echo
echo "Template Modification is Starting"
echo

for TEMPLATE in ${TEMPLATES}
do
  echo "  Changing ${TEMPLATE} to VM"
  govc vm.markasvm ${TEMPLATE} 
  echo "  Setting Secure Boot to false on ${TEMPLATE}"
  govc device.boot -vm ${TEMPLATE} -secure=false -firmware=efi
  echo "  Changing ${TEMPLATE} to Template"
  govc vm.markastemplate ${TEMPLATE}
done

echo
echo "Template Modification is Complete"

echo
echo "Preparing to Disable Secure Boot on Worker Nodes"

WORKERS=$(oc get nodes --no-headers -o custom-columns=NAME:metadata.name --selector='!node-role.kubernetes.io/master')

if [[ ${ENABLE_CONTROL_PLANE_UPGRADE} == "true" ]]
then
	CONTROL_PLANES=$(oc get nodes --no-headers -o custom-columns=NAME:metadata.name --selector='node-role.kubernetes.io/master')
fi	

NODES="${CONTROL_PLANES} ${WORKERS}"

for node in $NODES
do
	echo "Draining ${node}"
	oc adm drain --ignore-daemonsets --delete-emptydir-data ${node}  >/dev/null  2>&1
	sleep 30

	echo "Shutdown ${node}"
	govc vm.power -s -wait ${node}  >/dev/null

	while [[ -n "$(govc find . -type m -runtime.powerState poweredOn | grep ${node} )" ]] 
	do
		echo "   Waiting for ${node} to shutdown"
		sleep 5
	done

	while [[ "$(oc get node ${node} --subresource status --no-headers | awk '{print $2}')" != NotReady* ]] 
	do
		echo "   Waiting for ${node} to be NotReady "
		sleep 5
	done

	echo "Turn off Secure Boot on ${node}"
	govc device.boot -vm ${node} -secure=false >/dev/null

	echo "Power on ${node}"
	govc vm.power -wait -on ${node} >/dev/null

	while [[ "$(oc get node ${node} --subresource status --no-headers | awk '{print $2}')" != Ready* ]] 
	do
		echo "   Waiting for ${node} to be Ready "
		sleep 5
	done

	echo "Uncordon ${node}"
	oc adm uncordon ${node} >/dev/null

	echo "Waiting ${OKD_STABILIZE_TIME} Seconds for cluster to Stabilize"
	sleep ${OKD_STABILIZE_TIME}
	echo
done

echo "Disable Secure Boot on Worker Nodes Complete"
