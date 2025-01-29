# These are a set of scripts which faciltate the upgrade of OKD 4.15 (FCOS) to OKD 4.16 (SCOS) 

# pre-upgrade-4.15.sh:

This script updates the template and worker nodes on vSphere to disable Secure Boot.  Secure Boot is the default on FCOS templates but not currently supported on SCOS.

Copy config.sh-template file to config.sh and modify to match your environment.

Requires govc binary.  Latest is from https://github.com/vmware/govmomi/releases/

The script will read templates from the available MachineSets.  There is also a TEMPLATE variable to manually add FCOS templates.  They will then be iterated through to have Secure Boot disabled.

Each worker node will be drained of running pods and shutdown.  Once shutdown, the VM will have Secure Boot disabled and then the vm will be restarted.
The script waits for the node to come back up into a Ready state, uncordons the node and waits a configurable time to stabilize.  After that the next worker node is processed.


UPI Installs:
   * There is now a flag to process Control Plane nodes if needed.  I discovered that UPI nodes may have the Control Plane Secure Boot enabled:  
       ```ENABLE_CONTROL_PLANE_UPGRADE=false```
   * The vSphere vm names and the OKD node names need to be the same

# update_cluster_4.16.sh:

This cluster updates  4.15 cluster to fix the broken update process.  Applies a patch to kube-apiserver-operator.

update the following variable in the script to the target 4.16 version.  Default is 4.16.0-okd-scos.1

```tgt_cluster=4.16.0-okd-scos.1```

Patch looks something like this:

PATCH:
```{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "kube-apiserver-operator",
            "image": "quay.io/okd/scos-content@sha256:37d6b6c13d864deb7ea925acf2b2cb34305333f92ce64e7906d3f973a8071642",
            "env": [
              {
                "name": "IMAGE",
                "value": "quay.io/okd/scos-content@sha256:5c9128668752a9b891a24a9ec36e0724d975d6d49e6e4e2d516b5ba80ae2fb23"
              },
              {
                "name": "OPERATOR_IMAGE",
                "value": "quay.io/okd/scos-content@sha256:37d6b6c13d864deb7ea925acf2b2cb34305333f92ce64e7906d3f973a8071642"
              },
              {
                "name": "OPERAND_IMAGE_VERSION",
                "value": "1.29.6"
              }
            ]
          }
        ]
      }
    }
  }
}
```


