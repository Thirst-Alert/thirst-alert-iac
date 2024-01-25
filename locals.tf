data "google_project" "project" {}

locals {
  project = data.google_project.project
  emails = [
    "massimiliano.ricci@code.berlin",
    "alsje.lourens@code.berlin"
  ]
}