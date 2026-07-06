# AI News

A running archive of weekly artificial-intelligence news digests, updated automatically.

## How it works

Every **Monday at ~8:05 AM** a Windows Scheduled Task runs Claude Code headlessly. Claude searches the web for the most significant AI developments of the past week and writes a new dated digest into this folder (`YYYY-MM-DD-ai-news.md`), then refreshes the "Latest issues" list below.

## Latest issues

- [Issue No. 1 — Week of July 6, 2026](2026-07-06-ai-news.md)

## Automation details

| | |
|---|---|
| **Scheduled task** | `Update AI News Weekly` (Windows Task Scheduler) |
| **Runs** | Weekly, Mondays ~08:05 local |
| **Script** | [`_automation/update-ai-news.ps1`](_automation/update-ai-news.ps1) |
| **Prompt** | [`_automation/update-prompt.md`](_automation/update-prompt.md) |
| **Logs** | `_automation/logs/` |

### Managing the schedule

Open **PowerShell** and use these commands:

```powershell
# Run it right now (don't wait for Monday)
schtasks /Run /TN "Update AI News Weekly"

# See status / last run result
schtasks /Query /TN "Update AI News Weekly" /V /FO LIST

# Change the day/time — e.g. Fridays at 5pm
schtasks /Change /TN "Update AI News Weekly" /ST 17:00
# (day-of-week changes require re-creating the task; see update-ai-news.ps1 header)

# Turn it off / back on
schtasks /Change /TN "Update AI News Weekly" /DISABLE
schtasks /Change /TN "Update AI News Weekly" /ENABLE

# Remove it entirely
schtasks /Delete /TN "Update AI News Weekly" /F
```

### Adjusting what gets covered

Edit [`_automation/update-prompt.md`](_automation/update-prompt.md) to change the focus, length, or format of each digest — the next scheduled run picks up your changes automatically.

---

*Content is AI-generated from live web searches. Fast-moving figures (pricing, benchmarks, funding) are as reported that week — verify specifics before relying on them.*
