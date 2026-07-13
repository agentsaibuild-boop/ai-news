<#
    update-ai-news.ps1
    -------------------
    Weekly "The AI Brief" pipeline:
      1. Run Claude Code headlessly to research the past week's AI news and write
         a new newsletter issue into the "AI News" folder.
      2. (optional) Commit & push the folder to GitHub.
      3. (optional) Email the rendered issue to the configured address.

    Steps 2 and 3 are controlled by _automation\config.local.json (git-ignored).
    Each is skipped unless its "enabled" flag is true and its credentials are set.

    Run manually:   powershell -ExecutionPolicy Bypass -File "<path>\update-ai-news.ps1"
    Force a re-run for today (ignores the already-published check):  add -Force
#>
param([switch]$Force)

$ErrorActionPreference = 'Stop'

# --- Paths -------------------------------------------------------------------
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path   # ...\AI News\_automation
$NewsDir    = Split-Path -Parent $ScriptDir                     # ...\AI News
$PromptFile = Join-Path $ScriptDir 'update-prompt.md'
$ConfigFile = Join-Path $ScriptDir 'config.local.json'
$LogDir     = Join-Path $ScriptDir 'logs'

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Stamp   = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$LogFile = Join-Path $LogDir "run_$Stamp.log"

function Log($msg) {
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $msg" | Tee-Object -FilePath $LogFile -Append
}

Log "=== The AI Brief daily pipeline starting ==="
Log "News dir: $NewsDir"

# --- Skip if today's issue was already published (makes logon-trigger safe) ---
$StampFile = Join-Path $ScriptDir 'last-success.txt'
$TodayStr  = Get-Date -Format 'yyyy-MM-dd'
if (-not $Force -and (Test-Path $StampFile) -and ((Get-Content $StampFile -Raw).Trim() -eq $TodayStr)) {
    Log "Already published today ($TodayStr) - nothing to do. Use -Force to regenerate."
    exit 0
}

# --- Load optional config ----------------------------------------------------
$cfg = $null
if (Test-Path $ConfigFile) {
    try   { $cfg = Get-Content -Raw $ConfigFile | ConvertFrom-Json }
    catch { Log "WARNING: could not parse config.local.json: $_" }
}

# --- Failure tracking & alert email -------------------------------------------
$script:Failures = @()
function Add-Failure([string]$msg) { Log "ERROR: $msg"; $script:Failures += $msg }

function Send-AlertEmail {
    # Plain, no-frills alert so it works even when the fancy path is broken.
    if (-not ($cfg -and $cfg.email -and $cfg.email.enabled)) { Log "Alert wanted but email not configured."; return }
    try {
        $tail = (Get-Content $LogFile -Tail 25 -ErrorAction SilentlyContinue) -join "`n"
        $body = @"
The AI Brief daily run hit a problem on $(Get-Date -Format 'yyyy-MM-dd HH:mm').

WHAT FAILED:
$($script:Failures | ForEach-Object { " - $_" } | Out-String)
COMMON FIXES:
 - Claude logged out  -> open Claude Code once and sign in
 - GitHub push failed -> token may be expired; make a new one and update _automation\config.local.json
 - Email failed       -> app password may be revoked; generate a new one

LAST LOG LINES:
$tail

Log file: $LogFile
"@
        $msg = New-Object System.Net.Mail.MailMessage
        $msg.From = New-Object System.Net.Mail.MailAddress($cfg.email.from, 'The AI Brief - ALERT')
        $msg.To.Add($cfg.email.to)
        $msg.Subject = "!! The AI Brief - daily run FAILED ($(Get-Date -Format 'yyyy-MM-dd'))"
        $msg.Body = $body
        $smtp = New-Object System.Net.Mail.SmtpClient('smtp.gmail.com', 587)
        $smtp.EnableSsl = $true
        $smtp.Credentials = New-Object System.Net.NetworkCredential($cfg.email.from, $cfg.email.appPassword)
        $smtp.Send($msg)
        $msg.Dispose(); $smtp.Dispose()
        Log "Alert email sent."
    }
    catch { Log "Could not send alert email either: $_" }
}

# --- Locate the newest claude.exe (survives app updates) ---------------------
$searchRoots = @(
    (Join-Path $env:LOCALAPPDATA 'Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude-code'),
    (Join-Path $env:USERPROFILE  '.vscode\extensions'),
    (Join-Path $env:USERPROFILE  '.local\bin'),
    (Join-Path $env:APPDATA      'npm')
)
$candidates = foreach ($root in $searchRoots) {
    if (Test-Path $root) { Get-ChildItem $root -Filter 'claude.exe' -Recurse -ErrorAction SilentlyContinue }
}
$onPath = Get-Command claude.exe -ErrorAction SilentlyContinue
if ($onPath) { $candidates += Get-Item $onPath.Source }

$ClaudeExe = $candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
if (-not $ClaudeExe)          { Add-Failure "Could not locate claude.exe (was Claude Code uninstalled or moved?)"; Send-AlertEmail; exit 1 }
if (-not (Test-Path $PromptFile)) { Add-Failure "Prompt file not found: $PromptFile"; Send-AlertEmail; exit 1 }
Log "Using Claude binary: $ClaudeExe"

# --- 0. Refresh the reader's GitHub project profile (drives story relevance) --
if ($cfg -and $cfg.github -and $cfg.github.token) {
    try {
        $headers = @{ Authorization = "token $($cfg.github.token)"; 'User-Agent' = 'ai-news-bot' }
        $repos = Invoke-RestMethod -Uri "https://api.github.com/user/repos?per_page=100&sort=updated" -Headers $headers
        $lines = @("# Reader's GitHub projects (auto-generated $(Get-Date -Format 'yyyy-MM-dd'), git-ignored)", "")
        $rawHeaders = @{ Authorization = "token $($cfg.github.token)"; 'User-Agent' = 'ai-news-bot'; Accept = 'application/vnd.github.raw' }
        foreach ($r in $repos) {
            $vis = if ($r.private) { 'PRIVATE' } else { 'public' }
            $desc = if ($r.description) { $r.description } else { '(no description)' }
            $lines += "- $($r.name) [$vis, $($r.language)]: $desc"
            # Include the README's opening lines - descriptions alone miss what projects really do
            try {
                $readme = $null
                try { $readme = Invoke-RestMethod -Uri "https://api.github.com/repos/$($r.full_name)/readme" -Headers $rawHeaders }
                catch {
                    # Fallback: non-standard names like README_bg.md that the readme API misses
                    $items = Invoke-RestMethod -Uri "https://api.github.com/repos/$($r.full_name)/contents/" -Headers $headers
                    $alt = $items | Where-Object { $_.name -match '^README' } | Select-Object -First 1
                    if ($alt) { $readme = Invoke-RestMethod -Uri $alt.download_url -Headers $rawHeaders }
                }
                $head = ($readme -split "`n" | Where-Object { $_.Trim() -and $_ -notmatch '^#' } | Select-Object -First 3) -join ' '
                if ($head.Length -gt 400) { $head = $head.Substring(0, 400) + '...' }
                if ($head) { $lines += "    README: $head" }
            } catch { }
        }
        $lines -join "`n" | Out-File (Join-Path $ScriptDir 'github-projects.md') -Encoding utf8
        Log "Refreshed GitHub project profile ($($repos.Count) repos)."
    }
    catch { Log "WARNING: could not refresh GitHub project profile: $_ (using previous version if present)" }
}

# --- 1. Generate the newsletter ---------------------------------------------
$Prompt = Get-Content -Raw -Path $PromptFile -Encoding UTF8
Push-Location $NewsDir
try {
    Log "Launching Claude (headless) to write this week's issue..."
    & $ClaudeExe --print $Prompt `
        --permission-mode bypassPermissions `
        --allowedTools 'WebSearch,WebFetch,Read,Write,Edit,Glob,Grep' 2>&1 |
        Tee-Object -FilePath $LogFile -Append
    $genCode = $LASTEXITCODE
    Log "Claude exited with code $genCode"
}
catch { Log "ERROR while running Claude: $_"; $genCode = 1 }
finally { Pop-Location }

if ($genCode -ne 0) {
    Add-Failure "Newsletter generation failed (Claude exit code $genCode). Most common cause: Claude Code login expired."
    Send-AlertEmail
    exit $genCode
}

# Find the issue file for today (what Claude just wrote).
$today     = Get-Date -Format 'yyyy-MM-dd'
$IssueFile = Join-Path $NewsDir "$today-ai-news.md"
if (-not (Test-Path $IssueFile)) {
    $IssueFile = Get-ChildItem $NewsDir -Filter '*-ai-news.md' |
                 Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
}
Log "This week's issue: $IssueFile"

# --- Minimal Markdown -> HTML (covers our newsletter syntax) ------------------
function Convert-MarkdownToHtml([string]$md, [string]$navHtml = '') {
    # Cyber-dark theme, all styles inline (email clients strip <style> blocks).
    $sP  = 'color:#c9d6ee;margin:10px 0;'
    $sLi = 'color:#c9d6ee;margin:6px 0;'
    $sH1 = 'color:#eaf6ff;font-size:22px;margin:16px 0 4px;'
    $sH2 = 'color:#38e1ff;font-size:18px;margin:24px 0 8px;border-bottom:1px solid #1c2a4a;padding-bottom:6px;'
    $sH3 = 'color:#7f8db0;font-size:14px;font-weight:normal;letter-spacing:2px;margin:0 0 12px;'
    $sBq = 'border-left:3px solid #a569ff;padding:10px 14px;color:#dbe6ff;background:#121a30;margin:14px 0;border-radius:0 8px 8px 0;'
    $sHr = 'border:none;border-top:1px solid #1c2a4a;margin:18px 0;'

    $out = New-Object System.Text.StringBuilder
    $inList = $false
    foreach ($raw in ($md -split "`r?`n")) {
        $line = $raw
        # inline: links, then bold, then italic
        $line = [regex]::Replace($line, '\[([^\]]+)\]\(([^)]+)\)', '<a href="$2" style="color:#4fd8ff;">$1</a>')
        $line = [regex]::Replace($line, '\*\*([^*]+)\*\*', '<strong style="color:#ffffff;">$1</strong>')
        $line = [regex]::Replace($line, '(?<!\*)\*([^*]+)\*(?!\*)', '<em>$1</em>')

        if     ($line -match '^\s*---\s*$')   { if($inList){[void]$out.Append('</ul>');$inList=$false}; [void]$out.Append("<hr style=""$sHr"">") }
        elseif ($line -match '^### (.*)')     { if($inList){[void]$out.Append('</ul>');$inList=$false}; [void]$out.Append("<h3 style=""$sH3"">$($matches[1])</h3>") }
        elseif ($line -match '^## (.*)')      { if($inList){[void]$out.Append('</ul>');$inList=$false}; [void]$out.Append("<h2 style=""$sH2"">$($matches[1])</h2>") }
        elseif ($line -match '^# (.*)')       { if($inList){[void]$out.Append('</ul>');$inList=$false}; [void]$out.Append("<h1 style=""$sH1"">$($matches[1])</h1>") }
        elseif ($line -match '^> (.*)')       { if($inList){[void]$out.Append('</ul>');$inList=$false}; [void]$out.Append("<blockquote style=""$sBq"">$($matches[1])</blockquote>") }
        elseif ($line -match '^\s*[-*] (.*)') { if(-not $inList){[void]$out.Append('<ul style="padding-left:22px;margin:8px 0;">');$inList=$true}; [void]$out.Append("<li style=""$sLi"">$($matches[1])</li>") }
        elseif ($line.Trim() -eq '')          { if($inList){[void]$out.Append('</ul>');$inList=$false} }
        else                                   { if($inList){[void]$out.Append('</ul>');$inList=$false}; [void]$out.Append("<p style=""$sP"">$line</p>") }
    }
    if ($inList) { [void]$out.Append('</ul>') }
    $body = $out.ToString()
    return @"
<!doctype html><html><head><meta charset="utf-8"></head>
<body style="margin:0;padding:0;background-color:#04060d;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#04060d;"><tr><td align="center" style="padding:24px 12px;">
<table role="presentation" width="680" cellpadding="0" cellspacing="0" style="max-width:680px;width:100%;background-color:#0b1120;border:1px solid #1c2a4a;border-radius:12px;overflow:hidden;">
<tr><td><img src="cid:banner" width="680" alt="THE AI BRIEF" style="display:block;width:100%;height:auto;"></td></tr>
<tr><td style="padding:10px 28px 28px;font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;line-height:1.6;">
$body
$navHtml
</td></tr>
</table>
<p style="color:#3d4a6b;font-family:Consolas,monospace;font-size:11px;margin-top:14px;">&#9889; generated automatically &middot; delivered daily</p>
</td></tr></table>
</body></html>
"@
}

# --- 2. Publish to GitHub ----------------------------------------------------
if ($cfg -and $cfg.github -and $cfg.github.enabled) {
    try {
        # Git writes progress/warnings to stderr; under $ErrorActionPreference='Stop'
        # PowerShell 5.1 turns those into terminating errors. Relax it for this block.
        $ErrorActionPreference = 'Continue'
        $gh = $cfg.github
        Push-Location $NewsDir
        # Clear a stale index.lock left by a previously crashed git (only if no git is running)
        $lock = Join-Path $NewsDir '.git\index.lock'
        if ((Test-Path $lock) -and -not (Get-Process -Name git -ErrorAction SilentlyContinue)) {
            Remove-Item $lock -Force; Log "Removed stale git index.lock."
        }
        git config core.autocrlf false 2>$null   # silence LF/CRLF warnings
        if (-not (Test-Path (Join-Path $NewsDir '.git'))) {
            Log "Initializing local git repo..."
            git init -b main 2>&1 | Out-Null
        }
        git config user.email $cfg.email.from 2>&1 | Out-Null
        git config user.name  "AI News Bot"    2>&1 | Out-Null
        $remoteUrl = "https://github.com/$($gh.username)/$($gh.repo).git"
        $authUrl   = "https://$($gh.username):$($gh.token)@github.com/$($gh.username)/$($gh.repo).git"
        git remote remove origin 2>&1 | Out-Null
        git remote add origin $remoteUrl 2>&1 | Out-Null
        git add -A 2>&1 | Out-Null
        git commit -m "The AI Brief - issue $today" 2>&1 | Tee-Object -FilePath $LogFile -Append
        Log "Pushing to $remoteUrl ..."
        $pushOut = (git push $authUrl main 2>&1 | Out-String) -replace [regex]::Escape($gh.token), '***'
        $pushOut | Tee-Object -FilePath $LogFile -Append | Out-Null
        if ($LASTEXITCODE -eq 0) { Log "GitHub push complete." }
        else                     { Add-Failure "git push failed (exit $LASTEXITCODE) - GitHub token may be expired or repo unreachable." }
        Pop-Location
    }
    catch { Add-Failure "GitHub publish crashed: $_"; Pop-Location -ErrorAction SilentlyContinue }
    finally { $ErrorActionPreference = 'Stop' }
}
else { Log "GitHub publish disabled (skipping)." }

# --- 3. Email the issue ------------------------------------------------------
if ($cfg -and $cfg.email -and $cfg.email.enabled) {
    try {
        $em   = $cfg.email
        $md   = Get-Content -Raw -Path $IssueFile -Encoding UTF8

        # Strip the markdown nav footer (email gets real buttons instead).
        $md = ($md -split "`r?`n" | Where-Object { $_ -notmatch 'Previous issue\]|Next issue\]|All issues\]' }) -join "`n"

        # Build prev/next buttons linking to the GitHub archive.
        $navHtml = ''
        if ($cfg.github -and $cfg.github.username -and $cfg.github.repo) {
            $repoBase = "https://github.com/$($cfg.github.username)/$($cfg.github.repo)/blob/main"
            $issues = Get-ChildItem $NewsDir -Filter '*-ai-news.md' | Sort-Object Name
            $idx = [array]::IndexOf(($issues.Name), (Split-Path -Leaf $IssueFile))
            $btnOn  = 'display:inline-block;padding:10px 18px;border:1px solid #38e1ff;border-radius:8px;color:#38e1ff;text-decoration:none;font-family:Consolas,monospace;font-size:13px;background:#0d1526;'
            $btnDim = 'display:inline-block;padding:10px 18px;border:1px solid #3d4a6b;border-radius:8px;color:#7f8db0;text-decoration:none;font-family:Consolas,monospace;font-size:13px;background:#0d1526;'
            $cells = ''
            if ($idx -gt 0) {
                $prev = $issues[$idx - 1].Name
                $cells += "<td style=""padding:0 5px;""><a href=""$repoBase/$prev"" style=""$btnOn"">&#8592; Previous issue</a></td>"
            }
            $cells += "<td style=""padding:0 5px;""><a href=""https://github.com/$($cfg.github.username)/$($cfg.github.repo)"" style=""$btnDim"">&#128218; All issues</a></td>"
            if ($idx -ge 0 -and $idx -lt ($issues.Count - 1)) {
                $next = $issues[$idx + 1].Name
                $cells += "<td style=""padding:0 5px;""><a href=""$repoBase/$next"" style=""$btnOn"">Next issue &#8594;</a></td>"
            }
            $navHtml = "<table role=""presentation"" cellpadding=""0"" cellspacing=""0"" align=""center"" style=""margin:22px auto 4px;""><tr>$cells</tr></table>"
        }

        $html = Convert-MarkdownToHtml $md $navHtml
        # Subject = first "# ..." heading, cleaned of emoji/#.
        $subject = "The AI Brief - $today"
        $firstH1 = ($md -split "`r?`n" | Where-Object { $_ -match '^# ' } | Select-Object -First 1)
        if ($firstH1) { $subject = ($firstH1 -replace '^#\s*','').Trim() }

        # Ensure the header banner exists (regenerate if missing).
        $BannerFile = Join-Path $ScriptDir 'banner.png'
        if (-not (Test-Path $BannerFile)) {
            $genScript = Join-Path $ScriptDir 'generate-banner.ps1'
            if (Test-Path $genScript) { & powershell -NoProfile -ExecutionPolicy Bypass -File $genScript | Out-Null }
        }

        $msg = New-Object System.Net.Mail.MailMessage
        $msg.From = New-Object System.Net.Mail.MailAddress($em.from, 'The AI Brief')
        $msg.To.Add($em.to)
        $msg.Subject = $subject
        $msg.SubjectEncoding = [System.Text.Encoding]::UTF8

        $view = [System.Net.Mail.AlternateView]::CreateAlternateViewFromString($html, [System.Text.Encoding]::UTF8, 'text/html')
        if (Test-Path $BannerFile) {
            $banner = New-Object System.Net.Mail.LinkedResource($BannerFile, 'image/png')
            $banner.ContentId = 'banner'
            $view.LinkedResources.Add($banner)
        }
        $msg.AlternateViews.Add($view)

        $smtp = New-Object System.Net.Mail.SmtpClient('smtp.gmail.com', 587)
        $smtp.EnableSsl = $true
        $smtp.Credentials = New-Object System.Net.NetworkCredential($em.from, $em.appPassword)
        Log "Sending email to $($em.to) ..."
        $smtp.Send($msg)
        $msg.Dispose(); $smtp.Dispose()
        Log "Email sent."
    }
    catch { Add-Failure "Newsletter email failed to send: $_" }
}
else { Log "Email disabled (skipping)." }

# --- Alert on any collected failures; stamp success otherwise -----------------
if ($script:Failures.Count -gt 0) { Send-AlertEmail }
else { $TodayStr | Out-File $StampFile -Encoding ascii; Log "Success stamped for $TodayStr." }

# --- Prune old logs (keep last 20) ------------------------------------------
Get-ChildItem $LogDir -Filter 'run_*.log' |
    Sort-Object LastWriteTime -Descending | Select-Object -Skip 20 |
    Remove-Item -Force -ErrorAction SilentlyContinue

Log "=== Done ==="
exit 0
