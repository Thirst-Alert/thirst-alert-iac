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

resource "google_secret_manager_secret" "be_secrets" {
	project =  var.project.project_id
	secret_id = "be_secrets"

	replication {
		auto {}
	}
}

data "google_secret_manager_secret_version" "be_secrets_secret_version" {
  secret = google_secret_manager_secret.be_secrets.secret_id
}