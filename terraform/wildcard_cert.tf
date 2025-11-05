resource "google_certificate_manager_dns_authorization" "default" {
  name        = "dns-auth"
  location    = "global"
  description = "The default dns"
  domain      = "apps.tada.com.au"

  depends_on = [google_project_service.certificatemanager]
}

resource "google_certificate_manager_certificate" "default" {
  name        = "dns-cert"
  description = "The default cert"
  scope       = "DEFAULT"

  managed {
    domains = [
      "apps.tada.com.au",
      "*.apps.tada.com.au"
    ]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.default.id,
    ]
  }
}

resource "google_certificate_manager_certificate_map" "default" {
  name        = "cert-map"
  description = "Default certificate map"
}

output "google_certificate_manager_certificate_map" {
  value = google_certificate_manager_certificate_map.default.id
}

resource "google_certificate_manager_certificate_map_entry" "default" {
  name        = "cert-map-entry-default"
  description = "Default certificate map entry"
  map         = google_certificate_manager_certificate_map.default.name

  certificates = [google_certificate_manager_certificate.default.id]
  hostname     = "apps.tada.com.au"
}

resource "google_certificate_manager_certificate_map_entry" "wildcard" {
  name        = "cert-map-entry-wildcard"
  description = "Default certificate map entry"
  map         = google_certificate_manager_certificate_map.default.name

  certificates = [google_certificate_manager_certificate.default.id]
  hostname     = "*.apps.tada.com.au"
}


output "record_name_to_insert" {
  value = google_certificate_manager_dns_authorization.default.dns_resource_record.0.name
}

output "record_type_to_insert" {
  value = google_certificate_manager_dns_authorization.default.dns_resource_record.0.type
}

output "record_data_to_insert" {
  value = google_certificate_manager_dns_authorization.default.dns_resource_record.0.data
}