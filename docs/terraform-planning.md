# Terraform Planning Notes

## Purpose

Terraform should define and manage the shared CHM Google Cloud infrastructure for `chm.oceanagentics.org`.

The initial executable Terraform skeleton lives in `infra/`. Do not apply it until the plan output has been reviewed.

## Definitions

- Terraform: the command-line tool that creates, updates, and removes infrastructure from checked-in configuration files.
- Infrastructure as code: the practice of describing cloud resources in files instead of relying on console clicks.
- Provider: a Terraform plugin for a cloud or service API. CHM uses the Google provider, plus Google Beta only where a needed resource is not in the stable provider.
- Resource: one managed object, such as a Cloud Run service, service account, load balancer URL map, or IAM binding.
- Variable: an input value used by Terraform, such as project ID, region, or domain name.
- Output: a value Terraform prints or exposes after apply, such as the load balancer IP address.
- State: Terraform's record that maps checked-in resource definitions to real cloud resources.
- Backend: the place Terraform stores state. For CHM, use a Google Cloud Storage backend once the state bucket exists.
- Plan: the review step where Terraform shows what it would create, change, or delete.
- Apply: the execution step where Terraform makes the planned cloud changes.
- Drift: a difference between Terraform state/configuration and real cloud state, usually caused by manual console changes.

## Google Cloud Definitions

- Cloud Run service: a managed container service, such as `chm` or `explorer`.
- Service account: a Google identity used by a service or deploy process, such as `chm-sa`.
- Serverless NEG: a load-balancer backend target that points at a Cloud Run service.
- Backend service: the load-balancer backend configuration that wraps a NEG and can carry IAP policy.
- URL map: the load-balancer routing table that maps host/path rules to backend services.
- Host rule: the URL map rule that matches `chm.oceanagentics.org`.
- Path matcher: the URL map section that chooses a backend from the request path.
- Path rule: an explicit path mapping, such as `/explorer/*` to the Explorer backend.
- URL mask routing: a serverless NEG pattern that derives service names from URL paths. CHM will not use this first.
- IAP: Identity-Aware Proxy, the Google login and access boundary for protected CHM routes.
- IAM principal: the identity receiving access. Initial CHM IAP access uses `domain:oceanagentics.com`.
- Managed certificate: a Google-managed TLS certificate for `chm.oceanagentics.org`.

## Locked Decisions

- Project: `chm-network`.
- Domain: `chm.oceanagentics.org`.
- Primary Cloud Run region: `us-east4`.
- Terraform state bucket: `chm-network-tfstate-288836337031`.
- Infrastructure path: Terraform.
- Routing style: explicit URL map rules per app.
- IAP access principal: `domain:oceanagentics.com`.
- `/` and `/login` are IAP-protected.
- `/login` should trigger or forward to the IAP login flow.
- Minimal CHM app routes: `/`, `/login`, and `/healthz`.
- Minimal CHM app stack: Node.js and Express.
- DNS is managed manually in Dynadot.
- Explorer is path-mounted at `/explorer`.

## Open Decisions

- Whether the first Explorer backend is the real Ryu Cloud Run service or a temporary placeholder.
- Whether CHM validates the IAP signed JWT in the first app build or after the first infrastructure deployment.
- Whether IAP policy is applied per backend service with the same principal or initially at a broader IAP resource level.

## Planned Terraform Shape

Keep Terraform under an `infra/` directory once implementation begins.

Suggested files:

- `infra/versions.tf`: Terraform and provider version constraints.
- `infra/providers.tf`: Google provider project and region configuration.
- `infra/backend.tf`: GCS state backend configuration.
- `infra/variables.tf`: project, region, domain, and naming inputs.
- `infra/services.tf`: Google Cloud APIs Terraform expects to be enabled.
- `infra/artifact-registry.tf`: Artifact Registry Docker repository for CHM images.
- `infra/cloud-build.tf`: IAM bindings needed for Cloud Build image publishing.
- `infra/service-accounts.tf`: CHM service account.
- `infra/cloud-run.tf`: CHM Cloud Run service and ingress settings.
- `infra/load-balancer.tf`: global IP, certificate, HTTPS proxy, forwarding rule, CHM serverless NEG, CHM backend service, and URL map.
- `infra/iap.tf`: IAP access bindings and related IAM.
- `infra/outputs.tf`: load balancer IP, service URLs, and backend identifiers.
- `infra/terraform.tfvars.example`: example variable value for the CHM container image.

## First Resource Slice

The first executable Terraform should define only the minimum shared platform needed to test CHM routing:

1. Required Google Cloud APIs, including Cloud Run, Cloud Build, Compute, IAP, IAM, Artifact Registry, Cloud Logging, and Cloud Storage.
2. Artifact Registry repository `chm-apps`.
3. Cloud Build IAM needed to read submitted source and write the CHM image.
4. Service account `chm-sa`.
5. Cloud Run service `chm`.
6. Serverless NEG for `chm`.
7. Backend service for `chm` with IAP enabled.
8. Managed certificate for `chm.oceanagentics.org`.
9. Global external IP address.
10. Global external HTTPS Application Load Balancer pieces required by Google Cloud.
11. Explicit URL map rules for `/` and `/login`.
12. IAP service identity and Cloud Run invoker access for IAP.
13. IAP access for `domain:oceanagentics.com`.
14. Direct Cloud Run ingress restricted to internal and Cloud Load Balancing.
15. Output for the load balancer IP to enter manually in Dynadot.

The `/explorer` rules are part of the target URL map. Add them when Ryu provides a Cloud Run service name, health expectations, and base-path compatibility for `/explorer`, or when we explicitly choose a temporary Explorer placeholder backend. Do not silently route `/explorer` to CHM.

## Explicit URL Map Rules

Initial routing should be explicit and reviewable:

| Host | Path | Backend |
| --- | --- | --- |
| `chm.oceanagentics.org` | `/` | `chm` |
| `chm.oceanagentics.org` | `/login` | `chm` |

The URL map default backend should route to CHM so unmatched CHM-domain requests get a CHM-owned response.

Target Explorer routing remains explicit, but deferred:

| Host | Path | Backend |
| --- | --- | --- |
| `chm.oceanagentics.org` | `/explorer` | `explorer` |
| `chm.oceanagentics.org` | `/explorer/*` | `explorer` |

## State Plan

Use remote Terraform state in Google Cloud Storage before multiple agents or humans apply changes.

The GCS state bucket must exist before Terraform can use it as a backend. Bootstrap `chm-network-tfstate-288836337031` once, enable object versioning, then use `infra/backend.tf` with the `chm` prefix.

Do not commit local `terraform.tfstate` files.

## DNS Plan

Terraform does not manage DNS for the first slice because DNS is managed in Dynadot.

After Terraform creates the load balancer, use the `load_balancer_ip` output to create or update this Dynadot record:

```text
chm.oceanagentics.org A <load_balancer_ip>
```

## Implementation Rules

- Run `terraform plan` before every `terraform apply`.
- Review the plan output before applying.
- Terraform plan/apply requires Google credentials for `chm-network`; use `danny@oceanagentics.com` or another approved Ocean Agentics operator account.
- Follow `docs/deploy.md` for the one-time Artifact Registry and image bootstrap order.
- Avoid manual console edits after Terraform owns a resource.
- If a console change is unavoidable, reflect it in Terraform or import the changed resource before continuing.
- Keep CHM shared infrastructure separate from Explorer app internals.
- Do not use URL mask routing unless this plan is explicitly revised.
