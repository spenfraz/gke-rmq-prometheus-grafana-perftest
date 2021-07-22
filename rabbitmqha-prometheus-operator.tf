
resource "null_resource" "create_monitoring_ns" {
  provisioner "local-exec" {
    command = "kubectl create namespace monitoring"
  }
  depends_on = [null_resource.configure_kubectl]
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY PROMETHEUS OPERATOR (prometheus-community/kube-prometheus-stack)
# ---------------------------------------------------------------------------------------------------------------------

resource "helm_release" "prometheus-operator" {
  depends_on = [null_resource.create_monitoring_ns]
  
  name       = "prometheus-operator"
  chart      = "./helm/kube-prometheus-stack"

  namespace  = "monitoring"

  set {
    name  = "coreDns.enabled"
    value = "false"
  }

  set {
    name  = "kubeDns.enabled"
    value = "true"
  }

  set {
    name  = "prometheus.prometheusSpec.ruleSelector.matchExpressions[0].key"
    value = "app"
  }

  set {
    name  = "prometheus.prometheusSpec.ruleSelector.matchExpressions[0].operator"
    value = "In"
  }

  set {
    name  = "prometheus.prometheusSpec.ruleSelector.matchExpressions[0].values[0]"
    value = "kube-prometheus-stack"
  }

  set {
    name  = "prometheus.prometheusSpec.ruleSelector.matchExpressions[0].values[1]"
    value = "rabbitmq-ha"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY HA RABBITMQ HELM CHART
# ---------------------------------------------------------------------------------------------------------------------

resource "helm_release" "rabbitmq" {
  depends_on = [helm_release.prometheus-operator]

  name       = "rmq-ha"
  chart      = "./helm/rabbitmq-ha"

  set {
    name  = "prometheus.operator.serviceMonitor.selector.release"
    value = "prometheus-operator"
  }

  set {
    name  = "rabbitmqPrometheusPlugin.enabled"
    value = "true"
  }

  set {
    name  = "prometheus.operator.enabled"
    value = "true"
  }

  set {
    name  = "replicaCount"
    value = "3"
  }
 
  set {
    name  = "rabbitmqUsername"
    value = "admin"
  }

  set {
    name  = "rabbitmqPassword"
    value = "secretpassword"
  }

  set {
    name  = "managementPassword"
    value = "anothersecretpassword"
  }

  set {
    name  = "rabbitmqErlangCookie"
    value = "secretcookie"
  }

  set {
    name  = "persistentVolume.enabled"
    value = "true"
  }

  set {
    name  = "persistentVolume.storageClass"
    value = "standard"
  }

#  set {
#    name  = "rabbitmq.existingPasswordSecret"
#    value = "my-release-rabbitmq"
#  }
}

resource "null_resource" "apply-dashboard-configmap" {
  depends_on = [helm_release.prometheus-operator]
  provisioner "local-exec" {
    command = "kubectl apply -f ./json-imported-dashboards-configmap.yaml"
  }
}
