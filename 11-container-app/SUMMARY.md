# 11 – What I learned

## The idea, simply

- **A container** is a lunchbox: the app plus everything it needs. **Container Apps** is a canteen that only heats it up when someone's hungry.
- **Scale to zero:** no visitors, no copies running, no compute costs. The first visitor waits a few seconds (a cold start).
- **A revision** is one version of the app. A new image gives a new revision; in `Single` mode the old one is switched off.
- **A smoke test** checks after every deploy that the app really answers. "Apply complete" only means Azure accepted the settings.

## What I did (19 Oct 2026, West Europe)

| Step | What | Result |
|------|------|--------|
| 2 | `terraform test` | `2 passed` |
| 3–4 | PR #28, merge | `5 added`; smoke test: `The app answers.`; I opened the page myself |
| 5 | Refreshed the page, queried `ContainerAppHTTPLogs` | `200 | 11` and `304 | 112` |
| 5 | Counted replicas | `1` right after visiting, `0` about 10 minutes later |
| 6 | PR #29: image `containerapps-helloworld` | `1 to change`; new revision `--0000001` active, old `--jpzf3aa` inactive; page title `Azure Container Apps - Welcome` |
| Clean up | PR #30: deleted `app.tf`, `variables.tf`, `outputs.tf`, `tests/` | `5 destroyed`, but the **smoke test went red** |
| Fix | PR #31: smoke test checks for an empty `url` | Rerun green: `No app_url output: nothing to test.` |

## New things

- **Container Apps resources:** a Log Analytics workspace, an environment (the building), a diagnostic setting (the pipe from building to logbook) and the container app.
- **`template`** is what runs (image, CPU, memory, replicas). **`ingress`** is how people reach it (external, HTTPS only, port 80).
- **`logs_destination = "azure-monitor"`** plus a diagnostic setting. The older `log-analytics` way uses an API whose support ended on 14 September 2026.
- **`daily_quota_gb = 0.1`:** a 100 MB/day cap on the logs, as a safety net for the credit.
- **KQL:** `ContainerAppHTTPLogs | summarize requests = count() by StatusCode`. The `|` passes the result on to the next step.
- **Smoke test** in the pipeline: `curl --fail --retry 10 --retry-delay 10` after the apply.
- **An image allow-list:** a validation that only accepts `mcr.microsoft.com/`, tested with `terraform test`.

## What went wrong (and what it taught me)

| What happened | Why | Lesson |
|---|---|---|
| The logs were empty at first | Visits right after the deploy came before the diagnostic setting was active; later ones took about 4 minutes | Logs aren't instant; wait and try again |
| `304` far more often than `200` | The browser asks "has this changed?" for every file on a refresh; `304` means "no, use your copy" | Normal web behaviour |
| `--query "length(@)"` → `-o was unexpected at this time` | `az` on Windows is a batch file; PowerShell strips the quotes, and `cmd` trips over the parentheses | Use a query without parentheses, like `"[].name"` |
| The old revision missing from `revision list` | Inactive revisions are hidden by default | Add `--all` |
| `gh pr merge` → `GraphQL: Something went wrong` | A temporary problem on GitHub's side; the PR was still open | Check the PR's state, then just try again |
| Smoke test red after the teardown (`URL rejected`) | With an **empty** state, `terraform output -raw app_url` returns no text **and no error**; the check only looked for an error | Check for "empty" (`[ -z "$url" ]`), not just for "error" |
| My first fix broke the YAML | One line indented too far, and `fi` merged with the next line | Every line in a `run: |` block starts at the same position; actionlint catches it |
| The merge run didn't appear for two minutes | GitHub was slow to start it | Wait before assuming it didn't trigger |

## Cost

Practically nothing, though not checked in Cost Management. This lab's usage is far below the free monthly grants (Container Apps: 180,000 vCPU-seconds, 360,000 GiB-seconds and 2 million requests; Log Analytics: 5 GB).
