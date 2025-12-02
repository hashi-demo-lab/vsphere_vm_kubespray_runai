# Production Deployment Checklist

**Feature**: vSphere VM Provisioning with Kubernetes Deployment via Kubespray
**Environment**: Production
**Workspace**: `vm-k8s-kubespray-runai`
**Version**: 1.0.0
**Date**: _________________
**Deployed By**: _________________

---

## Pre-Deployment Checklist

### Infrastructure Validation

- [ ] vSphere environment has sufficient resources:
  - [ ] Minimum 6 vCPUs available
  - [ ] Minimum 12 GB RAM available
  - [ ] Minimum 60 GB storage available
- [ ] Ubuntu 22.04 LTS template exists and is accessible
- [ ] Network configuration validated (DHCP/static IP allocation)
- [ ] DNS resolution configured and tested
- [ ] Firewall rules allow required Kubernetes ports (see Network Requirements below)

### Access & Permissions

- [ ] HCP Terraform organization access confirmed: `tfo-apj-demos`
- [ ] HCP Terraform production workspace access: `vm-k8s-kubespray-runai`
- [ ] vSphere service account has required permissions (see runbook.md)
- [ ] Production SSH keys generated and stored securely
- [ ] Team members have required access levels

### Configuration Review

- [ ] `production.auto.tfvars` created and reviewed
- [ ] All required variables populated:
  - [ ] `vsphere_site` - Production vSphere datacenter
  - [ ] `vsphere_folder` - Production VM folder path
  - [ ] `environment` - Set to "prod"
  - [ ] VM sizes appropriate for production workload
  - [ ] Security profile configured correctly
  - [ ] Backup policy enabled (recommended: "daily")
  - [ ] Cluster name follows naming convention
- [ ] `override.tf` points to production workspace

### Security Validation

- [ ] **SEC-001**: No hardcoded credentials in code (verified)
- [ ] **SEC-002**: SSH keys stored as sensitive workspace variables
- [ ] **SEC-007**: Security profile parameter enforced
- [ ] **SEC-008**: HCP Terraform state encryption enabled
- [ ] **SEC-009**: Production SSH access restrictions documented
- [ ] All sensitive variables marked as "Sensitive" in HCP Terraform
- [ ] vSphere credentials stored as environment variables (not Terraform variables)

### Workspace Variable Configuration

**vSphere Credentials (Environment Variables):**
- [ ] `VSPHERE_SERVER` configured
- [ ] `VSPHERE_USER` configured
- [ ] `VSPHERE_PASSWORD` configured (marked sensitive)

**SSH Configuration (Terraform Variables):**
- [ ] `ssh_private_key` configured (marked sensitive)
- [ ] `ssh_private_key_path` configured
- [ ] `ssh_user` configured (default: "ubuntu")

### Code Review & Validation

- [ ] All Terraform files formatted: `terraform fmt -check`
- [ ] Configuration validated: `terraform validate`
- [ ] Code reviewed and approved by team lead
- [ ] All FR (Functional Requirements) satisfied (FR-001 through FR-016)
- [ ] All SEC (Security Requirements) satisfied (SEC-001 through SEC-010)

### Backup & Recovery

- [ ] Backup plan documented for Kubernetes persistent data
- [ ] Disaster recovery procedures documented
- [ ] HCP Terraform state backup strategy confirmed
- [ ] Rollback procedure tested in sandbox environment

### Communication

- [ ] Deployment scheduled and communicated to stakeholders
- [ ] Change request ticket created and approved (if required)
- [ ] On-call engineer notified
- [ ] Deployment window confirmed (recommended: off-peak hours)

---

## Deployment Execution

### Pre-Deployment Steps

- [ ] Authenticate to HCP Terraform: `terraform login`
- [ ] Initialize Terraform: `terraform init`
- [ ] Generate and review plan: `terraform plan -out=prod.tfplan`
- [ ] Plan output reviewed and approved by second engineer
- [ ] Production deployment window started

### Deployment

- [ ] Start time recorded: _________________
- [ ] Apply Terraform configuration: `terraform apply prod.tfplan`
- [ ] Monitor HCP Terraform UI for progress
- [ ] Monitor Ansible playbook execution logs
- [ ] No errors encountered during deployment
- [ ] End time recorded: _________________
- [ ] Total duration: _________________ (target: < 20 minutes)

---

## Post-Deployment Validation

### Infrastructure Validation

- [ ] All 3 VMs created successfully (verified in vSphere)
- [ ] Control plane VM powered on: `k8s-master-01`
- [ ] Worker VM 1 powered on: `k8s-worker-01`
- [ ] Worker VM 2 powered on: `k8s-worker-02`
- [ ] All VMs have IP addresses assigned
- [ ] SSH connectivity tested to all nodes

### Kubernetes Cluster Validation

- [ ] All nodes show Ready status: `kubectl get nodes`
  - [ ] k8s-master-01: Ready
  - [ ] k8s-worker-01: Ready
  - [ ] k8s-worker-02: Ready

- [ ] Control plane components healthy:
  - [ ] kube-apiserver: Running
  - [ ] kube-controller-manager: Running
  - [ ] kube-scheduler: Running
  - [ ] etcd: Running

- [ ] Worker components healthy:
  - [ ] kubelet: Running on all nodes
  - [ ] kube-proxy: Running on all nodes

- [ ] CNI plugin deployed and operational:
  - [ ] Calico/Flannel/Cilium pods: Running
  - [ ] Pod network CIDR configured

### Functional Testing

- [ ] Deploy test nginx pod: `kubectl run nginx-test --image=nginx`
- [ ] Test pod scheduled successfully: `kubectl get pods`
- [ ] Test pod running: `kubectl describe pod nginx-test`
- [ ] Test pod-to-pod networking (ping between pods)
- [ ] Test DNS resolution within cluster
- [ ] Test NodePort service accessibility (if applicable)
- [ ] Clean up test resources: `kubectl delete pod nginx-test`

### Terraform State Validation

- [ ] Terraform state stored in HCP Terraform workspace
- [ ] State file accessible via HCP Terraform UI
- [ ] No local state files present (`ls terraform.tfstate*`)
- [ ] State locking working correctly

### Output Verification

- [ ] `control_plane_ip` output available and correct
- [ ] `worker_ips` output available and correct
- [ ] `kubernetes_api_endpoint` output available and correct
- [ ] `ssh_connection_strings` output available and correct
- [ ] All outputs documented in deployment records

### Success Criteria Validation

From spec.md success criteria:

- [ ] **SC-001**: Deployment completed in < 20 minutes
- [ ] **SC-004**: All 3 VMs provisioned with 100% success rate
- [ ] **SC-005**: Kubespray deployment completed without errors
- [ ] **SC-007**: Terraform state stored in HCP Terraform
- [ ] **SC-008**: Zero manual configuration steps required
- [ ] **SC-009**: All Kubespray health checks passed
- [ ] **SC-010**: Cluster can be destroyed and recreated (tested in sandbox)

---

## Post-Deployment Tasks

### Documentation

- [ ] Cluster details documented in infrastructure wiki
- [ ] Deployment timestamp and owner recorded
- [ ] IP addresses and hostnames documented
- [ ] Kubernetes version and CNI plugin documented
- [ ] Known issues or warnings documented

### Access Configuration

- [ ] kubectl configuration distributed to authorized users
- [ ] RBAC roles configured (if applicable)
- [ ] Service accounts created for applications
- [ ] Production access restrictions enforced

### Monitoring Setup

- [ ] Cluster monitoring configured (Prometheus/Grafana)
- [ ] Alert rules configured for critical components
- [ ] Log aggregation configured (if applicable)
- [ ] Health check endpoints validated

### Integration

- [ ] CI/CD pipelines updated with cluster endpoint
- [ ] Application deployments scheduled
- [ ] Load balancer configured (if applicable)
- [ ] Ingress controller deployed (if applicable)

---

## Network Requirements Reference

**Required Ports (must be accessible between cluster nodes):**

**Control Plane:**
- 6443: Kubernetes API server
- 2379-2380: etcd server client API
- 10250: Kubelet API
- 10259: kube-scheduler
- 10257: kube-controller-manager

**Worker Nodes:**
- 10250: Kubelet API
- 30000-32767: NodePort Services

**All Nodes:**
- 22: SSH (for Ansible and management)
- CNI-specific ports (e.g., Calico: 179 BGP)

---

## Rollback Criteria

Rollback should be initiated if:

- [ ] VM provisioning fails for any node
- [ ] SSH connectivity cannot be established
- [ ] Kubespray deployment fails with errors
- [ ] Any node remains in NotReady state after 10 minutes
- [ ] Control plane components fail to start
- [ ] Pod networking is non-functional
- [ ] Deployment exceeds 30 minutes
- [ ] Critical security vulnerability discovered

**Rollback Procedure**: See runbook.md section "Rollback Procedure"

---

## Sign-Off

### Deployment Team

**Deployed By**: _________________ Date: _______________ Signature: _______________

**Reviewed By**: _________________ Date: _______________ Signature: _______________

### Approval

**Infrastructure Lead**: _________________ Date: _______________ Signature: _______________

**Security Review**: _________________ Date: _______________ Signature: _______________

---

## Issues & Notes

**Issues Encountered During Deployment**:
```
[Document any issues, warnings, or unexpected behavior observed during deployment]




```

**Deviations from Standard Procedure**:
```
[Document any steps that deviated from the runbook or standard procedure]




```

**Post-Deployment Observations**:
```
[Document any observations, performance notes, or recommendations for future deployments]




```

---

## References

- Deployment Runbook: `/workspace/specs/001-vsphere-k8s-kubespray/runbook.md`
- Feature Specification: `/workspace/specs/001-vsphere-k8s-kubespray/spec.md`
- Implementation Plan: `/workspace/specs/001-vsphere-k8s-kubespray/plan.md`
- Task List: `/workspace/specs/001-vsphere-k8s-kubespray/tasks.md`
- HCP Terraform Workspace: https://app.terraform.io/app/tfo-apj-demos/workspaces/vm-k8s-kubespray-runai

---

**END OF CHECKLIST**
