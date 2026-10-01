# 03 – Git and GitHub

Put this lab repo under version control, push it to a private GitHub repo, and practise the branch → pull request → merge loop that every pipeline in later projects builds on.

**Time:** about 1–1.5 hours. **Cost:** nothing, no Azure resources.

## What you learn

- Git's three places: working folder, staging area, commits
- `git add`, `commit`, `status`, `diff`, `log`
- Why `.gitignore` matters for Terraform (state and plans hold secrets)
- Creating a GitHub repo from the command line and pushing to it
- Branches, pull requests, reviewing a diff, merging, pulling `main`

## Words you'll see

| Word | Meaning |
|------|---------|
| **Repository (repo)** | A folder whose history Git tracks. Git stores the history in a hidden `.git` folder. |
| **Commit** | A saved snapshot of your files, with a message, author and date. You can always go back to one. |
| **Staging area** | The list of changes that go into the *next* commit. `git add` puts changes there. |
| **Branch** | A separate line of commits. `main` is the main one; you make a branch for each change. |
| **Remote** (`origin`) | The copy of the repo on GitHub. |
| **Push / pull** | Send your commits to GitHub / get commits from GitHub. |
| **Pull request (PR)** | A request on GitHub to merge a branch into `main`. Shows the changes so they can be reviewed first. |

## Steps

### 1. Tell Git who you are

Every commit records an author name and email.

```powershell
git config --global user.name "Jeetan Paul"
git config --global user.email "YOUR_ID+USERNAME@users.noreply.github.com"
```

- `--global` saves it for every repo on this PC (in `%USERPROFILE%\.gitconfig`).
- **Which email:** GitHub gives every account a `noreply` address so your real email doesn't end up in commit history. Find it on GitHub: **Settings > Emails**, turn on **Keep my email addresses private**, and copy the address shown there (for newer accounts it looks like `12345678+username@users.noreply.github.com`).

Check:

```powershell
git config --global --list
```

### 2. Connect the GitHub CLI to your account

```powershell
gh auth login --web --git-protocol https
```

- `--web`: log in through your browser. `gh` shows a one-time code; paste it in the browser page it opens.
- `--git-protocol https`: Git talks to GitHub over HTTPS (no SSH keys needed).
- If it asks **"Authenticate Git with your GitHub credentials?"**, answer **Yes**. Then `git push` uses the same login and you won't need a password.
- The token is stored in the Windows credential store, not in a plain text file.

Check:

```powershell
gh auth status
```

### 3. Make the lab folder a Git repo

```powershell
cd E:\Claude\projects\azure-terraform-labs
git init -b main
```

- `git init` creates the hidden `.git` folder. From now on Git can track this folder. Nothing is tracked yet.
- `-b main` names the first branch `main` (the GitHub default).

### 4. Check what Git sees, before adding anything

```powershell
git status
git status --ignored
```

- `git status` lists files Git sees but doesn't track yet ("Untracked files").
- `git status --ignored` also lists what `.gitignore` excludes. You should see `.terraform/` and `tfplan` under **Ignored files**, and no `*.tfstate` under untracked. **This is the check that keeps secrets out of GitHub.** If a `.tfstate` file ever appears as untracked, stop and fix `.gitignore` first.
- `.terraform.lock.hcl` *should* be tracked: it pins provider versions for everyone, including the pipeline in project 04.

### 5. First commit

```powershell
git add .
git status
git commit -m "Add Terraform labs 01 and 02"
```

- `git add .` stages every file in the folder that isn't ignored. Nothing is saved yet.
- `git status` now shows them under **Changes to be committed**. Read the list once more.
- `git commit -m` saves the snapshot with a message. Write messages as a short summary of *what* the commit does.
- You may see `warning: in the working copy of '...', LF will be replaced by CRLF`. That's Git for Windows converting line endings (`core.autocrlf=true`). Harmless.

```powershell
git log --oneline
```

Shows your commit: a short ID and the message.

### 6. Create the private GitHub repo and push

```powershell
gh repo create azure-terraform-labs --private --source . --remote origin --push
```

- `--private`: only you can see it.
- `--source .`: use the current folder as the repo.
- `--remote origin`: registers the GitHub repo under the name `origin` in your local repo.
- `--push`: uploads your commits.

Open it in the browser:

```powershell
gh repo view --web
```

Check that no `.tfstate`, `tfplan` or `.terraform` folder is there.

### 7. The change loop, round 1: from the command line

In project 02 you changed the `owner` tag to `jeetan-v2`. Change it back through a pull request.

**a. Make a branch**

```powershell
git switch -c fix/owner-tag
```

- `switch -c` creates a new branch and moves you onto it. Commits you make now go to `fix/owner-tag`, and `main` stays untouched.
- `git status` shows `On branch fix/owner-tag`.

**b. Change the code**

In `02-remote-state/variables.tf` set `owner = "jeetan"`. Then:

```powershell
git diff
```

Shows exactly what changed: a `-` line (old) and a `+` line (new). This is the same view a reviewer sees in a pull request.

**c. Commit and push the branch**

```powershell
git add 02-remote-state/variables.tf
git commit -m "Reset owner tag in lab 02"
git push -u origin fix/owner-tag
```

- This time you stage one file by name, not `.`. That way you only commit what you meant to.
- `push -u origin fix/owner-tag` uploads the branch to GitHub. `-u` links your local branch to the GitHub one, so next time plain `git push` is enough.

**d. Open a pull request**

```powershell
gh pr create --fill --base main
```

- `--fill` uses your commit message as the PR title and body.
- `--base main`: the branch you want to merge into.

Open it with `gh pr view --web`. Look at the **Files changed** tab: the diff from step b. In project 04 this is where `terraform plan` output will show up.

**e. Merge**

```powershell
gh pr merge --squash --delete-branch
```

- `--squash` combines the branch's commits into one commit on `main`. Keeps `main`'s history short: one commit per change.
- `--delete-branch` deletes the branch on GitHub and locally, and switches you back to `main`.

**f. Update your local main**

```powershell
git switch main
git pull
git log --oneline
```

- `git pull` fetches the merge commit GitHub made and adds it to your local `main`. Your PC and GitHub now match.
- `log` shows two commits: your first commit and the squashed fix.

### 8. The change loop, round 2: merge in the browser

Same loop, but you do the PR part on GitHub's website. That's how you'll usually review in a team.

1. `git switch -c docs/lab-03-status`
2. In the root `README.md`, change project 03's status from `ready` to `done`.
3. `git diff`, then `git add README.md`, `git commit -m "Mark lab 03 done"`, `git push -u origin docs/lab-03-status`
4. On GitHub, open the repo. A yellow banner offers **Compare & pull request**. Click it, check the diff, and click **Create pull request**.
5. The green button defaults to **Merge pull request**, which creates a merge commit. Click the arrow next to it, choose **Squash and merge** (the same method as round 1), confirm, then click **Delete branch**. If **Squash and merge** isn't in the list, it's turned off under **Settings > General > Pull Requests > Allow squash merging**.
6. Back in the terminal: `git switch main`, `git pull`, and delete the local branch: `git branch -d docs/lab-03-status`.

If `branch -d` refuses because the branch isn't "fully merged", that's because squash merging creates a *new* commit on `main`, so Git doesn't recognise the branch as merged. The PR was merged on GitHub, so it's safe to force it: `git branch -D docs/lab-03-status`.

## Done when

- [ ] `git config --global --list` shows your name and noreply email
- [ ] `gh auth status` shows you're logged in
- [ ] The private repo exists on GitHub with no state files, plans or `.terraform` folders
- [ ] You merged one PR from the command line and one in the browser
- [ ] `git status` on `main` says `nothing to commit, working tree clean`, and `git log --oneline` shows three commits

## Everyday commands

| Command | What it does |
|---------|--------------|
| `git status` | What changed, what's staged, which branch you're on |
| `git diff` | Unstaged changes, line by line |
| `git add <file>` | Stage a change for the next commit |
| `git commit -m "..."` | Save staged changes as a commit |
| `git log --oneline` | Commit history, short |
| `git switch -c <name>` | Create a branch and move to it |
| `git switch main` | Go back to main |
| `git push` / `git pull` | Send / get commits |
| `gh pr create --fill` | Open a PR from the current branch |
| `gh pr merge --squash --delete-branch` | Merge the PR and clean up |

## Private repo limits on GitHub Free

Per GitHub's docs, a private repo on GitHub Free doesn't get protected branches, environments, environment secrets or required reviewers. None of that is needed in this project. It matters from project 05 on; decide then between making the repo public or GitHub Pro.

## References

- [git init](https://git-scm.com/docs/git-init), [git switch](https://git-scm.com/docs/git-switch), [git commit](https://git-scm.com/docs/git-commit)
- [gh auth login](https://cli.github.com/manual/gh_auth_login), [gh repo create](https://cli.github.com/manual/gh_repo_create), [gh pr create](https://cli.github.com/manual/gh_pr_create), [gh pr merge](https://cli.github.com/manual/gh_pr_merge)
- [Setting your commit email address (GitHub Docs)](https://docs.github.com/en/account-and-profile/how-tos/email-preferences/setting-your-commit-email-address)
- [About protected branches (GitHub Docs)](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
