# CHM Deploy Notes

## Current Scope

The first deployment publishes the minimal CHM app to Cloud Run behind the IAP-protected HTTPS load balancer.

Terraform manages the Artifact Registry repository, Cloud Run service, load balancer, certificate, URL map, and IAP access. DNS remains manual in Dynadot.

## Current Deployment

Applied on 2026-08-26:

- Project: `chm-network`
- Region: `us-east4`
- Cloud Run service: `chm`
- Image: `us-east4-docker.pkg.dev/chm-network/chm-apps/chm:latest`
- Load balancer IP: `34.110.145.254`
- Managed certificates: `chm-oceanagentics-org-cert`, `chm-oceanagentics-com-cert`
- Hostnames: `chm.oceanagentics.org`, `chm.oceanagentics.com`

Terraform currently reports no drift with:

```sh
cd /Users/danvallentyne/dev/CHM/infra
terraform plan -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm:latest
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

Then bootstrap the image repository:

```sh
cd /Users/danvallentyne/dev/CHM/infra
terraform apply -target=google_project_service.required -target=google_artifact_registry_repository.chm_apps
```

Then build and push the app image:

```sh
cd /Users/danvallentyne/dev/CHM
gcloud builds submit --region us-east4 --tag us-east4-docker.pkg.dev/chm-network/chm-apps/chm:latest .
```

Then review and apply the full plan:

```sh
cd /Users/danvallentyne/dev/CHM/infra
terraform plan -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm:latest
terraform apply -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm:latest
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
