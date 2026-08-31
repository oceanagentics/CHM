output "load_balancer_ip" {
  description = "Use this IP for the manual Dynadot A records for CHM hostnames."
  value       = google_compute_global_address.chm.address
}

output "chm_cloud_run_service" {
  description = "CHM Cloud Run service name."
  value       = google_cloud_run_v2_service.chm.name
}

output "chm_region" {
  description = "Primary CHM Cloud Run region."
  value       = var.region
}

output "artifact_registry_repository" {
  description = "Artifact Registry Docker repository for CHM app images."
  value       = google_artifact_registry_repository.chm_apps.name
}

output "cloud_build_service_account" {
  description = "Dedicated service account used by CHM Cloud Build jobs."
  value       = google_service_account.chm_build.email
}

output "explorer_cloud_build_service_account" {
  description = "Dedicated service account used by Explorer Cloud Build jobs."
  value       = google_service_account.explorer_build.email
}

output "dynadot_dns_record" {
  description = "Manual DNS record to create in Dynadot after the load balancer exists."
  value       = "${var.domain} A ${google_compute_global_address.chm.address}"
}

output "dynadot_dns_records" {
  description = "Manual DNS records to create in Dynadot after the load balancer exists."
  value = [
    "${var.domain} A ${google_compute_global_address.chm.address}",
    "${var.alternate_domain} A ${google_compute_global_address.chm.address}",
  ]
}

output "explorer_cloud_run_service" {
  description = "Public read-only Explorer Cloud Run service name when Explorer is enabled."
  value       = var.enable_explorer ? google_cloud_run_v2_service.explorer[0].name : null
}

output "explorer_admin_cloud_run_service" {
  description = "IAP-protected Explorer admin Cloud Run service name when Explorer is enabled."
  value       = var.enable_explorer ? google_cloud_run_v2_service.explorer_admin[0].name : null
}

output "explorer_api_cloud_run_service" {
  description = "Private Explorer API Cloud Run service name when enabled."
  value       = local.explorer_api_enabled ? google_cloud_run_v2_service.explorer_api[0].name : null
}

output "explorer_schema_admin_service_account" {
  description = "Dedicated service account for Explorer schema administration."
  value       = var.enable_explorer ? google_service_account.explorer_schema_admin[0].email : null
}

output "cloud_sql_connection_name" {
  description = "Shared CHM Cloud SQL connection name when Explorer is enabled."
  value       = var.enable_explorer ? google_sql_database_instance.chm[0].connection_name : null
}

output "explorer_database" {
  description = "Explorer PostgreSQL database name when Explorer is enabled."
  value       = var.enable_explorer ? google_sql_database.explorer[0].name : null
}

output "explorer_db_password_secrets" {
  description = "Secret Manager secret IDs for Explorer database credentials."
  value = var.enable_explorer ? {
    read         = google_secret_manager_secret.explorer_db_read_password[0].secret_id
    schema_admin = google_secret_manager_secret.explorer_db_schema_admin_password[0].secret_id
    write        = google_secret_manager_secret.explorer_db_write_password[0].secret_id
  } : null
}
