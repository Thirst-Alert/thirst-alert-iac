data "google_iam_policy" "serviceagent_secretAccessor" {
  binding {
    role    = "roles/secretmanager.secretAccessor"
    members = ["serviceAccount:service-${var.project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"]
  }
}

resource "google_secret_manager_secret_iam_policy" "secret_manager_policy" {
  project     = var.project.project_id
  secret_id   = var.github_pat_secret_id
  policy_data = data.google_iam_policy.serviceagent_secretAccessor.policy_data
}