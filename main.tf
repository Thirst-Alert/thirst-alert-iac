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

module "mongo" {
  source = "./modules/mongo"

  project = local.project
	env = var.env
	mongodb_atlas_public_key = module.secrets.mongodb_atlas_public_key
	mongodb_atlas_private_key	= module.secrets.mongodb_atlas_private_key
	mongodb_atlas_org_id = module.secrets.mongodb_atlas_org_id
	mongodb_db_password = module.secrets.mongodb_db_password
}
