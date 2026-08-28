# CHM Deploy Notes

## Current Scope

The first deployment publishes the minimal CHM app to Cloud Run behind the IAP-protected HTTPS load balancer.

Terraform manages the Artifact Registry repository, Cloud Run service, load balancer, certificate, URL map, and IAP access. DNS remains manual in Dynadot.

The Explorer slice is gated by `enable_explorer`. The live CHM project currently runs that slice; keep it disabled only for fresh/bootstrap applies until an Explorer image exists and Cloud SQL cost is approved.

## Current Deployment

Initial apply on 2026-08-26; warm-instance update on 2026-08-27; Explorer and alerting updates on 2026-08-28:

- Project: `chm-network`
- Region: `us-east4`
- Cloud Run service: `chm`
- Image: `us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:83f98d262f9a14aef67f9a0f2f626a0e06859a949258ca1887845c7049dfbff8`
- Scaling: 1 minimum instance, 3 maximum instances
- Cloud Run deletion protection: enabled
- Cloud Build service account: `chm-build-sa@chm-network.iam.gserviceaccount.com`
- Explorer Cloud Run services: `explorer` and private `explorer-api`
- Explorer image: `us-east4-docker.pkg.dev/chm-network/chm-apps/explorer@sha256:f1ad37c1b953e225683021644307a337f3adab0e999f6328f541ed3dcf00013c`
- Explorer Cloud Build service account: `explorer-build-sa@chm-network.iam.gserviceaccount.com`
- Cloud SQL instance: `chm`, database `explorer`
- IAP JWT audience: `/projects/288836337031/global/backendServices/1981640158971360804`
- Load balancer IP: `34.110.145.254`
- Managed certificates: `chm-oceanagentics-org-cert`, `chm-oceanagentics-com-cert`
- Hostnames: `chm.oceanagentics.org`, `chm.oceanagentics.com`
- HTTP: port 80 redirects to the matching HTTPS URL
- Alerts: Cloud Monitoring email channel `danny@oceanagentics.com` with policies for IAP failures, Cloud Run 5xx spikes, IAM policy changes, and service-account key creation

Terraform currently reports no drift with:

```sh
cd /Users/danvallentyne/dev/CHM/infra
terraform plan \
  -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:83f98d262f9a14aef67f9a0f2f626a0e06859a949258ca1887845c7049dfbff8 \
  -var enable_explorer=true \
  -var explorer_image=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer@sha256:f1ad37c1b953e225683021644307a337f3adab0e999f6328f541ed3dcf00013c
```

Public DNS now points both CHM hostnames at the load balancer. Unauthenticated HTTPS requests should go to the Google IAP login flow, and signed-in `@oceanagentics.com` users should reach the CHM app.

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

## Explorer Deployment Slice

First apply CHM Terraform without enabling Explorer so the non-billable Explorer build identity exists:

```sh
cd /Users/danvallentyne/dev/CHM/infra
terraform plan -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:<chm-image-digest>
terraform apply -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:<chm-image-digest>
```

Then build the Explorer image from the Ryu repo:

```sh
cd /Users/danvallentyne/dev/oceanagentics/ryu
gcloud builds submit \
  --region us-east4 \
  --config cloudbuild.yaml \
  --substitutions _IMAGE=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer:$(git rev-parse --short HEAD) \
  .
```

Then apply the gated Explorer infrastructure:

```sh
cd /Users/danvallentyne/dev/CHM/infra
terraform plan \
  -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:<chm-image-digest> \
  -var enable_explorer=true \
  -var explorer_image=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer@sha256:<explorer-image-digest>
terraform apply \
  -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:<chm-image-digest> \
  -var enable_explorer=true \
  -var explorer_image=us-east4-docker.pkg.dev/chm-network/chm-apps/explorer@sha256:<explorer-image-digest>
```

After Cloud SQL exists, run the Ryu migration/import against database `explorer` using the migration database credentials from Secret Manager:

```sh
cd /Users/danvallentyne/dev/oceanagentics/ryu
npm --workspace server run migrate:postgres
npm --workspace server run import:postgres -- --truncate
```

Expected checks after routing is enabled:

```sh
curl -I https://chm.oceanagentics.org/explorer
curl -I https://chm.oceanagentics.com/explorer
```

Unauthenticated requests should be redirected by IAP before reaching Explorer.
