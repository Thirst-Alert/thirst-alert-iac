terraform {

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.12"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
  }
}
