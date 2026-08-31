data "google_compute_network" "default" {
  project = var.project_id
  name    = "default"
}

resource "google_compute_global_address" "cloud_sql_private_range" {
  count = var.enable_explorer ? 1 : 0

  project       = var.project_id
  name          = "chm-cloud-sql-private-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = data.google_compute_network.default.id

  depends_on = [google_project_service.required]
}

resource "google_service_networking_connection" "cloud_sql_private_vpc_connection" {
  count = var.enable_explorer ? 1 : 0

  network                 = data.google_compute_network.default.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.cloud_sql_private_range[0].name]

  depends_on = [google_project_service.required]
}

resource "google_sql_database_instance" "chm" {
  count = var.enable_explorer ? 1 : 0

  project             = var.project_id
  name                = "chm"
  region              = var.region
  database_version    = "POSTGRES_16"
  deletion_protection = true

  settings {
    tier              = var.cloud_sql_tier
    availability_type = "ZONAL"
    disk_type         = "PD_HDD"
    disk_size         = var.cloud_sql_disk_size_gb
    disk_autoresize   = true
    edition           = "ENTERPRISE"

    backup_configuration {
      enabled    = true
      start_time = var.cloud_sql_backup_start_time
    }

    deletion_protection_enabled = true

    ip_configuration {
      ipv4_enabled    = false
      private_network = data.google_compute_network.default.id
    }
  }

  depends_on = [
    google_project_service.required,
    google_service_networking_connection.cloud_sql_private_vpc_connection,
  ]
}

resource "google_sql_database" "explorer" {
  count = var.enable_explorer ? 1 : 0

  project  = var.project_id
  name     = "explorer"
  instance = google_sql_database_instance.chm[0].name
}

resource "random_password" "explorer_read" {
  count = var.enable_explorer ? 1 : 0

  length  = 32
  special = false
}

resource "random_password" "explorer_write" {
  count = var.enable_explorer ? 1 : 0

  length  = 32
  special = false
}

resource "random_password" "explorer_schema_admin" {
  count = var.enable_explorer ? 1 : 0

  length  = 32
  special = false
}

resource "google_sql_user" "explorer_read" {
  count = var.enable_explorer ? 1 : 0

  project  = var.project_id
  name     = "explorer_read"
  instance = google_sql_database_instance.chm[0].name
  password = random_password.explorer_read[0].result
}

resource "google_sql_user" "explorer_write" {
  count = var.enable_explorer ? 1 : 0

  project  = var.project_id
  name     = "explorer_write"
  instance = google_sql_database_instance.chm[0].name
  password = random_password.explorer_write[0].result
}

resource "google_sql_user" "explorer_schema_admin" {
  count = var.enable_explorer ? 1 : 0

  project  = var.project_id
  name     = "explorer_schema_admin"
  instance = google_sql_database_instance.chm[0].name
  password = random_password.explorer_schema_admin[0].result
}
