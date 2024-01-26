resource "google_secret_manager_secret" "github_pat_secret" {
	project =  var.project.project_id
	secret_id = "github-pat"

	replication {
		auto {}
	}
}

data "google_secret_manager_secret_version" "github_pat_secret_version" {
  secret = "github-pat"
}

resource "google_secret_manager_secret" "mongodb_atlas_keys_secret" {
	project =  var.project.project_id
	secret_id = "mongodb-atlas-keys"

	replication {
		auto {}
	}
}

data "google_secret_manager_secret_version" "mongodb_atlas_keys_secret_version" {
  secret = "mongodb-atlas-keys"
}

resource "google_secret_manager_secret" "mongodb_atlas_org_id_secret" {
	project =  var.project.project_id
	secret_id = "mongodb-atlas-org-id"

	replication {
		auto {}
	}
}

data "google_secret_manager_secret_version" "mongodb_atlas_org_id_secret_version" {
  secret = google_secret_manager_secret.mongodb_atlas_org_id_secret.secret_id
}

resource "google_secret_manager_secret" "mongodb_db_password_secret" {
	project =  var.project.project_id
	secret_id = "mongodb_db_password"

	replication {
		auto {}
	}
}

data "google_secret_manager_secret_version" "mongodb_db_password_secret_version" {
  secret = google_secret_manager_secret.mongodb_db_password_secret.secret_id
}
