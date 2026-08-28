# CHM

CHM is the Ocean Agentics portal for authenticated, path-mounted CHM applications.
It is intended to be the shared entry point, login boundary, application switcher,
and loader for apps served from `chm.oceanagentics.org` and
`chm.oceanagentics.com`.

Explorer lives under `/explorer`. Terraform keeps the Explorer slice gated by
`enable_explorer`, and the current live project has that slice applied with a
built Explorer image. Treat Explorer as security-gated until the remaining
database and private API checks are complete.

## What Exists Today

The current CHM app is a minimal Node.js and Express portal shell.

- `/` serves the CHM portal.
- `/login` relies on Google IAP for unauthenticated login and redirects
  authenticated users to `/`.
- `/healthz` returns `{ "status": "ok" }` for Cloud Run startup probes.
- `/explorer` routes to the Explorer backend behind IAP.

The app validates Google IAP signed JWT assertions for app routes, requires
Ocean Agentics Workspace users, sends security headers with Helmet, and runs as a
non-root user in the container.

## What Is Running

Last verified: August 28, 2026.

- Google Cloud project: `chm-network`
- Primary region: `us-east4`
- Cloud Run service: `chm`
- Runtime service account: `chm-sa@chm-network.iam.gserviceaccount.com`
- Build service account: `chm-build-sa@chm-network.iam.gserviceaccount.com`
- Image: `us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:83f98d262f9a14aef67f9a0f2f626a0e06859a949258ca1887845c7049dfbff8`
- Scaling: 1 minimum instance, 3 maximum instances
- Explorer Cloud Run services: `explorer` and private `explorer-api`
- Explorer image: `us-east4-docker.pkg.dev/chm-network/chm-apps/explorer@sha256:f1ad37c1b953e225683021644307a337f3adab0e999f6328f541ed3dcf00013c`
- Cloud SQL instance: `chm`, database `explorer`
- Load balancer IP: `34.110.145.254`
- Hostnames: `chm.oceanagentics.org`, `chm.oceanagentics.com`
- Managed certificates: `chm-oceanagentics-org-cert`,
  `chm-oceanagentics-com-cert`
- IAP access: `domain:oceanagentics.com`
- Alerts: Cloud Monitoring email channel `danny@oceanagentics.com` for IAP
  failures, Cloud Run 5xx spikes, IAM policy changes, and service-account key
  creation
- Terraform state: `gs://chm-network-tfstate-288836337031/chm`

The Cloud Run service is restricted to internal and Cloud Load Balancing ingress,
so the default `run.app` URL should not bypass IAP. HTTP port 80 redirects to the
matching HTTPS URL at the load balancer. Cloud Run deletion protection is
enabled. Public DNS for both hostnames resolves to the load balancer IP, and
unauthenticated HTTPS requests are intercepted by IAP.

Terraform keeps the Explorer slice behind `enable_explorer=false` by default for
fresh/bootstrap applies, but the live CHM project currently runs it with
`enable_explorer=true`.

## Development

```sh
npm install
npm test
npm start
```

The local app does not require IAP unless `IAP_JWT_AUDIENCE` is set.

## Deployment

Build images with the dedicated CHM Cloud Build service account:

```sh
gcloud builds submit --region us-east4 --config cloudbuild.yaml .
```

Deploy by immutable image digest through Terraform:

```sh
cd infra
terraform plan -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:<image-digest>
terraform apply -var chm_image=us-east4-docker.pkg.dev/chm-network/chm-apps/chm@sha256:<image-digest>
```

See `docs/deploy.md` for the full bootstrap and deployment sequence.

## Agent Notes

Before changing infrastructure, IAP, Cloud Run, app routing, login behavior, or
Terraform, read:

- `docs/server-migration.md`
- `docs/terraform-planning.md`
- `docs/deploy.md`

Use the Ocean Agentics SSH remote for GitHub pushes:

```sh
git@github-oceanagentics:oceanagentics/CHM.git
```

Avoid console-only infrastructure edits after Terraform owns a resource. If a
manual console change is unavoidable, reflect it in Terraform or import it before
continuing.
