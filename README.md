# AMEO Marketplace

Orange County directory and marketplace for AI coaching, team training, implementation, strategy, and automation.

Test site: https://ameo-marketplace.netlify.app/

## Scope and isolation

- Netlify project: `ameo-marketplace` (`4ac631cb-ec41-4f2d-8d3c-124942c5a447`).
- Supabase: `pxlheszgngeowjvzspvt` only.
- Never deploy this repository to aimadeeasyoc.com or use AMEO Dental database `mawubzebcynzyyinszzx`.
- Database migrations are additive. Existing `crm_admins` and `leads` are preserved.
- Payments are not implemented.

## Source

`public/` is buildless HTML/CSS/JavaScript. Serve this directory with a static web server. Deploy only its contents, not database SQL, tests, docs, or evidence. `netlify.toml` sets the publish directory.

Supabase browser dependency is vendored and pinned at 2.118.0. Only the publishable key is in browser code. Authorization is enforced by row-level policies and an explicitly authenticated database action endpoint. Do not add a service-role key to frontend code.

Database application order: `database/marketplace.sql`, then `database/owner.sql`. These have already been applied to the designated project; do not run CREATE statements twice. The SQL copies are a schema/source backup, not a backup of Supabase Auth configuration or live data.

See [ROADMAP-STATUS.md](ROADMAP-STATUS.md) for the complete original roadmap with honest implementation status, and [evidence/verification.md](evidence/verification.md) for checks performed.

## Owner access

Register and verify `craigasian@gmail.com`, then complete the marketplace display-name screen. The private trigger grants that verified email the admin role. Other accounts cannot nominate themselves as admin. No owner password is stored in this repository.

## Auth configuration

Canonical Site URL and exact allowed redirect: `https://ameo-marketplace.netlify.app/`. Email signups and email confirmation are enabled; anonymous sign-in is disabled. Google is disabled. Custom SMTP/delivery was not verified. Never disable email verification to work around delivery problems.

## Deployment

Initially deployed via Netlify Drop as this previously undeployed project's first production-context deployment, with team-only visibility. Owner subsequently authorized public access. This is a test release with noindex headers and a visible test banner, not a completed commercial launch. Redeploy `public/` contents or the prepared preview ZIP through this Netlify project only.

This backup does not configure automatic deployment from GitHub. Connecting Git later requires confirming the publish directory and the intended Netlify project.
