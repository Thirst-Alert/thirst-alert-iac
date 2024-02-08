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
  mongo_secrets = module.secrets.mongodb_db_password
  be_secrets = module.secrets.be_secrets
}

module "static-function" {
  source = "./modules/static-function"

  name = "test-function"
  description = "A test function"
  project = "thirst-alert"
  region = "europe-west1"
  source_files = {
    for filename in fileset("func", "*") :
    filename => file("func/${filename}")
  }
  runtime = "python312"
  entry_point = "sendToSlack"
  enable_versioning = true
  keep_versions = 2
  environment_variables = {
    MONGO_URIA = "mongodb://localhost:27017"
  }
  secret_environment_variables = [
    {
      key = "TEST"
      project_id = "thirst-alert"
      secret = "github-pat"
      version = "latest"
    },
    {
      key = "MONGO_URI"
      project_id = "thirst-alert"
      secret = "mongodb_db_password"
      version = "latest"
    }
  ]
  allow_unauthenticated_invocations = true
}