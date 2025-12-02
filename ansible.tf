# Ansible Integration for Kubespray Deployment
# Feature: vSphere VM Provisioning with Kubernetes Deployment via Kubespray
# Spec: /workspace/specs/001-vsphere-k8s-kubespray/spec.md
# User Story 2 (P2): Kubernetes Cluster Deployment (FR-011, FR-013, FR-014)
#
# Using private module: tfo-apj-demos/single-virtual-machine/vsphere v1.4.2

# =============================================================================
# Wait for VMs to be SSH Accessible (FR-013)
# =============================================================================

resource "null_resource" "wait_for_vms" {
  count = 3

  provisioner "remote-exec" {
    inline = ["echo 'VM is ready for Ansible provisioning'"]

    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = var.ssh_private_key
      host        = local.vm_ip_addresses[count.index]
      timeout     = "5m"
    }
  }

  depends_on = [
    module.k8s_control_plane_01,
    module.k8s_worker_01,
    module.k8s_worker_02
  ]
}

# =============================================================================
# Execute Kubespray Playbook for Kubernetes Deployment (FR-011, FR-014)
# =============================================================================

resource "ansible_playbook" "kubespray_cluster" {
  playbook   = var.kubespray_playbook_path
  name       = "kubespray-cluster-deployment"
  replayable = false

  extra_vars = {
    ansible_user                 = var.ssh_user
    ansible_ssh_private_key_file = var.ssh_private_key_path
    cluster_name                 = var.cluster_name
    kube_version                 = var.kubernetes_version
    kube_network_plugin          = var.cni_plugin
    ansible_inventory            = local_file.kubespray_inventory.filename
  }

  depends_on = [
    null_resource.wait_for_vms,
    local_file.kubespray_inventory
  ]
}
