terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.25.2"
    }
    kubectl = {
      source = "alekc/kubectl"
      version = "2.0.4"
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.12.0"
    }
    argocd = {
      source = "oboukili/argocd"
      version = "6.0.3"
    }
  }
}

module "gke_auth" {
  source = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  version = "30.0.0"
  depends_on   = [ module.gke ]
  project_id   = var.project.project_id
  location     = module.gke.location
  cluster_name = module.gke.name
}

module "gcp-network" {
  source       = "terraform-google-modules/network/google"
  version      = "9.0.0"
  project_id   = var.project.project_id
  network_name = "${var.network}-${var.env}"

  subnets = [
    {
      subnet_name   = "${var.subnetwork}-${var.env}"
      subnet_ip     = "10.10.0.0/16"
      subnet_region = var.region
    },
  ]

  secondary_ranges = {
    "${var.subnetwork}-${var.env}" = [
      {
        range_name    = var.ip_range_pods_name
        ip_cidr_range = "10.20.0.0/16"
      },
      {
        range_name    = var.ip_range_services_name
        ip_cidr_range = "10.30.0.0/16"
      },
    ]
  }
}

data "google_client_config" "default" {}

module "gke" {
  source                 = "terraform-google-modules/kubernetes-engine/google//modules/private-cluster"
  version                = "30.0.0"
  project_id             = var.project.project_id
  name                   = "${var.cluster_name}-${var.env}"
  regional               = true
  region                 = var.region
  network                = module.gcp-network.network_name
  subnetwork             = module.gcp-network.subnets_names[0]
  ip_range_pods          = var.ip_range_pods_name
  ip_range_services      = var.ip_range_services_name
  deletion_protection    = false
  
  node_pools = [
    {
      name                      = "node-pool"
      machine_type              = "e2-medium"
      min_count                 = 1
      max_count                 = 10
      disk_size_gb              = 50
    }
  ]
}

resource "google_project_iam_member" "allow_images_pull" {
  project = var.project.project_id
  role   = "roles/artifactregistry.reader"
  member = "serviceAccount:${module.gke.service_account}"
}

provider "kubernetes" {
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

provider "kubectl" {
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

# NAMESPACES

resource "kubernetes_namespace" "ta_backend_namespace" {
  metadata {
    name = "ta-backend"
  }
}

resource "kubernetes_namespace" "argocd_namespace" {
  metadata {
    name = "argocd"
  }
}

resource "kubernetes_namespace" "dnsconfig_namespace" {
  metadata {
    name = "dnsconfig"
  }
}

# SECRETS

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

# INGRESSES

resource "kubernetes_ingress_v1" "argocd_ingress" {
  metadata {
    name = "argocd-server-ingress"
    namespace = "argocd"
    annotations = {
      "nginx.ingress.kubernetes.io/force-ssl-redirect" = "false"
      "nginx.ingress.kubernetes.io/backend-protocol" = "HTTP"
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts = ["argocd.thirst-alert.com"]
      secret_name = "argocd-secret"
    }
    rule {
      host = "argocd.thirst-alert.com"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port {
                number = 443
              }
            }
          }
        }
      }
    }
  }
  depends_on = [ kubernetes_namespace.argocd_namespace ]
}

# CERT MANAGER

module "cert-manager" {
  source  = "terraform-iaac/cert-manager/kubernetes"
  version = "2.6.2"
  cluster_issuer_email = "massimiliano.ricci@code.berlin"
  chart_version = "1.14.0"
  namespace_name = "dnsconfig"
  create_namespace = false
  depends_on = [ kubernetes_namespace.dnsconfig_namespace ]
}

# HELM RELEASES

provider "helm" {
  kubernetes {
    host                   = module.gke_auth.host
    cluster_ca_certificate = module.gke_auth.cluster_ca_certificate
    token                  = module.gke_auth.token
  }
}

resource "helm_release" "ingress-nginx" {
  name  = "ingress-nginx"

  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "dnsconfig"
  version          = "4.9.1"
}

resource "helm_release" "argocd" {
  name  = "argocd"

  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  version          = "5.53.12"
}

# ARGOCD

provider "argocd" {
  core = true
}

resource "argocd_repository" "thirst_alert_iac_repo" {
  repo = "https://github.com/thirst-alert/thirst-alert-iac.git"
  depends_on = [ kubernetes_namespace.argocd_namespace, helm_release.argocd ]
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
  depends_on = [ kubernetes_namespace.argocd_namespace, helm_release.argocd ]
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
    }
  }
  depends_on = [ kubernetes_namespace.ta_backend_namespace, kubernetes_secret.be_secrets, argocd_application.mongo ]
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
  depends_on = [ kubernetes_namespace.ta_backend_namespace, kubernetes_secret.mongo_secrets ]
}


# resource "helm_release" "tmp" {
#   name  = "tmp"

#   repository       = "https://SimonMisencik.github.io/helm-charts"
#   chart            = "ubuntu"
#   namespace        = "ta-backend"
#   version          = "1.2.1"
# }

