resource "google_artifact_registry_repository" "chm_apps" {
  project       = var.project_id
  location      = var.region
  repository_id = "chm-apps"
  description   = "CHM application container images"
  format        = "DOCKER"

  depends_on = [google_project_service.required]
}
