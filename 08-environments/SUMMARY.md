# 08 – What I learned

## The idea, simply

- **One recipe, three kitchens:** dev = test kitchen, test = staff meal, prod = dining room. The same Terraform code runs everywhere; only the amounts differ, in `envs/<env>.tfvars`.
- **A GitHub Environment is a door with rules.** dev and test have no lock. prod only opens when I approve, and only for runs from `main`.
- **Each environment has its own state file** (`08-environments-dev.tfstate`, `-test`, `-prod`), so a change or mistake in dev can't touch prod's state.

## What I did (13 Oct 2026, West Europe)

| PR | Change | dev | test | prod |
|----|--------|-----|------|------|
| #16 | Add lab 08 | 5 added | 5 added | 8 added, after my approval |
| #17 | `snet-web` in `prod.tfvars` only | No changes | No changes | 3 added, after my approval |
| #18 | Teardown | 5 destroyed | 5 destroyed | 11 destroyed, after my approval |

Before the first PR:
- **Three guest list lines** on `id-github-tflabs`: `github-env-dev`, `-test`, `-prod`, with subject `...:environment:<env>`.
- **Three GitHub Environments** created with `gh api`. prod: reviewer = me, self-review allowed, branch policy `main`.

## New things

- **`strategy: matrix`** turns one `plan` job into three (`plan (dev)`, `plan (test)`, `plan (prod)`) that run side by side. `fail-fast: false` lets all three finish even if one fails.
- **`environment: prod`** on a job makes it wait for prod's rules before it starts. It also changes the OIDC badge from `:ref:refs/heads/main` to `:environment:prod`, which is why the guest list needed three new lines.
- **`needs: apply-test`**: start only after that job succeeds. dev → test → prod, one after the other.
- **Partial backend configuration:** `backend.tf` has no `key`. It's given at init: `terraform init -backend-config="key=08-environments-dev.tfstate"`.
- **`merge(var.tags, { environment = var.environment })`** gives every resource an `environment` tag.
- **`.gitignore` exception:** `!08-environments/envs/*.tfvars`. The `!` means "don't ignore". Without it, the tfvars files would never have reached GitHub.
- **`terraform init -backend=false`** makes the lock file without connecting to state.

## Three locks on prod

1. Nobody can push straight to `main` (ruleset from lab 05).
2. Only `main` may deploy to prod (branch policy).
3. Every run stops at prod until someone approves it, even when it only deletes.

## Things that surprised me

- **Deleting needs approval too.** The teardown waited at prod just like a deploy.
- **dev and test still run when nothing changed for them.** Their plan says `No changes`, and apply says `0 added, 0 changed, 0 destroyed`.
- **Leftover tfvars only give warnings** after the variables are removed: `Value for undeclared variable`. The pipeline still passes them, so they have to stay until the folder is gone.
- **No `concurrency` in the workflow, on purpose.** GitHub's docs say a newer run cancels a waiting one, and a prod deploy waiting for approval counts as waiting.

## Why one codebase beats three copies

With three copied folders, every fix has to be made three times, and it's easy to forget one. Then prod quietly drifts away from what you tested in dev. With one codebase, dev tests exactly the code that prod will run. Only the values in the tfvars files differ, and you can see those differences side by side.

## Cost

Resource groups, VNets, subnets and NSGs are free. Only pennies for the state storage.
