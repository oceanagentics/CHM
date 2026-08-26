locals {
  cloud_build_runtime_service_account = "${var.project_number}-compute@developer.gserviceaccount.com"
  cloud_build_source_bucket           = "${var.project_id}_cloudbuild"
}

data "google_storage_bucket" "cloud_build_source" {
  name = local.cloud_build_source_bucket
}

resource "google_storage_bucket_iam_member" "cloud_build_source_reader" {
  bucket = data.google_storage_bucket.cloud_build_source.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${local.cloud_build_runtime_service_account}"
}

resource "google_artifact_registry_repository_iam_member" "cloud_build_artifact_writer" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.chm_apps.repository_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${local.cloud_build_runtime_service_account}"
}
