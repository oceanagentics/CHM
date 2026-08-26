# CHM Deploy Notes

## Current Scope

The first deployment publishes the minimal CHM app to Cloud Run behind the IAP-protected HTTPS load balancer.

Terraform manages the Artifact Registry repository, Cloud Run service, load balancer, certificate, URL map, and IAP access. DNS remains manual in Dynadot.

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
gcloud builds submit --tag us-east4-docker.pkg.dev/chm-network/chm-apps/chm:latest .
```

Then review and apply the full plan:

```sh
cd /Users/danvallentyne/dev/CHM/infra
terraform plan -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm:latest
terraform apply -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm:latest
```

After apply, use the `load_balancer_ip` output to create or update this Dynadot DNS record:

```text
chm.oceanagentics.org A <load_balancer_ip>
```
