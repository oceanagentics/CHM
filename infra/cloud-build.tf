locals {
  cloud_build_source_bucket = "${var.project_id}_cloudbuild"
}

data "google_storage_bucket" "cloud_build_source" {
  name = local.cloud_build_source_bucket
}

resource "google_storage_bucket_iam_member" "cloud_build_source_reader" {
  bucket = data.google_storage_bucket.cloud_build_source.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.chm_build.member
}

resource "google_artifact_registry_repository_iam_member" "cloud_build_artifact_writer" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.chm_apps.repository_id
  role       = "roles/artifactregistry.writer"
  member     = google_service_account.chm_build.member
}

resource "google_project_iam_member" "cloud_build_logs_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = google_service_account.chm_build.member
}

resource "google_service_account_iam_member" "cloud_build_submitter" {
  service_account_id = google_service_account.chm_build.name
  role               = "roles/iam.serviceAccountUser"
  member             = var.cloud_build_submitter_member
}
