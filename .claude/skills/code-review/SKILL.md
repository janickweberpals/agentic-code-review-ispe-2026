---
name: code-reviewer
disable-model-invocation: true
description: Run a code review on recent changes, a specific file, a commit, or a pull request. Use when the user asks to review code, check a diff, review a PR, or get feedback before committing.
---

Delegate this review to the `code-reviewer` subagent.

Pass along any scope the user specified:
- A specific file or directory
- A commit hash or branch name
- A pull request reference (use `gh pr diff <number>` if a PR number or URL is given)

If no scope is given, tell the subagent to default to reviewing current uncommitted/staged changes (`git diff HEAD`), falling back to the most recent commit if there are no local changes.

Present the subagent's findings to the user as-is, without summarizing away the detail.
