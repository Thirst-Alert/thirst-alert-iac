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