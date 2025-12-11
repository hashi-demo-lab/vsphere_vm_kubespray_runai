# Monitoring Configuration
# Feature: Run:AI Platform Deployment
# Spec: /workspace/specs/002-runai-deployment/plan.md
# Dependency: StorageClass (for Prometheus PVCs)

# =============================================================================
# Prometheus Stack (kube-prometheus-stack)
# Requirement: Run:AI requires Prometheus for metrics collection
# =============================================================================

resource "kubernetes_namespace" "monitoring" {
  count = var.enable_prometheus ? 1 : 0

  metadata {
    name = "monitoring"

    labels = {
      "app.kubernetes.io/name" = "monitoring"
    }
  }
}

resource "helm_release" "prometheus_stack" {
  count = var.enable_prometheus ? 1 : 0

  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.prometheus_stack_version
  namespace  = kubernetes_namespace.monitoring[0].metadata[0].name

  # Wait for deployment
  wait    = true
  timeout = 600

  # Grafana configuration
  set {
    name  = "grafana.enabled"
    value = "true"
  }

  set {
    name  = "grafana.adminPassword"
    value = "admin" # Change in production
  }

  # Alertmanager configuration
  set {
    name  = "alertmanager.enabled"
    value = "true"
  }

  # Configure Prometheus to scrape all ServiceMonitors
  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  set {
    name  = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  # Storage configuration for Prometheus
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = "local-path"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]"
    value = "ReadWriteOnce"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "10Gi"
  }

  # Resource requests for Prometheus
  set {
    name  = "prometheus.prometheusSpec.resources.requests.cpu"
    value = "200m"
  }

  set {
    name  = "prometheus.prometheusSpec.resources.requests.memory"
    value = "512Mi"
  }

  # Retention
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "7d"
  }

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.local_path_provisioner
  ]
}
