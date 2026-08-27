# CHM Deploy Notes

## Current Scope

The first deployment publishes the minimal CHM app to Cloud Run behind the IAP-protected HTTPS load balancer.

Terraform manages the Artifact Registry repository, Cloud Run service, load balancer, certificate, URL map, and IAP access. DNS remains manual in Dynadot.

## Current Deployment

Initial apply on 2026-08-26; warm-instance update on 2026-08-27:

- Project: `chm-network`
- Region: `us-east4`
- Cloud Run service: `chm`
- Image: `us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:12e42f5a4af1f239842cd65db6e5e4f0daa05376f01058eab8282b7da434bce9`
- Scaling: 1 minimum instance, 3 maximum instances
- Cloud Run deletion protection: enabled
- Cloud Build service account: `chm-build-sa@chm-network.iam.gserviceaccount.com`
- IAP JWT audience: `/projects/288836337031/global/backendServices/1981640158971360804`
- Load balancer IP: `34.110.145.254`
- Managed certificates: `chm-oceanagentics-org-cert`, `chm-oceanagentics-com-cert`
- Hostnames: `chm.oceanagentics.org`, `chm.oceanagentics.com`
- HTTP: port 80 redirects to the matching HTTPS URL

Terraform currently reports no drift with:

```sh
cd /Users/danvallentyne/dev/CHM/infra
terraform plan -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:12e42f5a4af1f239842cd65db6e5e4f0daa05376f01058eab8282b7da434bce9
```

The managed certificate stays `PROVISIONING` until Dynadot DNS points the CHM hostnames at the load balancer.

## One-Time Bootstrap

Terraform state is stored in the GCS bucket `chm-network-tfstate-288836337031` with prefix `chm`.

The CHM image must exist before the full Terraform apply can create the Cloud Run service. The Artifact Registry repository must exist before the image can be pushed.

Bootstrap Terraform state and the image repository first:

```sh
gcloud storage buckets create gs://chm-network-tfstate-288836337031 --project chm-network --location us-east4 --uniform-bucket-level-access
gcloud storage buckets update gs://chm-network-tfstate-288836337031 --versioning
```

Then initialize Terraform:

```sh
cd /Users/danvallentyne/dev/CHM/infra
terraform init
```

Then bootstrap the image repository and build service account:

```sh
cd /Users/danvallentyne/dev/CHM/infra
terraform apply \
  -target=google_project_service.required \
  -target=google_artifact_registry_repository.chm_apps \
  -target=google_service_account.chm_build \
  -target=google_storage_bucket_iam_member.cloud_build_source_reader \
  -target=google_artifact_registry_repository_iam_member.cloud_build_artifact_writer \
  -target=google_project_iam_member.cloud_build_logs_writer \
  -target=google_service_account_iam_member.cloud_build_submitter
```

Then build and push the app image. The build config uses the dedicated CHM Cloud Build service account and stores build logs in Cloud Logging:

```sh
cd /Users/danvallentyne/dev/CHM
gcloud builds submit --region us-east4 --config cloudbuild.yaml .
```

Then review and apply the full plan:

```sh
cd /Users/danvallentyne/dev/CHM/infra
terraform plan -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:<image-digest>
terraform apply -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:<image-digest>
```

After apply, use the `load_balancer_ip` output to create or update this Dynadot DNS record:

```text
chm.oceanagentics.org A 34.110.145.254
chm.oceanagentics.com A 34.110.145.254
```

After DNS propagates, check certificate status:

```sh
gcloud compute ssl-certificates describe chm-oceanagentics-org-cert --global --project chm-network --format='get(managed.status)'
gcloud compute ssl-certificates describe chm-oceanagentics-com-cert --global --project chm-network --format='get(managed.status)'
```

When the certificate is active, unauthenticated requests to `/` and `/login` should go to the Google IAP login flow, and signed-in `@oceanagentics.com` users should reach the CHM app.
