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



# -----------------------------
# 2️⃣  Global IP Address
# -----------------------------
resource "google_compute_global_address" "xlb_ip" {
  name       = "xlb-ip"
  depends_on = [google_project_service.compute]
}


resource "google_compute_region_network_endpoint_group" "apigee_psc_neg" {
  name                  = "apigee-psc-neg"
  network_endpoint_type = "PRIVATE_SERVICE_CONNECT"
  region                = var.region
  network               = google_compute_network.apigee_vpc.self_link
  subnetwork            = google_compute_subnetwork.apigee_vpc_apigee_subnet.self_link
  psc_target_service    = google_apigee_instance.apigee_instance.service_attachment
}


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
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.gateway_neg.id
  }
  enable_cdn = false
}

resource "google_compute_backend_service" "api_backend" {
  name                  = "api-backend"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"
  timeout_sec           = 300
  backend {
    group = google_compute_region_network_endpoint_group.apigee_psc_neg.id
  }

  custom_request_headers = [
    # This entry overrides the client's Accept-Encoding header 
    # to *only* allow 'gzip and defalate' to be sent to the backend.
    # Apigee doesn't support 'br' encoding
    "Accept-Encoding: gzip, deflate",
  ]
}

# --- URL Map ---
resource "google_compute_url_map" "xlb_map" {
  name            = "xlb-url-map"
  default_service = google_compute_backend_service.gateway_backend.id

  host_rule {
    hosts        = ["gateway.servers.tada.com.au"]
    path_matcher = "gateway-matcher"
  }

  path_matcher {
    name            = "gateway-matcher"
    default_service = google_compute_backend_service.gateway_backend.id
  }

  host_rule {
    hosts        = [
      "api.servers.tada.com.au",
      "api-dev.servers.tada.com.au",
      "api.sandbox.hapana-dev.com",
      "api.sandbox.hapana.com"
      ]
    path_matcher = "api-matcher"
  }

  path_matcher {
    name            = "api-matcher"
    default_service = google_compute_backend_service.api_backend.id
  }
}

# --- Target HTTPS Proxy ---
resource "google_compute_target_https_proxy" "xlb_https_proxy" {
  name            = "xlb-https-proxy"
  url_map         = google_compute_url_map.xlb_map.id
  certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.default.id}"

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