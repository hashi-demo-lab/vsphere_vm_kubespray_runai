# Deployment Runbook: vSphere Kubernetes Cluster with Kubespray

**Feature**: vSphere VM Provisioning with Kubernetes Deployment via Kubespray
**Version**: 1.0.0
**Last Updated**: 2025-12-02
**Owner**: Infrastructure Team

---

## Overview

This runbook provides step-by-step instructions for deploying a 3-node Kubernetes cluster on vSphere infrastructure using Terraform and Kubespray.

**Expected Duration**: 20-25 minutes
**Cluster Configuration**: 1 control plane + 2 worker nodes
**Private Module**: `tfo-apj-demos/single-virtual-machine/vsphere` v1.4.2

---

## Prerequisites Checklist

### Infrastructure Requirements

- [ ] vSphere environment accessible (vCenter/ESXi)
- [ ] Ubuntu 22.04 LTS VM template exists in vSphere
- [ ] Sufficient resources available:
  - Minimum: 6 vCPUs (2 per node)
  - Minimum: 12 GB RAM (4 GB per node)
  - Minimum: 60 GB storage (20 GB per node)
- [ ] Network with DHCP or static IP allocation configured
- [ ] DNS resolution working for VM hostnames

### Access Requirements

- [ ] HCP Terraform organization access to `tfo-apj-demos`
- [ ] HCP Terraform workspace access to `vm-k8s-kubespray-runai` (production) or `sandbox_vm-k8s-kubespray-runai` (testing)
- [ ] vSphere credentials with required permissions
- [ ] SSH key pair generated and accessible

### Software Requirements

- [ ] Terraform >= 1.5.0 installed locally
- [ ] Git installed and configured
- [ ] Kubespray repository cloned locally (v2.24.0 or compatible)
- [ ] HCP Terraform CLI token configured (`terraform login`)

### vSphere Permissions

Required permissions for the vSphere service account:

- Virtual Machine > Configuration > All
- Virtual Machine > Interaction > All
- Datastore > Allocate space
- Network > Assign network
- Resource > Assign virtual machine to resource pool

---

## SSH Key Management

### Generating SSH Keys (Production)

**IMPORTANT**: Generate dedicated SSH keys for this deployment. Never reuse personal SSH keys.

```bash
# Generate new SSH key pair (4096-bit RSA recommended)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/k8s-vsphere-cluster -C "k8s-cluster@example.com"

# Set restrictive permissions
chmod 600 ~/.ssh/k8s-vsphere-cluster
chmod 644 ~/.ssh/k8s-vsphere-cluster.pub
```

### Storing SSH Keys in HCP Terraform

1. Navigate to HCP Terraform workspace settings
2. Go to Variables section
3. Add the following sensitive variables:

```
Variable Name: ssh_private_key
Value: [Paste ENTIRE contents of ~/.ssh/k8s-vsphere-cluster]
Sensitive: YES (check the box)
Category: Terraform variable
```

```
Variable Name: ssh_private_key_path
Value: /tmp/ssh_key (this is used within Terraform execution)
Sensitive: NO
Category: Terraform variable
```

**Security Notes:**
- Never commit SSH keys to version control
- Rotate SSH keys regularly (recommended: every 90 days)
- Use different keys for different environments (dev/staging/prod)
- Consider using HashiCorp Vault for enterprise key management

### SSH Key Distribution

The private module automatically injects the SSH public key into provisioned VMs during deployment. No manual configuration required.

---

## Deployment Steps

### Step 1: Prepare Configuration

```bash
# Clone repository
git clone <repository-url>
cd <repository-directory>

# Switch to feature branch
git checkout 001-vsphere-k8s-kubespray

# Copy example tfvars
cp sandbox.auto.tfvars.example sandbox.auto.tfvars
```

### Step 2: Configure Variables

Edit `sandbox.auto.tfvars` (or create `production.auto.tfvars` for production):

```hcl
# vSphere Configuration
vsphere_site   = "dc01"                    # Your vSphere datacenter identifier
vsphere_folder = "Demo Workloads/K8s"      # VM folder path
environment    = "dev"                      # dev, staging, or prod

# VM Configuration
control_plane_vm_size = "medium"            # medium, large, or xlarge
worker_vm_size        = "medium"            # medium, large, or xlarge
storage_profile       = "standard"          # standard, performance, or premium
service_tier          = "gold"              # bronze, silver, gold, or platinum
backup_policy         = "daily"             # none, daily, or weekly
security_profile      = "kubernetes-node"   # Security profile name
vm_domain             = "local"             # DNS domain for VMs

# Kubernetes Configuration
cluster_name       = "vsphere-k8s-dev"      # Unique cluster identifier
kubernetes_version = "v1.28.5"              # Kubernetes version
cni_plugin         = "calico"               # calico, flannel, or cilium

# Kubespray Configuration
kubespray_playbook_path = "./kubespray/cluster.yml"  # Path to Kubespray playbook
kubespray_version       = "v2.24.0"                   # Kubespray version

# SSH Configuration
ssh_user = "ubuntu"                         # SSH username (matches Ubuntu template)
```

### Step 3: Configure HCP Terraform Workspace Variables

In your HCP Terraform workspace UI, configure:

**vSphere Credentials (Environment Variables):**
```
VSPHERE_SERVER   = vcenter.example.com
VSPHERE_USER     = terraform-service-account@vsphere.local
VSPHERE_PASSWORD = [password] (mark as sensitive)
```

**SSH Keys (Terraform Variables - see SSH Key Management section above):**
```
ssh_private_key      = [contents of private key file] (mark as sensitive)
ssh_private_key_path = /tmp/ssh_key
```

### Step 4: Update Backend Configuration

For **sandbox testing**, `override.tf` should reference:
```hcl
terraform {
  cloud {
    organization = "tfo-apj-demos"
    workspaces {
      name = "sandbox_vm-k8s-kubespray-runai"
    }
  }
}
```

For **production deployment**, update to:
```hcl
terraform {
  cloud {
    organization = "tfo-apj-demos"
    workspaces {
      name = "vm-k8s-kubespray-runai"
    }
  }
}
```

### Step 5: Initialize Terraform

```bash
# Authenticate with HCP Terraform
terraform login

# Initialize Terraform with remote backend
terraform init

# Expected output: Backend initialization successful
```

### Step 6: Validate Configuration

```bash
# Validate syntax and configuration
terraform validate

# Expected output: Success! The configuration is valid.

# Format all Terraform files
terraform fmt -recursive

# Review what will be created
terraform plan -out=tfplan
```

**Review Plan Output Carefully:**
- Verify 3 VM module instances will be created
- Check all module parameters are correctly populated
- Ensure no unexpected resources are being created or destroyed

### Step 7: Deploy Infrastructure

```bash
# Apply the configuration
terraform apply tfplan

# Alternative: Apply without pre-saved plan (will prompt for confirmation)
terraform apply
```

**Expected Timeline:**
- VM Provisioning: 5-8 minutes (3 VMs created in parallel)
- SSH Readiness Check: 1-2 minutes
- Kubespray Deployment: 10-15 minutes
- **Total: 16-25 minutes**

**During Deployment:**
- Monitor HCP Terraform UI for live progress
- Review Ansible output in Terraform logs
- Do not interrupt the deployment process

### Step 8: Verify Deployment

```bash
# Check Terraform outputs
terraform output

# Expected outputs:
# - control_plane_ip
# - worker_ips
# - kubernetes_api_endpoint
# - ssh_connection_strings
```

### Step 9: Access VMs via SSH

```bash
# Retrieve SSH connection strings from outputs
terraform output ssh_connection_strings

# Connect to control plane
ssh ubuntu@<control_plane_ip> -i ~/.ssh/k8s-vsphere-cluster

# Connect to workers
ssh ubuntu@<worker_01_ip> -i ~/.ssh/k8s-vsphere-cluster
ssh ubuntu@<worker_02_ip> -i ~/.ssh/k8s-vsphere-cluster
```

### Step 10: Verify Kubernetes Cluster

```bash
# SSH into control plane node
ssh ubuntu@<control_plane_ip> -i ~/.ssh/k8s-vsphere-cluster

# Check cluster status
sudo kubectl get nodes

# Expected output: 3 nodes in Ready state
# NAME             STATUS   ROLES           AGE   VERSION
# k8s-master-01    Ready    control-plane   5m    v1.28.5
# k8s-worker-01    Ready    <none>          5m    v1.28.5
# k8s-worker-02    Ready    <none>          5m    v1.28.5

# Check control plane components
sudo kubectl get pods -n kube-system

# All pods should be Running or Completed

# Check CNI plugin
sudo kubectl get pods -n kube-system | grep calico
```

### Step 11: Test Kubernetes Functionality

```bash
# Deploy test pod
sudo kubectl run nginx-test --image=nginx:latest

# Check pod status
sudo kubectl get pods

# Verify pod scheduling
sudo kubectl describe pod nginx-test

# Test pod-to-pod networking
sudo kubectl run busybox --rm -it --image=busybox -- ping <nginx-pod-ip>

# Clean up test resources
sudo kubectl delete pod nginx-test
```

---

## Validation Checklist

Post-deployment validation checklist (from spec.md success criteria):

- [ ] **SC-001**: Deployment completed in under 20 minutes
- [ ] **SC-004**: All 3 VMs successfully provisioned
- [ ] **SC-005**: Kubespray deployment completed without errors
- [ ] **SC-007**: Terraform state stored in HCP Terraform workspace
- [ ] **SC-008**: Zero manual configuration steps required
- [ ] **SC-009**: All Kubernetes components healthy:
  - [ ] kube-apiserver Running
  - [ ] kube-controller-manager Running
  - [ ] kube-scheduler Running
  - [ ] etcd Running
  - [ ] kubelet Running on all nodes
  - [ ] kube-proxy Running on all nodes
- [ ] **SC-010**: Cluster can be destroyed and recreated successfully

---

## Troubleshooting

### Issue: Terraform init fails with authentication error

**Symptoms:**
```
Error: Failed to read organization "tfo-apj-demos"
```

**Resolution:**
```bash
# Re-authenticate with HCP Terraform
terraform login

# Verify token is valid
cat ~/.terraform.d/credentials.tfrc.json

# Retry initialization
terraform init
```

### Issue: VM provisioning fails with resource constraints

**Symptoms:**
```
Error: Insufficient resources in vSphere cluster
```

**Resolution:**
1. Check vSphere resource availability (vCenter UI)
2. Reduce VM sizes in tfvars:
   ```hcl
   control_plane_vm_size = "small"
   worker_vm_size        = "small"
   ```
3. Free up resources by removing unused VMs
4. Retry deployment: `terraform apply`

### Issue: SSH connectivity timeout

**Symptoms:**
```
Error: timeout waiting for SSH connectivity
```

**Resolution:**
1. Verify firewall rules allow SSH (port 22)
2. Check VM network configuration in vSphere
3. Verify SSH key is correctly configured in workspace variables
4. Manually test SSH connectivity:
   ```bash
   ssh -v ubuntu@<vm_ip> -i ~/.ssh/k8s-vsphere-cluster
   ```
5. Increase timeout in ansible.tf (if needed):
   ```hcl
   timeout = "10m"  # Increase from 5m
   ```

### Issue: Kubespray deployment fails

**Symptoms:**
```
Error: ansible_playbook resource failed
```

**Resolution:**
1. Review Ansible logs in Terraform output
2. SSH into VMs and check requirements:
   ```bash
   python3 --version  # Should be >= 3.8
   sudo apt update
   sudo apt install -y python3 python3-pip
   ```
3. Verify all nodes are reachable:
   ```bash
   ansible all -i inventory.yml -m ping
   ```
4. Check Kubespray version compatibility
5. Retry: `terraform apply` (Kubespray is idempotent)

### Issue: Kubernetes nodes not Ready

**Symptoms:**
```
kubectl get nodes
NAME            STATUS     ROLES    AGE   VERSION
k8s-worker-01   NotReady   <none>   2m    v1.28.5
```

**Resolution:**
1. Check kubelet status:
   ```bash
   sudo systemctl status kubelet
   sudo journalctl -u kubelet -f
   ```
2. Check CNI plugin:
   ```bash
   sudo kubectl get pods -n kube-system | grep calico
   sudo kubectl logs -n kube-system <calico-pod-name>
   ```
3. Verify network connectivity between nodes:
   ```bash
   ping <other-node-ip>
   ```
4. Check for port conflicts or firewall issues

### Issue: State file inconsistency

**Symptoms:**
```
Error: state file out of sync with infrastructure
```

**Resolution:**
```bash
# Refresh state from actual infrastructure
terraform refresh

# If corruption is severe, consider clean slate
terraform destroy
terraform apply
```

---

## Rollback Procedure

If deployment fails or needs to be rolled back:

```bash
# Option 1: Destroy entire infrastructure
terraform destroy

# Review destroy plan carefully
# Type 'yes' to confirm

# Option 2: Targeted destroy (specific resources)
terraform destroy -target=ansible_playbook.kubespray_cluster
terraform destroy -target=module.k8s_worker_02

# Wait for destruction to complete
# Re-deploy if needed: terraform apply
```

**WARNING**: `terraform destroy` is IRREVERSIBLE. All VMs and data will be permanently deleted.

---

## Post-Deployment Tasks

### Configure kubectl Access (Local Machine)

```bash
# SSH into control plane and retrieve kubeconfig
ssh ubuntu@<control_plane_ip> -i ~/.ssh/k8s-vsphere-cluster
sudo cat /etc/kubernetes/admin.conf > ~/kubeconfig

# Copy to local machine
scp ubuntu@<control_plane_ip>:~/kubeconfig ~/.kube/config-vsphere-k8s

# Set KUBECONFIG environment variable
export KUBECONFIG=~/.kube/config-vsphere-k8s

# Verify connectivity
kubectl get nodes
```

### Enable Monitoring (Optional)

```bash
# Deploy metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify metrics collection
kubectl top nodes
kubectl top pods -A
```

### Configure Persistent Storage (Optional)

```bash
# Deploy vSphere CSI driver (if using vSphere storage)
# Follow official vSphere CSI documentation
```

### Document Cluster Details

Record the following in your infrastructure documentation:
- Cluster name and environment
- Control plane IP address
- Worker node IP addresses
- Kubernetes version
- CNI plugin version
- Deployment date and owner
- HCP Terraform workspace name

---

## Maintenance Procedures

### Updating Kubernetes Version

1. Update `kubernetes_version` in tfvars
2. Update `kubespray_version` to compatible version
3. Run `terraform plan` to preview changes
4. Run `terraform apply` to upgrade cluster
5. Verify all nodes after upgrade

### Adding Worker Nodes

1. Duplicate worker module block in main.tf
2. Update hostname (e.g., `k8s-worker-03`)
3. Update locals and outputs
4. Run `terraform apply`
5. New node will automatically join cluster

### Rotating SSH Keys

1. Generate new SSH key pair
2. Update `ssh_private_key` workspace variable
3. Run `terraform apply` to update VM authorized_keys
4. Verify new key works before removing old key

---

## Emergency Contacts

**Infrastructure Team Lead**: [Name] [Email] [Phone]
**Terraform Platform Team**: [Team Email]
**vSphere Administrators**: [Team Email]
**On-Call Engineer**: [Pager/Slack Channel]

---

## Change Log

| Date       | Version | Author | Changes |
|------------|---------|--------|---------|
| 2025-12-02 | 1.0.0   | Claude | Initial runbook creation |

---

## References

- Feature Specification: `/workspace/specs/001-vsphere-k8s-kubespray/spec.md`
- Implementation Plan: `/workspace/specs/001-vsphere-k8s-kubespray/plan.md`
- Data Model: `/workspace/specs/001-vsphere-k8s-kubespray/data-model.md`
- Task List: `/workspace/specs/001-vsphere-k8s-kubespray/tasks.md`
- Kubespray Documentation: https://kubespray.io/
- Terraform Ansible Provider: https://registry.terraform.io/providers/ansible/ansible/latest
- HCP Terraform: https://app.terraform.io/app/tfo-apj-demos/workspaces/vm-k8s-kubespray-runai
