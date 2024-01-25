terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.13.0"
    }
  }
}

provider "google" {
  credentials = file("creds.json")

  project = "thirst-alert"
  region  = "europe-west3"
  zone    = "europe-west3-b"
}
