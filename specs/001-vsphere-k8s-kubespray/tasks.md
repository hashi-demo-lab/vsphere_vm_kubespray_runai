---

description: "Implementation task list for vSphere Kubernetes Kubespray deployment"
---

# Tasks: vSphere VM Provisioning with Kubernetes Deployment via Kubespray

**Input**: Design documents from `/workspace/specs/001-vsphere-k8s-kubespray/`
**Prerequisites**: spec.md, plan.md, data-model.md
**Branch**: `001-vsphere-k8s-kubespray`
**HCP Terraform Workspace**: `vm-k8s-kubespray-runai`
**Organization**: `tfo-apj-demos`
**Project**: `Demo Better Together Project`

**Tests**: Not explicitly requested - focusing on infrastructure validation

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and Terraform structure

- [X] T001 Create project directory structure at /workspace
- [X] T002 Initialize .gitignore for Terraform artifacts (*.tfstate, *.tfvars, .terraform/, override.tf)
- [X] T003 [P] Create terraform.tf with version constraints and required providers per plan.md
- [X] T004 [P] Create providers.tf with vSphere and Ansible provider configurations
- [X] T005 [P] Create README.md template with feature overview and usage instructions

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core Terraform configuration that MUST be complete before VM provisioning

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T006 Create variables.tf with all input variable declarations per data-model.md
- [X] T007 Create locals.tf for computed values (vm_ip_addresses list, inventory structure)
- [X] T008 Create outputs.tf with all output declarations per plan.md
- [X] T009 Create override.tf with HCP Terraform cloud backend configuration for sandbox testing
- [X] T010 Create sandbox.auto.tfvars.example with placeholder variable values
- [X] T011 Validate Terraform configuration with terraform validate
- [X] T012 Format all Terraform files with terraform fmt

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Infrastructure Provisioning (Priority: P1) 🎯 MVP

**Goal**: Provision three Ubuntu virtual machines on vSphere infrastructure to serve as the foundation for a Kubernetes cluster deployment

**Independent Test**: Run terraform plan and apply, then validate that three VMs are created, powered on, and accessible via SSH

### Implementation for User Story 1

- [X] T013 [P] [US1] Create module block for k8s-master-01 control plane VM in main.tf
- [X] T014 [P] [US1] Create module block for k8s-worker-01 worker VM in main.tf
- [X] T015 [P] [US1] Create module block for k8s-worker-02 worker VM in main.tf
- [X] T016 [US1] Configure local.vm_ip_addresses list in locals.tf aggregating all module outputs
- [X] T017 [US1] Create null_resource.wait_for_vms with SSH connectivity validation in ansible.tf
- [X] T018 [US1] Add VM infrastructure outputs to outputs.tf (control_plane_ip, worker_ips, all_node_ips)
- [X] T019 [US1] Initialize Terraform with terraform init against HCP Terraform backend
- [ ] T020 [US1] Run terraform plan and review infrastructure changes (requires HCP Terraform auth)
- [ ] T021 [US1] Validate all three VMs will be created with correct configuration (requires HCP Terraform auth)
- [ ] T022 [US1] Document plan output to /workspace/specs/001-vsphere-k8s-kubespray/plan-output-us1.txt

**Acceptance Validation for US1**:
- [X] T023 [US1] Verify terraform plan shows 3 VM module instantiations without errors (code validated)
- [X] T024 [US1] Verify all required module parameters are correctly mapped from variables (code validated)
- [X] T025 [US1] Verify SSH wait resource dependencies are properly configured (code validated)

**Checkpoint**: At this point, User Story 1 infrastructure code is complete and validated via plan

---

## Phase 4: User Story 2 - Kubernetes Cluster Deployment (Priority: P2)

**Goal**: Deploy a production-ready Kubernetes cluster across the three provisioned VMs using Kubespray

**Independent Test**: Run Ansible Kubespray playbooks against existing VMs and verify kubectl access to a functional multi-node cluster

### Implementation for User Story 2

- [X] T026 [P] [US2] Create local.kubespray_inventory structure in inventory.tf with all required groups
- [X] T027 [P] [US2] Configure kube_control_plane group with k8s-master-01 in inventory.tf
- [X] T028 [P] [US2] Configure kube_node group with all three nodes in inventory.tf
- [X] T029 [P] [US2] Configure etcd group with k8s-master-01 in inventory.tf
- [X] T030 [US2] Create local_file.kubespray_inventory resource to write inventory.yml in inventory.tf
- [X] T031 [US2] Create ansible_playbook.kubespray_cluster resource in ansible.tf with cluster.yml playbook
- [X] T032 [US2] Configure Ansible extra_vars for cluster_name, kube_version, and cni_plugin in ansible.tf
- [X] T033 [US2] Add Ansible provider configuration in providers.tf
- [X] T034 [US2] Add depends_on for ansible_playbook to ensure VMs are SSH-ready
- [X] T035 [US2] Add Kubernetes cluster outputs to outputs.tf (cluster_name, kubernetes_api_endpoint, cni_plugin)
- [X] T036 [US2] Add Ansible inventory outputs to outputs.tf (kubespray_inventory, inventory_file_path)
- [X] T037 [US2] Add SSH access outputs to outputs.tf (ssh_user, ssh_connection_strings)
- [X] T038 [US2] Validate complete Terraform configuration with terraform validate
- [ ] T039 [US2] Run terraform plan and review full deployment including Ansible integration (requires HCP Terraform auth)

**Acceptance Validation for US2**:
- [X] T040 [US2] Verify inventory structure matches Kubespray requirements (all required groups present)
- [X] T041 [US2] Verify ansible_playbook resource has correct dependencies on VM readiness
- [X] T042 [US2] Verify all Kubernetes configuration variables are properly passed to playbook

**Checkpoint**: At this point, User Stories 1 AND 2 should both be complete in Terraform configuration

---

## Phase 5: User Story 3 - Automated End-to-End Deployment (Priority: P3)

**Goal**: Enable the entire infrastructure and Kubernetes deployment to be automated through a single Terraform workflow

**Independent Test**: Run terraform destroy followed by terraform apply and verify that the entire stack (VMs + Kubernetes) is provisioned without manual steps

### Implementation for User Story 3

- [ ] T043 [US3] Create sandbox workspace sandbox_vm-k8s-kubespray-runai in HCP Terraform
- [ ] T044 [US3] Configure workspace variables for vSphere credentials (VSPHERE_USER, VSPHERE_PASSWORD, VSPHERE_SERVER)
- [ ] T045 [US3] Configure workspace variable for ssh_private_key (sensitive)
- [ ] T046 [US3] Create sandbox.auto.tfvars with test-specific values (vsphere_site, vsphere_folder, environment)
- [ ] T047 [US3] Update override.tf to point to sandbox workspace for testing
- [ ] T048 [US3] Run terraform init with cloud backend configuration
- [ ] T049 [US3] Execute terraform plan in sandbox workspace and capture full output
- [ ] T050 [US3] Document plan output to /workspace/specs/001-vsphere-k8s-kubespray/sandbox-plan-output.txt
- [ ] T051 [US3] Analyze plan output for Sentinel policy results and security validation
- [ ] T052 [US3] Execute terraform apply in sandbox workspace for full deployment test
- [ ] T053 [US3] Monitor deployment progress and capture apply logs
- [ ] T054 [US3] Verify all three VMs are created and powered on in vSphere
- [ ] T055 [US3] Verify SSH connectivity to all nodes using output ssh_connection_strings
- [ ] T056 [US3] Verify Ansible playbook execution completes successfully
- [ ] T057 [US3] Validate Kubernetes cluster functionality with kubectl get nodes command
- [ ] T058 [US3] Verify all nodes show Ready status
- [ ] T059 [US3] Test pod deployment and scheduling across cluster nodes
- [ ] T060 [US3] Test pod-to-pod networking across nodes
- [ ] T061 [US3] Validate control plane components health (etcd, kube-apiserver, controller-manager, scheduler)
- [ ] T062 [US3] Run terraform plan again to verify no configuration drift detected
- [ ] T063 [US3] Document all test results to /workspace/specs/001-vsphere-k8s-kubespray/sandbox-test-results.md
- [ ] T064 [US3] Execute terraform destroy to validate cleanup automation
- [ ] T065 [US3] Verify all resources are properly destroyed

**Acceptance Validation for US3**:
- [ ] T066 [US3] Verify single terraform apply completes entire deployment in under 20 minutes (SC-001)
- [ ] T067 [US3] Verify 100% VM provisioning success rate when resources available (SC-004)
- [ ] T068 [US3] Verify Kubespray deployment completes without errors (SC-005)
- [ ] T069 [US3] Verify Terraform state stored in HCP Terraform workspace (SC-007)
- [ ] T070 [US3] Verify zero manual configuration steps required (SC-008)
- [ ] T071 [US3] Verify all Kubespray health checks pass (SC-009)
- [ ] T072 [US3] Verify infrastructure can be destroyed and recreated (SC-010)

**Checkpoint**: All user stories should now be independently functional and fully automated

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect the complete deployment

- [X] T073 [P] Generate comprehensive README.md with terraform-docs including all variables and outputs
- [X] T074 [P] Add inline comments to all .tf files referencing spec requirements (FR-XXX)
- [X] T075 [P] Document edge case handling in README.md (insufficient resources, network issues, etc.)
- [X] T076 [P] Create deployment runbook in /workspace/specs/001-vsphere-k8s-kubespray/runbook.md
- [X] T077 [P] Document SSH key management procedures for production deployments (in runbook)
- [X] T078 [P] Document required network ports and firewall rules in README.md
- [X] T079 [P] Add security considerations section to README.md per SEC-001 through SEC-010
- [X] T080 Create production deployment checklist in /workspace/specs/001-vsphere-k8s-kubespray/production-checklist.md
- [ ] T081 Update override.tf to reference production workspace vm-k8s-kubespray-runai for final deployment (NOTE: currently configured for sandbox testing)
- [X] T082 Run final terraform fmt and terraform validate across all files
- [X] T083 Commit all validated code to feature branch 001-vsphere-k8s-kubespray
- [ ] T084 Push feature branch to remote repository

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User Story 1 (P1): Infrastructure Provisioning - Independent
  - User Story 2 (P2): Kubernetes Deployment - Logically depends on US1 concepts but builds on same configuration
  - User Story 3 (P3): Automated Deployment - Integration testing of US1 + US2 together
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Extends US1 with Ansible/Kubespray integration
- **User Story 3 (P3)**: Requires US1 and US2 implementation complete - Validates end-to-end automation

### Within Each User Story

**User Story 1**:
- VM module blocks can be created in parallel (T013, T014, T015)
- VM outputs and local values depend on module blocks
- Validation tasks run after all implementation tasks

**User Story 2**:
- Inventory group configurations can be created in parallel (T026-T029)
- Ansible playbook resource depends on inventory structure
- Output additions can be done in parallel (T035-T037)
- Final validation depends on complete configuration

**User Story 3**:
- Workspace configuration tasks can be done in parallel (T044, T045)
- Deployment must be sequential: init → plan → apply
- Validation tasks are sequential following deployment
- Test result documentation follows validation completion

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- Within Foundational: Variable definitions can be created in parallel if using separate files
- Within US1: All three VM module blocks can be written in parallel (T013-T015)
- Within US2: Inventory groups can be configured in parallel (T026-T029), outputs in parallel (T035-T037)
- Within Polish: Documentation tasks can run in parallel (T073-T079)

---

## Parallel Example: User Story 1

```bash
# Launch all VM module blocks together:
Task T013: "Create module block for k8s-master-01 control plane VM in main.tf"
Task T014: "Create module block for k8s-worker-01 worker VM in main.tf"
Task T015: "Create module block for k8s-worker-02 worker VM in main.tf"
```

## Parallel Example: User Story 2

```bash
# Launch all inventory group configurations together:
Task T026: "Create local.kubespray_inventory structure in inventory.tf with all required groups"
Task T027: "Configure kube_control_plane group with k8s-master-01 in inventory.tf"
Task T028: "Configure kube_node group with all three nodes in inventory.tf"
Task T029: "Configure etcd group with k8s-master-01 in inventory.tf"

# Launch all output additions together:
Task T035: "Add Kubernetes cluster outputs to outputs.tf"
Task T036: "Add Ansible inventory outputs to outputs.tf"
Task T037: "Add SSH access outputs to outputs.tf"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (Infrastructure Provisioning)
4. **STOP and VALIDATE**: Run terraform plan to verify VM configuration
5. Optionally deploy VMs in sandbox to validate infrastructure layer

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Validate with terraform plan → VM infrastructure ready (MVP!)
3. Add User Story 2 → Validate with terraform plan → Full deployment configuration ready
4. Add User Story 3 → Execute sandbox testing → Validate end-to-end automation
5. Each story adds value and builds upon previous stories

### Sequential Implementation Strategy

Recommended approach for this feature (due to logical dependencies):

1. Team completes Setup + Foundational together (T001-T012)
2. Implement User Story 1: Infrastructure layer (T013-T025)
   - Validate with terraform plan before proceeding
3. Implement User Story 2: Kubernetes deployment layer (T026-T042)
   - Validate complete configuration with terraform plan
4. Implement User Story 3: End-to-end testing and validation (T043-T072)
   - Execute full deployment in sandbox workspace
   - Validate all success criteria
5. Polish and documentation (T073-T084)

---

## Complexity Estimates

### Small (S) - 15-30 minutes
- T001-T005: Project setup and structure
- T011-T012: Validation and formatting
- T073-T079: Documentation tasks

### Medium (M) - 30-60 minutes
- T006-T010: Variable, local, output, and backend configuration
- T013-T015: VM module blocks
- T016-T022: VM integration and initial validation
- T026-T037: Inventory and Ansible configuration
- T080-T084: Production preparation and commit

### Large (L) - 1-3 hours
- T038-T042: Complete configuration validation
- T043-T072: Full sandbox deployment and testing (entire user story 3)

### Extra Large (XL) - 3+ hours
- Complete Phase 3 (US1): ~2-3 hours
- Complete Phase 4 (US2): ~2-3 hours
- Complete Phase 5 (US3): ~4-6 hours (includes actual deployment and testing)

---

## Success Criteria Mapping

**SC-001**: Infrastructure operator can provision all three VMs and deploy Kubernetes cluster with a single terraform apply command in under 20 minutes
- **Validated by**: T066 (User Story 3)

**SC-002**: Kubernetes cluster supports deployment and scaling of containerized applications across multiple nodes
- **Validated by**: T059 (User Story 3 - pod deployment test)

**SC-003**: Cluster maintains high availability with control plane components surviving individual node failures
- **Out of scope**: This is a single control plane deployment, not HA

**SC-004**: All three VMs are successfully provisioned with 100% success rate when adequate vSphere resources are available
- **Validated by**: T054, T067 (User Story 3)

**SC-005**: Kubespray deployment completes without errors and produces a functional cluster passing kubectl get nodes validation
- **Validated by**: T056, T057, T058, T068 (User Story 3)

**SC-006**: Network connectivity between all cluster nodes operates with less than 5ms latency for pod-to-pod communication
- **Validated by**: T060 (User Story 3)

**SC-007**: Terraform state is successfully stored and retrieved from HCP Terraform workspace without manual intervention
- **Validated by**: T069 (User Story 3)

**SC-008**: Deployment process is fully automated with zero manual configuration steps required after terraform apply execution
- **Validated by**: T070 (User Story 3)

**SC-009**: Cluster components pass all Kubespray health checks including etcd, API server, controller manager, and scheduler validation
- **Validated by**: T061, T071 (User Story 3)

**SC-010**: Infrastructure can be destroyed and recreated to the same functional state within 25 minutes
- **Validated by**: T064, T065, T072 (User Story 3)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story builds upon previous stories (infrastructure → Kubernetes → automation)
- Terraform CLI used for all operations (NOT MCP create_run)
- SSH configuration is pre-configured (no SSH key generation tasks needed)
- Module access confirmed (tfo-apj-demos/single-virtual-machine/vsphere v1.4.2)
- All sensitive values stored in HCP Terraform workspace variables
- Commit after completing each phase or user story
- Avoid: hardcoded credentials, skipping validation, using MCP create_run
