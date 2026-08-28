# CHM Server Migration Notes

Source plan: `/Users/danvallentyne/dev/oceanagentics/CHM-Network/outputs/ryu-cloud-run-migration-plan.md`

## Purpose

CHM is the official user-facing entry app, application switcher, loader, and IAP-protected portal for `chm.oceanagentics.org` and `chm.oceanagentics.com`.

Explorer, currently developed in the Ryu repo, remains the graph application and is mounted under CHM at `/explorer`.

## Current Status

The first CHM slice was deployed on 2026-08-26. The Explorer infrastructure
slice was applied on 2026-08-28 and remains security-gated before being treated
as production-ready.

- Cloud Run service `chm` is deployed in `us-east4`.
- Terraform state is stored in `gs://chm-network-tfstate-288836337031/chm`.
- The HTTPS load balancer IP is `34.110.145.254`.
- Dynadot DNS has `A` records for `chm.oceanagentics.org` and `chm.oceanagentics.com` pointing to `34.110.145.254`.
- Public HTTPS requests to both hostnames reach Google IAP.
- `/explorer` routing is active behind IAP when Terraform is applied with `enable_explorer=true`.
- Terraform includes the Explorer slice: shared Cloud SQL `chm`, database `explorer`, Explorer service accounts, generated database-password secrets, Cloud Run `explorer`, optional private `explorer-api`, and `/explorer` URL-map routing.

## Target Routes

Use one shared domain with path routing:

- `https://chm.oceanagentics.org/` routes to CHM.
- `https://chm.oceanagentics.org/login` routes to CHM and should trigger or forward to the IAP login flow, not implement a separate CHM password screen.
- `https://chm.oceanagentics.org/explorer` routes to Explorer.
- `https://chm.oceanagentics.com/`, `/login`, and `/explorer` route to the same CHM-managed load balancer and explicit app backends.
- Future CHM apps use their own path prefixes, for example `/otherapp1` and `/otherapp2`.

`/` and `/login` are IAP-protected. The first implementation should treat IAP as the shared Google login boundary and avoid building a separate user-auth system.

## Locked Decisions

- Infrastructure should be managed with Terraform, not console-only setup.
- URL routing should use explicit URL map rules per app, not URL mask routing.
- IAP access should be granted to Ocean Agentics Workspace users with the principal `domain:oceanagentics.com`.
- `/` and `/login` are IAP-protected CHM routes.
- `/login` should trigger or forward to the IAP login flow instead of implementing a separate CHM login form.
- The minimal CHM app exposes `/`, `/login`, and `/healthz`.
- The minimal CHM app stack is Node.js and Express.
- The primary Cloud Run region is `us-east4`.
- DNS is managed manually in Dynadot, not Terraform.
- `chm.oceanagentics.com` is served as an additional CHM hostname, not redirected.
- HTTP requests redirect to the same host and path on HTTPS at the load balancer.
- CHM validates the signed IAP JWT assertion for app routes, except `/healthz` for Cloud Run startup probes.
- Cloud Run deletion protection is enabled for the CHM service.
- Cloud Build uses the dedicated `chm-build-sa` service account instead of the default Compute service account.
- Initial Terraform-managed routes are `/` and `/login`.
- Target Explorer routes are `/explorer` and `/explorer/*`, managed only when `enable_explorer=true`.
- The Explorer/Ryu repo now provides Cloud Run base-path compatibility for `/explorer`, runtime modes, a Dockerfile, Cloud Build config, PostgreSQL schema, and SQLite-to-PostgreSQL import tooling.

## CHM Owns

- The shared domain `chm.oceanagentics.org`.
- The external HTTPS Application Load Balancer.
- Google-managed TLS certificate setup.
- Serverless NEGs and backend services for CHM, Explorer, and future apps.
- URL map path routing.
- IAP setup on protected load-balancer backend services.
- IAP access policy for approved users, groups, and service accounts.
- Cloud Run service `chm`.
- CHM portal UI, `/login` route, application switcher, and app loader.
- CHM app registry for path-mounted apps.
- IAP signed JWT validation in CHM.
- Trusted user-context forwarding from CHM to private app services.
- Shared service-account, Secret Manager, Artifact Registry, Cloud SQL, Cloud Storage, logging, and deployment conventions.

CHM should not own Explorer graph logic, Explorer validation, Explorer database schema decisions, or broad Explorer write credentials.

## Explorer Handoff

Explorer/Ryu should provide CHM with:

- Route prefix: `/explorer`.
- Built Explorer image digest for `explorer_image`.
- Optional built Explorer API image digest for `explorer_api_image`; this defaults to `explorer_image` when empty.
- Health check path: `/healthz`.
- Required environment variables, including `APP_BASE_PATH=/explorer`, `RYU_DATA_BACKEND=postgres`, and `RYU_MODE=public|api`.
- Required secrets and database roles: `explorer_read`, `explorer_write`, and `explorer_migration`.
- Private API surface through `explorer-api`, if write/admin routes are split from the browser-facing service.
- Smoke test commands for `/explorer`, read-only access, authorized writes, and unauthorized denial.

Explorer remains responsible for enforcing its own validation and database role separation even when CHM has already authenticated the user through IAP.

## Shared Guardrails

- Do not enable IAP both on a load-balancer backend service and directly on the Cloud Run service behind it.
- Restrict load-balanced Cloud Run services to internal and Cloud Load Balancing ingress so default `run.app` URLs cannot bypass IAP.
- Do not grant public unauthenticated invoke access to `chm`.
- Do not expose raw Explorer write/admin endpoints directly to browsers.
- Do not share database users or runtime secrets across apps.
- Do not let public services use writer or migration credentials.
- Do not enable Cloud CDN on IAP-protected backend services.

## First CHM Slice

1. Build the minimal CHM app routes: `/`, `/login`, and `/healthz`.
2. Make `/login` rely on IAP for unauthenticated login and redirect authenticated requests to `/`.
3. Deploy Cloud Run `chm` in `us-east4` with service account `chm-sa`.
4. Create Terraform definitions for the CHM Artifact Registry repository, Cloud Run service, load balancer, managed certificate, serverless NEG, backend service, `/` and `/login` URL map rules, and IAP policy.
5. Bootstrap the Artifact Registry repository, then build and push the CHM image before applying the full Cloud Run plan.
6. Output the load balancer IP so the `chm.oceanagentics.org` DNS `A` record can be created manually in Dynadot.
7. Restrict direct Cloud Run ingress for load-balanced services.
8. Grant only the needed invoker permissions between CHM and IAP.
9. Add `/explorer` routing by applying the gated Explorer Terraform slice with `enable_explorer=true` and a real Explorer image.
