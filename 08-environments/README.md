# 08 – Environments

One set of Terraform code, three environments: **dev**, **test** and **prod**. Each has its own settings and its own state. The pipeline deploys them one after the other, and **waits for your approval** before it touches prod.

**Time:** about 2 hours. **Cost:** nothing. Only resource groups, virtual networks, subnets and NSGs, which are free. The repo is public, so GitHub's approval feature is free too.

## The picture (explained simply)

Think of a restaurant trying a new dish.

- **dev** is the test kitchen. The chef tries things; if it goes wrong, nobody notices.
- **test** is the staff meal. Real people eat it, but no paying guests.
- **prod** (production) is the dining room with paying guests. A mistake here really hurts.

The **recipe is the same** in all three (the Terraform code). What differs is how much you make, and for whom (the settings per environment). And before a new dish goes to the dining room, the **head chef tastes it and says yes** (the approval).

## What's new

| Idea | Where | What it does |
|------|-------|--------------|
| **tfvars per environment** | `envs/dev.tfvars`, `test.tfvars`, `prod.tfvars` | The settings that differ: address range and subnets. The code reads them with `-var-file`. |
| **State per environment** | `backend.tf` has no `key` | Each environment gets its own state file: `08-environments-dev.tfstate` and so on. Given at init with `-backend-config="key=..."`. |
| **Validation** | `variables.tf` | `environment` may only be `dev`, `test` or `prod`. Anything else stops Terraform before it does anything. |
| **GitHub Environments** | GitHub repo settings | `dev`, `test` and `prod` as named targets. `prod` has a **required reviewer** (you) and only allows deploys from `main`. |
| **Matrix** | `terraform-08.yml`, `plan` job | One job definition that runs three times, once per environment, side by side. |
| **`needs`** | `apply-test`, `apply-prod` | Wait for the previous job: dev, then test, then prod. |

### Why not three folders?

You could copy the code into `dev/`, `test/` and `prod/`. But then a change has to be made three times, and sooner or later the copies drift apart: prod gets a fix that dev never had. **One codebase with different settings** means what you tested in dev is exactly what goes to prod. Only the values differ, and those are in small, readable files.

### Why a separate state per environment?

If dev and prod shared one state file, a mistake in dev could make Terraform think prod's resources belong to dev, and try to change them. Separate state files are like separate notebooks: dev can't accidentally read or overwrite prod's.

### The badge changes when a job uses an environment

GitHub's OIDC docs say: when a job references an environment, the badge (subject) contains the **environment's name** instead of the branch. So:

| Job | Badge text (subject) |
|-----|----------------------|
| `plan` (no environment) | `repo:Jeetan-Paul@292231152/azure-terraform-labs@1400549836:pull_request` (already on the guest list) |
| `apply-dev` | `...:environment:dev` **(new)** |
| `apply-test` | `...:environment:test` **(new)** |
| `apply-prod` | `...:environment:prod` **(new)** |

That means three new lines on Azure's guest list (step 1). The robot's account and roles stay the same.

## Steps

### 1. Add three lines to the guest list

```powershell
az login --tenant "4017b86f-a08b-45f8-949e-5982125883a1"
az account set --subscription "sub-msdn-jeetan"
$prefix = "repo:Jeetan-Paul@292231152/azure-terraform-labs@1400549836"

foreach ($e in "dev", "test", "prod") {
  az identity federated-credential create --name "github-env-$e" `
    --identity-name id-github-tflabs --resource-group rg-tfstate `
    --issuer "https://token.actions.githubusercontent.com" `
    --subject "${prefix}:environment:$e" `
    --audiences "api://AzureADTokenExchange"
}
```

- `foreach ($e in "dev", "test", "prod") { ... }`: a PowerShell **loop**. It runs the command three times, with `$e` as `dev`, then `test`, then `prod`.
- One at a time, not all at once: Microsoft's docs say creating several on the same identity at the same moment fails with a 409 Conflict. A `foreach` runs them one after the other, which is fine.
- A managed identity can have up to 20 guest list lines (Microsoft's docs). After this you have 5.

Check, and compare the subjects character by character:

```powershell
az identity federated-credential list --identity-name id-github-tflabs -g rg-tfstate --query "[].{name:name, subject:subject}" -o table
```

### 2. Create the three GitHub Environments

```powershell
cd E:\Claude\projects\azure-terraform-labs
gh api --method PUT repos/Jeetan-Paul/azure-terraform-labs/environments/dev
gh api --method PUT repos/Jeetan-Paul/azure-terraform-labs/environments/test
gh api --method PUT repos/Jeetan-Paul/azure-terraform-labs/environments/prod --input .github/environments/prod.json
gh api --method POST repos/Jeetan-Paul/azure-terraform-labs/environments/prod/deployment-branch-policies -f name=main -f type=branch
```

- `--method PUT`: create, or update if it already exists.
- `dev` and `test`: no rules. The robot deploys there straight away.
- `prod` gets [.github/environments/prod.json](../.github/environments/prod.json):
  - `reviewers`: you (`292231152` is your GitHub account's ID number). GitHub's docs: only one of the required reviewers needs to approve.
  - `prevent_self_review: false`: you may approve a run you started yourself. With only one person, that has to be allowed. In a team you'd set it to `true`, so nobody can approve their own change.
  - `wait_timer: 0`: no extra waiting time after approval.
  - `custom_branch_policies: true`: only branches matching a pattern may deploy to prod.
- The last command adds that pattern: `main`. Only runs from `main` may deploy to prod.
- `-f name=main -f type=branch`: `-f` sends a field in the request; here the pattern `main`, of type branch.

Check on GitHub: repo **Settings** > **Environments**. You'll see `dev`, `test` and `prod`, with prod showing a reviewer and the branch rule.

### 3. Read the code

- [main.tf](main.tf): one resource group and one `module "network"` (your vnet module from project 06). Names include `${var.environment}`, so each environment gets its own: `rg-tflab-08-dev`, `vnet-tflab-08-prod`.
- `local.tags = merge(var.tags, { environment = var.environment })`: `merge` combines two maps, so every resource also gets an `environment` tag.
- [envs/prod.tfvars](envs/prod.tfvars): prod gets an extra subnet `snet-data`. Dev and test don't.
- [backend.tf](backend.tf): no `key`.
- [.gitignore](../.gitignore): normally all `*.tfvars` are ignored, because they often contain secrets. Line `!08-environments/envs/*.tfvars` makes an exception (`!` means "don't ignore"), because these only contain address ranges and the pipeline needs them.

Open [.github/workflows/terraform-08.yml](../.github/workflows/terraform-08.yml):

- `plan` has `strategy: matrix: tf_env: [dev, test, prod]`: GitHub makes **three** jobs from it, one per value. `${{ matrix.tf_env }}` is that value. `fail-fast: false`: if one plan fails, the others still finish, so you see all three results.
- `apply-dev` has `environment: dev`, `apply-test` has `needs: apply-dev` and `environment: test`, and `apply-prod` has `needs: apply-test` and `environment: prod`. **`needs`** = "start only when that job has succeeded". If dev fails, test and prod don't even start.
- GitHub's docs: all protection rules must pass **before** a job that references the environment is sent to a runner. So `apply-prod` waits for your approval **before** it starts.

### 4. Create the lock file

```powershell
cd E:\Claude\projects\azure-terraform-labs\08-environments
terraform init -backend=false
```

`-backend=false` is fine even though `backend.tf` has no `key`: without a backend connection, it isn't needed.

### 5. Pull request: three plans side by side

```powershell
cd E:\Claude\projects\azure-terraform-labs
git switch -c feature/lab-08-environments
git add 08-environments .github .gitignore README.md
git status
```

**Check in `git status`** that all three `08-environments/envs/*.tfvars` files are listed. If they're missing, the `.gitignore` exception didn't work.

```powershell
git commit -m "Add lab 08 environments"
git push -u origin feature/lab-08-environments
gh pr create --fill --base main
gh pr checks --watch
```

You'll see the three inspectors plus **three** plan jobs, one per environment. The PR gets three plan comments:
- **dev:** `Plan: 5 to add`
- **test:** `Plan: 5 to add`
- **prod:** `Plan: 8 to add` (the extra subnet with its NSG and link)

Every resource has `environment = "dev"` (or test, prod) in its tags.

### 6. Merge, and approve prod

```powershell
gh pr merge --squash --delete-branch
git pull
git fetch --prune
```

Open the run on GitHub: repo **Actions** tab > the newest **terraform-08** run. You'll see:
1. `apply-dev` runs → green.
2. `apply-test` starts after it → green.
3. `apply-prod` shows **Waiting**. That's the pause. GitHub's docs: click **Review deployments**, select `prod`, optionally write a comment, and click **Approve and deploy**.
4. Only then does `apply-prod` run.

Check:

```powershell
az group list --query "[?starts_with(name, 'rg-tflab-08')].{name:name, env:tags.environment}" -o table
```

- `starts_with(name, 'rg-tflab-08')`: only the resource groups whose name starts with that.
- **Expect** three: `rg-tflab-08-dev`, `rg-tflab-08-test`, `rg-tflab-08-prod`, each with its environment tag.

### 7. Change only prod

The real test of "same code, different settings":

```powershell
git switch -c feature/lab-08-prod-web
```

In [envs/prod.tfvars](envs/prod.tfvars), add a line to `subnets`:

```hcl
  "snet-web"  = "10.82.3.0/24"
```

```powershell
terraform fmt -recursive
git diff
git add 08-environments/envs/prod.tfvars
git commit -m "Add web subnet to prod"
git push -u origin feature/lab-08-prod-web
gh pr create --fill --base main
gh pr checks --watch
```

The plan comments should say:
- **dev:** `No changes.`
- **test:** `No changes.`
- **prod:** `Plan: 3 to add` (subnet, NSG, link)

Merge. Dev and test run and change nothing; prod waits for you again. Approve it.

### 8. Try to skip the approval (optional)

Look at what you **can't** do anymore:
- **Push straight to `main`:** the ruleset from project 05 refuses it.
- **Deploy to prod from another branch:** the branch policy only allows `main`.
- **Skip prod's approval:** a merge always stops at `apply-prod`.

Those three together mean nothing reaches prod without passing the checks, going through `main`, and being approved.

## Clean up

1. `git switch -c chore/lab-08-teardown`
2. In `main.tf`: delete `locals`, the resource group and the `module` block. Keep `terraform` and `provider`.
3. Empty `outputs.tf` and `variables.tf`.
4. **Leave `envs/*.tfvars` as they are.** The pipeline still passes them with `-var-file`; if they were gone, it would fail. Terraform now gives **warnings** (`Value for undeclared variable`), not errors, because nothing declares those variables anymore. That was tested.
5. `fmt`, `diff`, PR. The plans: **dev 5 to destroy, test 5, prod 11** (8 + the 3 from step 7). Read all three.
6. Merge. Dev and test are destroyed; **prod waits for your approval, even for deleting**. Approve it.
7. Check: `az group list --query "[?starts_with(name, 'rg-tflab-08')].name" -o tsv` should print nothing.

Keep the three GitHub Environments and the guest list lines; they're free.

## Done when

- [ ] The guest list has `github-env-dev`, `-test` and `-prod` with the right subjects
- [ ] A PR showed three plan comments with different numbers
- [ ] `apply-prod` waited until you clicked **Approve and deploy**
- [ ] A change in `prod.tfvars` gave `No changes` for dev and test, and changes only for prod
- [ ] You can explain why one codebase with tfvars per environment beats three copies

## References

- [Deployments and environments (GitHub Docs)](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments) – required reviewers, prevent self-review
- [Reviewing deployments (GitHub Docs)](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/review-deployments) – Review deployments, Approve and deploy
- [Create or update an environment (GitHub REST API)](https://docs.github.com/en/rest/deployments/environments#create-or-update-an-environment)
- [OpenID Connect reference (GitHub Docs)](https://docs.github.com/en/actions/reference/security/oidc) – the subject includes the environment name when a job references an environment
- [Workflow syntax: environment, needs, strategy.matrix (GitHub Docs)](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
- [Backend configuration: partial configuration (HashiCorp)](https://developer.hashicorp.com/terraform/language/backend) – `-backend-config="KEY=VALUE"`
- [Input variables: validation and -var-file (HashiCorp)](https://developer.hashicorp.com/terraform/language/values/variables)
