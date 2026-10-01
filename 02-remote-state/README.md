# 02 – Remote state

Move the state file from your laptop to an Azure storage account, log in to it with Entra ID instead of a key, and see locking and versioning in action.

**Time:** about 1 hour. **Cost:** the state storage account stays (a state file is a few KB). The lab resources are destroyed at the end.

## Why

In project 01 the state was `terraform.tfstate` on your laptop. Microsoft's guide lists three problems with that:

- It doesn't work in a team or a pipeline: nobody else can see it.
- It contains secrets in plain text (you saw `primary_access_key`).
- It's easy to delete by accident, and then Terraform forgets what it manages.

A **backend** tells Terraform where to keep the state. The `azurerm` backend stores it as a blob in a storage account, and supports locking.

## What you learn

- Why the state storage is created *outside* Terraform (the chicken-and-egg problem)
- The `backend "azurerm"` block, and logging in with Entra ID instead of an access key
- Data plane vs management plane permissions (why Owner isn't enough to read blobs)
- State locking: what happens when two runs overlap
- Blob versioning as an undo for the state file
- Migrating an existing local state with `terraform init -migrate-state`

## Files

| File | Purpose |
|------|---------|
| `backend.tf` | Where the state lives. You fill in the storage account name |
| `main.tf` | Providers and resources, same as 01 but named `-02` |
| `variables.tf`, `outputs.tf` | Same as 01 |

## Steps

Open a terminal in this folder and check you're logged in:

```powershell
cd E:\Claude\projects\azure-terraform-labs\02-remote-state
az account show --query name -o tsv   # should print sub-msdn-jeetan
```

### 1. Create the state storage (once, with the Azure CLI)

Terraform needs somewhere to store state *before* it can create anything. So the storage for the state can't be created by the same configuration it stores. This is the chicken-and-egg problem. The common fix is to create it once with the CLI.

Run these one at a time in the same PowerShell window, and read what each does:

```powershell
$location = "westeurope"
$rg = "rg-tfstate"
$sa = "sttfstate" + (Get-Random -Minimum 10000 -Maximum 99999)
$sa    # write this name down, you need it in step 2 and in later projects
```
Sets variables. Storage account names must be globally unique, hence the random number.

```powershell
az group create --name $rg --location $location
```
A separate resource group for state, so destroying a lab never touches it.

```powershell
az storage account create --name $sa --resource-group $rg --location $location `
  --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 `
  --allow-blob-public-access false --allow-shared-key-access false
```
The storage account. `--allow-shared-key-access false` turns off access keys completely, so the only way in is Entra ID with the right role. HashiCorp marks access keys as "not recommended for new workloads".

```powershell
az storage account blob-service-properties update --account-name $sa --resource-group $rg --enable-versioning true
```
Turns on blob versioning. Every time Terraform writes the state, Azure keeps the previous version. If the state ever gets damaged, you can restore an older one.

```powershell
az storage container-rm create --storage-account $sa --resource-group $rg --name tfstate --public-access off
```
The container that will hold the state blobs. `container-rm` creates it through Azure Resource Manager, which works even though keys are disabled and you have no data access yet.

```powershell
$me = az ad signed-in-user show --query id -o tsv
$scope = (az storage account show --name $sa --resource-group $rg --query id -o tsv) + "/blobServices/default/containers/tfstate"
az role assignment create --role "Storage Blob Data Contributor" `
  --assignee-object-id $me --assignee-principal-type User --scope $scope
```
Gives **you** read/write access to blobs in that one container.

Why this is needed: being Owner of the subscription lets you *manage* the storage account (management plane), but not read or write the *data* inside it (data plane). Microsoft's docs are explicit: only roles defined for data access, like Storage Blob Data Contributor, give access to blob data through Entra ID. The role is scoped to the container, the least privilege HashiCorp recommends.

Role assignments can take **up to 10 minutes** to take effect. If step 3 fails with a 403 / `AuthorizationPermissionMismatch`, wait and try again.

### 2. Point the backend at your storage account

Open `backend.tf` and replace `REPLACE_ME` with your `$sa` value.

What each setting does:
- `use_cli = true`: use your `az login` session.
- `use_azuread_auth = true`: log in to the blob with Entra ID (your role from step 1), not an access key.
- `container_name`, `key`: the container and the blob name. Each project gets its own `key`, so each project has its own state.

### 3. Init

```powershell
terraform init
```

Same as in 01 (downloads providers), plus it now connects to the backend. Look for a line saying the `azurerm` backend was successfully configured. Terraform stores the backend settings in `.terraform\`; these are names, not secrets.

### 4. Plan and apply

```powershell
terraform plan -out tfplan
terraform apply tfplan
```

Same result as project 01: 3 resources. The difference is where the state went. Check:

```powershell
Get-ChildItem terraform.tfstate*          # nothing: no local state file
az storage blob list --account-name $sa --container-name tfstate --auth-mode login --query "[].name" -o tsv
```
The second command lists `02-remote-state.tfstate`: your state, now in Azure. `--auth-mode login` makes the CLI use your Entra ID role instead of a key.

Microsoft's guide notes that with a remote backend, Terraform loads the state into memory when it needs it and never writes it to your local disk.

### 5. See locking

Terraform locks the state for every operation that could write it, so two runs can't overwrite each other's changes.

1. Terminal 1: run `terraform apply` (no plan file). It shows the plan and waits at `Enter a value:`. **Don't answer yet.**
2. In the portal: storage account > Containers > `tfstate` > `02-remote-state.tfstate`. Look at the lease status.
3. Terminal 2 (same folder): run `terraform plan`.
4. Note what terminal 2 says. Then answer `no` in terminal 1 and run `terraform plan` in terminal 2 again.

What you should learn from it: if a lock is held, a second run stops instead of continuing. HashiCorp's docs say Terraform won't continue if it can't get the lock. `terraform force-unlock <LOCK_ID>` exists for when a lock gets stuck (for example after a crash), but only use it on your own lock.

### 6. See versioning

Change a tag in `variables.tf` (for example `owner`), then `terraform plan -out tfplan` and `terraform apply tfplan`. In the portal, open the state blob and select **Versions**. You'll see the previous version of the state kept next to the current one.

### 7. Optional: migrate project 01's local state

This is how you move an existing project to remote state without losing track of its resources.

1. Copy `backend.tf` into `01-first-deployment` and change `key` to `"01-first-deployment.tfstate"`.
2. In the 01 folder run `terraform init -migrate-state`. Terraform sees the backend changed and offers to copy the existing local state to the new backend. Answer `yes`.
3. Run `terraform plan`. It should say `No changes`: same resources, same state, different location.

If you already destroyed 01, the state you migrate is empty; the steps still work and show the same prompts.

### 8. Clean up

```powershell
terraform destroy
```

This deletes the lab resources (`rg-tflab-02`), not the state storage. **Keep `rg-tfstate`**: projects 03 and 04 use it. The state blob stays behind with an empty state, which is fine.

## Done when

- [ ] You can explain why the state storage is created with the CLI, not with Terraform
- [ ] You can explain management plane vs data plane, and why Owner isn't enough
- [ ] You saw your state blob in Azure and no local `terraform.tfstate`
- [ ] You saw what happens when two runs want the same lock
- [ ] You saw an older version of the state blob
- [ ] `rg-tflab-02` is gone, `rg-tfstate` still exists

## References

- [Backend type: azurerm (HashiCorp)](https://developer.hashicorp.com/terraform/language/backend/azurerm)
- [State locking (HashiCorp)](https://developer.hashicorp.com/terraform/language/state/locking)
- [terraform init: backend initialization (HashiCorp)](https://developer.hashicorp.com/terraform/cli/commands/init)
- [Store Terraform state in Azure Storage (Microsoft Learn)](https://learn.microsoft.com/azure/developer/terraform/store-state-in-azure-storage) (uses an access key; this lab follows HashiCorp's Entra ID recommendation instead)
- [Authorize access to blobs with Microsoft Entra ID (Microsoft Learn)](https://learn.microsoft.com/azure/storage/blobs/authorize-access-azure-active-directory)
- [Assign an Azure role for access to blob data (Microsoft Learn)](https://learn.microsoft.com/azure/storage/blobs/assign-azure-role-data-access)
