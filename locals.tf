data "google_project" "project" {}

locals {
  project = data.google_project.project
  emails = [
    "massimiliano.ricci@code.berlin",
    "alsje.lourens@code.berlin"
  ]
  apis = [
    "secretmanager.googleapis.com",
    "artifactregistry.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudbuild.googleapis.com",
    "storage.googleapis.com"
  ]
  buckets = {
    "thirst-alert-public-assets" = {
      iam_members = [{
        role   = "roles/storage.objectViewer"
        member = "allUsers"
      }]
      versioning = true
    }
    "thirst-alert-sensor-images" = {
      iam_members = [
        {
          role   = "roles/storage.objectAdmin"
          member = google_service_account.url_signer.member
        }
      ]
      versioning = false
    }
  }
}
