# -----------------------------
# 1️⃣  Static Website Bucket
# -----------------------------
resource "google_storage_bucket" "static_site" {
  name                        = var.bucket_name
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = true
  website {
    main_page_suffix = "index.html"
    not_found_page   = "index.html"
  }
  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}

# Public read access
resource "google_storage_bucket_iam_binding" "public_read" {
  bucket = google_storage_bucket.static_site.name
  role   = "roles/storage.objectViewer"
  members = [
    "allUsers"
  ]
}

# -----------------------------
# 2️⃣  Global IP Address
# -----------------------------
resource "google_compute_global_address" "lb_ip" {
  name       = "${var.bucket_name}-ip"
  depends_on = [google_project_service.compute]
}

# -----------------------------
# 3️⃣   Create per-site backend buckets
# -----------------------------

locals {
  unique_fqdn_hosts = [
    for host in var.site_hosts :
    {
      prefix = host
      rule   = host
      fqdn   = "${host}.apps.tada.com.au"
      # fqdn   = "${host}-${google_compute_global_address.lb_ip.address}.nip.io"
    }
  ]
  wildcard_host = [{
    prefix = "core"
    rule   = "wildcard"
    fqdn   = "*.apps.tada.com.au"
  }]

  fqdn_hosts = concat(local.unique_fqdn_hosts, local.wildcard_host)
}

# -----------------------------
# 4️⃣  Create per-site backend buckets
# -----------------------------

resource "google_compute_backend_bucket" "site_backends" {
  for_each = { for h in local.unique_fqdn_hosts : h.prefix => h }

  name        = "${each.key}-backend"
  bucket_name = google_storage_bucket.static_site.name
  enable_cdn  = true

  # Serve files from subfolder (e.g. gs://bucket/admin/*)
  custom_response_headers = [
    "X-Backend-Path: /${each.key}/"
  ]
}

# -----------------------------
# 5️⃣ HTTPS Certificate
# -----------------------------

# resource "google_compute_managed_ssl_certificate" "cert" {
#   name = "${var.bucket_name}-cert"
#   managed {
#     domains = [for h in local.fqdn_hosts : h.fqdn]
#   }
# }

resource "google_compute_region_network_endpoint_group" "serverless_neg_admin" {
  name                  = "admin-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = "admin"
  }
  description = "Serverless NEG pointing at Admin Cloud Run service "
}

resource "google_compute_backend_service" "admin-be" {
  name                  = "admin-cr-be"
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  enable_cdn            = false

  backend {
    group = google_compute_region_network_endpoint_group.serverless_neg_admin.id
  }
}

resource "google_compute_region_network_endpoint_group" "serverless_neg_core" {
  name                  = "core-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = "core"
  }
  description = "Serverless NEG pointing at Core Cloud Run service "
}

resource "google_compute_backend_service" "core-be" {
  name                  = "core-cr-be"
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  enable_cdn            = false
  iap {
    enabled = true
  }

  backend {
    group = google_compute_region_network_endpoint_group.serverless_neg_core.id
  }
}


# -----------------------------
# 6️⃣   Advanced URL Map Host Match and Path rewrite
# -----------------------------
resource "google_compute_url_map" "advanced_map" {
  name            = "${var.bucket_name}-map"
  default_service = google_compute_backend_bucket.site_backends[var.site_hosts[0]].id

  dynamic "host_rule" {
    for_each = local.fqdn_hosts
    content {
      hosts        = [host_rule.value.fqdn]
      path_matcher = host_rule.value.rule
    }
  }

  dynamic "path_matcher" {
    for_each = local.fqdn_hosts
    content {
      name            = path_matcher.value.rule
      default_service = google_compute_backend_bucket.site_backends[path_matcher.value.prefix].id
      default_custom_error_response_policy {
        error_response_rule {
          match_response_codes   = ["404"]                                    # Catch all 404 responses under /*
          path                   = "/${path_matcher.value.prefix}/index.html" # Serve /index.html 
          override_response_code = 200
        }
        error_service = google_compute_backend_bucket.site_backends[path_matcher.value.prefix].id
      }

      # All requests go to the app’s subfolder
      route_rules {
        service = google_compute_backend_bucket.site_backends[path_matcher.value.prefix].id

        priority = 1
        match_rules {
          prefix_match = "/"
        }
        route_action {
          url_rewrite {
            # Rewrite / → /<subfolder>/
            path_prefix_rewrite = "/${path_matcher.value.prefix}/"
          }

        }
      }
    }
  }

  host_rule {
    hosts        = ["admin-protected.apps.tada.com.au", "admin-protected.sandbox.hapana-dev.com"]
    path_matcher = "admin-protected"
  }

  path_matcher {
    name            = "admin-protected"
    default_service = google_compute_backend_service.admin-be.id
  }

  host_rule {
    hosts        = ["core-protected.apps.tada.com.au", "core-protected.sandbox.hapana-dev.com"]
    path_matcher = "core-protected"
  }

  path_matcher {
    name            = "core-protected"
    default_service = google_compute_backend_service.core-be.id
  }
}

# -----------------------------
# 7️⃣  Advanced HTTPS Proxy
# -----------------------------
resource "google_compute_target_https_proxy" "https_proxy" {
  name    = "${var.bucket_name}-https-proxy"
  url_map = google_compute_url_map.advanced_map.name

  certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.default.id}"
  # ssl_certificates = [
  #   google_compute_managed_ssl_certificate.cert.id,
  # ]
}

# -----------------------------
# 8️⃣  Global Forwarding Rule (Advanced)
# -----------------------------
resource "google_compute_global_forwarding_rule" "https_rule" {
  name                  = "${var.bucket_name}-lb"
  target                = google_compute_target_https_proxy.https_proxy.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.lb_ip.address
  port_range            = "443"
  ip_protocol           = "TCP"
}




#   dynamic "host_rule" {
#     for_each = local.fqdn_hosts
#     content {
#       hosts        = [host_rule.value.fqdn]
#       path_matcher = host_rule.value.prefix
#     }
#   }

# path_matcher {
#   name            = "admin"
#   default_service = google_compute_backend_bucket.site_backends["admin"].id
#   default_custom_error_response_policy {
#     error_response_rule {
#       match_response_codes   = ["404"]             # Catch all 404 responses under /*
#       path                   = "/admin/index.html" # Serve /index.html 
#       override_response_code = 200
#     }
#     error_service = google_compute_backend_bucket.site_backends["admin"].id
#   }

#   route_rules {
#     service  = google_compute_backend_bucket.site_backends["admin"].id
#     priority = 1
#     match_rules {
#       prefix_match = "/"
#     }
#     route_action {
#       url_rewrite {
#         # Rewrite / → /<subfolder>/
#         path_prefix_rewrite = "/admin/"
#       }
#     }
#   }
# }

# path_matcher {
#   name            = "core"
#   default_service = google_compute_backend_bucket.site_backends["core"].id
#   route_rules {
#     service  = google_compute_backend_bucket.site_backends["core"].id
#     priority = 1
#     match_rules {
#       prefix_match = "/"
#     }
#     route_action {
#       url_rewrite {
#         # Rewrite / → /<subfolder>/
#         path_prefix_rewrite = "/core/"
#       }
#     }
#   }
# }

# -----------------------------
# # 2️⃣  Backend Bucket
# # -----------------------------
# resource "google_compute_backend_bucket" "cdn_backend" {
#   name        = "${var.bucket_name}-be"
#   bucket_name = google_storage_bucket.static_site.name
#   enable_cdn  = true

#   cdn_policy {
#     cache_mode = "CACHE_ALL_STATIC"
#   }
#   depends_on = [google_project_service.compute]

# }

# -----------------------------
# 3️⃣  URL Map (path-based routing)
# -----------------------------
# locals {
#   fqdn_hosts = [
#     for host in var.site_hosts :
#     "${host}-${google_compute_global_address.lb_ip.address}.nip.io"
#   ]
# }




# resource "google_compute_url_map" "cdn_map" {
#   name = "${var.bucket_name}-url-map"

#   default_service = google_compute_backend_bucket.cdn_backend.id

#   dynamic "host_rule" {
#     for_each = local.fqdn_hosts
#     content {
#       hosts        = [host_rule.value]
#       path_matcher = replace(host_rule.value, ".", "-") # unique name per host
#     }
#   }

#   dynamic "path_matcher" {
#     for_each = local.fqdn_hosts
#     content {
#       name            = replace(path_matcher.value, ".", "-")
#       default_service = google_compute_backend_bucket.cdn_backend.id
#     }
#   }
# }

# # -----------------------------
# # 6️⃣   Advanced URL Map
# # -----------------------------
# resource "google_compute_url_map" "advanced_map" {
#   name = "${var.bucket_name}-map"

#   dynamic "host_rule" {
#     for_each = local.fqdn_hosts
#     content {
#       hosts        = [host_rule.value.fqdn]
#       path_matcher = host_rule.value.prefix
#     }
#   }

#   dynamic "path_matcher" {
#     for_each = local.fqdn_hosts
#     content {
#       name = path_matcher.value.prefix
#      default_service = google_compute_backend_bucket.site_backends[path_matcher.value.prefix].id


#       # All requests go to the app’s subfolder
#       route_rules {
#         priority = 1
#         match_rules {
#           prefix_match = "/"
#         }
#         route_action {
#           url_rewrite {
#             # Rewrite / → /<subfolder>/
#             path_prefix_rewrite = "/${path_matcher.value.prefix}/"
#           }
#           weighted_backend_services {
#             backend_service = google_compute_backend_bucket.site_backends[path_matcher.value.prefix].id
#             weight          = 1
#           }
#         }
#       }
#     }
#   }
#   default_service = google_compute_backend_bucket.site_backends[var.site_hosts[0]].id
# }