terraform {
  required_providers {
		mongodbatlas = {
			source  = "mongodb/mongodbatlas"
			version = "1.14.0"
		}
  }
} # non hashicorp provider, have to define it here :(

provider "mongodbatlas" {
  public_key = var.mongodb_atlas_public_key
  private_key  = var.mongodb_atlas_private_key
}

resource "mongodbatlas_project" "mongodb_atlas_project" {
  org_id = var.mongodb_atlas_org_id
  name = "${var.project.project_id}-${var.env}"
}

resource "mongodbatlas_database_user" "mongodb_atlas_db_user" {
  username = "${var.project.project_id}-${var.env}"
  password = var.mongodb_db_password
  project_id = mongodbatlas_project.mongodb_atlas_project.id
  auth_database_name = "admin"
  roles {
    role_name     = "readWrite"
    database_name = "${var.project.project_id}-${var.env}"
  }
}

resource "mongodbatlas_advanced_cluster" "atlas-cluster" {
  project_id = mongodbatlas_project.mongodb_atlas_project.id
  name = "${var.project.project_id}-${var.env}"
	cluster_type = "REPLICASET"
	replication_specs {
		region_configs {
			electable_specs {
				instance_size = "M0"
			}
			provider_name = "TENANT"
			backing_provider_name = "GCP"
			priority      = 7
			region_name   = "WESTERN_EUROPE"
		}
	}
}