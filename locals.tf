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
    "cloudbuild.googleapis.com"
  ]
}
