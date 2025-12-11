# Remote State and Local Values
# Feature: Run:AI Platform Deployment
# Spec: /workspace/specs/002-runai-deployment/plan.md

# =============================================================================
# Remote State from Infrastructure Configuration (Config 1)
# Reads kubeconfig and cluster details for provider configuration
# =============================================================================

data "terraform_remote_state" "infrastructure" {
  backend = "remote"

  config = {
    organization = var.tfc_organization
    workspaces = {
      name = var.infrastructure_workspace
    }
  }
}

# =============================================================================
# Local Values from Remote State
# =============================================================================

locals {
  # Cluster connection details from infrastructure outputs
  kubernetes_host           = data.terraform_remote_state.infrastructure.outputs.kubernetes_api_endpoint
  kubernetes_ca_certificate = base64decode(data.terraform_remote_state.infrastructure.outputs.kubeconfig_ca_certificate)
  kubernetes_client_cert    = base64decode(data.terraform_remote_state.infrastructure.outputs.kubeconfig_client_certificate)
  kubernetes_client_key     = base64decode(data.terraform_remote_state.infrastructure.outputs.kubeconfig_client_key)

  # Cluster metadata
  cluster_name     = data.terraform_remote_state.infrastructure.outputs.cluster_name
  control_plane_ip = data.terraform_remote_state.infrastructure.outputs.control_plane_ip
  worker_ips       = data.terraform_remote_state.infrastructure.outputs.worker_ips
}
