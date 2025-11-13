resource "google_certificate_manager_certificate_map" "default" {
  name        = "cert-map"
  description = "Default certificate map"
}

resource "google_certificate_manager_dns_authorization" "sandbox_hapana_dev" {
  name        = "dns-auth-sandbox-hapana"
  location    = "global"
  description = "DNS Authorization for sandbox.hapana-dev.com"
  domain      = "sandbox.hapana-dev.com"

  depends_on = [google_project_service.certificatemanager]
}

resource "google_certificate_manager_certificate" "sandbox_hapana_dev" {
  name        = "dns-cert-hapana-dev"
  description = "Wilcard DNS cert for hapana-dev.com"
  scope       = "DEFAULT"

  managed {
    domains = [
      "sandbox.hapana-dev.com",
      "*.sandbox.hapana-dev.com"
    ]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.sandbox_hapana_dev.id,
    ]
  }
}

# resource "google_certificate_manager_dns_authorization" "default" {
#   name        = "dns-auth"
#   location    = "global"
#   description = "The default dns"
#   domain      = "apps.tada.com.au"

#   depends_on = [google_project_service.certificatemanager]
# }

# resource "google_certificate_manager_certificate" "default" {
#   name        = "dns-cert"
#   description = "The default cert"
#   scope       = "DEFAULT"

#   managed {
#     domains = [
#       "apps.tada.com.au",
#       "*.apps.tada.com.au"
#     ]
#     dns_authorizations = [
#       google_certificate_manager_dns_authorization.default.id,
#     ]
#   }
# }

# resource "google_certificate_manager_certificate_map_entry" "default" {
#   name        = "cert-map-entry-default"
#   description = "Default certificate map entry"
#   map         = google_certificate_manager_certificate_map.default.name

#   certificates = [google_certificate_manager_certificate.default.id]
#   hostname     = "apps.tada.com.au"
# }

# resource "google_certificate_manager_certificate_map_entry" "wildcard" {
#   name        = "cert-map-entry-wildcard"
#   description = "Default certificate map entry"
#   map         = google_certificate_manager_certificate_map.default.name

#   certificates = [google_certificate_manager_certificate.default.id]
#   hostname     = "*.apps.tada.com.au"
# }

resource "google_certificate_manager_certificate_map_entry" "sandbox_hapana_dev" {
  name        = "cert-map-entry-sandbox-hapana-dev"
  description = "Certificate map entry for sandbox.hapana-dev.com"
  map         = google_certificate_manager_certificate_map.default.name

  certificates = [google_certificate_manager_certificate.sandbox_hapana_dev.id]
  hostname     = "sandbox.hapana-dev.com"
}

resource "google_certificate_manager_certificate_map_entry" "sandbox_hapana_dev_wildcard" {
  name        = "cert-map-entry-sandbox-hapana-dev-wildcard"
  description = "Certificate map entry for *.sandbox.hapana-dev.com"
  map         = google_certificate_manager_certificate_map.default.name

  certificates = [google_certificate_manager_certificate.sandbox_hapana_dev.id]
  hostname     = "*.sandbox.hapana-dev.com"
}


# output "record_name_to_insert" {
#   value = google_certificate_manager_dns_authorization.default.dns_resource_record.0.name
# }

# output "record_type_to_insert" {
#   value = google_certificate_manager_dns_authorization.default.dns_resource_record.0.type
# }

# output "record_data_to_insert" {
#   value = google_certificate_manager_dns_authorization.default.dns_resource_record.0.data
# }

output "record_name_to_insert_hapana" {
  value = google_certificate_manager_dns_authorization.sandbox_hapana_dev.dns_resource_record.0.name
}

output "record_type_to_insert_hapana" {
  value = google_certificate_manager_dns_authorization.sandbox_hapana_dev.dns_resource_record.0.type
}

output "record_data_to_insert_hapana" {
  value = google_certificate_manager_dns_authorization.sandbox_hapana_dev.dns_resource_record.0.data
}

# resource "google_certificate_manager_dns_authorization" "servers" {
#   name        = "dns-auth-servers"
#   location    = "global"
#   description = "The default dns"
#   domain      = "servers.tada.com.au"

#   depends_on = [google_project_service.certificatemanager]
# }

# resource "google_certificate_manager_certificate" "servers" {
#   name        = "dns-cert-servers"
#   description = "The default cert"
#   scope       = "DEFAULT"

#   managed {
#     domains = [
#       "servers.tada.com.au",
#       "*.servers.tada.com.au"
#     ]
#     dns_authorizations = [
#       google_certificate_manager_dns_authorization.servers.id,
#     ]
#   }
# }

# resource "google_certificate_manager_certificate_map" "servers" {
#   name        = "cert-map-servers"
#   description = "Default certificate map"
# }

# resource "google_certificate_manager_certificate_map_entry" "servers_default" {
#   name        = "cert-map-entry-servers-default"
#   description = "Default certificate map entry"
#   map         = google_certificate_manager_certificate_map.default.name

#   certificates = [google_certificate_manager_certificate.servers.id]
#   hostname     = "servers.tada.com.au"
# }

# resource "google_certificate_manager_certificate_map_entry" "servers_wildcard" {
#   name        = "cert-map-entry-servers-wildcard"
#   description = "Default certificate map entry"
#   map         = google_certificate_manager_certificate_map.default.name

#   certificates = [google_certificate_manager_certificate.servers.id]
#   hostname     = "*.servers.tada.com.au"
# }

# output "record_name_to_insert_servers" {
#   value = google_certificate_manager_dns_authorization.servers.dns_resource_record.0.name
# }

# output "record_type_to_insert_servers" {
#   value = google_certificate_manager_dns_authorization.servers.dns_resource_record.0.type
# }

# output "record_data_to_insert_servers" {
#   value = google_certificate_manager_dns_authorization.servers.dns_resource_record.0.data
# }
