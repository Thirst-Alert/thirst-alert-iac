terraform {
  required_providers {
    argocd = {
      source = "oboukili/argocd"
      version = "6.0.3"
    }
  }
}

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

provider "argocd" {
  core = true
}

resource "argocd_repository" "thirst_alert_iac_repo" {
  repo = "https://github.com/thirst-alert/thirst-alert-iac.git"
}

resource "argocd_project" "thirst_alert_argocd_project" {
  metadata {
    name = "thirst-alert"
    namespace = "argocd"
  }

  spec {
    description = "Thirst Alert IAC Project"
    source_namespaces = ["ta-*"]
    source_repos = [
      argocd_repository.thirst_alert_iac_repo.repo,
      "https://charts.bitnami.com/bitnami"
    ]
    destination {
      server = "https://kubernetes.default.svc"
      namespace = "ta-backend"
    }
    role {
      name = "admin"
      policies = [
        "p, proj:thirst-alert:admin, applications, override, thirst-alert/*, allow",
        "p, proj:thirst-alert:admin, applications, sync, thirst-alert/*, allow",
        "p, proj:thirst-alert:admin, clusters, get, thirst-alert/*, allow",
        "p, proj:thirst-alert:admin, repositories, create, thirst-alert/*, allow",
        "p, proj:thirst-alert:admin, repositories, delete, thirst-alert/*, allow",
        "p, proj:thirst-alert:admin, repositories, update, thirst-alert/*, allow",
        "p, proj:thirst-alert:admin, logs, get, thirst-alert/*, allow",
        "p, proj:thirst-alert:admin, exec, create, thirst-alert/*, allow",
      ]
    }

  }
}

resource "argocd_application" "backend" {
  metadata {
    name = "backend"
    namespace = "argocd"
  }
  spec {
    project = "thirst-alert"
    source {
      repo_url = argocd_repository.thirst_alert_iac_repo.repo
      path = "modules/gke/argocd/be"
      target_revision = "HEAD"
    }
    destination {
      server = "https://kubernetes.default.svc"
      namespace = "ta-backend"
    }
    sync_policy {
      automated {
        prune = true
        self_heal = true
      }
      sync_options = ["CreateNamespace=True"]
    }
  }
}

resource "argocd_application" "mongo" {
  metadata {
    name      = "mongo"
    namespace = "argocd"
  }

  spec {
    project = "thirst-alert"

    source {
      repo_url        = "https://charts.bitnami.com/bitnami"
      chart           = "mongodb"
      target_revision = "14.8.0"
      helm {
        value_files = ["$values/modules/gke/argocd/mongo/mongo-values.yaml"]
      }
    }

    source {
      repo_url        = argocd_repository.thirst_alert_iac_repo.repo
      target_revision = "HEAD"
      ref             = "values"
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "ta-backend"
    }
  }
}

