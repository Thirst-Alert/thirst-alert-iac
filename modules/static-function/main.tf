data "google_project" "provider_project" {
  project_id = var.project
}

locals {
  project    = coalesce(var.project, data.google_project.provider_project.project_id)
  builds_dir = "${path.module}/builds"
  source_files = var.detached_deployment ? {
    "function.js" = <<EOT
      exports.router = (req, res) => {
        res.status(200).send('Managed by Terraform')
      }
    EOT
  } : var.source_files
  runtime = coalesce(var.runtime, "nodejs20")
}

data "archive_file" "function_archive" {
  type = "zip"

  output_path = "${local.builds_dir}/${var.name}-source.zip"

  dynamic "source" {
    for_each = local.source_files
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
  location      = var.region
  force_destroy = true
}

resource "google_storage_bucket_object" "function_object" {
  name   = "source-${data.archive_file.function_archive.output_base64sha256}.zip"
  bucket = google_storage_bucket.function_storage.name
  source = data.archive_file.function_archive.output_path
}

resource "random_id" "function_invoker_sa" {
  byte_length = 2
  prefix      = var.name
}

resource "google_service_account" "function_invoker" {
  project      = local.project
  account_id   = random_id.function_invoker_sa.hex
  display_name = "${var.name} function identity"
}

resource "google_cloudfunctions2_function" "function" {
  count = var.detached_deployment ? 0 : 1
  project     = local.project
  location    = var.region
  name        = var.name
  description = var.description

  build_config {
    runtime     = local.runtime
    entry_point = var.entry_point
    source {
      storage_source {
        bucket = google_storage_bucket.function_storage.name
        object = google_storage_bucket_object.function_object.name
      }
    }
  }

  service_config {
    max_instance_count    = var.max_instances
    available_memory      = var.available_memory
    timeout_seconds       = var.timeout
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
    ingress_settings              = var.ingress_settings
    vpc_connector                 = var.egress_connector
    vpc_connector_egress_settings = var.egress_connector_settings
  }

  dynamic "event_trigger" {
    for_each = var.event_trigger.event_type != null ? [1] : []

    content {
      event_type            = var.event_trigger.event_type
      trigger_region        = var.region
      pubsub_topic          = var.event_trigger.pubsub_topic
      service_account_email = google_service_account.function_invoker.email
      retry_policy          = var.event_trigger.retry_policy
      dynamic "event_filters" {
        for_each = var.event_trigger.event_filters != null ? var.event_trigger.event_filters : []
        content {
          attribute = event_filters.value.attribute
          value     = event_filters.value.value
          operator  = event_filters.value.operator
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [build_config[0].docker_repository]
  }
}

resource "google_cloudfunctions2_function" "function_detached" {
  count = var.detached_deployment ? 1 : 0
  project     = local.project
  location    = var.region
  name        = var.name
  description = var.description

  build_config {
    runtime     = local.runtime
    entry_point = var.entry_point
    source {
      storage_source {
        bucket = google_storage_bucket.function_storage.name
        object = google_storage_bucket_object.function_object.name
      }
    }
  }

  service_config {
    max_instance_count    = var.max_instances
    available_memory      = var.available_memory
    timeout_seconds       = var.timeout
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
    ingress_settings              = var.ingress_settings
    vpc_connector                 = var.egress_connector
    vpc_connector_egress_settings = var.egress_connector_settings
  }

  dynamic "event_trigger" {
    for_each = var.event_trigger.event_type != null ? [1] : []

    content {
      event_type            = var.event_trigger.event_type
      trigger_region        = var.region
      pubsub_topic          = var.event_trigger.pubsub_topic
      service_account_email = google_service_account.function_invoker.email
      retry_policy          = var.event_trigger.retry_policy
      dynamic "event_filters" {
        for_each = var.event_trigger.event_filters != null ? var.event_trigger.event_filters : []
        content {
          attribute = event_filters.value.attribute
          value     = event_filters.value.value
          operator  = event_filters.value.operator
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      build_config[0].docker_repository,
      build_config[0].source[0].storage_source[0].bucket,
      build_config[0].source[0].storage_source[0].object,
    ]
  }
}

locals {
  created_function = one(var.detached_deployment ? google_cloudfunctions2_function.function_detached : google_cloudfunctions2_function.function)
}

# WORKAROUND: https://github.com/hashicorp/terraform-provider-google/issues/15264
resource "google_cloud_run_service_iam_member" "function_invoker_permission" {
  location = local.created_function.location
  project  = local.created_function.project
  service  = local.created_function.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.function_invoker.email}"
}

# WORKAROUND: https://github.com/hashicorp/terraform-provider-google/issues/15264
resource "google_cloud_run_service_iam_member" "function_all_invoker" {
  count    = var.allow_unauthenticated_invocations ? 1 : 0
  location = local.created_function.location
  project  = local.created_function.project
  service  = local.created_function.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Only allow the service account to access the secrets if secrets have been provided
resource "google_secret_manager_secret_iam_member" "secret_accessor_permission" {
  count     = length(var.secret_environment_variables)
  project   = var.secret_environment_variables[count.index].project_id
  secret_id = var.secret_environment_variables[count.index].secret
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.function_invoker.email}"
}