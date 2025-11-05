terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0.0"
    }
  }
  required_version = ">= 1.12.0"
  backend "gcs" {
    bucket = "aviato-sandbox-477200-terraform"
    prefix = "aviato-sandbox"
  }
}

provider "google" {
  project = var.project_id
}