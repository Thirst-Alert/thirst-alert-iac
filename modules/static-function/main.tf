data "google_project" "provider_project" {
  project_id = var.project
}

locals {
  project   = coalesce(var.project, data.google_project.provider_project.project_id)
  builds_dir = "${path.module}/builds"
}

data "archive_file" "function_archive" {
  type = "zip"

  output_path = "${local.builds_dir}/${var.name}-source.zip"

  dynamic "source" {
    for_each = var.source_files
    content {
      filename = source.key
      content  = source.value
    }
  }
}

resource "random_id" "source_bucket_name" {
  byte_length = 4
  prefix      = "${var.name}-function-source-"
}

resource "google_storage_bucket" "function_storage" {
  project = local.project
  name    = random_id.source_bucket_name.hex
  versioning {
    enabled = var.enable_versioning
  }
  dynamic "lifecycle_rule" {
    for_each = var.enable_versioning == true ? [1] : []
    content {
      condition {
        age                = 1
        with_state         = "ANY"
        num_newer_versions = var.keep_versions
      }

      action {
        type = "Delete"
      }
    }
  }
  location = var.region
}

resource "google_storage_bucket_object" "function_object" {
  name   = "source-${data.archive_file.function_archive.output_base64sha256}.zip"
  bucket = google_storage_bucket.function_storage.name
  source = data.archive_file.function_archive.output_path
}

resource "random_id" "function_invoker_sa" {
  byte_length = 2
  prefix      = "${var.name}-sa-"
}

resource "google_service_account" "function_invoker" {
  project      = local.project
  account_id   = random_id.function_invoker_sa.hex
  display_name = "${var.name} function identity"
}

resource "google_cloudfunctions2_function" "function" {
  project = local.project
  location  = var.region
  name        = var.name
  description = var.description

  build_config {
    runtime     = var.runtime
    entry_point = var.entry_point
    environment_variables = var.environment_variables
    source {
      storage_source {
        bucket = google_storage_bucket.function_storage.name
        object = google_storage_bucket_object.function_object.name
      }
    }
  }

  service_config {
    max_instance_count = var.max_instances
    available_memory = var.available_memory_mb
    timeout_seconds = var.timeout
    service_account_email = google_service_account.function_invoker.email
  }

  

  trigger_http = var.trigger_http

  dynamic "event_trigger" {
    for_each = var.event_trigger.event_type == null ? [] : [1]

    content {
      event_type = var.event_trigger.event_type
      resource   = var.event_trigger.resource

      failure_policy {
        retry = var.event_trigger.retry_on_failure == null ? false : var.event_trigger.retry_on_failure
      }
    }
  }

  ingress_settings = var.ingress_settings

  vpc_connector                 = var.egress_connector
  vpc_connector_egress_settings = var.egress_connector_settings
}

# Allow the service account to invoke the function.
resource "google_cloudfunctions_function_iam_member" "function_invoker_permission" {
  project        = google_cloudfunctions_function.function.project
  region         = google_cloudfunctions_function.function.region
  cloud_function = google_cloudfunctions_function.function.name

  role   = "roles/cloudfunctions.invoker"
  member = "serviceAccount:${google_service_account.function_invoker.email}"
}

# Conditionally allow everyone to invoke the function
resource "google_cloudfunctions_function_iam_member" "function_all_invoker" {
  count          = var.allow_unauthenticated_invocations ? 1 : 0
  project        = google_cloudfunctions_function.function.project
  region         = google_cloudfunctions_function.function.region
  cloud_function = google_cloudfunctions_function.function.name
  role           = "roles/cloudfunctions.invoker"
  member         = "allUsers"
}
