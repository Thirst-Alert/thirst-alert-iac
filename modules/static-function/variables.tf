variable "name" {
  description = <<-EOT
		The name of the function. Please use kebab-case (e.g. my-function-name)! There's
		currently no support by the google_cloudfunctions2_function_iam_policy resource for
		the role needed by service accounts to actually invoke the function, so a workaround
		had to be used.
	EOT
  type        = string
}

variable "description" {
  description = "A description of what the function does."
  type        = string
}

variable "project" {
  description = "Project to create resources in. Defaults to provider project."
  type        = string
  default     = null
}

variable "region" {
  description = "Region to create resources in. Defaults to europe-west3."
  type        = string
  default     = "europe-west3"
}

variable "runtime" {
  description = <<-EOT
    The runtime of this function. Available values can be found here:
    https://cloud.google.com/functions/docs/runtime-support
  EOT
  type        = string
  default = null
}

variable "source_files" {
  description = "The source files for this function, in the form of file_name => file_content."
  type        = map(any)
  default = null
}

variable "entry_point" {
  description = "Entrypoint to script."
  type        = string
  default     = "main"
}

variable "enable_versioning" {
  description = <<-EOT
    The bucket's versioning configuration.
    While set to true, versioning is fully enabled for the bucket.
  EOT
  type        = bool
  default     = true
}

variable "keep_versions" {
  description = <<-EOT
    The number of file versions to keep if enable_versioning is set to true.
    Default: 1
  EOT
  type        = number
  default     = 1
}

variable "event_trigger" {
  description = "Specify an event trigger for the function."
  type = object({
    event_type   = string
    pubsub_topic = optional(string)
    retry_policy = optional(string)
    event_filters = optional(list(object({
      attribute = string
      value     = string
      operator  = optional(string)
    })))
  })
  default = {
    event_type = null
  }
}

variable "ingress_settings" {
  description = <<-EOT
    Where to allow ingress traffic from, see:
    [Ingress settings](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudfunctions_function#ingress_settings)
  EOT
  type        = string
  default     = "ALLOW_ALL"
}

variable "egress_connector" {
  type        = string
  description = <<-EOT
    The VPC Connector that egress traffic is routed through. See:
    [VPC Connector](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudfunctions_function#vpc_connector)
EOT
  default     = ""
}

variable "egress_connector_settings" {
  type        = string
  description = <<-EOT
    Which egress traffic should be routed through the VPC connector. See:
    [Egress settings](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudfunctions_function#vpc_connector_egress_settings)
  EOT
  default     = null
}

variable "allow_unauthenticated_invocations" {
  description = "Whether this function can be invoked by unauthenticated users."
  type        = bool
  default     = false
}

variable "timeout" {
  description = <<-EOT
    Maximum time, in seconds, that a script can take to execute. Invocations
    which take longer than this fail.
  EOT
  type        = number
  default     = 120
}

variable "available_memory" {
  description = "Maximum memory available to the script in MiB."
  type        = string
  default     = "256M"
}

variable "max_instances" {
  # This is the recommended default(!)
  # https://cloud.google.com/functions/docs/configuring/max-instances
  description = <<-EOI
    The maximum number of instances that may be run at any one time.
    Default: 3000
  EOI
  type        = number
  default     = 3000
}

variable "environment_variables" {
  description = "Map of environment variables to pass to the function."
  type        = map(string)
  default     = {}
}

variable "secret_environment_variables" {
  description = "Map of secret environment variables to pass to the function."
  type        = list(map(any))
  default     = []
}

variable "detached_deployment" {
  description = "Manage function's source files manually, detaching the bucket content lifecycle from Terraform."
  type = bool
  default = false
}