resource "google_artifact_registry_repository" "docker-repo" {
  location      = var.region
  repository_id = "docker"
  description   = "example docker repository"
  format        = "DOCKER"

  depends_on = [google_project_service.artifactregistry]
}


resource "google_compute_network" "internal_vpc" {
  name                    = "internal_vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.compute]
}

resource "google_compute_subnetwork" "internal_vpc_subnet" {
  name                     = "internal-vpc"
  ip_cidr_range            = "10.10.0.0/24"
  region                   = var.region
  network                  = google_compute_network.internal_vpc.id
  private_ip_google_access = true
}

resource "google_certificate_manager_dns_authorization" "servers" {
  name        = "dns-auth-servers"
  location    = "global"
  description = "The default dns"
  domain      = "servers.tada.com.au"

  depends_on = [google_project_service.certificatemanager]
}

resource "google_certificate_manager_certificate" "servers" {
  name        = "dns-cert-servers"
  description = "The default cert"
  scope       = "DEFAULT"

  managed {
    domains = [
      "servers.tada.com.au",
      "*.servers.tada.com.au"
    ]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.servers.id,
    ]
  }
}

resource "google_certificate_manager_certificate_map" "servers" {
  name        = "cert-map-servers"
  description = "Default certificate map"
}

output "google_certificate_manager_certificate_map" {
  value = google_certificate_manager_certificate_map.servers.id
}

resource "google_certificate_manager_certificate_map_entry" "servers_default" {
  name        = "cert-map-entry-servers-default"
  description = "Default certificate map entry"
  map         = google_certificate_manager_certificate_map.servers.name

  certificates = [google_certificate_manager_certificate.servers.id]
  hostname     = "servers.tada.com.au"
}

resource "google_certificate_manager_certificate_map_entry" "servers_wildcard" {
  name        = "cert-map-entry-servers-wildcard"
  description = "Default certificate map entry"
  map         = google_certificate_manager_certificate_map.servers.name

  certificates = [google_certificate_manager_certificate.servers.id]
  hostname     = "*.servers.tada.com.au"
}

output "record_name_to_insert_servers" {
  value = google_certificate_manager_dns_authorization.servers.dns_resource_record.0.name
}

output "record_type_to_insert_servers" {
  value = google_certificate_manager_dns_authorization.servers.dns_resource_record.0.type
}

output "record_data_to_insert_servers" {
  value = google_certificate_manager_dns_authorization.servers.dns_resource_record.0.data
}