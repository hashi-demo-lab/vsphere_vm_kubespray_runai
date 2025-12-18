# Feature Specification: vSphere VM Provisioning with Kubernetes Deployment via Kubespray

**Feature Branch**: `001-vsphere-k8s-kubespray`
**Created**: 2025-12-02
**Status**: Draft
**Input**: User description: "Provision 3 VMs using single-virtual-machine module with Ubuntu and deploy Kubernetes cluster using Kubespray via Ansible provider"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Infrastructure Provisioning (Priority: P1)

As a DevOps engineer, I need to provision three Ubuntu virtual machines on vSphere infrastructure to serve as the foundation for a Kubernetes cluster deployment, enabling me to build a production-ready container orchestration platform.

**Why this priority**: Without the underlying VM infrastructure, no subsequent deployment steps can proceed. This is the foundational requirement that all other features depend upon.

**Independent Test**: Can be fully tested by running Terraform plan and apply, then validating that three VMs are created, powered on, and accessible via SSH. Delivers immediate value by providing compute resources for the team.

**Acceptance Scenarios**:

1. **Given** vSphere credentials are configured and the single-virtual-machine module is available, **When** Terraform apply is executed, **Then** three Ubuntu VMs are provisioned with the specified configuration
2. **Given** the VMs are successfully created, **When** an administrator attempts SSH access, **Then** all three VMs are accessible and responsive
3. **Given** the VMs are running, **When** checking system resources, **Then** each VM has the allocated CPU, memory, and storage as specified in the configuration
4. **Given** network configuration is applied, **When** testing connectivity between VMs, **Then** all three VMs can communicate with each other on the private network

---

### User Story 2 - Kubernetes Cluster Deployment (Priority: P2)

As a platform engineer, I need to deploy a production-ready Kubernetes cluster across the three provisioned VMs using Kubespray, so that application teams can deploy and manage containerized workloads with high availability.

**Why this priority**: Once infrastructure exists (P1), the Kubernetes deployment transforms raw compute into a usable platform. This is the primary value delivery mechanism for container orchestration.

**Independent Test**: Can be tested independently by running the Ansible Kubespray playbooks against the existing VMs and verifying kubectl access to a functional multi-node cluster. Delivers a working Kubernetes API and control plane.

**Acceptance Scenarios**:

1. **Given** three Ubuntu VMs are provisioned and accessible, **When** Kubespray Ansible playbooks are executed via Terraform Ansible provider, **Then** Kubernetes control plane components are deployed successfully
2. **Given** Kubernetes is deployed, **When** running kubectl get nodes, **Then** all three nodes appear in Ready state
3. **Given** the cluster is operational, **When** deploying a test application, **Then** pods are scheduled and running across the cluster
4. **Given** the cluster is configured, **When** checking networking, **Then** pod-to-pod communication works across nodes
5. **Given** Kubernetes is installed, **When** validating cluster components, **Then** etcd, kube-apiserver, kube-controller-manager, and kube-scheduler are healthy

---

### User Story 3 - Automated End-to-End Deployment (Priority: P3)

As a DevOps engineer, I need the entire infrastructure and Kubernetes deployment to be automated through a single Terraform workflow, enabling repeatable and consistent deployments without manual intervention.

**Why this priority**: Automation improves reliability and enables disaster recovery, but the individual components (P1, P2) must work first before automation value can be realized.

**Independent Test**: Can be tested by running terraform destroy followed by terraform apply and verifying that the entire stack (VMs + Kubernetes) is provisioned without manual steps. Delivers efficiency and repeatability.

**Acceptance Scenarios**:

1. **Given** a clean environment with no existing resources, **When** executing terraform apply once, **Then** all infrastructure and Kubernetes components are deployed successfully
2. **Given** the deployment is complete, **When** running terraform plan again, **Then** no configuration drift is detected
3. **Given** infrastructure needs to be recreated, **When** running terraform destroy and then terraform apply, **Then** the cluster is restored to the same functional state
4. **Given** the automated deployment completes, **When** checking cluster health, **Then** all Kubernetes components are operational without manual intervention

---

### Edge Cases

- What happens when one of the three VMs fails to provision due to insufficient vSphere resources?
- How does the system handle network connectivity issues between VMs during Kubernetes deployment?
- What occurs if the Kubespray Ansible playbook execution is interrupted midway?
- How does the deployment handle pre-existing VMs with the same hostnames?
- What happens when vSphere credentials expire or become invalid during deployment?
- How does the system handle DNS resolution failures for cluster components?
- What occurs if the Ubuntu template specified does not exist in the vSphere environment?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provision exactly three virtual machines using the tfo-apj-demos/single-virtual-machine/vsphere module version 1.4.2
- **FR-002**: System MUST configure each VM with Ubuntu Linux operating system
- **FR-003**: System MUST assign unique hostnames to each VM following a consistent naming pattern (e.g., k8s-master-01, k8s-worker-01, k8s-worker-02)
- **FR-004**: System MUST configure network connectivity between all three VMs to enable cluster communication
- **FR-005**: System MUST deploy VMs with sufficient resources to support Kubernetes control plane and worker node requirements (minimum 2 CPU cores, 4GB RAM per node)
- **FR-006**: System MUST integrate terraform-provider-ansible to execute Kubespray deployment playbooks
- **FR-007**: System MUST configure one VM as a Kubernetes control plane node and two VMs as worker nodes
- **FR-008**: System MUST install Kubernetes cluster components using the Kubespray Ansible playbooks
- **FR-009**: System MUST configure kubectl access credentials for cluster administration
- **FR-010**: System MUST enable pod networking across all cluster nodes using a Container Network Interface (CNI)
- **FR-011**: System MUST store Terraform state in HCP Terraform workspace "vm-k8s-kubespray-runai"
- **FR-012**: System MUST use HCP Terraform organization "tfo-apj-demos" and project "Demo Better Together Project"
- **FR-013**: System MUST generate an Ansible inventory file dynamically from Terraform state
- **FR-014**: System MUST ensure idempotent deployment allowing repeated terraform apply operations
- **FR-015**: System MUST validate VM accessibility via SSH before proceeding with Kubernetes deployment
- **FR-016**: System MUST configure required VM module parameters: backup_policy, environment, os_type, security_profile, site, size, storage_profile, tier, hostname, and folder

### Key Entities

- **Virtual Machine**: Represents a compute instance in vSphere with allocated CPU, memory, storage, and network configuration. Each VM has a unique hostname and IP address within the cluster network.
- **Kubernetes Cluster**: Logical grouping of nodes (VMs) that collectively run containerized applications, consisting of control plane components and worker nodes.
- **Kubernetes Node**: Individual VM participating in the Kubernetes cluster, either as control plane (master) or worker, running kubelet and container runtime.
- **Ansible Inventory**: Dynamic list of target hosts (VMs) with their connection details and role assignments, generated from Terraform state for Kubespray playbook execution.
- **HCP Terraform Workspace**: Remote execution environment that stores Terraform state and manages deployment lifecycle for the infrastructure.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Infrastructure operator can provision all three VMs and deploy Kubernetes cluster with a single terraform apply command in under 20 minutes
- **SC-002**: Kubernetes cluster supports deployment and scaling of containerized applications across multiple nodes
- **SC-003**: Cluster maintains high availability with control plane components surviving individual node failures
- **SC-004**: All three VMs are successfully provisioned with 100% success rate when adequate vSphere resources are available
- **SC-005**: Kubespray deployment completes without errors and produces a functional cluster passing kubectl get nodes validation
- **SC-006**: Network connectivity between all cluster nodes operates with less than 5ms latency for pod-to-pod communication
- **SC-007**: Terraform state is successfully stored and retrieved from HCP Terraform workspace without manual intervention
- **SC-008**: Deployment process is fully automated with zero manual configuration steps required after terraform apply execution
- **SC-009**: Cluster components pass all Kubespray health checks including etcd, API server, controller manager, and scheduler validation
- **SC-010**: Infrastructure can be destroyed and recreated to the same functional state within 25 minutes

## Assumptions *(mandatory)*

- vSphere infrastructure is available and accessible with adequate resources (CPU, memory, storage) for three VMs
- HCP Terraform workspace "vm-k8s-kubespray-runai" exists in organization "tfo-apj-demos" under project "Demo Better Together Project"
- vSphere credentials are configured as workspace environment variables or via dynamic credentials
- Ubuntu VM template exists in the vSphere environment and is compatible with the single-virtual-machine module
- Network configuration in vSphere allows VM-to-VM communication on required Kubernetes ports
- DNS resolution is available for VM hostnames or static IP addresses will be used
- Terraform version 1.5+ is installed and configured locally or in the execution environment
- Kubespray version compatible with terraform-provider-ansible is available (recommend 2.24.0 or later)
- SSH key pair is available for VM access and Ansible playbook execution
- Internet connectivity is available for downloading Kubernetes components and container images
- The tfo-apj-demos/single-virtual-machine/vsphere module version 1.4.2 is accessible from HCP Terraform
- Standard Kubernetes cluster architecture is acceptable: 1 control plane node, 2 worker nodes (not a highly available control plane with multiple masters)

## Dependencies *(mandatory)*

### External Dependencies

- **vSphere Infrastructure**: ESXi hosts, vCenter Server, and sufficient compute/storage resources
- **HCP Terraform**: Remote backend for state management and execution environment
- **Terraform Provider - vSphere**: Required for VM provisioning operations
- **Terraform Provider - Ansible**: Required for executing Kubespray playbooks (nbering/terraform-provider-ansible or equivalent)
- **Kubespray Project**: Ansible playbooks and roles for Kubernetes deployment
- **Ubuntu Cloud Images**: Base operating system template for VMs
- **Kubernetes Release**: Container images and binaries for cluster components
- **Container Network Interface (CNI) Plugin**: For pod networking (e.g., Calico, Flannel)

### Internal Dependencies

- **Private Module**: tfo-apj-demos/single-virtual-machine/vsphere version 1.4.2 must be available in HCP Terraform registry
- **Workspace Configuration**: HCP Terraform workspace must have appropriate execution mode and Terraform version
- **Authentication**: vSphere credentials must be configured in workspace or via dynamic credential injection

## Security Considerations *(mandatory)*

- **SEC-001**: vSphere credentials MUST NOT be hardcoded in Terraform configuration files
- **SEC-002**: SSH private keys MUST be stored securely and never committed to version control
- **SEC-003**: VM operating systems MUST have security updates applied via automated patching mechanism
- **SEC-004**: Network security groups or firewall rules SHOULD restrict access to Kubernetes API server to authorized networks only
- **SEC-005**: Kubernetes RBAC (Role-Based Access Control) MUST be enabled to control cluster access
- **SEC-006**: Secrets management solution SHOULD be integrated for storing sensitive Kubernetes configuration data
- **SEC-007**: VM security_profile parameter MUST be set appropriately based on workload sensitivity
- **SEC-008**: Terraform state in HCP Terraform MUST use encryption at rest and in transit
- **SEC-009**: SSH access to VMs SHOULD be restricted to bastion hosts or VPN connections in production environments
- **SEC-010**: Container runtime security scanning SHOULD be enabled for deployed workloads

## Technical Architecture *(optional)*

### Component Overview

The solution consists of three architectural layers:

1. **Infrastructure Layer**: Three Ubuntu VMs provisioned via Terraform using the single-virtual-machine module on vSphere
2. **Orchestration Layer**: Terraform with Ansible provider executing Kubespray playbooks for Kubernetes installation
3. **Platform Layer**: Production-ready Kubernetes cluster with control plane and worker nodes

### Deployment Flow

1. Terraform initializes with HCP Terraform backend configuration
2. Single-virtual-machine module provisions three VMs with specified configuration parameters
3. Terraform null_resource or ansible_host resources wait for SSH availability
4. Dynamic inventory generation from Terraform outputs maps VMs to Kubernetes roles
5. Ansible provider executes Kubespray playbooks targeting the inventory
6. Kubespray installs and configures Kubernetes components on each node
7. Cluster validation confirms all nodes are ready and components are healthy
8. kubeconfig is generated and stored for administrative access

### Module Configuration Pattern

Each VM will be provisioned using this pattern:

```hcl
module "k8s_node_<n>" {
  source  = "app.terraform.io/tfo-apj-demos/single-virtual-machine/vsphere"
  version = "1.4.2"

  hostname         = "k8s-<role>-<number>"
  environment      = "<environment>"
  site             = "<datacenter>"
  size             = "medium"
  storage_profile  = "standard"
  tier             = "gold"
  backup_policy    = "daily"
  os_type          = "linux"
  security_profile = "kubernetes-node"
  folder           = "<vm-folder-path>"
}
```

### Ansible Integration Pattern

The terraform-provider-ansible integration follows this approach:

1. Terraform creates ansible_host resources for each provisioned VM
2. Inventory is dynamically generated from Terraform state using terraform-inventory script
3. Ansible playbook resource executes Kubespray cluster.yml playbook
4. Dependencies ensure VMs are fully provisioned before Ansible execution begins

## Non-Functional Requirements *(optional)*

- **NFR-001**: Deployment repeatability - System must produce identical cluster configuration across multiple deployments
- **NFR-002**: Infrastructure as Code compliance - All configuration must be version-controlled and declarative
- **NFR-003**: Deployment observability - All deployment steps must produce detailed logs for troubleshooting
- **NFR-004**: Resource efficiency - VMs should be right-sized to avoid resource waste while meeting Kubernetes requirements
- **NFR-005**: State consistency - Terraform state must accurately reflect actual infrastructure state at all times

## Out of Scope *(optional)*

- Highly available Kubernetes control plane with multiple master nodes (future enhancement)
- Monitoring and observability stack installation (Prometheus, Grafana, etc.)
- Ingress controller deployment and configuration
- Storage class and persistent volume configuration
- Certificate management and rotation automation
- Kubernetes cluster upgrades and version management
- Multi-cluster federation or service mesh implementation
- Cost optimization and resource scheduling policies
- Disaster recovery and backup automation for Kubernetes workloads
- Production-grade security hardening (CIS benchmarks, pod security policies)
- GitOps integration for application deployment
- Load balancer configuration for external service access

## Open Questions *(optional)*

None - All critical decisions have been made based on industry best practices and the provided requirements.
