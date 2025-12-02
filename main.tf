# VM Resource Declarations
# Feature: vSphere VM Provisioning with Kubernetes Deployment via Kubespray
# Spec: /workspace/specs/001-vsphere-k8s-kubespray/spec.md
# User Story 1 (P1): Infrastructure Provisioning (FR-001, FR-003, FR-004, FR-005)
#
# Using private module: tfo-apj-demos/single-virtual-machine/vsphere v1.4.2

# =============================================================================
# Control Plane Node (FR-003)
# =============================================================================

module "k8s_control_plane_01" {
  source  = "app.terraform.io/tfo-apj-demos/single-virtual-machine/vsphere"
  version = "1.4.2"

  # Required inputs
  hostname         = "k8s-master-01"
  size             = var.control_plane_vm_size
  os_type          = "linux"
  environment      = var.environment
  site             = var.vsphere_site
  storage_profile  = var.storage_profile
  tier             = var.service_tier
  security_profile = var.security_profile
  backup_policy    = var.backup_policy
  ad_domain        = var.vm_domain

  # Optional inputs
  folder_path        = var.vsphere_folder
  linux_distribution = "ubuntu"
}

# =============================================================================
# Worker Node 01 (FR-004)
# =============================================================================

module "k8s_worker_01" {
  source  = "app.terraform.io/tfo-apj-demos/single-virtual-machine/vsphere"
  version = "1.4.2"

  # Required inputs
  hostname         = "k8s-worker-01"
  size             = var.worker_vm_size
  os_type          = "linux"
  environment      = var.environment
  site             = var.vsphere_site
  storage_profile  = var.storage_profile
  tier             = var.service_tier
  security_profile = var.security_profile
  backup_policy    = var.backup_policy
  ad_domain        = var.vm_domain

  # Optional inputs
  folder_path        = var.vsphere_folder
  linux_distribution = "ubuntu"
}

# =============================================================================
# Worker Node 02 (FR-004)
# =============================================================================

module "k8s_worker_02" {
  source  = "app.terraform.io/tfo-apj-demos/single-virtual-machine/vsphere"
  version = "1.4.2"

  # Required inputs
  hostname         = "k8s-worker-02"
  size             = var.worker_vm_size
  os_type          = "linux"
  environment      = var.environment
  site             = var.vsphere_site
  storage_profile  = var.storage_profile
  tier             = var.service_tier
  security_profile = var.security_profile
  backup_policy    = var.backup_policy
  ad_domain        = var.vm_domain

  # Optional inputs
  folder_path        = var.vsphere_folder
  linux_distribution = "ubuntu"
}
