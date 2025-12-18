# Implementation Plan: vSphere VM Provisioning with Kubernetes Deployment via Kubespray

**Feature Branch**: `001-vsphere-k8s-kubespray`
**Plan Version**: 1.0.0
**Created**: 2025-12-02
**Status**: Draft

---

## Technical Context

### Known Technical Details

- **Target Infrastructure**: VMware vSphere environment with 3 Ubuntu VMs
- **VM Module**: `tfo-apj-demos/single-virtual-machine/vsphere` version 1.4.2
- **Operating System**: Ubuntu Linux (latest LTS compatible with module)
- **Cluster Architecture**: 1 control plane node + 2 worker nodes
- **Kubernetes Deployment Tool**: Kubespray (Ansible-based)
- **Terraform Provider Integration**: terraform-provider-ansible for Kubespray execution
- **State Management**: HCP Terraform workspace `vm-k8s-kubespray-runai` in org `tfo-apj-demos`, project `Demo Better Together Project`
- **Network Requirements**: VM-to-VM communication on standard Kubernetes ports
- **Authentication**: SSH key-based access for Ansible playbook execution

### Constitution Check

**Module-First Architecture (1.1)**:
- ✅ Using approved private module: `tfo-apj-demos/single-virtual-machine/vsphere` v1.4.2
- ✅ No direct resource declarations planned
- ✅ Module source uses `app.terraform.io` prefix

**Specification-Driven Development (1.2)**:
- ✅ Complete specification exists at `/workspace/specs/001-vsphere-k8s-kubespray/spec.md`
- ✅ All functional requirements clearly defined (FR-001 through FR-016)
- ✅ Success criteria measurable and testable

**Security-First Automation (1.3)**:
- ✅ No static credentials in code
- ✅ SSH key management via secure variable handling
- ✅ vSphere credentials via HCP Terraform workspace configuration
- ✅ Security profile parameter enforced per module requirements

**HCP Terraform Prerequisites (2.1)**:
- ✅ Organization: `tfo-apj-demos`
- ✅ Project: `Demo Better Together Project`
- ✅ Workspace: `vm-k8s-kubespray-runai`
- ✅ Backend configuration will use cloud block for remote execution

**Testing and Validation Framework (X)**:
- ✅ Will use sandbox workspace pattern: `sandbox_vm-k8s-kubespray-runai`
- ✅ Terraform CLI with HCP cloud backend for testing
- ✅ Full validation before deployment to dev workspace

### Quality Gates

**GATE-001: Module Availability**
- **Status**: ⚠️ NEEDS VERIFICATION
- **Requirement**: Verify `tfo-apj-demos/single-virtual-machine/vsphere` v1.4.2 is accessible
- **Action**: Test module access during implementation phase

**GATE-002: Ansible Provider Selection**
- **Status**: ✅ PASSED
- **Decision**: Use `nbering/ansible` provider or `ansible/ansible` provider
- **Rationale**: Industry-standard providers for Terraform-Ansible integration

**GATE-003: Security Requirements**
- **Status**: ✅ PASSED
- **Requirement**: No hardcoded credentials, SSH keys managed securely
- **Implementation**: Use HCP Terraform workspace variables for sensitive data

**GATE-004: Kubespray Version Compatibility**
- **Status**: ⚠️ NEEDS CLARIFICATION
- **Requirement**: Determine compatible Kubespray version with terraform-provider-ansible
- **Action**: Research during Phase 0

---

## Phase 0: Outline & Research

### Research Tasks

#### R-001: Terraform-Provider-Ansible Integration
**Objective**: Determine best approach for using Ansible provider with Terraform for Kubespray deployment

**Research Questions**:
- Which Ansible provider is most suitable: `nbering/ansible` vs `ansible/ansible`?
- How to pass dynamic inventory from Terraform outputs to Ansible playbooks?
- How to handle SSH key distribution for Ansible connectivity?
- How to ensure proper dependency ordering (VMs ready → Ansible execution)?
- What are the best practices for handling Ansible playbook execution errors in Terraform?

**Decision Criteria**:
- Provider maintenance status and community support
- Compatibility with Kubespray requirements
- HCP Terraform remote execution compatibility

#### R-002: Kubespray Integration Patterns
**Objective**: Research Kubespray deployment patterns with Terraform

**Research Questions**:
- What is the recommended Kubespray version for production deployments (as of Dec 2025)?
- How to structure Kubespray inventory for Terraform-managed VMs?
- What Kubespray configuration variables are critical for initial deployment?
- How to handle Kubespray pre-requisites (Python, SSH connectivity)?
- What CNI plugin should be used (Calico, Flannel, Cilium)?

**Decision Criteria**:
- Kubespray stability and maintenance status
- Ease of integration with Terraform
- Production-readiness for basic use cases

#### R-003: vSphere Module Configuration
**Objective**: Document all required and optional parameters for single-virtual-machine module v1.4.2

**Research Questions**:
- What are the exact required parameters for the module?
- What values are acceptable for: `backup_policy`, `environment`, `security_profile`, `site`, `size`, `storage_profile`, `tier`?
- Does the module support custom CPU/memory sizing beyond the `size` parameter?
- How does the module handle networking configuration?
- What Ubuntu template naming conventions are expected?

**Decision Criteria**:
- Module documentation and source code review
- Organizational standards for parameter values

#### R-004: Dynamic Inventory Generation
**Objective**: Determine strategy for generating Ansible inventory from Terraform state

**Research Questions**:
- Should we use Terraform outputs, local-exec provisioners, or external scripts?
- What inventory format does Kubespray require (INI, YAML)?
- How to map Terraform outputs to Kubespray inventory groups (kube_control_plane, kube_node, etcd)?
- How to handle IP address assignment and SSH connectivity details?

**Decision Criteria**:
- Reliability and maintainability
- Integration with HCP Terraform remote execution
- Idempotency and repeatability

#### R-005: SSH Key Management
**Objective**: Design secure SSH key handling for VM access and Ansible execution

**Research Questions**:
- Should SSH keys be generated by Terraform or pre-created?
- How to securely store and reference private keys in HCP Terraform?
- How to inject SSH public keys into VMs during provisioning?
- What are best practices for SSH key rotation in this pattern?

**Decision Criteria**:
- Security compliance with SEC-002 requirement
- Operational simplicity
- HCP Terraform workspace variable handling

### Research Deliverables

**Output**: `/workspace/specs/001-vsphere-k8s-kubespray/research.md` with:
- Decisions for each research area
- Rationale for technology and approach selections
- Alternatives considered and why they were rejected
- References to authoritative sources and documentation

---

## Phase 1: Design & Contracts

### Prerequisites
- ✅ Phase 0 research.md completed with all decisions documented

### Data Model Design

**Entity: VirtualMachine**
```yaml
entity: VirtualMachine
attributes:
  - name: hostname
    type: string
    required: true
    description: Unique hostname for the VM
    validation: "Must match pattern k8s-(master|worker)-\\d{2}"

  - name: role
    type: string
    required: true
    description: Kubernetes role assignment
    values: ["control-plane", "worker"]

  - name: ip_address
    type: string
    required: false
    description: IP address assigned after provisioning

  - name: backup_policy
    type: string
    required: true
    description: Backup policy for VM

  - name: environment
    type: string
    required: true
    description: Deployment environment

  - name: os_type
    type: string
    required: true
    values: ["linux"]

  - name: security_profile
    type: string
    required: true
    description: Security profile classification

  - name: site
    type: string
    required: true
    description: vSphere datacenter/site identifier

  - name: size
    type: string
    required: true
    description: VM size tier

  - name: storage_profile
    type: string
    required: true
    description: Storage performance profile

  - name: tier
    type: string
    required: true
    description: Service tier classification

  - name: folder
    type: string
    required: true
    description: vSphere folder path for VM placement

relationships:
  - target: KubernetesCluster
    type: belongs_to
    description: VM is a node in the Kubernetes cluster
```

**Entity: KubernetesCluster**
```yaml
entity: KubernetesCluster
attributes:
  - name: cluster_name
    type: string
    required: true
    description: Kubernetes cluster identifier

  - name: kubernetes_version
    type: string
    required: true
    description: Target Kubernetes version
    validation: "Determined by Kubespray version selection"

  - name: cni_plugin
    type: string
    required: true
    description: Container Network Interface plugin
    values: ["calico", "flannel", "cilium"]

  - name: control_plane_nodes
    type: list(string)
    required: true
    description: List of control plane node hostnames

  - name: worker_nodes
    type: list(string)
    required: true
    description: List of worker node hostnames

  - name: api_endpoint
    type: string
    required: false
    description: Kubernetes API server endpoint (generated)

state_transitions:
  - from: provisioning
    to: ready
    condition: All nodes in Ready state via kubectl

  - from: ready
    to: degraded
    condition: One or more nodes not Ready
```

**Entity: AnsibleInventory**
```yaml
entity: AnsibleInventory
attributes:
  - name: inventory_format
    type: string
    required: true
    values: ["yaml", "ini"]

  - name: groups
    type: map(list(string))
    required: true
    description: Ansible inventory groups with host assignments
    structure:
      kube_control_plane: [list of control plane hosts]
      kube_node: [list of all nodes]
      etcd: [list of etcd hosts]
      k8s_cluster:children: [kube_control_plane, kube_node]

  - name: host_vars
    type: map(map(string))
    required: true
    description: Per-host variables including IP and SSH details

relationships:
  - source: VirtualMachine
    relationship: provides_hosts_for
    target: AnsibleInventory
```

### Terraform File Structure

```
/workspace/
├── main.tf                    # VM module instantiations
├── locals.tf                  # Computed values and data transformations
├── variables.tf               # Input variable declarations
├── outputs.tf                 # Output value declarations
├── providers.tf               # Provider configurations
├── terraform.tf               # Terraform and provider version constraints
├── override.tf                # HCP Terraform cloud backend configuration
├── ansible.tf                 # Ansible provider and playbook resources
├── inventory.tf               # Dynamic inventory generation logic
├── sandbox.auto.tfvars.example # Example variable values
├── sandbox.auto.tfvars        # Actual test variable values (gitignored)
└── README.md                  # Documentation (auto-generated via terraform-docs)
```

### Module Configurations

#### VM Provisioning (main.tf)

```hcl
# Control Plane Node
module "k8s_control_plane_01" {
  source  = "app.terraform.io/tfo-apj-demos/single-virtual-machine/vsphere"
  version = "1.4.2"

  hostname         = "k8s-master-01"
  environment      = var.environment
  site             = var.vsphere_site
  size             = var.control_plane_vm_size
  storage_profile  = var.storage_profile
  tier             = var.service_tier
  backup_policy    = var.backup_policy
  os_type          = "linux"
  security_profile = var.security_profile
  folder           = var.vsphere_folder

  # Additional configuration as required by module
}

# Worker Node 01
module "k8s_worker_01" {
  source  = "app.terraform.io/tfo-apj-demos/single-virtual-machine/vsphere"
  version = "1.4.2"

  hostname         = "k8s-worker-01"
  environment      = var.environment
  site             = var.vsphere_site
  size             = var.worker_vm_size
  storage_profile  = var.storage_profile
  tier             = var.service_tier
  backup_policy    = var.backup_policy
  os_type          = "linux"
  security_profile = var.security_profile
  folder           = var.vsphere_folder
}

# Worker Node 02
module "k8s_worker_02" {
  source  = "app.terraform.io/tfo-apj-demos/single-virtual-machine/vsphere"
  version = "1.4.2"

  hostname         = "k8s-worker-02"
  environment      = var.environment
  site             = var.vsphere_site
  size             = var.worker_vm_size
  storage_profile  = var.storage_profile
  tier             = var.service_tier
  backup_policy    = var.backup_policy
  os_type          = "linux"
  security_profile = var.security_profile
  folder           = var.vsphere_folder
}
```

#### Ansible Integration (ansible.tf)

```hcl
# Ansible provider configuration
terraform {
  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.3.0"
    }
  }
}

# Wait for VMs to be SSH accessible
resource "null_resource" "wait_for_vms" {
  count = 3

  provisioner "remote-exec" {
    inline = ["echo 'VM is ready'"]

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

# Execute Kubespray playbook
resource "ansible_playbook" "kubespray_cluster" {
  playbook   = var.kubespray_playbook_path
  name       = local.vm_ip_addresses
  replayable = false

  extra_vars = {
    ansible_user                 = var.ssh_user
    ansible_ssh_private_key_file = var.ssh_private_key_path
    cluster_name                 = var.cluster_name
    kube_version                 = var.kubernetes_version
    kube_network_plugin          = var.cni_plugin
  }

  depends_on = [
    null_resource.wait_for_vms
  ]
}
```

#### Dynamic Inventory (inventory.tf)

```hcl
# Generate Kubespray-compatible inventory
locals {
  vm_ip_addresses = [
    module.k8s_control_plane_01.ip_address,
    module.k8s_worker_01.ip_address,
    module.k8s_worker_02.ip_address
  ]

  kubespray_inventory = {
    all = {
      hosts = {
        "k8s-master-01" = {
          ansible_host = module.k8s_control_plane_01.ip_address
          ip           = module.k8s_control_plane_01.ip_address
          access_ip    = module.k8s_control_plane_01.ip_address
        }
        "k8s-worker-01" = {
          ansible_host = module.k8s_worker_01.ip_address
          ip           = module.k8s_worker_01.ip_address
          access_ip    = module.k8s_worker_01.ip_address
        }
        "k8s-worker-02" = {
          ansible_host = module.k8s_worker_02.ip_address
          ip           = module.k8s_worker_02.ip_address
          access_ip    = module.k8s_worker_02.ip_address
        }
      }
      children = {
        kube_control_plane = {
          hosts = {
            "k8s-master-01" = null
          }
        }
        kube_node = {
          hosts = {
            "k8s-master-01" = null
            "k8s-worker-01" = null
            "k8s-worker-02" = null
          }
        }
        etcd = {
          hosts = {
            "k8s-master-01" = null
          }
        }
        k8s_cluster = {
          children = {
            kube_control_plane = null
            kube_node          = null
          }
        }
      }
    }
  }
}

# Write inventory to file for reference
resource "local_file" "kubespray_inventory" {
  content  = yamlencode(local.kubespray_inventory)
  filename = "${path.module}/inventory.yml"

  depends_on = [
    module.k8s_control_plane_01,
    module.k8s_worker_01,
    module.k8s_worker_02
  ]
}
```

### Variable Definitions (variables.tf)

```hcl
# vSphere Configuration Variables
variable "vsphere_site" {
  description = "vSphere datacenter/site identifier for VM placement"
  type        = string

  validation {
    condition     = length(var.vsphere_site) > 0
    error_message = "vSphere site must be specified."
  }
}

variable "vsphere_folder" {
  description = "vSphere folder path for VM organization (e.g., /Datacenter/vm/kubernetes)"
  type        = string
}

variable "environment" {
  description = "Deployment environment classification (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# VM Configuration Variables
variable "control_plane_vm_size" {
  description = "VM size tier for control plane node (must meet minimum 2 CPU, 4GB RAM per FR-005)"
  type        = string
  default     = "medium"

  validation {
    condition     = contains(["medium", "large", "xlarge"], var.control_plane_vm_size)
    error_message = "Control plane VM size must be medium or larger to meet Kubernetes requirements."
  }
}

variable "worker_vm_size" {
  description = "VM size tier for worker nodes (must meet minimum 2 CPU, 4GB RAM per FR-005)"
  type        = string
  default     = "medium"

  validation {
    condition     = contains(["medium", "large", "xlarge"], var.worker_vm_size)
    error_message = "Worker VM size must be medium or larger to meet Kubernetes requirements."
  }
}

variable "storage_profile" {
  description = "Storage performance profile for VM disks"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "performance", "premium"], var.storage_profile)
    error_message = "Storage profile must be standard, performance, or premium."
  }
}

variable "service_tier" {
  description = "Service tier classification for resource allocation"
  type        = string
  default     = "gold"

  validation {
    condition     = contains(["bronze", "silver", "gold", "platinum"], var.service_tier)
    error_message = "Service tier must be bronze, silver, gold, or platinum."
  }
}

variable "backup_policy" {
  description = "Backup policy for VM data protection"
  type        = string
  default     = "daily"

  validation {
    condition     = contains(["none", "daily", "weekly"], var.backup_policy)
    error_message = "Backup policy must be none, daily, or weekly."
  }
}

variable "security_profile" {
  description = "Security profile classification for VM hardening (per SEC-007)"
  type        = string
  default     = "kubernetes-node"
}

# Kubernetes Configuration Variables
variable "cluster_name" {
  description = "Kubernetes cluster name identifier"
  type        = string
  default     = "vsphere-k8s-cluster"

  validation {
    condition     = length(var.cluster_name) > 0 && length(var.cluster_name) <= 63
    error_message = "Cluster name must be 1-63 characters."
  }
}

variable "kubernetes_version" {
  description = "Target Kubernetes version for deployment (determined by Kubespray compatibility)"
  type        = string
  default     = "v1.28.5"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "Kubernetes version must be in format vX.Y.Z."
  }
}

variable "cni_plugin" {
  description = "Container Network Interface plugin for pod networking (per FR-010)"
  type        = string
  default     = "calico"

  validation {
    condition     = contains(["calico", "flannel", "cilium"], var.cni_plugin)
    error_message = "CNI plugin must be calico, flannel, or cilium."
  }
}

# SSH Configuration Variables
variable "ssh_user" {
  description = "SSH username for VM access and Ansible connectivity"
  type        = string
  default     = "ubuntu"
}

variable "ssh_private_key" {
  description = "SSH private key content for VM authentication (per SEC-002, stored in HCP Terraform)"
  type        = string
  sensitive   = true
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key file for Ansible playbook execution"
  type        = string
  default     = "~/.ssh/id_rsa"
}

# Kubespray Configuration Variables
variable "kubespray_playbook_path" {
  description = "Path to Kubespray cluster.yml playbook file"
  type        = string
  default     = "./kubespray/cluster.yml"

  validation {
    condition     = can(regex("\\.yml$", var.kubespray_playbook_path))
    error_message = "Kubespray playbook path must reference a .yml file."
  }
}

variable "kubespray_version" {
  description = "Kubespray release version or Git tag"
  type        = string
  default     = "v2.24.0"
}
```

### Output Definitions (outputs.tf)

```hcl
# VM Infrastructure Outputs
output "control_plane_hostname" {
  description = "Hostname of Kubernetes control plane node"
  value       = module.k8s_control_plane_01.hostname
}

output "control_plane_ip" {
  description = "IP address of Kubernetes control plane node for API access"
  value       = module.k8s_control_plane_01.ip_address
}

output "worker_hostnames" {
  description = "Hostnames of Kubernetes worker nodes"
  value = [
    module.k8s_worker_01.hostname,
    module.k8s_worker_02.hostname
  ]
}

output "worker_ips" {
  description = "IP addresses of Kubernetes worker nodes"
  value = [
    module.k8s_worker_01.ip_address,
    module.k8s_worker_02.ip_address
  ]
}

output "all_node_ips" {
  description = "All Kubernetes node IP addresses for monitoring integration"
  value       = local.vm_ip_addresses
}

# Kubernetes Cluster Outputs
output "cluster_name" {
  description = "Kubernetes cluster name for kubectl configuration"
  value       = var.cluster_name
}

output "kubernetes_version" {
  description = "Deployed Kubernetes version"
  value       = var.kubernetes_version
}

output "cni_plugin" {
  description = "Deployed CNI plugin for pod networking"
  value       = var.cni_plugin
}

output "kubernetes_api_endpoint" {
  description = "Kubernetes API server endpoint (https://<control_plane_ip>:6443)"
  value       = "https://${module.k8s_control_plane_01.ip_address}:6443"
}

# Ansible Inventory Output
output "kubespray_inventory" {
  description = "Generated Kubespray inventory in YAML format"
  value       = yamlencode(local.kubespray_inventory)
  sensitive   = false
}

output "inventory_file_path" {
  description = "Path to generated inventory.yml file"
  value       = local_file.kubespray_inventory.filename
}

# SSH Access Information
output "ssh_user" {
  description = "SSH username for VM access"
  value       = var.ssh_user
}

output "ssh_connection_strings" {
  description = "SSH connection commands for each node"
  value = {
    control_plane = "ssh ${var.ssh_user}@${module.k8s_control_plane_01.ip_address}"
    worker_01     = "ssh ${var.ssh_user}@${module.k8s_worker_01.ip_address}"
    worker_02     = "ssh ${var.ssh_user}@${module.k8s_worker_02.ip_address}"
  }
}
```

### Backend Configuration (override.tf)

```hcl
# HCP Terraform cloud backend for remote execution and state management
terraform {
  cloud {
    organization = "tfo-apj-demos"

    workspaces {
      name = "sandbox_vm-k8s-kubespray-runai"  # For testing; will use actual workspace during deployment
    }
  }
}
```

### Provider Configuration (providers.tf)

```hcl
# vSphere provider for VM provisioning
# Authentication via dynamic credentials (pre-configured at workspace level per Constitution 3.1)
provider "vsphere" {
  # Credentials provided via workspace environment variables
  # VSPHERE_USER, VSPHERE_PASSWORD, VSPHERE_SERVER
}

# Ansible provider for Kubespray execution
provider "ansible" {
  # No explicit configuration required
  # SSH connectivity handled via resource-level connection blocks
}
```

### Version Constraints (terraform.tf)

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.6.0"
    }

    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.3.0"
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.4.0"
    }
  }
}
```

---

## Phase 2: Architecture & Deployment Strategy

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        HCP Terraform Workspace                       │
│                      (vm-k8s-kubespray-runai)                       │
│                                                                       │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                   Terraform Execution                          │ │
│  │                                                                 │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐│ │
│  │  │  single-vm      │  │  single-vm      │  │  single-vm      ││ │
│  │  │  module v1.4.2  │  │  module v1.4.2  │  │  module v1.4.2  ││ │
│  │  │                 │  │                 │  │                 ││ │
│  │  │  k8s-master-01  │  │  k8s-worker-01  │  │  k8s-worker-02  ││ │
│  │  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘│ │
│  │           │                    │                    │         │ │
│  └───────────┼────────────────────┼────────────────────┼─────────┘ │
└──────────────┼────────────────────┼────────────────────┼───────────┘
               │                    │                    │
               ▼                    ▼                    ▼
┌──────────────────────────────────────────────────────────────────────┐
│                      VMware vSphere Infrastructure                    │
│                                                                        │
│   ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐ │
│   │   Ubuntu VM      │  │   Ubuntu VM      │  │   Ubuntu VM      │ │
│   │                  │  │                  │  │                  │ │
│   │  k8s-master-01   │  │  k8s-worker-01   │  │  k8s-worker-02   │ │
│   │  (Control Plane) │  │    (Worker)      │  │    (Worker)      │ │
│   │                  │  │                  │  │                  │ │
│   │  IP: 10.0.1.10   │  │  IP: 10.0.1.11   │  │  IP: 10.0.1.12   │ │
│   └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘ │
│            │                     │                     │            │
│            └─────────────────────┴─────────────────────┘            │
│                          VM Network                                  │
└────────────────────────────────┬─────────────────────────────────────┘
                                 │
                                 │ SSH + Ansible
                                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│                   Terraform Ansible Provider                          │
│                                                                        │
│   ┌────────────────────────────────────────────────────────────────┐ │
│   │               Kubespray Ansible Playbooks                       │ │
│   │                                                                  │ │
│   │  • Prepare nodes (install packages, configure system)          │ │
│   │  • Deploy etcd cluster                                         │ │
│   │  • Deploy Kubernetes control plane components                  │ │
│   │  • Deploy worker node components (kubelet, kube-proxy)         │ │
│   │  • Configure CNI plugin (Calico/Flannel)                       │ │
│   │  • Generate kubeconfig for cluster access                      │ │
│   └────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────┬─────────────────────────────────────┘
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster (Running)                      │
│                                                                        │
│   Control Plane (k8s-master-01):                                     │
│   ├── kube-apiserver                                                 │
│   ├── kube-controller-manager                                        │
│   ├── kube-scheduler                                                 │
│   ├── etcd                                                           │
│   └── kubelet                                                        │
│                                                                        │
│   Worker Nodes (k8s-worker-01, k8s-worker-02):                       │
│   ├── kubelet                                                        │
│   ├── kube-proxy                                                     │
│   └── container runtime (containerd)                                 │
│                                                                        │
│   Pod Network: CNI Plugin (Calico/Flannel)                           │
└──────────────────────────────────────────────────────────────────────┘
```

### Deployment Sequence

**Phase 1: Infrastructure Provisioning (Terraform)**
1. Initialize Terraform with HCP cloud backend
2. Validate configuration: `terraform validate`
3. Plan infrastructure changes: `terraform plan`
4. Create three Ubuntu VMs via single-virtual-machine module:
   - k8s-master-01 (control plane)
   - k8s-worker-01 (worker)
   - k8s-worker-02 (worker)
5. Wait for VMs to complete provisioning and obtain IP addresses
6. Generate dynamic Ansible inventory from VM outputs

**Phase 2: VM Readiness Validation (Terraform + SSH)**
1. Wait for SSH connectivity on all VMs (null_resource with remote-exec)
2. Verify VM accessibility via SSH key authentication
3. Validate network connectivity between VMs
4. Write inventory.yml file with host details

**Phase 3: Kubernetes Deployment (Ansible via Terraform)**
1. Ansible provider executes Kubespray cluster.yml playbook
2. Kubespray performs pre-flight checks on all nodes
3. Install required packages (Python, Docker/containerd)
4. Deploy etcd cluster on control plane node
5. Deploy Kubernetes control plane components:
   - kube-apiserver
   - kube-controller-manager
   - kube-scheduler
6. Deploy worker node components:
   - kubelet
   - kube-proxy
7. Configure CNI plugin for pod networking
8. Generate and distribute kubeconfig for cluster access

**Phase 4: Validation (Manual/External)**
1. Verify cluster status: `kubectl get nodes`
2. Validate all nodes in Ready state
3. Test pod deployment and scheduling
4. Verify pod-to-pod networking
5. Validate control plane component health

### Deployment Timeline

Based on Success Criteria SC-001 (under 20 minutes):
- VM Provisioning: 5-8 minutes (3 VMs in parallel)
- SSH Readiness Wait: 1-2 minutes
- Kubespray Execution: 10-15 minutes
- Total: ~16-25 minutes (target: <20 minutes under optimal conditions)

### Testing Strategy

#### Unit Testing
- Terraform validation: `terraform validate`
- Terraform formatting: `terraform fmt -check`
- TFLint static analysis: `tflint`

#### Integration Testing (Sandbox Workspace)
1. Create sandbox workspace: `sandbox_vm-k8s-kubespray-runai`
2. Configure test variables in `sandbox.auto.tfvars`
3. Run `terraform init` with cloud backend configuration
4. Execute `terraform plan` and review proposed changes
5. Execute `terraform apply` for full deployment test
6. Validate Kubernetes cluster functionality:
   - `kubectl get nodes` → All nodes Ready
   - Deploy test pod → Successful scheduling
   - Test pod networking → Cross-node communication
7. Document test results
8. Clean up: `terraform destroy` (optional, based on test duration needs)

#### Validation Checklist (Post-Deployment)
- [ ] All 3 VMs provisioned and powered on
- [ ] SSH access working for all VMs
- [ ] `kubectl get nodes` shows 3 nodes in Ready state
- [ ] Control plane components healthy (kube-apiserver, etcd, etc.)
- [ ] Worker nodes registered and accepting workloads
- [ ] Pod networking operational (CNI plugin deployed)
- [ ] Test pod deployment successful
- [ ] Cross-node pod communication working
- [ ] Cluster API accessible via generated kubeconfig

---

## Phase 3: Implementation Guidelines

### Development Workflow

1. **Branch Setup**:
   - Feature branch: `001-vsphere-k8s-kubespray` (already created)
   - Base branch: `dev` (per Constitution 3.1)

2. **Code Generation**:
   - Create all Terraform files per structure defined above
   - Follow HashiCorp style guide for formatting
   - Include inline comments referencing spec requirements (FR-XXX)
   - Run `terraform fmt` before committing

3. **Pre-Commit Validation**:
   - Initialize pre-commit hooks: `pre-commit install`
   - Run TFLint: `tflint --init && tflint`
   - Validate syntax: `terraform validate`
   - Auto-generate README: `terraform-docs markdown . > README.md`

4. **Sandbox Testing**:
   - Configure sandbox workspace with cloud backend
   - Create `sandbox.auto.tfvars` with test values
   - Execute full deployment test via Terraform CLI
   - Document plan output and apply results

5. **Code Review**:
   - Commit validated code to feature branch
   - Push to remote repository
   - Automated policy checks via HCP Terraform
   - Human review before merge to dev branch

### Security Implementation

**SEC-002: SSH Key Management**
- SSH private key stored as HCP Terraform workspace variable (sensitive)
- Public key injected into VMs during provisioning via module configuration
- Private key referenced in Ansible connection blocks
- Never commit keys to version control

**SEC-007: Security Profile**
- Use `security_profile = "kubernetes-node"` for all VMs
- This enforces organizational security hardening standards
- Profile defined at platform team level, consumed via module

**SEC-008: State Encryption**
- HCP Terraform provides automatic encryption at rest and in transit
- No additional configuration required in code

**SEC-009: SSH Access Restrictions**
- Document that production deployments should restrict SSH access
- Consider bastion host pattern for production environments
- Not implemented in initial version (marked as future enhancement)

### Error Handling

**VM Provisioning Failures**:
- Module will fail with descriptive error messages
- Common causes: insufficient resources, invalid template, network issues
- Resolution: Review vSphere environment capacity and configuration

**SSH Connectivity Failures**:
- null_resource remote-exec will timeout after 5 minutes
- Common causes: firewall rules, incorrect SSH key, VM not fully booted
- Resolution: Verify network connectivity and SSH key configuration

**Kubespray Execution Failures**:
- Ansible playbook errors will halt deployment
- Common causes: missing dependencies, network timeouts, incompatible OS
- Resolution: Review Ansible logs, verify VM meets Kubespray requirements

**State Consistency**:
- If deployment fails mid-execution, Terraform state may be inconsistent
- Use `terraform refresh` to sync state with actual infrastructure
- Consider `terraform destroy` and retry for clean slate

---

## Risk Mitigation

### Risk: Module Version Availability
- **Mitigation**: Verify module v1.4.2 exists before implementation
- **Fallback**: Use latest stable version if 1.4.2 unavailable
- **Impact**: Low - module interface should be stable

### Risk: Kubespray Compatibility
- **Mitigation**: Phase 0 research confirms compatible version
- **Fallback**: Use well-tested Kubespray v2.24.0 or latest stable
- **Impact**: Medium - version mismatch could cause deployment failures

### Risk: Ansible Provider Reliability
- **Mitigation**: Use official ansible/ansible provider
- **Fallback**: Consider alternative approaches (local-exec with ansible-playbook)
- **Impact**: Medium - affects deployment automation reliability

### Risk: HCP Terraform Remote Execution with Ansible
- **Mitigation**: Test in sandbox workspace before production deployment
- **Fallback**: Use Terraform Cloud agents or self-hosted runners if needed
- **Impact**: High - may require architecture adjustment

### Risk: SSH Key Management
- **Mitigation**: Use HCP Terraform sensitive variables
- **Fallback**: Use SSH agent forwarding or temporary keys
- **Impact**: Medium - affects security posture

### Risk: Network Connectivity Requirements
- **Mitigation**: Document required ports and network paths
- **Fallback**: Work with network team to open required firewall rules
- **Impact**: High - blocks deployment if not resolved

---

## Success Metrics

Alignment with Success Criteria from spec.md:

- **SC-001**: Single `terraform apply` depletes in <20 minutes
  - **Measurement**: Track deployment time from plan to cluster ready

- **SC-004**: 100% VM provisioning success rate
  - **Measurement**: All 3 VMs created without errors

- **SC-005**: Kubespray deployment completes without errors
  - **Measurement**: ansible_playbook resource completes successfully

- **SC-007**: Terraform state stored in HCP Terraform
  - **Measurement**: State visible in workspace UI, not local

- **SC-008**: Zero manual configuration steps
  - **Measurement**: No human intervention between apply and cluster ready

- **SC-009**: All components pass health checks
  - **Measurement**: kubectl validation and component status checks

- **SC-010**: Infrastructure can be destroyed and recreated
  - **Measurement**: terraform destroy + apply restores functionality

---

## Next Steps

1. **Complete Phase 0 Research** → Generate `/workspace/specs/001-vsphere-k8s-kubespray/research.md`
2. **Complete Phase 1 Design** → Generate `/workspace/specs/001-vsphere-k8s-kubespray/data-model.md`
3. **Generate Code Scaffolding** → Create all `.tf` files per structure above
4. **Initialize Testing Environment** → Configure sandbox workspace and variables
5. **Execute Sandbox Testing** → Validate full deployment workflow
6. **Document Results** → Capture test output and lessons learned
7. **Prepare for Implementation** → Ready for `/speckit.tasks` and `/speckit.implement`

---

## References

- Feature Specification: `/workspace/specs/001-vsphere-k8s-kubespray/spec.md`
- Constitution: `/workspace/.specify/memory/constitution.md`
- HCP Terraform Workspace: `https://app.terraform.io/app/tfo-apj-demos/workspaces/vm-k8s-kubespray-runai`
- Kubespray Documentation: `https://kubespray.io/`
- Terraform Ansible Provider: `https://registry.terraform.io/providers/ansible/ansible/latest`
- Single VM Module: `app.terraform.io/tfo-apj-demos/single-virtual-machine/vsphere` v1.4.2
