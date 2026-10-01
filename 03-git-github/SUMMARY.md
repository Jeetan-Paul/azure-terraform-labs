# 03 – What I learned

## The idea, in game terms

- **Git** is a save system for files.
- A **commit** is a save point. You can always go back to it.
- **`main`** is the main save: the version that works.
- A **branch** is a copy of the save to try something on, so `main` stays safe.
- **GitHub** is the cloud where the saves are kept. **Push** uploads, **pull** downloads.
- A **pull request (PR)** asks "may I put my copy into `main`?" and shows exactly what changed.
- **Merge** says yes: the change goes into `main`, and the copy can be deleted.

## The loop I'll use for every change

```powershell
git switch -c fix/short-description      # 1. make a copy (branch) and move onto it
# ...edit files...
git diff                                 # 2. see what changed (- old, + new)
git add path/to/file                     # 3. pick what goes in the save
git commit -m "What this change does"    # 4. save (commit)
git push -u origin fix/short-description # 5. upload the copy to GitHub
gh pr create --fill --base main          # 6. ask "may I?" (pull request)
gh pr merge --squash --delete-branch     # 7. say yes (merge), delete the copy
git switch main                          # 8. back to the main save
git pull                                 # 9. download the new main
git fetch --prune                        # 10. forget copies deleted on GitHub
```

Steps 6–7 can also be done on the website: **Compare & pull request**, then the arrow next to **Merge pull request** > **Squash and merge** > **Delete branch**. After a website merge, delete the local copy with `git branch -D <name>`. Capital `D` is needed because squash makes a new commit, so Git doesn't recognise the copy as merged.

## Words and abbreviations

| Term | Meaning |
|------|---------|
| `git` | The save system itself. Works on my PC. |
| `gh` | GitHub CLI (Command Line Interface): GitHub's own terminal program for repos, PRs and logging in |
| `origin` | The standard name for the copy on GitHub |
| `HEAD` | Where I am right now (which branch and commit) |
| staging area | The list of changes that go into the next commit (`git add` puts them there) |
| squash | Combine all commits of a branch into one commit on `main` |
| `-c` / `-m` / `-u` / `-D` | create / message / set upstream (link to GitHub) / force delete |

## Things that surprised me

- The first `gh repo create --push` failed with "Repository not found" although the repo existed. A push a minute later worked with the same login and address. Most likely GitHub wasn't ready yet. "Not found" on a private repo can also mean "no access".
- `gh auth login` logged in `gh`, but Git also needed `gh auth setup-git` to use that login for pushing.
- A merge on the website only changes GitHub. My PC needs `git pull` to catch up.

## Safety check before a first commit

`git status --ignored` must show `.terraform/` and `tfplan` under **Ignored**, and no `.tfstate` anywhere under untracked. Anything pushed stays in the history.

## My setup

| Item | Value |
|------|-------|
| GitHub account | `Jeetan-Paul` |
| Repo | `Jeetan-Paul/azure-terraform-labs` (private) |
| Commit email | `github@jeetan.nl` (noreply address on my own domain) |
| Git login | through `gh` (`gh auth setup-git`), token in the Windows credential store |

Private repo on GitHub Free: no protected branches, environments or required reviewers. Decide on public or GitHub Pro before project 05.
