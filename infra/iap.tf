resource "google_iap_web_backend_service_iam_member" "chm_domain" {
  project             = var.project_id
  web_backend_service = google_compute_backend_service.chm.name
  role                = "roles/iap.httpsResourceAccessor"
  member              = var.iap_member
}
