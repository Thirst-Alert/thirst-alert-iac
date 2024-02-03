resource "google_container_cluster" "thirst_alert_dev_cluster" {
  name                     = "${var.project.project_id}-dev"
  deletion_protection = false
  location                 = "europe-west3"
  maintenance_policy {
    recurring_window {
      start_time = "2021-06-18T00:00:00Z"
      end_time   = "2050-01-01T04:00:00Z"
      recurrence = "FREQ=WEEKLY"
    }
  }
  enable_autopilot = true
  release_channel {
    channel = "REGULAR"
  }

  # notification_config {
  #   pubsub {
  #     enabled = true
  #     topic = google_pubsub_topic.gke_updates_topic.id
  #   }
  # }
}

module "gke_auth" {
  source               = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  project_id           = var.project.project_id
  cluster_name         = google_container_cluster.thirst_alert_dev_cluster.name
  location             = google_container_cluster.thirst_alert_dev_cluster.location
  use_private_endpoint = false
  depends_on           = [google_container_cluster.thirst_alert_dev_cluster]
}

provider "helm" {
  kubernetes {
    host                   = module.gke_auth.host
    cluster_ca_certificate = module.gke_auth.cluster_ca_certificate
    token                  = module.gke_auth.token
  }
}

resource "helm_release" "argocd" {
  name  = "argocd"

  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  version          = "5.53.12"
  create_namespace = true
}

# resource "helm_release" "argocd-apps" {
#   name  = "backend"

#   repository       = "https://argoproj.github.io/argo-helm"
#   chart            = "argocd-apps"
#   namespace        = "argocd"
#   version          = "1.6.0"

#   values = [
#     file("${path.module}/argocd/application.yaml")
#   ]

#   depends_on = [helm_release.argocd]
# }
