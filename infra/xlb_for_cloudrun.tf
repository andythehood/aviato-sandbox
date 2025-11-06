resource "google_artifact_registry_repository" "docker-repo" {
  location      = var.region
  repository_id = "docker"
  description   = "example docker repository"
  format        = "DOCKER"

  depends_on = [google_project_service.artifactregistry]
}


resource "google_compute_network" "internal_vpc" {
  name                    = "internal-vpc"
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


# -----------------------------
# 2️⃣  Global IP Address
# -----------------------------
resource "google_compute_global_address" "xlb_ip" {
  name       = "xlb-ip"
  depends_on = [google_project_service.compute]
}



# # --- Existing Cloud Run backend service ---
# data "google_cloud_run_service" "gateway_service" {
#   name     = "gateway"
#   location = var.region
# }


resource "google_compute_region_network_endpoint_group" "gateway_neg" {
  name                  = "gateway-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = "gateway"
  }
}



resource "google_compute_backend_service" "gateway_backend" {
  name                  = "gateway-backend"
  protocol              = "HTTP"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.gateway_neg.id
  }
  enable_cdn = false
}

# --- URL Map ---
resource "google_compute_url_map" "xlb_map" {
  name            = "xlb-url-map"
  default_service = google_compute_backend_service.gateway_backend.id
}

# --- Target HTTPS Proxy ---
resource "google_compute_target_https_proxy" "xlb_https_proxy" {
  name            = "xlb-https-proxy"
  url_map         = google_compute_url_map.xlb_map.id
  certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.servers.id}"

}

# --- Global Forwarding Rule ---
resource "google_compute_global_forwarding_rule" "xlb_forwarding_rule" {
  name                  = "xlb-forwarding-rule"
  target                = google_compute_target_https_proxy.xlb_https_proxy.id
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.xlb_ip.address
  ip_protocol           = "TCP"
}