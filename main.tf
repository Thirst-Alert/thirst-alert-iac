module "secrets" {
  source = "./modules/secrets"

  project    = local.project
}

module "iam" {
  source = "./modules/iam"

  project    = local.project
	github_pat_secret_id = module.secrets.github_pat_secret_id
}

module "cloudbuild" {
  source = "./modules/cloudbuild"

  project    = local.project
  depends_on = [module.iam]
}

module "gke" {
  source = "./modules/gke"

  project    = local.project
  env = "dev"
  cluster_name = "thirst-alert"
  mongo_secrets = module.secrets.mongodb_db_password
  be_secrets = module.secrets.be_secrets
  gitops_argocd_image_updater_key = module.secrets.gitops_argocd_image_updater_key
}

module "bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 5.0"

  name       = "thirst-alert-public-assets"
  project_id = local.project.project_id
  location   = "europe-west1"
  iam_members = [{
    role   = "roles/storage.objectViewer"
    member = "allUsers"
  }]
}

resource "google_storage_bucket_object" "cch_data_folders" {
  for_each = toset([
    "thirst-alert-sensor-repo/",
    "thirst-alert-assets/"
  ])
  name     = each.value
  bucket   = module.bucket.name
  content  = " "
}