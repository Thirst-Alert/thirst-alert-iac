terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.25.2"
    }
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
}

resource "google_compute_firewall" "backend_node_port" {
  name    = "backend-node-port"
  network = google_container_cluster.thirst_alert_dev_cluster.network

  allow {
    protocol = "tcp"
    ports    = ["30000"]
  }

  source_ranges = ["0.0.0.0/0"]
}

module "gke_auth" {
  source               = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  project_id           = var.project.project_id
  cluster_name         = google_container_cluster.thirst_alert_dev_cluster.name
  location             = google_container_cluster.thirst_alert_dev_cluster.location
  use_private_endpoint = false
  depends_on           = [google_container_cluster.thirst_alert_dev_cluster]
}

provider "kubernetes" {
  cluster_ca_certificate = module.gke_auth.cluster_ca_certificate
  host                   = module.gke_auth.host
  token                  = module.gke_auth.token
}

resource "kubernetes_namespace" "ta_backend_namespace" {
  metadata {
    name = "ta-backend"
  }
}

resource "kubernetes_secret" "mongo_secrets" {
  metadata {
    name = "mongo-auth"
    namespace = "ta-backend"
  }
  binary_data = jsondecode(var.mongo_secrets)
  depends_on = [ kubernetes_namespace.ta_backend_namespace ]
}

resource "kubernetes_secret" "be_secrets" {
  metadata {
    name = "be-secrets"
    namespace = "ta-backend"
  }
  data = jsondecode(var.be_secrets)
  depends_on = [ kubernetes_namespace.ta_backend_namespace ]
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
    source_namespaces = ["ta-backend"]
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

# resource "argocd_application" "backend" {
#   metadata {
#     name = "backend"
#     namespace = "argocd"
#   }pec {
#     project = "thirst-alert"
#     source {
#       repo_url = argocd_repository.thirst_alert_iac_repo.repo
#       path = "modules/gke/argocd/be"
#       target_revision = "HEAD"
#     }
#     destination {
#       server = "https://kubernetes.default.svc"
#       namespace = "ta-backend"
#     }
#     sync_policy {
#       automated {
#         prune = true
#         self_heal = true
#       }
#     }
#   }
#   depends_on = [ kubernetes_namespace.ta_backend_namespace, kubernetes_secret.be_secrets ]
# }

# resource "argocd_application" "mongo" {
#   metadata {
#     name      = "mongo"
#     namespace = "argocd"
#   }

#   spec {
#     project = "thirst-alert"

#     source {
#       repo_url        = "https://charts.bitnami.com/bitnami"
#       chart           = "mongodb"
#       target_revision = "14.8.0"
#       helm {
#         value_files = ["$values/modules/gke/argocd/mongo/mongo-values.yaml"]
#       }
#     }

#     source {
#       repo_url        = argocd_repository.thirst_alert_iac_repo.repo
#       target_revision = "HEAD"
#       ref             = "values"
#     }

#     destination {
#       server    = "https://kubernetes.default.svc"
#       namespace = "ta-backend"
#     }
#   }
#   depends_on = [ kubernetes_namespace.ta_backend_namespace, kubernetes_secret.mongo_secrets ]
# }
#   s

# resource "helm_release" "tmp" {
#   name  = "tmp"

#   repository       = "https://SimonMisencik.github.io/helm-charts"
#   chart            = "ubuntu"
#   namespace        = "ta-backend"
#   version          = "1.2.1"
# }

