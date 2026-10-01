# 02 – What I learned

## My state storage

| Item | Value |
|------|-------|
| Resource group | `rg-tfstate` (West Europe) |
| Storage account | `sttfstate23461`: access keys off, no public access, TLS 1.2, blob versioning on |
| Container | `tfstate` |
| My access | Storage Blob Data Contributor, scoped to the `tfstate` container |
| State blobs | One per project, named by the backend `key`: `01-first-deployment.tfstate`, `02-remote-state.tfstate` |

Keep `rg-tfstate`. Later projects use it.

## Key ideas

- **Backend:** tells Terraform where the state lives. The `azurerm` backend stores it as a blob. No `terraform.tfstate` appears in the project folder any more.
- **Chicken and egg:** the state storage is created with the Azure CLI, not with Terraform, because Terraform needs somewhere to store state before it can create anything.
- **Entra ID instead of keys:** `use_cli = true` and `use_azuread_auth = true` log in with my `az login` session and my role. HashiCorp marks access keys as not recommended for new workloads.
- **Management plane vs data plane:** Owner lets me manage the storage account, but not read its blobs. Reading and writing blob data needs a data role such as Storage Blob Data Contributor. Role assignments can take up to 10 minutes to work.
- **Least privilege:** the role is on the container only, not the account or subscription.
- **`container-rm`:** creates a container through Azure Resource Manager, which works when keys are off and you don't have a data role yet.
- **`key`:** the blob name for a project's state. Every project needs its own key; two projects sharing a key would share a state and try to delete each other's resources.

## Locking

Every operation that can write state takes a lock (a lease on the blob). A second run stops with `Error acquiring the state lock` and shows the Lock Info: ID, path, operation, who, when. If a lock gets stuck after a crash: `terraform force-unlock <ID>`, only for my own lock.

## Versioning

Every write to the state blob keeps the previous version. See them with `az storage blob list ... --include v` or the blob's **Versions** tab in the portal. It's a way back when the state gets damaged, but a restored version must still match what is really in Azure.

## Migrating state

`terraform init -migrate-state` copies the existing state to a new backend. When a backend changes, Terraform requires `-migrate-state` (copy) or `-reconfigure` (start fresh). It only asks for confirmation when the local state has resources; an empty state needs no migration.

## Commands

| Command | What it does |
|---------|--------------|
| `terraform init` | Downloads providers and connects to the backend |
| `terraform init -migrate-state` | Moves existing state to a new backend |
| `terraform force-unlock <ID>` | Removes a stuck lock |
| `az storage blob list --account-name sttfstate23461 --container-name tfstate --auth-mode login -o table` | Lists the state blobs using my Entra ID role |
| `az role assignment list --assignee <object id> --all` | Shows my role assignments, including container-level ones |

In the portal, a container-level role shows under the container's own Access Control (IAM), not the storage account's.
