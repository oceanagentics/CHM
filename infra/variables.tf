variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
  default     = "chm-network"
}

variable "project_number" {
  description = "Google Cloud project number, used for the IAP service agent."
  type        = string
  default     = "288836337031"
}

variable "region" {
  description = "Primary Cloud Run region."
  type        = string
  default     = "us-east4"
}

variable "domain" {
  description = "Public CHM domain."
  type        = string
  default     = "chm.oceanagentics.org"
}

variable "alternate_domain" {
  description = "Additional CHM domain served by the same load balancer."
  type        = string
  default     = "chm.oceanagentics.com"
}

variable "chm_image" {
  description = "Container image for the CHM Cloud Run service."
  type        = string
}

variable "iap_member" {
  description = "Initial IAP access principal for CHM."
  type        = string
  default     = "domain:oceanagentics.com"
}

variable "iap_backend_service_id" {
  description = "Numeric CHM backend service ID used in the IAP JWT audience."
  type        = string
  default     = "1981640158971360804"
}

variable "cloud_build_submitter_member" {
  description = "Operator allowed to submit CHM builds as the dedicated Cloud Build service account."
  type        = string
  default     = "user:danny@oceanagentics.com"
}
