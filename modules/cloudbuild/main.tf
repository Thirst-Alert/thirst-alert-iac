resource "google_cloudbuildv2_connection" "cloudbuild_repo_connection" {
	project = var.project.project_id
  location = "europe-west3"
  name = "repo-connection"

  github_config {
    app_installation_id = 46510807
    authorizer_credential {
      oauth_token_secret_version = "projects/${var.project.project_id}/secrets/github-pat/versions/latest"
    }
  }
}

resource "google_cloudbuildv2_repository" "thirst_alert_be" {
  name = "thirst-alert-be"
  parent_connection = google_cloudbuildv2_connection.cloudbuild_repo_connection.id
  remote_uri = "https://github.com/Thirst-Alert/thirst-alert-be.git"
}

resource "google_cloudbuild_trigger" "backend-trigger" {
	name = "thirst-alert-be"
	description = "Trigger for thirst-alert backend build"
  location = "europe-west3"
	disabled = true

  repository_event_config {
    repository = google_cloudbuildv2_repository.thirst_alert_be.id
    push {
      tag = ".*"
    }
  }

  filename = "cloudbuild.yaml"
}