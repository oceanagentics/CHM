# Agent Instructions

## Repository Access

- Canonical repository: `github.com/oceanagentics/CHM`
- Local SSH remote for Ocean Agentics pushes: `git@github-oceanagentics:oceanagentics/CHM.git`
- Use SSH authentication for the Ocean Agentics GitHub account when fetching or pushing.
- Use the repo-local Git identity `oceanagentics <aaron@oceanagentics.com>` for commits.
- Before pushing, confirm `git remote -v` points at the canonical remote.
- If GitHub access fails, stop and ask the user to authorize the Ocean Agentics account or provide updated access.

## Working Style

- Review and propose by default; only implement changes when explicitly asked.
- Keep changes minimal and prefer existing patterns.
- Avoid adding helpers, scripts, or cleanup work unless requested.

## Project Plans

- Read `docs/server-migration.md` before changing CHM infrastructure, IAP, Cloud Run, app routing, login, or Explorer integration behavior.
- Read `docs/terraform-planning.md` before adding or changing Terraform.
- Read `docs/deploy.md` before building images, pushing images, applying Terraform, or updating Dynadot DNS.
