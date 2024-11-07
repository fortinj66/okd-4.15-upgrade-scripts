This script updates the template and worker nodes on vSphere to disable Secure Boot.  Secure Boot is the default on FCOS templates but not currently supported on SCOS.

Copy config.sh-template file to config.sh and modify to match your environment.

Requires govc binary.  Latest is from https://github.com/vmware/govmomi/releases/

The script will read templates from the available MachineSets.  There is also a TEMPLATE variable to manually add FCOS templates.  They will then be iterated through to have Secure Boot disabled.

Each worker node will be drained of running pods and shutdown.  Once shutdown, the VM will have Secure Boot disabled and then the vm will be restarted.
The script waits for the node to come back up into a Ready state, uncordons the node and waits a configurable time to stabilize.  After that the next worker node is processed.

There is now a flag to process Control Plane nodes if needed.  I discovered that UPI nodes may have the Control Plane Secure Boot enabled:  
  ENABLE_CONTROL_PLANE_UPGRADE=false
