# 04 – GitHub Actions with OIDC

Let GitHub run Terraform for you. When you open a pull request, GitHub runs `terraform plan` and posts the result in the PR. When you merge, GitHub runs `terraform apply`. GitHub logs in to Azure without any password or key stored anywhere.

**Time:** about 2 hours. **Cost:** a few cents for the lab storage account (deleted at the end). Pipeline runs on GitHub's standard runners are free for public repos.

## The picture (explained simply)

**GitHub Actions is a robot.** It lives on GitHub. When something happens in your repo (a PR is opened, something is merged), the robot starts a fresh, empty computer, follows a list of instructions, and throws the computer away afterwards. That list of instructions is the **workflow**: a YAML file in `.github/workflows/`. YAML is just a text format for settings, like a shopping list with indentation.

**The robot needs to get into Azure.** Normally you'd give it a password. But a password stored in GitHub can leak, and it never expires on its own.

**OIDC is a visitor badge instead of a password.** OIDC stands for OpenID Connect. Every time the robot runs, GitHub prints it a fresh badge saying "I am a run from repo `azure-terraform-labs`, for a pull request". GitHub's docs call it short-lived: it's only valid for that one job, then it expires. The robot shows the badge at Azure's door.

**The managed identity is the robot's account in Azure.** It's like an employee account, but for a program instead of a person. It has no password at all. You give it roles (what it's allowed to do), just like you'd give a user.

**The federated credential is the guest list at Azure's door.** It says: "Let in anyone who shows a badge from GitHub, *but only* if the badge says it's from this exact repo, and from a pull request (or from `main`)." If the badge doesn't match the guest list exactly, the door stays shut.

So in the end: GitHub prints a badge → Azure checks the guest list → Azure lets the robot in as the managed identity → Terraform runs with that identity's roles. No password anywhere.

## What you'll build

```
You open a PR ──► robot runs: fmt check, init, validate, plan ──► posts plan as a PR comment
You merge PR  ──► robot runs: init, plan, apply                ──► resources appear in Azure
```

| Piece | Where | Name |
|-------|-------|------|
| Managed identity (robot's account) | Azure, `rg-tfstate` | `id-github-tflabs` |
| Federated credential for PRs | on the identity | `github-pull-request` |
| Federated credential for `main` | on the identity | `github-main` |
| Role: create and change resources | whole subscription | Contributor |
| Role: read and write the state blob | `tfstate` container | Storage Blob Data Contributor |
| Repo variables (who to log in as) | GitHub repo settings | `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` |
| Workflow | repo | `.github/workflows/terraform-04.yml` |
| Terraform code | repo | `04-github-actions/` |

## Your repo's badge text (subject)

GitHub changed the badge format for repos created after 15 July 2026. Your repo is newer, so its badges include ID numbers. **Almost every tutorial online shows the old format, which would not work for you.**

| When | Badge text (subject) |
|------|----------------------|
| Pull request | `repo:Jeetan-Paul@292231152/azure-terraform-labs@1400549836:pull_request` |
| Push to `main` (after a merge) | `repo:Jeetan-Paul@292231152/azure-terraform-labs@1400549836:ref:refs/heads/main` |

`292231152` is your GitHub account's ID number, `1400549836` is the repo's. You can check the prefix yourself:

```powershell
gh api repos/Jeetan-Paul/azure-terraform-labs/actions/oidc/customization/sub
```

## Steps

### 1. Log in to Azure

```powershell
az login --tenant "4017b86f-a08b-45f8-949e-5982125883a1"
az account set --subscription "sub-msdn-jeetan"
```

### 2. Make sure Azure can create managed identities

```powershell
az provider register --namespace Microsoft.ManagedIdentity --wait
```

- A **resource provider** is the part of Azure that handles one kind of resource. `Microsoft.ManagedIdentity` handles managed identities.
- On a new subscription, some providers are switched off until you **register** (switch on) them. If it's already on, this does nothing.
- `--wait`: wait until it's done instead of returning immediately.

### 3. Create the robot's account (managed identity)

```powershell
$rg = "rg-tfstate"
$id = "id-github-tflabs"
az identity create --name $id --resource-group $rg --location westeurope
```

- `$rg` and `$id` are PowerShell variables: short names so you don't have to retype long values.
- `az identity create` makes a **user-assigned managed identity**. "User-assigned" means it's a separate resource you create and manage yourself (the other kind is built into a VM or app and dies with it).
- It goes in `rg-tfstate` because that resource group holds the things the pipeline depends on. Destroying a lab can't touch it.

Now collect the IDs you need later:

```powershell
$clientId    = az identity show --name $id --resource-group $rg --query clientId -o tsv
$principalId = az identity show --name $id --resource-group $rg --query principalId -o tsv
$tenantId    = az account show --query tenantId -o tsv
$subId       = az account show --query id -o tsv
$clientId; $principalId; $tenantId; $subId
```

- `--query clientId -o tsv`: pick one field from the output and print it as plain text (`tsv` = tab-separated values).
- **Client ID**: the identity's "username". The robot says "I want to log in as this one".
- **Principal ID** (also called object ID): the identity's ID *inside Entra ID*. Roles are given to this ID.
- **Tenant ID**: your Entra ID directory (your organisation's user database).
- **Subscription ID**: which subscription Terraform works in.
- The last line prints all four so you can see them. Keep this PowerShell window open: the variables disappear when it closes.

### 4. Write the guest list (two federated credentials)

```powershell
$prefix = "repo:Jeetan-Paul@292231152/azure-terraform-labs@1400549836"

az identity federated-credential create --name github-pull-request `
  --identity-name $id --resource-group $rg `
  --issuer "https://token.actions.githubusercontent.com" `
  --subject "${prefix}:pull_request" `
  --audiences "api://AzureADTokenExchange"

az identity federated-credential create --name github-main `
  --identity-name $id --resource-group $rg `
  --issuer "https://token.actions.githubusercontent.com" `
  --subject "${prefix}:ref:refs/heads/main" `
  --audiences "api://AzureADTokenExchange"
```

- `--issuer`: *who prints the badges*. This is GitHub's badge printer address. Azure only accepts badges from here.
- `--subject`: *what the badge must say*. Must match exactly, character for character.
- `--audiences`: *who the badge is meant for*. `api://AzureADTokenExchange` is the value Microsoft recommends; it means "this badge is meant to be exchanged at Azure's door".
- `${prefix}` with curly braces: in PowerShell, `$prefix:` (with a colon right after) would confuse PowerShell, so the braces mark where the variable name ends.
- Run them **one after the other**, not at the same time: Microsoft's docs say creating two at once on the same identity fails with a 409 Conflict error.
- The backtick `` ` `` at the end of a line means "the command continues on the next line".

**Important:** Microsoft warns that a wrong subject is saved without any error. You only find out later, when the robot's login fails. Double-check with:

```powershell
az identity federated-credential list --identity-name $id --resource-group $rg --query "[].{name:name, subject:subject}" -o table
```

### 5. Give the robot permissions (roles)

```powershell
az role assignment create --role "Contributor" `
  --assignee-object-id $principalId --assignee-principal-type ServicePrincipal `
  --scope "/subscriptions/$subId"
```

- **Contributor** on the subscription: the robot may create, change and delete resources (but not hand out permissions to others).
- `--assignee-principal-type ServicePrincipal`: a managed identity is a kind of "service principal" (an account for a program). Saying so up front avoids an error when the brand-new identity isn't fully known everywhere in Entra ID yet.
- For a lab this is fine. In a company you'd give it much less, for example only one resource group.

```powershell
$scope = (az storage account show --name sttfstate23461 --resource-group $rg --query id -o tsv) + "/blobServices/default/containers/tfstate"
az role assignment create --role "Storage Blob Data Contributor" `
  --assignee-object-id $principalId --assignee-principal-type ServicePrincipal `
  --scope $scope
```

- Same role you gave yourself in project 02: read and write the state files in the `tfstate` container. Contributor alone isn't enough, because that's the *management plane* and state files are *data plane*.

### 6. Tell GitHub who to log in as (repo variables)

```powershell
cd E:\Claude\projects\azure-terraform-labs
gh variable set AZURE_CLIENT_ID --body $clientId
gh variable set AZURE_TENANT_ID --body $tenantId
gh variable set AZURE_SUBSCRIPTION_ID --body $subId
gh variable list
```

- `gh variable set NAME --body VALUE`: store a setting in your GitHub repo. The workflow reads it as `${{ vars.NAME }}`.
- **Why variables and not secrets?** These IDs aren't passwords. Knowing them doesn't let anyone in; only a badge that matches the guest list does. Microsoft's own guide calls these values the managed identity's Client ID, Subscription ID and Tenant ID, not credentials.
- Repo variables work in a private repo on GitHub Free (only organisation-level and environment-level ones don't).

### 7. Read the workflow file

Open [../.github/workflows/terraform-04.yml](../.github/workflows/terraform-04.yml). The comments in it explain each part. The key bits:

- **`on:`** when the robot starts: on a `pull_request` to `main`, and on a `push` to `main` (a merge is a push to `main`). `paths:` means: only if something in `04-github-actions/` or the workflow file itself changed.
- **`permissions:`** what the robot's GitHub key may do. `id-token: write` is the one that lets it ask for a badge. `pull-requests: write` lets it post the comment. Everything not listed is switched off.
- **`env:`** settings for every step. `ARM_USE_OIDC: "true"` tells Terraform "log in with the badge". The `ARM_...` values come from your repo variables.
- **`jobs:`** two jobs. `plan` only runs for pull requests (`if: github.event_name == 'pull_request'`), `apply` only after a merge (`if: github.event_name == 'push'`).
- **`steps:`** the instructions, in order. `uses:` runs a ready-made action (`actions/checkout@v7` copies your code onto the robot's computer, `hashicorp/setup-terraform@v4` installs Terraform 1.16.4). `run:` runs a command.

Also look at [backend.tf](backend.tf): it has **no** `use_cli` line. The pipeline logs in with the badge (`ARM_USE_OIDC`), and on your own PC you'd set `$env:ARM_USE_CLI = "true"`. Same code, two ways to log in.

### 8. Create the lock file

```powershell
cd E:\Claude\projects\azure-terraform-labs\04-github-actions
terraform init -backend=false
```

- `-backend=false`: download the providers but **don't** connect to the state storage (not needed for this).
- This creates `.terraform.lock.hcl`, which pins the provider versions. Commit it, so the robot uses exactly the same versions you tested with.

### 9. Open a pull request and watch the robot plan

```powershell
cd E:\Claude\projects\azure-terraform-labs
git switch -c feature/lab-04-pipeline
git add 04-github-actions .github
git status
git commit -m "Add lab 04 GitHub Actions pipeline"
git push -u origin feature/lab-04-pipeline
gh pr create --fill --base main
gh pr checks --watch
```

- `git status` before committing: check that only `04-github-actions/...` and `.github/workflows/terraform-04.yml` are staged, and no `.terraform/` folder.
- `gh pr checks --watch`: shows the robot's progress live, until it finishes.
- When it's green, open the PR (`gh pr view --web`). You'll find a comment from **github-actions** with the plan: `Plan: 3 to add, 0 to change, 0 to destroy.`
- On the GitHub website, the **Actions** tab shows every run. Click one to see each step's output.

**If it fails at Init or Plan with `AADSTS70021: No matching federated identity record found`:** the badge didn't match the guest list. Either the subject has a typo (check step 4's list command against the table above), or the guest list hasn't spread through Azure yet. Microsoft's docs say this can take a few minutes. Wait, then re-run: `gh run rerun --failed`.

### 10. Merge and watch the robot apply

```powershell
gh pr merge --squash --delete-branch
git pull
gh run list --workflow terraform-04.yml --limit 3
gh run watch
```

- Merging puts the change on `main`. That's a push to `main`, so the `apply` job starts.
- `gh run list`: the latest runs of this workflow. `gh run watch`: follow the running one live.
- When it's done, check Azure:
  ```powershell
  az group show --name rg-tflab-04 --query "{name:name, tags:tags}" -o json
  ```

You didn't run `terraform apply` yourself. The robot did, with its own identity, after a reviewed plan.

### 11. Change something through the pipeline

The everyday flow from now on:

1. `git switch -c fix/lab-04-tag`
2. In `04-github-actions/variables.tf`, change `owner` to something else.
3. Commit, push, `gh pr create --fill --base main`, `gh pr checks --watch`.
4. Read the plan comment: `~ update in-place`, `0 to add, 2 to change, 0 to destroy`.
5. Merge, `git pull`, `gh run watch`.

### 12. Clean up, the IaC way

With a pipeline, you don't run `destroy` by hand. You remove the code, and the pipeline removes what the code described.

1. `git switch -c chore/lab-04-teardown`
2. Delete the three `resource` blocks from `main.tf` (`random_string`, `azurerm_resource_group`, `azurerm_storage_account`), and empty `outputs.tf` (the outputs point at the resources you're deleting).
3. Commit, push, open a PR. **Read the plan comment:** `Plan: 0 to add, 0 to change, 3 to destroy.` This is exactly the check from project 01: always look at the destroy count.
4. Merge. The apply job deletes the resources.
5. Check: `az group list --query "[].name" -o tsv` should no longer show `rg-tflab-04`.

**Keep** `id-github-tflabs`, its guest list, its roles and the repo variables. Later projects reuse them.

## Done when

- [ ] The identity has two federated credentials with your repo's new-format subjects
- [ ] A PR showed the plan as a comment from github-actions
- [ ] A merge ran `apply`, and the resources appeared in Azure without you running Terraform
- [ ] You changed something through a PR and saw `update in-place` in the plan comment
- [ ] You removed the resources through a PR and saw `3 to destroy` before merging

## Good to know for later

- **Same identity for plan and apply.** Anyone who can push a branch to this repo could edit the workflow to run `apply` with the PR badge. That's only you. Pull requests from forks get read-only permissions (so no badge), and the repo requires your approval before any external contributor's workflow runs. In a team you'd still give the PR badge a separate identity with read-only roles.
- **No approval step yet.** Project 08 adds one with environments and required reviewers, which GitHub Free offers for public repos.

## References

- [OpenID Connect reference, subject formats and immutable subjects (GitHub Docs)](https://docs.github.com/en/actions/reference/security/oidc)
- [Federated identity credential on a user-assigned managed identity (Microsoft Learn)](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-create-trust-user-assigned-managed-identity)
- [Workload identity federation considerations, AADSTS70021 (Microsoft Learn)](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-considerations)
- [azurerm provider: authenticating with OIDC (HashiCorp)](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_oidc) (note: its subject example says `refs:`, GitHub's docs say `ref:`)
- [azurerm backend: OIDC settings (HashiCorp)](https://developer.hashicorp.com/terraform/language/backend/azurerm)
- [Workflow syntax (GitHub Docs)](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
- [Using GitHub CLI in workflows (GitHub Docs)](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-github-cli)
- [Variables (GitHub Docs)](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-variables)
