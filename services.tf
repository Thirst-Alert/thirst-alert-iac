resource "google_project_service" "apis" {
  count = length(local.apis)
  project = local.project.project_id
  service = local.apis[count.index]

  timeouts {
    create = "30m"
    update = "40m"
  }

  disable_dependent_services = true
}