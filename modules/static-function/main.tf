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
  name        = var.name # use kebab-case!!!
  description = var.description

  build_config {
    runtime     = var.runtime
    entry_point = var.entry_point
    source {
      storage_source {
        bucket = google_storage_bucket.function_storage.name
        object = google_storage_bucket_object.function_object.name
      }
    }
  }

  service_config {
    max_instance_count = var.max_instances
    available_memory = var.available_memory
    timeout_seconds = var.timeout
    service_account_email = google_service_account.function_invoker.email
    environment_variables = var.environment_variables
    dynamic "secret_environment_variables" {
      for_each = var.secret_environment_variables
      content {
        key        = secret_environment_variables.value.key
        project_id = secret_environment_variables.value.project_id
        secret     = secret_environment_variables.value.secret
        version    = secret_environment_variables.value.version
      }
    }
    ingress_settings = var.ingress_settings
    vpc_connector                 = var.egress_connector
    vpc_connector_egress_settings = var.egress_connector_settings
  }

  dynamic "event_trigger" {
    for_each = var.event_trigger != null ? [1] : []

    content {
      event_type            = var.event_trigger.event_type
      trigger_region        = var.region
      pubsub_topic          = var.event_trigger.pubsub_topic
      service_account_email = google_service_account.function_invoker.email
      retry_policy          = var.event_trigger.retry_policy
      dynamic event_filters {
        for_each = var.event_trigger.event_filters != null ? var.event_trigger.event_filters : []
        content {
          attribute = event_filters.value.attribute
          value     = event_filters.value.value
          operator = event_filters.value.operator
        }
      }
    }
  }
}

# WORKAROUND: https://github.com/hashicorp/terraform-provider-google/issues/15264
resource "google_cloud_run_service_iam_member" "function_invoker_permission" {
  location = google_cloudfunctions2_function.function.location
  project        = google_cloudfunctions2_function.function.project
  service = google_cloudfunctions2_function.function.name
  role = "roles/run.invoker"
  member = "serviceAccount:${google_service_account.function_invoker.email}"
}

# WORKAROUND: https://github.com/hashicorp/terraform-provider-google/issues/15264
resource "google_cloud_run_service_iam_member" "function_all_invoker" {
  location = google_cloudfunctions2_function.function.location
  project        = google_cloudfunctions2_function.function.project
  service = google_cloudfunctions2_function.function.name
  role = "roles/run.invoker"
  member         = "allUsers"
}

# Only allow the service account to access the secrets if secrets have been provided
resource "google_secret_manager_secret_iam_member" "secret_accessor_permission" {
  count         = var.secret_environment_variables != null ? length(var.secret_environment_variables) : 0
  project = var.secret_environment_variables[count.index].project_id
  secret_id     = var.secret_environment_variables[count.index].secret
  role          = "roles/secretmanager.secretAccessor"
  member        = "serviceAccount:${google_service_account.function_invoker.email}"
}
