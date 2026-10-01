# 04 – What I learned

## The idea, simply

- **GitHub Actions is a robot.** When something happens in the repo, it starts a fresh computer, follows the workflow file, and throws the computer away.
- **The workflow** (`.github/workflows/terraform-04.yml`) is the robot's instruction list, written in YAML.
- **OIDC is a visitor badge instead of a password.** Each run, GitHub gives the robot a short-lived badge that's only valid for that one job.
- **The managed identity** (`id-github-tflabs`) is the robot's account in Azure. It has no password at all.
- **The federated credentials** are the guest list at Azure's door: they say which badges to let in.
- **Roles** decide what the robot may do once it's inside.

No password or key is stored anywhere: not in GitHub, not in Azure.

## What I built

| Piece | Where | Value |
|-------|-------|-------|
| Robot's account | `rg-tfstate` | `id-github-tflabs` |
| Guest list line for PRs | on the identity | `github-pull-request` → `repo:Jeetan-Paul@292231152/azure-terraform-labs@1396286466:pull_request` |
| Guest list line for `main` | on the identity | `github-main` → `repo:Jeetan-Paul@292231152/azure-terraform-labs@1396286466:ref:refs/heads/main` |
| Role to build things | whole subscription | Contributor (can't hand out permissions) |
| Role for state files | `tfstate` container | Storage Blob Data Contributor |
| Repo variables | GitHub repo | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |

Keep all of this. Later projects reuse it.

## How it runs

```
Open a PR   ─► robot: fmt check, init, validate, plan ─► plan posted as a PR comment
Merge to main ─► robot: init, plan, apply              ─► Azure changes
```

The PR run's badge says `pull_request`, the merge run's badge says `ref:refs/heads/main`. Each matches its own line on the guest list.

## What I did

| PR | Change | Plan said |
|----|--------|-----------|
| #3 | Add the pipeline and lab 04 code | 3 to add |
| #4 | Change the `owner` tag | 0 to add, 2 to change (update in-place) |
| #5 | Remove the resource blocks | 3 to destroy |

All applies were done by the robot. I never ran `terraform apply` myself.

## Things to remember

- **New repos use a new badge format.** Repos created after 15 July 2026 put the account and repo ID numbers in the badge (`Jeetan-Paul@292231152/...@1396286466`). Most tutorials show the old format, which would be refused. Check a repo's format with `gh api repos/OWNER/REPO/actions/oidc/customization/sub`.
- **A wrong guest list line is saved without error.** You only find out when the login fails with `AADSTS70021: No matching federated identity record found`. Compare subjects character by character.
- **Create guest list lines one at a time.** Two at once on the same identity fails with 409 Conflict.
- **Contributor isn't enough for state files.** State is data plane, so the robot also needs Storage Blob Data Contributor, just like I did in project 02.
- **The IDs aren't secrets.** Client, tenant and subscription IDs only say who to log in as. They go in repo variables, not secrets.
- **Tearing down the IaC way:** remove the resource blocks (and outputs that point at them), keep the providers, check that the plan says exactly the number of destroys you expect, then merge.
- **Read the plan comment before every merge.** It's the review: it shows exactly what the robot is about to do.

## Commands

| Command | What it does |
|---------|--------------|
| `gh pr checks --watch` | Follow the robot's jobs on the current PR until they finish |
| `gh run list --workflow terraform-04.yml --limit 3` | The latest runs of this workflow |
| `gh run watch` | Follow a running workflow live |
| `gh run rerun --failed` | Run the failed jobs again (for example after waiting for the guest list to spread) |
| `gh variable list` | Show the repo variables |
| `az identity federated-credential list --identity-name id-github-tflabs -g rg-tfstate -o table` | Show the guest list |

## Still open for later

- PR runs and `main` runs use the same identity with Contributor. In a team, the PR badge would get a separate, read-only identity.
- No approval step before apply: private repos on GitHub Free don't get environments with required reviewers. Decide on public or GitHub Pro before project 08.
