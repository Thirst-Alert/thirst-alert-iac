terraform {
  backend "gcs" {
    bucket = "tfstate-bucket-266a1081137cf00d"
    prefix = "global-resources/"
  }
}

resource "google_storage_bucket" "tfstate_bucket" {
  name          = "tfstate-bucket-266a1081137cf00d"
  force_destroy = false
  location      = "EU"
  storage_class = "STANDARD"
  versioning {
    enabled = true
  }
}