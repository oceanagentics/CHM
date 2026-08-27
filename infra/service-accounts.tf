resource "google_service_account" "chm" {
  project      = var.project_id
  account_id   = "chm-sa"
  display_name = "CHM Cloud Run service account"

  depends_on = [google_project_service.required]
}

resource "google_service_account" "chm_build" {
  project      = var.project_id
  account_id   = "chm-build-sa"
  display_name = "CHM Cloud Build service account"

  depends_on = [google_project_service.required]
}
