variable "project_id" {
  description = "The ID of the GCP project"
  type        = string
}


variable "region" {
  description = "Region for resources"
  type        = string
}

variable "bucket_name" {
  description = "GCS bucket name"
  type        = string
}

variable "site_hosts" {
  description = "Map of site identifiers to their hostnames"
  type        = list(string)
}




