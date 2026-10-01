# 01 – What I learned

## The commands

| Command | What it does | What changes |
|---------|--------------|--------------|
| `terraform init` | Downloads the providers listed in `required_providers` | `.terraform\` and `.terraform.lock.hcl` on disk |
| `terraform fmt` | Rewrites `.tf` files to the standard layout | Your `.tf` files |
| `terraform validate` | Checks syntax and references, without contacting Azure | Nothing |
| `terraform plan` | Compares code, state and Azure, and shows what would change | Nothing |
| `terraform plan -out tfplan` | Same, and saves the plan to a file | `tfplan` on disk |
| `terraform apply tfplan` | Carries out exactly the saved plan, without asking | Azure and the state file |
| `terraform apply` | Makes a new plan, shows it, asks for `yes` | Azure and the state file |
| `terraform destroy` | Deletes everything in the state, asks for `yes` | Azure and the state file |
| `terraform state list` / `state show` | Shows what Terraform manages, from the state file only | Nothing |
| `terraform show tfplan` | Prints a saved plan in readable form | Nothing |

## Key ideas

- **Provider:** the plugin that turns Terraform code into Azure API calls. azurerm 5.x registers no resource providers by default, so list them in `resource_providers_to_register`.
- **State file** (`terraform.tfstate`): Terraform's record of what it created. Plan compares against it. Bicep has nothing like it.
- **Sensitive values** show as `(sensitive value)` on screen, but are stored in plain text in the state file and in `tfplan`. Neither file belongs in Git.
- **Lock file** (`.terraform.lock.hcl`): pins provider versions. It does belong in Git.
- **Dependencies:** Terraform works out the order from references such as `azurerm_resource_group.lab.name`.

## Reading a plan

| Symbol | Meaning |
|--------|---------|
| `+` | create |
| `~` | update in place, the resource stays |
| `-` | delete |
| `-/+` | replace: delete, then create. Data is lost. Look for `# forces replacement` |

Always check the `to destroy` count before applying.

## Plan vs Bicep what-if

- Plan runs locally against the state file; what-if runs in Azure Resource Manager.
- A plan can be saved and applied exactly; what-if can't.
- A resource removed from Terraform code gets **deleted**; in Bicep (incremental mode) it's ignored and stays in Azure.

## Drift

Changes made by hand in the portal show up as `Objects have changed outside of Terraform`. The next apply undoes them unless you add them to the code. Once something is managed by Terraform, change it in code only.

## Login caveat on this machine

Terraform uses the Azure CLI login. The Windows broker (WAM) login left no usable token, so the CLI is set to browser login: `az config set core.enable_broker_on_windows=false`. The tenant's sign-in frequency policy expires the login after about 9 hours; run `az login` again when Terraform mentions tokens.
