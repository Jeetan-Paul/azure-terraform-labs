# 05 – What I learned

## The idea, simply

Three inspectors look at every pull request, and all three must say OK before GitHub lets anything into `main`.

| Inspector (check) | Looks at | Caught in my test |
|-------------------|----------|-------------------|
| **fmt-validate** | Tidy layout (`terraform fmt -check`) and valid code (`terraform validate`) | `type = string` badly aligned |
| **tflint** | Mistakes and bad habits | `variable "admin_ip" is declared but not used` |
| **checkov** | Security | `CKV_AZURE_9`: RDP open to the internet |

`terraform validate` said `Success!` the whole time. **Valid code isn't the same as tidy or safe code.**

## The rules on `main` (ruleset `protect-main`)

Written in `.github/rulesets/main.json`, sent to GitHub with:

```powershell
gh api --method POST repos/Jeetan-Paul/azure-terraform-labs/rulesets --input .github/rulesets/main.json
```

- Nothing reaches `main` except through a pull request (0 approvals needed, because I can't approve my own PR).
- Only squash merges.
- `fmt-validate`, `tflint` and `checkov` must be green.
- No force push, no deleting `main`.
- No exceptions, not even for me as the owner.

With a failing check, the PR's state was `BLOCKED` and GitHub refused the merge. After the fix it was `CLEAN`.

## Things to remember

- **Required checks and `paths:` don't mix.** A workflow skipped by a path filter leaves its required check on "Pending" forever, so the PR can never merge. The checks workflow runs on every PR.
- **Status check names are the job names** (`fmt-validate`, `tflint`, `checkov`). The ruleset refers to those names.
- **Switching a rule off is fine; doing it silently isn't.** `.tflint.hcl` turns off `azurerm_resources_missing_prevent_destroy` because lab resources must be deletable, and says so in a comment.
- **A baseline handles old problems.** `.checkov.baseline` lists the 20 known findings in labs 01 and 02. Only new findings fail. The baseline matches by resource name and check ID, not by file, so new code should use different resource names.
- **Scanners can be wrong.** Checkov flags blob public access in 01 and 02, but azurerm 5.x blocks it by default.
- **A new push to a PR's branch re-runs the checks automatically.** No new PR needed.
- **Check the merge title.** `gh pr create --fill` takes the title from the first commit. With squash, that becomes the message on `main`. Use `gh pr merge --squash --subject "..."` when the first commit's message no longer fits.
- **Squash hides the messy middle.** The bad commit and the fix became one clean commit on `main`.

## The fix

```hcl
source_address_prefix = var.admin_ip   # was "*"
```

One line fixed two findings: RDP only from one address (Checkov), and the variable is used (TFLint). `terraform fmt -recursive` fixed the layout.

## Habit

Before every commit:

```powershell
terraform fmt -recursive
```

## Commands

| Command | What it does |
|---------|--------------|
| `gh pr checks --watch` | Follow the checks on the current PR |
| `gh run view --log-failed` | Show only the output of failed steps |
| `gh pr view --json mergeStateStatus` | `BLOCKED` or `CLEAN`: can this PR be merged? |
| `gh api repos/Jeetan-Paul/azure-terraform-labs/rulesets` | List the rulesets |
| `gh pr merge --squash --delete-branch --subject "..."` | Merge with a better message |
