# Implementation Plan: Run:AI Deployment on Kubernetes via Terraform

**Feature Branch**: `002-runai-deployment`
**Plan Version**: 2.0.0
**Created**: 2025-12-11
**Updated**: 2025-12-11
**Status**: Draft

---

## Executive Summary

Deploy NVIDIA Run:AI GPU orchestration platform on the existing Kubernetes v1.28.6 cluster using a **two-configuration Terraform architecture**. This separates infrastructure provisioning from platform deployment, resolving provider dependency issues and enabling clean GitOps workflows.

---

## Architecture Decision: Two Terraform Configurations

### Why Two Configurations?

The Kubernetes and Helm providers require valid cluster credentials at **plan time**, but the kubeconfig doesn't exist until **after Kubespray deploys Kubernetes**. This creates a circular dependency that cannot be resolved in a single configuration.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    DEPENDENCY ANALYSIS                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Single Config Problem:                                                      │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐                │
│  │ terraform    │────▶│ Kubernetes   │────▶│ helm_release │                │
│  │ plan         │     │ provider     │     │ resources    │                │
│  └──────────────┘     └──────┬───────┘     └──────────────┘                │
│                              │                                              │
│                              │ Needs kubeconfig                             │
│                              ▼                                              │
│                       ┌──────────────┐                                      │
│                       │ kubeconfig   │ ◀── Created by Kubespray            │
│                       │ (NOT EXISTS) │     DURING apply phase              │
│                       └──────────────┘                                      │
│                                                                              │
│  ❌ FAILS: Provider config evaluated before Kubespray runs                  │
│                                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Two Config Solution:                                                        │
│                                                                              │
│  Config 1: Infrastructure          Config 2: Platform                       │
│  ┌────────────────────────┐       ┌────────────────────────┐               │
│  │ • vSphere VMs          │       │ • GPU Operator         │               │
│  │ • Kubespray/K8s        │──────▶│ • Run:AI               │               │
│  │ • Outputs: kubeconfig  │       │ • Prometheus           │               │
│  └────────────────────────┘       │ • Ingress              │               │
│           │                       └────────────────────────┘               │
│           │                                 ▲                               │
│           │    terraform_remote_state       │                               │
│           └─────────────────────────────────┘                               │
│                                                                              │
│  ✅ WORKS: Config 2 reads kubeconfig from Config 1 state                    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Benefits of Two Configurations

| Benefit | Description |
|---------|-------------|
| **Clean Dependencies** | No circular provider dependencies |
| **Separation of Concerns** | Infrastructure vs Platform |
| **Independent Lifecycles** | Update Run:AI without touching VMs |
| **Team Ownership** | Platform team owns Config 2 |
| **Easier Troubleshooting** | Isolate issues to specific layer |
| **GitOps Ready** | Separate repos/branches per config |
| **Safer Deployments** | Run:AI changes don't risk infrastructure |

---

## Configuration Structure

```
/workspace/
├── infrastructure/                    # Config 1: Infrastructure
│   ├── main.tf                       # VM module instantiations
│   ├── locals.tf                     # Computed values
│   ├── variables.tf                  # Infrastructure variables
│   ├── outputs.tf                    # Exports kubeconfig, IPs
│   ├── providers.tf                  # vSphere provider only
│   ├── terraform.tf                  # Version constraints
│   ├── override.tf                   # HCP Terraform backend
│   ├── ansible.tf                    # Kubespray deployment
│   └── ssh_key.tf                    # SSH key generation
│
├── platform/                          # Config 2: Platform/Run:AI
│   ├── main.tf                       # Remote state data source
│   ├── locals.tf                     # Platform computed values
│   ├── variables.tf                  # Platform variables
│   ├── outputs.tf                    # Run:AI outputs
│   ├── providers.tf                  # Kubernetes + Helm providers
│   ├── terraform.tf                  # Version constraints
│   ├── override.tf                   # HCP Terraform backend
│   ├── storage.tf                    # StorageClass
│   ├── ingress.tf                    # NGINX Ingress
│   ├── monitoring.tf                 # Prometheus stack
│   ├── gpu-operator.tf               # NVIDIA GPU Operator
│   └── runai.tf                      # Run:AI deployment
│
└── specs/
    └── 002-runai-deployment/
        └── plan.md                    # This file
```

---

## Config 1: Infrastructure

### HCP Terraform Workspace

- **Organization**: `tfo-apj-demos`
- **Workspace**: `vm-k8s-kubespray-runai` (or `sandbox_vm-k8s-kubespray-runai`)
- **Purpose**: VMs + Kubernetes cluster deployment

### Key Outputs (infrastructure/outputs.tf)

```hcl
# =============================================================================
# Outputs for Platform Configuration (Config 2)
# These are consumed via terraform_remote_state
# =============================================================================

output "control_plane_ip" {
  description = "Control plane node IP address"
  value       = module.k8s_control_plane_01.ip_address
}

output "worker_ips" {
  description = "Worker node IP addresses"
  value = [
    module.k8s_worker_01.ip_address,
    module.k8s_worker_02.ip_address
  ]
}

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = var.cluster_name
}

output "kubernetes_api_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = "https://${module.k8s_control_plane_01.ip_address}:6443"
}

# =============================================================================
# Kubeconfig for Platform Config
# Fetched from control plane after Kubespray deployment
# =============================================================================

output "kubeconfig_raw" {
  description = "Raw kubeconfig content from control plane"
  value       = data.external.fetch_kubeconfig[0].result.kubeconfig
  sensitive   = true
}

output "kubeconfig_host" {
  description = "Kubernetes API host"
  value       = "https://${module.k8s_control_plane_01.ip_address}:6443"
}

output "kubeconfig_ca_certificate" {
  description = "Cluster CA certificate (base64)"
  value       = data.external.fetch_kubeconfig[0].result.ca_certificate
  sensitive   = true
}

output "kubeconfig_client_certificate" {
  description = "Client certificate (base64)"
  value       = data.external.fetch_kubeconfig[0].result.client_certificate
  sensitive   = true
}

output "kubeconfig_client_key" {
  description = "Client key (base64)"
  value       = data.external.fetch_kubeconfig[0].result.client_key
  sensitive   = true
}
```

### Kubeconfig Fetch (infrastructure/locals.tf addition)

```hcl
# =============================================================================
# Fetch Kubeconfig from Control Plane Node
# Executed after Kubespray completes
# =============================================================================

data "external" "fetch_kubeconfig" {
  count = var.enable_kubespray_deployment ? 1 : 0

  program = ["bash", "-c", <<-EOT
    set -e

    # Fetch kubeconfig from control plane
    KUBECONFIG_RAW=$(ssh -o StrictHostKeyChecking=no \
      -i ${local_sensitive_file.ssh_private_key.filename} \
      ${var.ssh_user}@${module.k8s_control_plane_01.ip_address} \
      'sudo cat /etc/kubernetes/admin.conf')

    # Extract components using Python
    python3 << 'PYTHON'
import yaml
import json
import base64
import sys
import os

kubeconfig_raw = os.environ.get('KUBECONFIG_RAW', '')
if not kubeconfig_raw:
    # Read from stdin as fallback
    kubeconfig_raw = """$KUBECONFIG_RAW"""

config = yaml.safe_load(kubeconfig_raw)

# Extract certificates
ca_cert = config['clusters'][0]['cluster']['certificate-authority-data']
client_cert = config['users'][0]['user']['client-certificate-data']
client_key = config['users'][0]['user']['client-key-data']

result = {
    "kubeconfig": base64.b64encode(kubeconfig_raw.encode()).decode(),
    "ca_certificate": ca_cert,
    "client_certificate": client_cert,
    "client_key": client_key
}

print(json.dumps(result))
PYTHON
  EOT
  ]

  depends_on = [
    terraform_data.run_kubespray
  ]
}
```

---

## Config 2: Platform (Run:AI)

### HCP Terraform Workspace

- **Organization**: `tfo-apj-demos`
- **Workspace**: `vm-k8s-runai-platform` (or `sandbox_vm-k8s-runai-platform`)
- **Purpose**: Run:AI + supporting components deployment

### Remote State Data Source (platform/main.tf)

```hcl
# =============================================================================
# Remote State from Infrastructure Configuration
# Reads kubeconfig and cluster details from Config 1
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
  # Cluster connection details
  kubernetes_host            = data.terraform_remote_state.infrastructure.outputs.kubernetes_api_endpoint
  kubernetes_ca_certificate  = base64decode(data.terraform_remote_state.infrastructure.outputs.kubeconfig_ca_certificate)
  kubernetes_client_cert     = base64decode(data.terraform_remote_state.infrastructure.outputs.kubeconfig_client_certificate)
  kubernetes_client_key      = base64decode(data.terraform_remote_state.infrastructure.outputs.kubeconfig_client_key)

  # Cluster metadata
  cluster_name       = data.terraform_remote_state.infrastructure.outputs.cluster_name
  control_plane_ip   = data.terraform_remote_state.infrastructure.outputs.control_plane_ip
  worker_ips         = data.terraform_remote_state.infrastructure.outputs.worker_ips
}
```

### Provider Configuration (platform/providers.tf)

```hcl
# =============================================================================
# Kubernetes Provider
# Uses credentials from infrastructure remote state
# =============================================================================

provider "kubernetes" {
  host                   = local.kubernetes_host
  cluster_ca_certificate = local.kubernetes_ca_certificate
  client_certificate     = local.kubernetes_client_cert
  client_key             = local.kubernetes_client_key
}

# =============================================================================
# Helm Provider
# Uses same credentials as Kubernetes provider
# =============================================================================

provider "helm" {
  kubernetes {
    host                   = local.kubernetes_host
    cluster_ca_certificate = local.kubernetes_ca_certificate
    client_certificate     = local.kubernetes_client_cert
    client_key             = local.kubernetes_client_key
  }
}
```

### Variables (platform/variables.tf)

```hcl
# =============================================================================
# Terraform Cloud Configuration
# =============================================================================

variable "tfc_organization" {
  description = "Terraform Cloud organization name"
  type        = string
  default     = "tfo-apj-demos"
}

variable "infrastructure_workspace" {
  description = "Infrastructure workspace name (Config 1)"
  type        = string
  default     = "sandbox_vm-k8s-kubespray-runai"
}

# =============================================================================
# Run:AI Configuration
# =============================================================================

variable "enable_runai" {
  description = "Enable Run:AI deployment"
  type        = bool
  default     = true
}

variable "runai_version" {
  description = "Run:AI Helm chart version"
  type        = string
  default     = "2.19.0"
}

variable "runai_cluster_name" {
  description = "Run:AI cluster name (for registration)"
  type        = string
  default     = "vsphere-k8s-cluster"
}

variable "runai_cluster_url" {
  description = "FQDN for Run:AI cluster access"
  type        = string
}

variable "runai_control_plane_url" {
  description = "Run:AI control plane URL"
  type        = string
  default     = "https://app.run.ai"
}

variable "runai_cluster_token" {
  description = "Run:AI cluster token (from Run:AI console)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "runai_cluster_uid" {
  description = "Run:AI cluster UID (from Run:AI console)"
  type        = string
  default     = ""
}

# =============================================================================
# NVIDIA GPU Operator Configuration
# =============================================================================

variable "enable_gpu_operator" {
  description = "Enable NVIDIA GPU Operator"
  type        = bool
  default     = true
}

variable "gpu_operator_version" {
  description = "GPU Operator Helm chart version"
  type        = string
  default     = "v24.6.0"
}

variable "gpu_driver_enabled" {
  description = "Deploy GPU drivers as containers"
  type        = bool
  default     = true
}

# =============================================================================
# Supporting Components
# =============================================================================

variable "enable_ingress_nginx" {
  description = "Enable NGINX Ingress Controller"
  type        = bool
  default     = true
}

variable "ingress_nginx_version" {
  description = "NGINX Ingress Helm chart version"
  type        = string
  default     = "4.9.0"
}

variable "enable_prometheus" {
  description = "Enable Prometheus monitoring"
  type        = bool
  default     = true
}

variable "prometheus_stack_version" {
  description = "kube-prometheus-stack Helm chart version"
  type        = string
  default     = "56.6.0"
}

variable "enable_local_storage" {
  description = "Enable local-path-provisioner StorageClass"
  type        = bool
  default     = true
}

# =============================================================================
# TLS Configuration
# =============================================================================

variable "generate_self_signed_cert" {
  description = "Generate self-signed TLS certificate"
  type        = bool
  default     = true
}

variable "runai_tls_cert" {
  description = "TLS certificate (PEM format)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "runai_tls_key" {
  description = "TLS private key (PEM format)"
  type        = string
  sensitive   = true
  default     = ""
}
```

### Version Constraints (platform/terraform.tf)

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.0"
    }
  }
}
```

### Backend Configuration (platform/override.tf)

```hcl
terraform {
  cloud {
    organization = "tfo-apj-demos"

    workspaces {
      name = "sandbox_vm-k8s-runai-platform"
    }
  }
}
```

---

## Platform Resource Dependency Chain

```hcl
# =============================================================================
# Dependency Order (platform/locals.tf)
# =============================================================================

# The dependency chain ensures correct deployment order:
#
# 1. StorageClass (local-path-provisioner)
#    └── Required for PersistentVolumeClaims
#
# 2. Ingress Controller (nginx)
#    ├── Depends on: StorageClass
#    └── Required for external access
#
# 3. Prometheus Stack
#    ├── Depends on: StorageClass (for PVCs)
#    └── Required for Run:AI metrics
#
# 4. GPU Operator
#    ├── Depends on: Prometheus (for DCGM metrics)
#    └── Required for GPU scheduling
#
# 5. Run:AI
#    ├── Depends on: GPU Operator
#    ├── Depends on: Prometheus
#    ├── Depends on: Ingress
#    └── Final deployment
```

### Storage Class (platform/storage.tf)

```hcl
# =============================================================================
# Local Path Provisioner - Default StorageClass
# Dependency: None (first to deploy)
# =============================================================================

resource "helm_release" "local_path_provisioner" {
  count = var.enable_local_storage ? 1 : 0

  name             = "local-path-provisioner"
  repository       = "https://charts.containeroo.ch"
  chart            = "local-path-provisioner"
  version          = "0.0.26"
  namespace        = "local-path-storage"
  create_namespace = true

  set {
    name  = "storageClass.defaultClass"
    value = "true"
  }

  set {
    name  = "storageClass.name"
    value = "local-path"
  }
}
```

### Ingress Controller (platform/ingress.tf)

```hcl
# =============================================================================
# NGINX Ingress Controller
# Dependency: StorageClass (for potential PVCs)
# =============================================================================

resource "kubernetes_namespace" "ingress_nginx" {
  count = var.enable_ingress_nginx ? 1 : 0

  metadata {
    name = "ingress-nginx"
    labels = {
      "app.kubernetes.io/name" = "ingress-nginx"
    }
  }
}

resource "helm_release" "ingress_nginx" {
  count = var.enable_ingress_nginx ? 1 : 0

  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.ingress_nginx_version
  namespace  = kubernetes_namespace.ingress_nginx[0].metadata[0].name

  set {
    name  = "controller.service.type"
    value = "NodePort"
  }

  set {
    name  = "controller.service.nodePorts.https"
    value = "30443"
  }

  depends_on = [
    helm_release.local_path_provisioner
  ]
}
```

### Prometheus Monitoring (platform/monitoring.tf)

```hcl
# =============================================================================
# Prometheus Stack
# Dependency: StorageClass (for Prometheus PVCs)
# =============================================================================

resource "kubernetes_namespace" "monitoring" {
  count = var.enable_prometheus ? 1 : 0

  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "prometheus_stack" {
  count = var.enable_prometheus ? 1 : 0

  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.prometheus_stack_version
  namespace  = kubernetes_namespace.monitoring[0].metadata[0].name

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = "local-path"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "10Gi"
  }

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.local_path_provisioner
  ]
}
```

### GPU Operator (platform/gpu-operator.tf)

```hcl
# =============================================================================
# NVIDIA GPU Operator
# Dependency: Prometheus (for DCGM Exporter ServiceMonitor)
# =============================================================================

resource "kubernetes_namespace" "gpu_operator" {
  count = var.enable_gpu_operator ? 1 : 0

  metadata {
    name = "gpu-operator"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

resource "helm_release" "gpu_operator" {
  count = var.enable_gpu_operator ? 1 : 0

  name       = "gpu-operator"
  repository = "https://helm.ngc.nvidia.com/nvidia"
  chart      = "gpu-operator"
  version    = var.gpu_operator_version
  namespace  = kubernetes_namespace.gpu_operator[0].metadata[0].name

  wait    = true
  timeout = 900 # 15 minutes for driver installation

  set {
    name  = "driver.enabled"
    value = tostring(var.gpu_driver_enabled)
  }

  set {
    name  = "toolkit.enabled"
    value = "true"
  }

  set {
    name  = "dcgmExporter.enabled"
    value = "true"
  }

  set {
    name  = "nfd.enabled"
    value = "true"
  }

  depends_on = [
    kubernetes_namespace.gpu_operator,
    helm_release.prometheus_stack
  ]
}
```

### Run:AI (platform/runai.tf)

```hcl
# =============================================================================
# Run:AI Cluster
# Dependency: GPU Operator, Prometheus, Ingress (all must be ready)
# =============================================================================

resource "kubernetes_namespace" "runai" {
  count = var.enable_runai ? 1 : 0

  metadata {
    name = "runai"
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

# TLS Certificate
resource "tls_private_key" "runai" {
  count     = var.enable_runai && var.generate_self_signed_cert ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "runai" {
  count           = var.enable_runai && var.generate_self_signed_cert ? 1 : 0
  private_key_pem = tls_private_key.runai[0].private_key_pem

  subject {
    common_name  = var.runai_cluster_url
    organization = "Run:AI Cluster"
  }

  dns_names = [
    var.runai_cluster_url,
    "*.${var.runai_cluster_url}"
  ]

  ip_addresses = [local.control_plane_ip]

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]
}

resource "kubernetes_secret" "runai_tls" {
  count = var.enable_runai ? 1 : 0

  metadata {
    name      = "runai-cluster-domain-tls-secret"
    namespace = kubernetes_namespace.runai[0].metadata[0].name
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = var.generate_self_signed_cert ? tls_self_signed_cert.runai[0].cert_pem : var.runai_tls_cert
    "tls.key" = var.generate_self_signed_cert ? tls_private_key.runai[0].private_key_pem : var.runai_tls_key
  }
}

# Run:AI Cluster Helm Release
resource "helm_release" "runai_cluster" {
  count = var.enable_runai && var.runai_cluster_token != "" ? 1 : 0

  name       = "runai-cluster"
  repository = "https://runai.jfrog.io/artifactory/cp-charts-prod"
  chart      = "runai-cluster"
  version    = var.runai_version
  namespace  = kubernetes_namespace.runai[0].metadata[0].name

  wait    = true
  timeout = 600

  # Control plane connection
  set {
    name  = "controlPlane.url"
    value = var.runai_control_plane_url
  }

  set {
    name  = "cluster.uid"
    value = var.runai_cluster_uid
  }

  set_sensitive {
    name  = "cluster.token"
    value = var.runai_cluster_token
  }

  set {
    name  = "cluster.url"
    value = "https://${var.runai_cluster_url}"
  }

  # Disable bundled components (we deploy separately)
  set {
    name  = "gpu-operator.enabled"
    value = "false"
  }

  set {
    name  = "prometheus.install"
    value = "false"
  }

  # Use our Prometheus
  set {
    name  = "prometheus.prometheusServiceName"
    value = "prometheus-kube-prometheus-prometheus"
  }

  set {
    name  = "prometheus.prometheusServiceNamespace"
    value = "monitoring"
  }

  # Ingress
  set {
    name  = "ingress.enabled"
    value = "true"
  }

  set {
    name  = "ingress.tlsSecretName"
    value = kubernetes_secret.runai_tls[0].metadata[0].name
  }

  depends_on = [
    kubernetes_namespace.runai,
    kubernetes_secret.runai_tls,
    helm_release.gpu_operator,
    helm_release.prometheus_stack,
    helm_release.ingress_nginx
  ]
}
```

---

## Deployment Workflow

### Step 1: Deploy Infrastructure (Config 1)

```bash
cd infrastructure/

# Initialize
terraform init

# Plan
terraform plan -out=tfplan

# Apply - creates VMs, deploys Kubernetes
terraform apply tfplan

# Verify outputs
terraform output kubeconfig_host
terraform output -raw kubeconfig_raw | base64 -d > ~/.kube/config

# Test cluster
kubectl get nodes
```

### Step 2: Deploy Platform (Config 2)

```bash
cd platform/

# Initialize
terraform init

# Plan
terraform plan -out=tfplan

# Apply - deploys Run:AI stack
terraform apply tfplan

# Verify
kubectl get pods -n runai
kubectl get pods -n gpu-operator
kubectl get pods -n monitoring
```

---

## Dependency Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        DEPLOYMENT DEPENDENCY GRAPH                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  CONFIG 1: Infrastructure                                                    │
│  ─────────────────────────                                                   │
│                                                                              │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐                │
│  │   vSphere    │────▶│  Kubespray   │────▶│  Kubeconfig  │                │
│  │     VMs      │     │  Deployment  │     │    Output    │                │
│  └──────────────┘     └──────────────┘     └──────┬───────┘                │
│                                                    │                        │
│                                                    │ terraform_remote_state │
│                                                    ▼                        │
│  CONFIG 2: Platform                                                         │
│  ──────────────────                                                         │
│                                                                              │
│  ┌──────────────┐                                                           │
│  │ StorageClass │                                                           │
│  │ (local-path) │                                                           │
│  └──────┬───────┘                                                           │
│         │                                                                    │
│         ├─────────────────────┬─────────────────────┐                       │
│         ▼                     ▼                     ▼                       │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐                │
│  │   Ingress    │     │  Prometheus  │     │     ...      │                │
│  │   (NGINX)    │     │    Stack     │     │              │                │
│  └──────┬───────┘     └──────┬───────┘     └──────────────┘                │
│         │                    │                                              │
│         │                    ▼                                              │
│         │             ┌──────────────┐                                      │
│         │             │ GPU Operator │                                      │
│         │             │   (NVIDIA)   │                                      │
│         │             └──────┬───────┘                                      │
│         │                    │                                              │
│         └────────────────────┼──────────────────────┐                       │
│                              │                      │                       │
│                              ▼                      ▼                       │
│                       ┌─────────────────────────────────┐                   │
│                       │           Run:AI                │                   │
│                       │    (GPU Orchestration)          │                   │
│                       └─────────────────────────────────┘                   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## HCP Terraform Workspace Configuration

### Infrastructure Workspace

| Setting | Value |
|---------|-------|
| Name | `sandbox_vm-k8s-kubespray-runai` |
| Execution Mode | Remote |
| Working Directory | `infrastructure/` |
| VCS Branch | `001-vsphere-k8s-kubespray` |

### Platform Workspace

| Setting | Value |
|---------|-------|
| Name | `sandbox_vm-k8s-runai-platform` |
| Execution Mode | Remote |
| Working Directory | `platform/` |
| VCS Branch | `002-runai-deployment` |
| **Run Triggers** | `sandbox_vm-k8s-kubespray-runai` |

**Note**: Enable "Run Triggers" so Platform workspace automatically runs when Infrastructure completes.

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Remote state access denied | High | Configure workspace sharing in HCP TF |
| Kubeconfig fetch fails | High | Add retry logic, verify SSH works |
| No GPUs available | Medium | Set `enable_gpu_operator = false` |
| Run:AI token missing | Medium | Skip Run:AI until token provided |
| Helm chart timeout | Medium | Increase timeout values |

---

## Decision Points

### Decision 1: Run:AI Credentials
Obtain from Run:AI console before Config 2 deployment:
1. Log into https://app.run.ai
2. Clusters > +NEW CLUSTER
3. Copy `cluster.token` and `cluster.uid`

### Decision 2: GPU Availability
- If GPUs present: `enable_gpu_operator = true`
- If no GPUs: `enable_gpu_operator = false` (deploy Run:AI for scheduling only)

### Decision 3: Workspace Sharing
Configure HCP Terraform workspace sharing:
1. Infrastructure workspace: Settings > General > Remote state sharing
2. Add Platform workspace as consumer

---

## References

- [Run:AI v2.19 Documentation](https://docs.run.ai/v2.19/admin/runai-setup/cluster-setup/cluster-prerequisites/)
- [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html)
- [Terraform Remote State](https://developer.hashicorp.com/terraform/language/state/remote-state-data)
- [Terraform Helm Provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)

---

## Next Steps

1. **Reorganize repo** - Create `infrastructure/` and `platform/` directories
2. **Create HCP workspaces** - `sandbox_vm-k8s-runai-platform`
3. **Configure workspace sharing** - Enable remote state access
4. **Obtain Run:AI credentials** - Token + UID from console
5. **Deploy Config 1** - If not already done (K8s cluster exists)
6. **Deploy Config 2** - Run:AI platform stack
