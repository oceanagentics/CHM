output "load_balancer_ip" {
  description = "Use this IP for the manual Dynadot A record for chm.oceanagentics.org."
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

output "dynadot_dns_record" {
  description = "Manual DNS record to create in Dynadot after the load balancer exists."
  value       = "${var.domain} A ${google_compute_global_address.chm.address}"
}
