# VPC network resource
resource "google_compute_network" "apigee_vpc" {
  name                    = "apigee-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
  depends_on              = [google_project_service.compute, google_project_service.apigee]
}

# Subnet resource
resource "google_compute_subnetwork" "apigee_vpc_apigee_subnet" {
  name          = "apigee-vpc-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.apigee_vpc.id
  project       = var.project_id
}


# Reserve IP range for service networking

locals {
  service_networking_peering_cidr_address = cidrhost(var.service_networking_peering_cidr, 0)
  service_networking_peering_cidr_length  = tonumber(split("/", var.service_networking_peering_cidr)[1])
}

resource "google_compute_global_address" "apigee_service_networking_peering_range" {
  name          = "apigee-service-networking-peering-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = local.service_networking_peering_cidr_address
  prefix_length = local.service_networking_peering_cidr_length
  network       = google_compute_network.apigee_vpc.id
  project       = var.project_id

  depends_on = [google_compute_network.apigee_vpc]
}

# service networking peering connection
resource "google_service_networking_connection" "apigee_private_connection" {
  network                 = google_compute_network.apigee_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.apigee_service_networking_peering_range.name]

  depends_on = [
    google_project_service.servicenetworking
  ]
}


locals {
  # FOR EVALUATION, allocate a /28 for management and runtime.
  # For PAID ORGS, choose to either deploy with VPC or not
  # If VPC, allocate a /22 for runtime and a /28 for management.
  # Assumes that service_networking_peering_cidr is a /21 CIDR block.

  #EVAL
  # /28 for runtime
  apigee_runtime_cidr_range = cidrsubnet(var.service_networking_peering_cidr, 7, 0) # 10.21.0.0/28
  apigee_mgmt_cidr_range    = cidrsubnet(var.service_networking_peering_cidr, 7, 1) # 10.21.0.16/28
}


# Apigee organization
resource "google_apigee_organization" "apigee_org" {
  project_id          = var.project_id
  display_name        = "Apigee Organization for ${var.project_id}"
  description         = "Apigee Organization created via Terraform"
  analytics_region    = var.region
  disable_vpc_peering = false
  authorized_network  = google_compute_network.apigee_vpc.id
  runtime_type        = "CLOUD"

  # For testing purposes, we can use EVALUATION billing type
  billing_type = "EVALUATION"
  retention    = "MINIMUM"

  # billing_type = "SUBSCRIPTION"
  # retention = "DELETION_RETENTION_UNSPECIFIED"

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [
    google_service_networking_connection.apigee_private_connection,
    google_project_service.apigee
  ]
}

# Apigee instance
resource "google_apigee_instance" "apigee_instance" {
  name     = "eval-instance"
  location = var.region
  org_id   = google_apigee_organization.apigee_org.id

  # Uncomment the following line to specify a the CIDR ranges, otherwise Apigee will auto allocate from the Service Networking peering range
  # ip_range = "10.21.0.0/28,10.21.0.16/28"
  ip_range = "${local.apigee_runtime_cidr_range},${local.apigee_mgmt_cidr_range}"

  consumer_accept_list = [
    "${var.project_id}"
  ]
}

# Apigee environments and groups
resource "google_apigee_environment" "dev_env" {
  name   = "dev"
  org_id = google_apigee_organization.apigee_org.id
}

resource "google_apigee_envgroup" "dev_group" {
  name   = "dev-group"
  org_id = google_apigee_organization.apigee_org.id
  hostnames = [
    "api-dev.servers.tada.com.au",
    "api.sandbox.hapana-dev.com",
  ]
}

resource "google_apigee_environment" "prod_env" {
  name   = "prod"
  org_id = google_apigee_organization.apigee_org.id
}

resource "google_apigee_envgroup" "prod_group" {
  name   = "prod-group"
  org_id = google_apigee_organization.apigee_org.id
  hostnames = [
    "api.servers.tada.com.au",
    "api.sandbox.hapana.com",
  ]
}

# Eval Orgs only support a maximum of two environments and environment groups

# Attach environments to environment groups
resource "google_apigee_envgroup_attachment" "attach_dev" {
  envgroup_id = google_apigee_envgroup.dev_group.id
  environment = google_apigee_environment.dev_env.name
}

resource "google_apigee_envgroup_attachment" "attach_prod" {
  envgroup_id = google_apigee_envgroup.prod_group.id
  environment = google_apigee_environment.prod_env.name
}

# Attach environments to instance
# This doesn't always work for Evaluation

resource "google_apigee_instance_attachment" "attach_dev" {
  instance_id = google_apigee_instance.apigee_instance.id
  environment = google_apigee_environment.dev_env.name
}

resource "google_apigee_instance_attachment" "attach_prod" {
  instance_id = google_apigee_instance.apigee_instance.id
  environment = google_apigee_environment.prod_env.name

  depends_on = [google_apigee_instance_attachment.attach_dev]
}

resource "google_apigee_target_server" "gateway_service_dev" {
  name        = "gateway-service"
  description = "Gateway Cloud Run Service"
  env_id      = google_apigee_environment.dev_env.id
  host        = "httpbin.org"
  port        = 443
  protocol    = "HTTP"
  s_sl_info {
    enabled = true
  }
}

resource "google_apigee_target_server" "gateway_service_prod" {
  name        = "gateway-service"
  description = "Gateway Cloud Run Service"
  env_id      = google_apigee_environment.prod_env.id
  host        = "httpbin.org"
  port        = 443
  protocol    = "HTTP"
  s_sl_info {
    enabled = true
  }
}


# Create a Service Account that allows an Apigee Proxy to invoke a Cloud Run Service.
# For production, following principle of least privlege, you should create a Service Account per proxy
# and grant it Cloud Run Invoker on the specific Cloud Run Service(s) it needs to invoke. 
# For Dev, you can create a single SA and grant it Cloud Run Invoker permission at the Project level


resource "google_service_account" "proxy_sa" {
  account_id   = "proxy-sa"
  display_name = "Apigee Proxy Cloud Run Invoker Service Account"
}


resource "google_project_iam_member" "invoker_project_level" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.proxy_sa.email}"
}
