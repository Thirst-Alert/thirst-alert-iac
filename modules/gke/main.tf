resource "google_pubsub_topic" "gke_updates_topic" {
  name = "gke-updates"
}

resource "google_project_service" "tmp" {
  project = "thirst-alert"
  service = "cloudfunctions.googleapis.com"

  disable_dependent_services = true
}

resource "google_project_service" "tmp2" {
  project = "thirst-alert"
  service = "eventarc.googleapis.com"

  disable_dependent_services = true
}

resource "google_project_service" "tmp3" {
  project = "thirst-alert"
  service = "run.googleapis.com"

  disable_dependent_services = true
}

resource "google_secret_manager_secret" "func_secret" {
	project =  var.project.project_id
	secret_id = "func-secret"

	replication {
		auto {}
	}
}

data "google_secret_manager_secret_version" "func_secret_version" {
  secret = "func-secret"
}

resource "google_storage_bucket" "tmp_bucket" {
  name                        = "thirst-alert-tmp-bucket"
  location                    = "EU"
  uniform_bucket_level_access = true
}

data "archive_file" "source_zip" {
  type        = "zip"
  output_path = "/tmp/function-source.zip"
  source_dir  = "${path.module}/func"
}

resource "google_storage_bucket_object" "source_in_bucket" {
  name   = "function-source.zip"
  bucket = google_storage_bucket.tmp_bucket.name
  source = data.archive_file.source_zip.output_path
}

resource "google_cloudfunctions2_function" "default" {
  name        = "function"
  location    = "europe-west3"
  description = "a new function"

  build_config {
    runtime     = "python312"
    entry_point = "sendTo" # Set the entry point
    source {
      storage_source {
        bucket = google_storage_bucket.tmp_bucket.name
        object = google_storage_bucket_object.source_in_bucket.name
      }
    }
  }

  service_config {
    max_instance_count = 3
    min_instance_count = 1
    available_memory   = "256M"
    timeout_seconds    = 60
    secret_environment_variables {
      key        = "SLACK_WEBHOOK"
      project_id = var.project.project_id
      secret     = google_secret_manager_secret.func_secret.secret_id
      version    = "latest"
    }
    ingress_settings               = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email = "tf-sa-480@thirst-alert.iam.gserviceaccount.com"
  }

  event_trigger {
    trigger_region = "europe-west3"
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.gke_updates_topic.id
    retry_policy   = "RETRY_POLICY_RETRY"
  }
}

############

resource "google_container_cluster" "thirst_alert_dev_cluster" {
  name                     = "${var.project.project_id}-dev"
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

  notification_config {
    pubsub {
      enabled = true
      topic = google_pubsub_topic.gke_updates_topic.id
    }
  }
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

resource "helm_release" "argocd-apps" {
  name  = "argocd-apps"

  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-apps"
  namespace        = "argocd"
  version          = "1.6.0"

  values = [
    file("${path.module}/argocd/application.yaml")
  ]

  depends_on = [helm_release.argocd]
}
