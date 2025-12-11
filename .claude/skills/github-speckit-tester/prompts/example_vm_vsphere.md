# Example: vsphere vm with kubespray

**IMPORTANT** - Do not prompt me, make best practice decisions independently (this is for prompt eval)

Using the **github-speckit-tester** skill non-interactively.

## Infrastructure Requirements

Provision using Terraform:

- 3 VMs using module single-virtual-machine with Ubuntu
- Using Ansible provider terraform-provider-ansible provision kubernetes cluster using these vms using kubespray

module "single-virtual-machine" {
source = "app.terraform.io/tfo-apj-demos/single-virtual-machine/vsphere"
version = "1.4.2"

# insert required variables here

}

## HCP Terraform Configuration

- **Organization**: `tfo-apj-demos`
- **Project**: `Demo Better Together Project`
- **Workspace**: `vm-k8s-kubespray-runai`

## Workflow Instructions

- Follow best practice
- Use subagents to make best practice decisions if you need clarity
- Don't prompt the user - make decisions yourself
- If you hit issues, resolve them without prompting
