# Data Model: vSphere VM Provisioning with Kubernetes Deployment via Kubespray

**Feature Branch**: `001-vsphere-k8s-kubespray`
**Version**: 1.0.0
**Created**: 2025-12-02
**Status**: Draft

---

## Overview

This document defines the complete data model for the vSphere Kubernetes cluster deployment, including input variables, computed values, resource relationships, and output values. The data model ensures consistent configuration across all Terraform resources and modules.

---

## Input Variables Schema

### vSphere Infrastructure Variables

| Variable | Type | Required | Default | Description | Validation |
|----------|------|----------|---------|-------------|------------|
| `vsphere_site` | `string` | Yes | - | vSphere datacenter/site identifier for VM placement | Length > 0 |
| `vsphere_folder` | `string` | Yes | - | vSphere folder path for VM organization (e.g., /Datacenter/vm/kubernetes) | - |
| `environment` | `string` | Yes | - | Deployment environment classification | Must be: dev, staging, prod |

### VM Configuration Variables

| Variable | Type | Required | Default | Description | Validation |
|----------|------|----------|---------|-------------|------------|
| `control_plane_vm_size` | `string` | No | `"medium"` | VM size tier for control plane node (minimum 2 CPU, 4GB RAM) | Must be: medium, large, xlarge |
| `worker_vm_size` | `string` | No | `"medium"` | VM size tier for worker nodes (minimum 2 CPU, 4GB RAM) | Must be: medium, large, xlarge |
| `storage_profile` | `string` | No | `"standard"` | Storage performance profile for VM disks | Must be: standard, performance, premium |
| `service_tier` | `string` | No | `"gold"` | Service tier classification for resource allocation | Must be: bronze, silver, gold, platinum |
| `backup_policy` | `string` | No | `"daily"` | Backup policy for VM data protection | Must be: none, daily, weekly |
| `security_profile` | `string` | No | `"kubernetes-node"` | Security profile classification for VM hardening (per SEC-007) | - |

### Kubernetes Configuration Variables

| Variable | Type | Required | Default | Description | Validation |
|----------|------|----------|---------|-------------|------------|
| `cluster_name` | `string` | No | `"vsphere-k8s-cluster"` | Kubernetes cluster name identifier | Length 1-63 characters |
| `kubernetes_version` | `string` | No | `"v1.28.5"` | Target Kubernetes version for deployment | Format: vX.Y.Z |
| `cni_plugin` | `string` | No | `"calico"` | Container Network Interface plugin for pod networking | Must be: calico, flannel, cilium |

### SSH Configuration Variables

| Variable | Type | Required | Default | Description | Validation |
|----------|------|----------|---------|-------------|------------|
| `ssh_user` | `string` | No | `"ubuntu"` | SSH username for VM access and Ansible connectivity | - |
| `ssh_private_key` | `string` (sensitive) | Yes | - | SSH private key content for VM authentication (stored in HCP Terraform) | - |
| `ssh_private_key_path` | `string` | No | `"~/.ssh/id_rsa"` | Path to SSH private key file for Ansible playbook execution | - |

### Kubespray Configuration Variables

| Variable | Type | Required | Default | Description | Validation |
|----------|------|----------|---------|-------------|------------|
| `kubespray_playbook_path` | `string` | No | `"./kubespray/cluster.yml"` | Path to Kubespray cluster.yml playbook file | Must end with .yml |
| `kubespray_version` | `string` | No | `"v2.24.0"` | Kubespray release version or Git tag | - |

---

## Computed Local Values

### VM IP Addresses List

```hcl
local.vm_ip_addresses = [
  module.k8s_control_plane_01.ip_address,
  module.k8s_worker_01.ip_address,
  module.k8s_worker_02.ip_address
]
```

**Type**: `list(string)`
**Description**: Ordered list of all VM IP addresses (control plane first, workers second)
**Usage**: SSH connectivity validation, Ansible inventory generation

### Kubespray Inventory

```hcl
local.kubespray_inventory = {
  all = {
    hosts = {
      "<hostname>" = {
        ansible_host = "<ip_address>"
        ip           = "<ip_address>"
        access_ip    = "<ip_address>"
      }
    }
    children = {
      kube_control_plane = { hosts = {...} }
      kube_node = { hosts = {...} }
      etcd = { hosts = {...} }
      k8s_cluster = { children = {...} }
    }
  }
}
```

**Type**: `map(any)`
**Description**: Complete Kubespray-compatible inventory structure in YAML format
**Usage**: Ansible playbook execution via terraform-provider-ansible

---

## Resource Relationships

### Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Input Variables                           │
│  (vsphere_site, environment, vm_size, cluster_name, etc.)       │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                   VM Module Instances (3x)                       │
│                                                                   │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐ │
│  │ k8s-master-01    │  │ k8s-worker-01    │  │ k8s-worker-02│ │
│  │ (control_plane)  │  │ (worker)         │  │ (worker)     │ │
│  └────────┬─────────┘  └────────┬─────────┘  └──────┬───────┘ │
│           │ hostname             │ hostname           │ hostname│
│           │ ip_address           │ ip_address         │ ip_addr │
└───────────┼──────────────────────┼────────────────────┼─────────┘
            │                      │                    │
            └──────────────────────┴────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Local Computed Values                         │
│                                                                   │
│  • local.vm_ip_addresses (list)                                 │
│  • local.kubespray_inventory (map)                              │
└────────────────────────────┬────────────────────────────────────┘
                             │
                ┌────────────┴────────────┐
                │                         │
                ▼                         ▼
┌──────────────────────────┐  ┌──────────────────────────────────┐
│  null_resource           │  │  local_file                       │
│  wait_for_vms            │  │  kubespray_inventory              │
│                          │  │                                   │
│  • SSH connectivity test │  │  • Write inventory.yml           │
│  • Validates VM readiness│  │  • YAML format                   │
└────────────┬─────────────┘  └──────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────────┐
│              ansible_playbook Resource                           │
│              kubespray_cluster                                   │
│                                                                   │
│  • Executes Kubespray cluster.yml                               │
│  • Uses dynamic inventory from locals                           │
│  • Deploys Kubernetes cluster                                   │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Output Values                               │
│                                                                   │
│  • VM hostnames and IP addresses                                │
│  • Kubernetes API endpoint                                      │
│  • Cluster configuration details                                │
│  • SSH connection strings                                       │
└─────────────────────────────────────────────────────────────────┘
```

### Dependency Chain

1. **Input Variables** → Define configuration requirements
2. **VM Module Instances** → Consume variables, produce VM resources
3. **Local Computed Values** → Aggregate module outputs into usable structures
4. **null_resource (wait_for_vms)** → Depends on VM modules, validates SSH connectivity
5. **local_file (inventory)** → Depends on VM modules, generates inventory file
6. **ansible_playbook** → Depends on wait_for_vms, consumes inventory, deploys Kubernetes
7. **Output Values** → Expose critical information for downstream consumption

### Resource Dependencies Matrix

| Resource | Depends On | Provides For |
|----------|------------|--------------|
| `module.k8s_control_plane_01` | Input variables | VM hostname, IP address |
| `module.k8s_worker_01` | Input variables | VM hostname, IP address |
| `module.k8s_worker_02` | Input variables | VM hostname, IP address |
| `local.vm_ip_addresses` | All VM modules | SSH validation, Ansible execution |
| `local.kubespray_inventory` | All VM modules | Inventory file, Ansible playbook |
| `null_resource.wait_for_vms` | All VM modules | Ansible playbook execution |
| `local_file.kubespray_inventory` | All VM modules | Manual inventory reference |
| `ansible_playbook.kubespray_cluster` | wait_for_vms, inventory locals | Kubernetes cluster |

---

## Output Values Schema

### VM Infrastructure Outputs

| Output | Type | Sensitive | Description | Usage |
|--------|------|-----------|-------------|-------|
| `control_plane_hostname` | `string` | No | Hostname of Kubernetes control plane node | Reference, documentation |
| `control_plane_ip` | `string` | No | IP address of Kubernetes control plane node | API access, kubectl configuration |
| `worker_hostnames` | `list(string)` | No | Hostnames of Kubernetes worker nodes | Reference, monitoring |
| `worker_ips` | `list(string)` | No | IP addresses of Kubernetes worker nodes | Monitoring, debugging |
| `all_node_ips` | `list(string)` | No | All Kubernetes node IP addresses | Monitoring integration, load balancers |

### Kubernetes Cluster Outputs

| Output | Type | Sensitive | Description | Usage |
|--------|------|-----------|-------------|-------|
| `cluster_name` | `string` | No | Kubernetes cluster name | kubectl context, documentation |
| `kubernetes_version` | `string` | No | Deployed Kubernetes version | Version tracking, upgrades |
| `cni_plugin` | `string` | No | Deployed CNI plugin | Network troubleshooting, documentation |
| `kubernetes_api_endpoint` | `string` | No | Kubernetes API server endpoint (https://IP:6443) | kubectl configuration, API access |

### Ansible Inventory Outputs

| Output | Type | Sensitive | Description | Usage |
|--------|------|-----------|-------------|-------|
| `kubespray_inventory` | `string` | No | Generated Kubespray inventory in YAML format | Manual playbook execution, debugging |
| `inventory_file_path` | `string` | No | Path to generated inventory.yml file | Reference, manual Ansible operations |

### SSH Access Outputs

| Output | Type | Sensitive | Description | Usage |
|--------|------|-----------|-------------|-------|
| `ssh_user` | `string` | No | SSH username for VM access | Connection instructions, documentation |
| `ssh_connection_strings` | `map(string)` | No | SSH connection commands for each node | Quick access, troubleshooting |

---

## Data Flow Diagram

```
┌─────────────┐
│   User      │
│  Provides   │
│  Variables  │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────────┐
│         Terraform Configuration              │
│                                              │
│  ┌────────────────────────────────────────┐ │
│  │  variables.tf                          │ │
│  │  • Declares all input variables        │ │
│  │  • Defines validation rules            │ │
│  │  • Sets default values                 │ │
│  └────────────┬───────────────────────────┘ │
│               │                              │
│               ▼                              │
│  ┌────────────────────────────────────────┐ │
│  │  main.tf                               │ │
│  │  • Instantiates VM modules (3x)        │ │
│  │  • Passes variables to modules         │ │
│  └────────────┬───────────────────────────┘ │
│               │                              │
│               ▼                              │
│  ┌────────────────────────────────────────┐ │
│  │  locals.tf / inventory.tf              │ │
│  │  • Aggregates module outputs           │ │
│  │  • Generates inventory structure       │ │
│  │  • Creates IP address list             │ │
│  └────────────┬───────────────────────────┘ │
│               │                              │
│               ▼                              │
│  ┌────────────────────────────────────────┐ │
│  │  ansible.tf                            │ │
│  │  • Validates VM SSH connectivity       │ │
│  │  • Executes Kubespray playbook         │ │
│  │  • Deploys Kubernetes cluster          │ │
│  └────────────┬───────────────────────────┘ │
│               │                              │
│               ▼                              │
│  ┌────────────────────────────────────────┐ │
│  │  outputs.tf                            │ │
│  │  • Exposes VM details                  │ │
│  │  • Provides cluster endpoints          │ │
│  │  • Generates connection strings        │ │
│  └────────────┬───────────────────────────┘ │
└───────────────┼──────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────┐
│         HCP Terraform State                  │
│  • Stores resource state                    │
│  • Tracks infrastructure configuration      │
│  • Enables team collaboration               │
└─────────────────────────────────────────────┘
```

---

## State Transitions

### Virtual Machine Lifecycle

```
[undefined] → [creating] → [created] → [ready] → [destroying] → [destroyed]
                   ↓           ↓          ↓
                [failed]   [failed]   [failed]
```

**States**:
- `undefined`: VM resource not yet declared
- `creating`: Module provisioning VM in vSphere
- `created`: VM exists but may not be fully booted
- `ready`: VM is running and SSH accessible
- `destroying`: Terraform destroy operation in progress
- `destroyed`: VM no longer exists in vSphere
- `failed`: Provisioning or configuration error occurred

### Kubernetes Cluster Lifecycle

```
[not_deployed] → [deploying] → [deployed] → [ready] → [degraded]
                      ↓            ↓           ↓
                  [failed]     [failed]   [destroying] → [destroyed]
```

**States**:
- `not_deployed`: VMs exist but Kubernetes not installed
- `deploying`: Kubespray Ansible playbooks executing
- `deployed`: Kubernetes components installed
- `ready`: All nodes Ready, control plane healthy
- `degraded`: One or more nodes not Ready
- `destroying`: terraform destroy removing infrastructure
- `destroyed`: All resources removed
- `failed`: Deployment error (Ansible failure, connectivity issue)

### Ansible Inventory Lifecycle

```
[not_generated] → [generating] → [generated] → [valid] → [stale]
                       ↓             ↓           ↓
                   [failed]      [failed]   [refreshing] → [valid]
```

**States**:
- `not_generated`: VMs not yet provisioned
- `generating`: Terraform computing inventory from module outputs
- `generated`: Inventory structure exists in locals
- `valid`: Inventory matches current VM state
- `stale`: VM state changed (IP reassignment, hostname change)
- `refreshing`: terraform refresh syncing state
- `failed`: Inventory generation error

---

## Validation Rules

### Input Validation

1. **Environment Validation**:
   ```hcl
   condition     = contains(["dev", "staging", "prod"], var.environment)
   error_message = "Environment must be dev, staging, or prod."
   ```

2. **VM Size Validation**:
   ```hcl
   condition     = contains(["medium", "large", "xlarge"], var.control_plane_vm_size)
   error_message = "Control plane VM size must be medium or larger to meet Kubernetes requirements."
   ```

3. **Kubernetes Version Validation**:
   ```hcl
   condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.kubernetes_version))
   error_message = "Kubernetes version must be in format vX.Y.Z."
   ```

4. **Cluster Name Validation**:
   ```hcl
   condition     = length(var.cluster_name) > 0 && length(var.cluster_name) <= 63
   error_message = "Cluster name must be 1-63 characters."
   ```

### Output Validation

1. **IP Address Format**: Outputs must be valid IPv4 addresses
2. **Hostname Format**: Outputs must match pattern `k8s-(master|worker)-\d{2}`
3. **API Endpoint Format**: Must be valid HTTPS URL with port 6443

### Resource Validation

1. **Module Output Availability**: All VM modules must produce `hostname` and `ip_address` outputs
2. **Inventory Structure Completeness**: Inventory must include all required Kubespray groups
3. **SSH Connectivity**: All VMs must respond to SSH within timeout period

---

## Data Constraints

### Required Constraints

- Exactly 3 VMs must be provisioned (1 control plane, 2 workers)
- All VMs must share the same `environment`, `site`, and `security_profile` values
- All VMs must be accessible via SSH on port 22
- Control plane VM must be named following pattern: `k8s-master-01`
- Worker VMs must be named following pattern: `k8s-worker-01`, `k8s-worker-02`

### Optional Constraints

- VM sizes can differ between control plane and workers
- CNI plugin selection affects cluster networking behavior
- Kubernetes version determines available features

### Security Constraints

- SSH private key (`var.ssh_private_key`) MUST be marked sensitive
- SSH private key MUST NOT appear in plan output or logs
- vSphere credentials MUST NOT be declared in code (workspace-level configuration)
- All outputs containing sensitive data MUST be marked `sensitive = true`

---

## Integration Points

### Upstream Dependencies

1. **HCP Terraform Workspace**: Provides vSphere credentials and execution environment
2. **vSphere Infrastructure**: Provides compute, storage, and network resources
3. **Ubuntu Template**: Provides base OS image for VMs
4. **Kubespray Project**: Provides Ansible playbooks for Kubernetes deployment

### Downstream Consumers

1. **Kubectl Configuration**: Consumes `kubernetes_api_endpoint` and cluster credentials
2. **Monitoring Systems**: Consume `all_node_ips` for health checks
3. **Load Balancers**: Consume `worker_ips` for backend configuration
4. **Documentation**: Consumes all outputs for operational runbooks

---

## References

- Feature Specification: `/workspace/specs/001-vsphere-k8s-kubespray/spec.md`
- Implementation Plan: `/workspace/specs/001-vsphere-k8s-kubespray/plan.md`
- Constitution: `/workspace/.specify/memory/constitution.md`
- Terraform Variable Documentation: https://developer.hashicorp.com/terraform/language/values/variables
- Kubespray Inventory Format: https://kubespray.io/#/docs/getting-started
