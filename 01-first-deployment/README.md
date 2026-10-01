# 01 – First deployment

Deploy a resource group and a storage account from your own machine, change it, and tear it down.

**Time:** about 1 hour. **Cost:** a few cents if you destroy it the same day.

## What you learn

- The Terraform loop: `init` → `plan` → `apply` → `destroy`
- Providers and version pinning (`required_providers`, `.terraform.lock.hcl`)
- Resources, references between resources, and the dependency graph
- Variables, validation, defaults and outputs
- What the state file is and why it matters

## Files

| File | Purpose |
|------|---------|
| `main.tf` | Terraform and provider settings, the resources |
| `variables.tf` | Inputs with defaults and validation |
| `outputs.tf` | Values printed after `apply` |

Terraform reads every `.tf` file in the folder as one configuration. The file names are a convention only.

## Coming from Bicep

| Bicep | Terraform |
|-------|-----------|
| `param` | `variable` |
| `output` | `output` |
| `resource sa 'Microsoft.Storage/storageAccounts@2023-05-01'` | `resource "azurerm_storage_account" "lab"` |
| API version per resource | One provider version for everything |
| `uniqueString(resourceGroup().id)` | `random_string` resource, or your own naming |
| `what-if` | `plan` |
| Azure keeps track of what exists | Terraform keeps track in a **state file** |

The state file is the biggest difference. Terraform only manages what is in its state. If you delete the state file, Terraform forgets the resources exist, even though they are still in Azure.

## Steps

Run everything from this folder:

```powershell
cd E:\Claude\projects\azure-terraform-labs\01-first-deployment
az account show --query name -o tsv   # should print sub-msdn-jeetan
```

### 1. Init

```powershell
terraform init
```

This downloads the `azurerm` and `random` providers into `.terraform/` and writes `.terraform.lock.hcl`. Open the lock file: it records the exact provider versions and hashes, so every run uses the same versions.

### 2. Format and validate

```powershell
terraform fmt
terraform validate
```

`fmt` fixes indentation and alignment. `validate` checks syntax and references without calling Azure.

### 3. Plan

```powershell
terraform plan -out tfplan
```

Read the output. You should see `Plan: 3 to add, 0 to change, 0 to destroy.` Values marked `(known after apply)` are values Azure or the `random` provider only decide during creation.

Before each plan or apply, the provider makes sure `Microsoft.Storage` is registered, because `main.tf` lists it in `resource_providers_to_register`. Since azurerm 5.0 the provider registers nothing unless you ask.

### 4. Apply

```powershell
terraform apply tfplan
```

Applying a saved plan runs exactly what you reviewed, without asking again. Check the result in the portal, or:

```powershell
terraform output
az resource list -g rg-tflab-01 -o table
```

### 5. Look at the state

```powershell
terraform state list
terraform state show azurerm_storage_account.lab
```

A `terraform.tfstate` file now exists in this folder. Open it: it holds every attribute of every resource, including the storage account access keys. That is why `.gitignore` excludes it, and why project 02 moves it to a secured storage account.

### 6. Make a change

In `variables.tf`, add `owner = "jeetan"` to the `tags` default. Then:

```powershell
terraform plan
```

The plan shows `~ update in-place` for both resources, and only the tags change. Apply it.

### 7. Cause a replacement (plan only, don't apply)

Change `account_tier` from `"Standard"` to `"Premium"` and run `terraform plan`. The provider docs say changing `account_tier` forces a new resource, so the plan shows `-/+ destroy and then create replacement` with `# forces replacement` next to the argument. Replacement deletes the data inside. Always look for `forces replacement` in a plan before you apply. Set it back to `"Standard"` afterwards.

Don't try this with LRS → ZRS: according to the [storage account docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account#account_replication_type), that pair starts a customer-initiated migration in Azure that can take days, and Terraform doesn't wait for it.

### 8. Drift

In the portal, add a tag `manual = "yes"` to the resource group. Then run `terraform plan`. Terraform refreshes the state first and reports `Objects have changed outside of Terraform`. It then plans an in-place update to bring the resource group back in line with your code, which removes the manual tag.

### 9. Destroy

```powershell
terraform destroy
```

Type `yes`. Check that `rg-tflab-01` is gone.

## Done when

- [ ] You can explain what `init`, `plan`, `apply` and `destroy` each do
- [ ] You know what the lock file and the state file are, and which one goes in Git
- [ ] You have seen an in-place update, a replacement and drift in a plan
- [ ] Nothing from this project is left in Azure

## Extra exercises

1. Pass a variable on the command line: `terraform plan -var="prefix=test"`.
2. Create `terraform.tfvars` with `location = "northeurope"` and run `plan`. Terraform picks this file up automatically. It is in `.gitignore`.
3. Try `prefix = "Test_1"` and read the validation error.
4. Add an `azurerm_storage_container` named `data`. The v5 provider wants `storage_account_id`, not `storage_account_name`.

## References

- [Terraform on Azure: get started](https://developer.hashicorp.com/terraform/tutorials/azure-get-started)
- [azurerm provider docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [azurerm 5.0 upgrade guide](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/5.0-upgrade-guide) (most tutorials online still use 3.x or 4.x syntax)
- [azurerm_storage_account](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account)
- [terraform apply](https://developer.hashicorp.com/terraform/cli/commands/apply), [validate](https://developer.hashicorp.com/terraform/cli/commands/validate), [variable precedence and tfvars](https://developer.hashicorp.com/terraform/language/values/variables)
- [Manage resource drift](https://developer.hashicorp.com/terraform/tutorials/state/resource-drift)
