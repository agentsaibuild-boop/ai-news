# 📰 The AI Brief

A weekly, auto-generated newsletter about artificial intelligence. Every Monday it
researches the past week's biggest AI stories, writes a new issue into this folder,
optionally **publishes to GitHub**, and optionally **emails** you the issue.

## Latest issues

- [Issue No. 1 — Week of July 6, 2026](2026-07-06-ai-news.md)

## How it works

Every **Monday at ~08:05** a Windows Scheduled Task (`Update AI News Weekly`) runs
Claude Code headlessly. Claude searches the web, writes `YYYY-MM-DD-ai-news.md`,
and updates the list above. The same script then (if enabled) pushes to GitHub and
emails the issue.

| | |
|---|---|
| **Script** | [`_automation/update-ai-news.ps1`](_automation/update-ai-news.ps1) |
| **Prompt / format** | [`_automation/update-prompt.md`](_automation/update-prompt.md) |
| **Private settings** | `_automation/config.local.json` (git-ignored — holds your credentials) |
| **Logs** | `_automation/logs/` |

## Enabling email & GitHub

Both are off until you fill in `_automation/config.local.json` and flip `enabled` to `true`:

- **Email** — needs a Gmail *App Password* (with 2-Step Verification on). Sent via Gmail SMTP.
- **GitHub** — needs your GitHub username + a Personal Access Token, and a repo of that name.

The `config.local.json` file is git-ignored, so your password and token are **never uploaded**.

## Managing the schedule (PowerShell)

```powershell
schtasks /Run    /TN "Update AI News Weekly"            # run now
schtasks /Query  /TN "Update AI News Weekly" /V /FO LIST # status / last result
schtasks /Change /TN "Update AI News Weekly" /ST 17:00   # change time
schtasks /Change /TN "Update AI News Weekly" /DISABLE    # pause
schtasks /Delete /TN "Update AI News Weekly" /F          # remove
```

---

*Content is AI-generated from live web searches. Fast-moving figures (pricing,
benchmarks, funding) are as reported that week — verify before relying on them.*
