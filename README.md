# 📰 The AI Brief

A **daily**, auto-generated newsletter about artificial intelligence. Every morning
it researches the last day's biggest AI stories, writes a new issue into this folder,
publishes it to **GitHub**, and **emails** it to you.

## Latest issues

- [July 6, 2026 — Issue No. 1](2026-07-06-ai-news.md)

## How it works

Every **day at ~08:05** a Windows Scheduled Task (`Update AI News Daily`) runs
Claude Code headlessly. Claude searches the web, writes `YYYY-MM-DD-ai-news.md`,
and updates the list above. The same script then pushes to GitHub and emails the issue.

| | |
|---|---|
| **Script** | [`_automation/update-ai-news.ps1`](_automation/update-ai-news.ps1) |
| **Prompt / format** | [`_automation/update-prompt.md`](_automation/update-prompt.md) |
| **Private settings** | `_automation/config.local.json` (git-ignored — holds your credentials) |
| **Logs** | `_automation/logs/` |

## Email & GitHub

Controlled by `_automation/config.local.json` (git-ignored, so your password and
token are never uploaded):

- **Email** — sent via Gmail SMTP using a Gmail *App Password*.
- **GitHub** — pushed using your GitHub username + a Personal Access Token.

## Managing the schedule (PowerShell)

```powershell
schtasks /Run    /TN "Update AI News Daily"            # run now
schtasks /Query  /TN "Update AI News Daily" /V /FO LIST # status / last result
schtasks /Change /TN "Update AI News Daily" /ST 07:30   # change time
schtasks /Change /TN "Update AI News Daily" /DISABLE    # pause
schtasks /Change /TN "Update AI News Daily" /ENABLE     # resume
schtasks /Delete /TN "Update AI News Daily" /F          # remove
```

---

*Content is AI-generated from live web searches. Fast-moving figures (pricing,
benchmarks, funding) are as reported that day — verify before relying on them.*
