# 11 – A real workload: Container Apps

Run a real web app in Azure Container Apps, with logs in Log Analytics, deployed by the pipeline. After every deploy, the pipeline checks that the app really answers. Then ship a new version through a PR.

**Time:** about 1.5 hours. **Cost:** practically nothing. Container Apps gives every subscription a free monthly grant (180,000 vCPU-seconds, 360,000 GiB-seconds, 2 million requests), and an app scaled to zero costs nothing. Log Analytics: the first 5 GB per month are free, with a daily cap of 100 MB set in the code.

## The picture (explained simply)

- **A container** is a lunchbox: the app plus everything it needs, packed so it runs the same everywhere.
- **Container Apps** is a canteen that heats up lunchboxes on request. Nobody hungry? The canteen is dark and costs nothing (**scale to zero**). Someone arrives? A lunchbox is heated in seconds.
- **The environment** is the canteen building. One building can hold many apps.
- **A revision** is one version of the app. A new image gives a new revision; in `Single` mode the new one takes over all traffic.
- **Log Analytics** is the canteen's logbook: who came in, what went wrong.
- **A smoke test** is switching on a new appliance and checking it doesn't smoke. After every deploy, the pipeline visits the app's URL. No answer? The pipeline goes red.

## What's new

| Idea | Where | What it does |
|------|-------|--------------|
| **Container app** | `app.tf`, `azurerm_container_app.web` | Runs `mcr.microsoft.com/k8se/quickstart`, Microsoft's sample web page, on port 80. |
| **Ingress** | `ingress { ... }` | `external_enabled = true`: reachable from the internet. `allow_insecure_connections = false`: HTTPS only. |
| **Scale to zero** | `min_replicas = 0` | No visitors, no replicas, no compute charges. The first visitor waits a few seconds (a cold start). |
| **Diagnostic setting** | `azurerm_monitor_diagnostic_setting.env` | Sends the environment's logs (console, system, HTTP) to the workspace. |
| **Daily quota** | `daily_quota_gb = 0.1` | The workspace stops taking in data after 100 MB per day. A safety net for your credit. |
| **Image allow-list** | `variables.tf` | `image` must start with `mcr.microsoft.com/`. Tested in `tests/app.tftest.hcl`. |
| **Smoke test** | `terraform-11.yml`, after Apply | `curl` the app's URL, with retries for the cold start. |

### Why `logs_destination = "azure-monitor"`

There are two ways to send Container Apps logs to Log Analytics. The older one (`log-analytics`) writes to tables ending in `_CL`, through an API whose support **ended on 14 September 2026** (Microsoft docs). The current way is `azure-monitor` plus a **diagnostic setting**. The logs then land in the tables `ContainerAppConsoleLogs`, `ContainerAppSystemLogs` and `ContainerAppHTTPLogs`. Many tutorials still show the old way.

### Why `"microsoft.insights"` is in lowercase

The diagnostic setting needs the resource provider `microsoft.insights`. With `"Microsoft.Insights"` in `resource_providers_to_register`, azurerm skipped it without an error, and the apply failed with `SubscriptionNotRegistered`. Terraform's debug log (`TF_LOG=DEBUG`) showed why: `The required Resource Provider "Microsoft.Insights" wasn't returned from the Azure API`. Azure lists that namespace in lowercase. In lowercase, it registers (tested). While testing this lab, it got registered on your subscription, so you won't run into it, but the code keeps the working spelling.

## Steps

### 1. Read the code

- [main.tf](main.tf): one provider, three resource providers to register (`Microsoft.App`, `Microsoft.OperationalInsights`, `microsoft.insights`).
- [app.tf](app.tf), from top to bottom:
  - the resource group
  - `azurerm_log_analytics_workspace`: the logbook, with 30 days of retention and the 100 MB daily cap
  - `azurerm_container_app_environment`: the building, with `logs_destination = "azure-monitor"`
  - `azurerm_monitor_diagnostic_setting`: three `enabled_log` blocks, one per log type
  - `azurerm_container_app`: `template` (what runs: one container with 0.25 vCPU and 0.5 GiB) and `ingress` (how people reach it). `traffic_weight` sends 100% to the latest revision.
- [variables.tf](variables.tf): `image`, with a validation that only allows Microsoft's registry.
- [outputs.tf](outputs.tf): `app_url`, built from the ingress's `fqdn`.
- [tests/app.tftest.hcl](tests/app.tftest.hcl): two tests, like in lab 10.

Open [.github/workflows/terraform-11.yml](../.github/workflows/terraform-11.yml) and find the **Smoke test** step at the bottom:

- `terraform output -raw app_url`: reads the URL from the state. `-raw` prints only the text, without quotes.
- `curl --fail`: exit with an error on any HTTP error, which turns the job red.
- `--retry 10 --retry-delay 10 --retry-all-errors`: try up to 10 more times, 10 seconds apart. A scaled-to-zero app needs a moment to wake up.
- `url=$(... || true)` and `if [ -z "$url" ]`: after the teardown there's no `app_url` anymore. Then the step says so and stops without failing. `-z` means "is empty". (The first version checked for an error instead, but with an empty state `terraform output -raw` returns no text **and no error**, so the smoke test went red after the teardown. Fixed in PR #31.)

### 2. Tests and lock file

No Azure login needed.

```powershell
cd E:\Claude\projects\azure-terraform-labs\11-container-app
terraform init -backend=false
terraform test
```

Expect `Success! 2 passed, 0 failed.`

### 3. Pull request

```powershell
cd E:\Claude\projects\azure-terraform-labs
git switch -c feature/lab-11-container-app
git add 11-container-app .github/workflows/terraform-11.yml README.md
git status
git commit -m "Add lab 11 container app"
git push -u origin feature/lab-11-container-app
gh pr create --fill --base main
gh pr checks --watch
```

The plan comment should say **`Plan: 5 to add`**: the resource group, the workspace, the environment, the diagnostic setting and the container app.

### 4. Merge: the deploy

```powershell
gh pr merge --squash --delete-branch
git pull
git fetch --prune
```

The `apply` job takes about 3 minutes; the workspace and the environment are the slow parts. Open the job's log and check the last two steps:

- **Apply:** `Apply complete! Resources: 5 added, 0 changed, 0 destroyed.`
- **Smoke test:** `Testing https://ca-tflab-11-web.<random>.westeurope.azurecontainerapps.io` and then `The app answers.`

Open the URL yourself. You'll see Microsoft's sample page, titled **Azure Container Apps**. If it takes a few seconds, that's the cold start: the app was scaled to zero.

You can also find the URL from your PC:

```powershell
az login --tenant "4017b86f-a08b-45f8-949e-5982125883a1"
az account set --subscription "sub-msdn-jeetan"
az containerapp show -g rg-tflab-11 -n ca-tflab-11-web --query properties.configuration.ingress.fqdn -o tsv
```

### 5. Read the logs

Visit the app a few times (refresh 10 times). Logs take a few minutes to arrive, and the first ones after a new diagnostic setting can take longer.

In the portal: **log-tflab-11** > **Logs**. Close the query gallery if it opens, switch to **KQL mode**, and run:

```kusto
ContainerAppHTTPLogs
| summarize requests = count() by StatusCode
```

- `ContainerAppHTTPLogs`: one row per request to your app.
- `summarize ... by StatusCode`: count the rows per HTTP status code.

Expect a row like `200` with the number of times you visited. (When this lab was tested, 5 visits showed up as `200 | 5` after about 4 minutes.)

`ContainerAppSystemLogs` and `ContainerAppConsoleLogs` are switched on too, but for this sample app they stayed empty during testing, even while it scaled up and down. A real app that writes to its console would fill `ContainerAppConsoleLogs`.

**Watch scale to zero.** Right after your visits, count the running replicas:

```powershell
az containerapp replica list -g rg-tflab-11 -n ca-tflab-11-web --query "length(@)" -o tsv
```

- `az containerapp replica list`: the copies of your app that are running right now.
- `--query "length(@)"`: only count them.

Expect `1`. Wait about 10 minutes without visiting, and run it again: `0`. The canteen is dark, and costs nothing. (Tested: the last visit was at 16:43, and the count went from 1 to 0 at 16:51.) Visit the URL once more, and it wakes up again in a few seconds.

### 6. Ship a new version

```powershell
git switch -c feature/lab-11-helloworld
```

In `variables.tf`, change the default of `image` to:

```hcl
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
```

Then:

```powershell
cd 11-container-app
terraform fmt
terraform test
cd ..
git add 11-container-app/variables.tf
git commit -m "Ship the hello world image"
git push -u origin feature/lab-11-helloworld
gh pr create --fill --base main
gh pr checks --watch
```

The plan: `1 to change`, with the `image` line going from `k8se/quickstart` to `azuredocs/containerapps-helloworld`. Merge it, wait for the smoke test, and reload the page: the title is now **Azure Container Apps - Welcome**. Check the revisions:

```powershell
az containerapp revision list -g rg-tflab-11 -n ca-tflab-11-web --query "[].{name:name, active:properties.active, image:properties.template.containers[0].image}" -o table
```

A second revision has appeared. In `Single` mode, the new one gets all the traffic, and the old one is deactivated shortly after.

**Optional:** try `image = "docker.io/library/nginx:latest"`. `terraform test` refuses it before anything else happens.

## Clean up

1. `git switch -c chore/lab-11-teardown`
2. Delete `app.tf`, `variables.tf`, `outputs.tf` and the `tests` folder. Keep `main.tf` and `backend.tf`.
3. `terraform fmt`, `git status`, PR. The plan: **`5 to destroy`**.
4. Merge. The smoke test says `No app_url output: nothing to test.`
5. Check: `az group exists -n rg-tflab-11` should print `false`.

A deleted Log Analytics workspace is kept for 14 days in a soft-deleted state (Microsoft docs). If you create one with the same name, resource group, subscription and region within that time, Azure recovers the old one, data included, instead of making a new one.

## Done when

- [ ] The smoke test said `The app answers.` after the first deploy
- [ ] You saw your own requests in `ContainerAppHTTPLogs`, and the replica count go from 1 to 0
- [ ] A PR changed the image, a new revision appeared, and the page changed
- [ ] You can explain what scale to zero means for the cost
- [ ] You can explain why a smoke test after the apply is useful even when the apply succeeded

## References

- [Billing in Azure Container Apps](https://learn.microsoft.com/azure/container-apps/billing): free grant, no charges at zero replicas
- [Change Container Apps logging from Log Analytics to Azure Monitor](https://learn.microsoft.com/azure/container-apps/migrate-logs-azure-monitor): the old API's support ended on 14 September 2026; new table names
- [Azure Monitor Logs cost calculations](https://learn.microsoft.com/azure/azure-monitor/logs/cost-logs): 31 days of retention included
- [Scaling in Container Apps](https://learn.microsoft.com/azure/container-apps/scale-app): minimum replicas default to 0
- azurerm: [container_app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app), [container_app_environment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app_environment) (`logs_destination`), [monitor_diagnostic_setting](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting)
