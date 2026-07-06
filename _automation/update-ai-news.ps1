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
#>

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

Log "=== The AI Brief weekly pipeline starting ==="
Log "News dir: $NewsDir"

# --- Load optional config ----------------------------------------------------
$cfg = $null
if (Test-Path $ConfigFile) {
    try   { $cfg = Get-Content -Raw $ConfigFile | ConvertFrom-Json }
    catch { Log "WARNING: could not parse config.local.json: $_" }
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
if (-not $ClaudeExe)          { Log "ERROR: could not locate claude.exe. Aborting."; exit 1 }
if (-not (Test-Path $PromptFile)) { Log "ERROR: prompt file not found: $PromptFile. Aborting."; exit 1 }
Log "Using Claude binary: $ClaudeExe"

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

if ($genCode -ne 0) { Log "Generation failed; skipping publish/email."; exit $genCode }

# Find the issue file for today (what Claude just wrote).
$today     = Get-Date -Format 'yyyy-MM-dd'
$IssueFile = Join-Path $NewsDir "$today-ai-news.md"
if (-not (Test-Path $IssueFile)) {
    $IssueFile = Get-ChildItem $NewsDir -Filter '*-ai-news.md' |
                 Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
}
Log "This week's issue: $IssueFile"

# --- Minimal Markdown -> HTML (covers our newsletter syntax) ------------------
function Convert-MarkdownToHtml([string]$md) {
    $out = New-Object System.Text.StringBuilder
    $inList = $false
    foreach ($raw in ($md -split "`r?`n")) {
        $line = $raw
        # inline: links, then bold, then italic
        $line = [regex]::Replace($line, '\[([^\]]+)\]\(([^)]+)\)', '<a href="$2">$1</a>')
        $line = [regex]::Replace($line, '\*\*([^*]+)\*\*', '<strong>$1</strong>')
        $line = [regex]::Replace($line, '(?<!\*)\*([^*]+)\*(?!\*)', '<em>$1</em>')

        if     ($line -match '^\s*---\s*$')   { if($inList){[void]$out.Append('</ul>');$inList=$false}; [void]$out.Append('<hr>') }
        elseif ($line -match '^### (.*)')     { if($inList){[void]$out.Append('</ul>');$inList=$false}; [void]$out.Append("<h3>$($matches[1])</h3>") }
        elseif ($line -match '^## (.*)')      { if($inList){[void]$out.Append('</ul>');$inList=$false}; [void]$out.Append("<h2>$($matches[1])</h2>") }
        elseif ($line -match '^# (.*)')       { if($inList){[void]$out.Append('</ul>');$inList=$false}; [void]$out.Append("<h1>$($matches[1])</h1>") }
        elseif ($line -match '^> (.*)')       { if($inList){[void]$out.Append('</ul>');$inList=$false}; [void]$out.Append("<blockquote>$($matches[1])</blockquote>") }
        elseif ($line -match '^\s*[-*] (.*)') { if(-not $inList){[void]$out.Append('<ul>');$inList=$true}; [void]$out.Append("<li>$($matches[1])</li>") }
        elseif ($line.Trim() -eq '')          { if($inList){[void]$out.Append('</ul>');$inList=$false} }
        else                                   { if($inList){[void]$out.Append('</ul>');$inList=$false}; [void]$out.Append("<p>$line</p>") }
    }
    if ($inList) { [void]$out.Append('</ul>') }
    $body = $out.ToString()
    return @"
<!doctype html><html><head><meta charset="utf-8"></head>
<body style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;line-height:1.55;color:#1a1a1a;max-width:680px;margin:0 auto;padding:16px;">
$body
</body></html>
"@
}

# --- 2. Publish to GitHub ----------------------------------------------------
if ($cfg -and $cfg.github -and $cfg.github.enabled) {
    try {
        $gh = $cfg.github
        Push-Location $NewsDir
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
        git push $authUrl main 2>&1 | Tee-Object -FilePath $LogFile -Append
        Log "GitHub push complete."
        Pop-Location
    }
    catch { Log "ERROR during GitHub publish: $_"; if((Get-Location).Path -ne $NewsDir){} ; Pop-Location -ErrorAction SilentlyContinue }
}
else { Log "GitHub publish disabled (skipping)." }

# --- 3. Email the issue ------------------------------------------------------
if ($cfg -and $cfg.email -and $cfg.email.enabled) {
    try {
        $em   = $cfg.email
        $md   = Get-Content -Raw -Path $IssueFile -Encoding UTF8
        $html = Convert-MarkdownToHtml $md
        # Subject = first "# ..." heading, cleaned of emoji/#.
        $subject = "The AI Brief - $today"
        $firstH1 = ($md -split "`r?`n" | Where-Object { $_ -match '^# ' } | Select-Object -First 1)
        if ($firstH1) { $subject = ($firstH1 -replace '^#\s*','').Trim() }

        $sec  = ConvertTo-SecureString $em.appPassword -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential($em.from, $sec)
        Log "Sending email to $($em.to) ..."
        Send-MailMessage -From $em.from -To $em.to -Subject $subject `
            -BodyAsHtml -Body $html -SmtpServer 'smtp.gmail.com' -Port 587 -UseSsl `
            -Credential $cred -Encoding ([System.Text.Encoding]::UTF8)
        Log "Email sent."
    }
    catch { Log "ERROR sending email: $_" }
}
else { Log "Email disabled (skipping)." }

# --- Prune old logs (keep last 20) ------------------------------------------
Get-ChildItem $LogDir -Filter 'run_*.log' |
    Sort-Object LastWriteTime -Descending | Select-Object -Skip 20 |
    Remove-Item -Force -ErrorAction SilentlyContinue

Log "=== Done ==="
exit 0
