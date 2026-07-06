<#
    generate-banner.ps1
    Draws the cyber/circuit-board header banner used in The AI Brief emails.
    Output: banner.png next to this script. Deterministic (seeded random), so
    re-running produces the identical image.
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$W = 1200; $H = 300
$out = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'banner.png'

$bmp = New-Object System.Drawing.Bitmap($W, $H)
$g   = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias

# --- Background: deep-space gradient ---
$rect  = New-Object System.Drawing.Rectangle(0, 0, $W, $H)
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    [System.Drawing.Color]::FromArgb(255, 4, 8, 22),
    [System.Drawing.Color]::FromArgb(255, 24, 8, 52),
    30.0)
$g.FillRectangle($bg, $rect)

# --- Circuit traces: right-angled neon paths with glow ---
$rand = New-Object System.Random(1337)   # fixed seed -> same art every run
$cyan   = [System.Drawing.Color]::FromArgb(255,  56, 225, 255)
$purple = [System.Drawing.Color]::FromArgb(255, 165, 105, 255)

for ($i = 0; $i -lt 26; $i++) {
    $color = if ($rand.Next(2) -eq 0) { $cyan } else { $purple }
    $glow  = [System.Drawing.Color]::FromArgb(38, $color.R, $color.G, $color.B)
    $line  = [System.Drawing.Color]::FromArgb(150, $color.R, $color.G, $color.B)

    # Build a 3-5 segment right-angle path
    $x = $rand.Next(0, $W); $y = $rand.Next(0, $H)
    $pts = New-Object System.Collections.Generic.List[System.Drawing.Point]
    $pts.Add((New-Object System.Drawing.Point($x, $y)))
    $horizontal = ($rand.Next(2) -eq 0)
    $segs = $rand.Next(3, 6)
    for ($s = 0; $s -lt $segs; $s++) {
        $len = $rand.Next(50, 220)
        if ($horizontal) { $x += (($rand.Next(2) * 2 - 1) * $len) } else { $y += (($rand.Next(2) * 2 - 1) * $len) }
        $x = [Math]::Max(0, [Math]::Min($W, $x)); $y = [Math]::Max(0, [Math]::Min($H, $y))
        $pts.Add((New-Object System.Drawing.Point($x, $y)))
        $horizontal = -not $horizontal
    }
    $penGlow = New-Object System.Drawing.Pen($glow, 6)
    $penLine = New-Object System.Drawing.Pen($line, 1.6)
    $g.DrawLines($penGlow, $pts.ToArray())
    $g.DrawLines($penLine, $pts.ToArray())
    $penGlow.Dispose(); $penLine.Dispose()

    # Node dot at the end of each trace
    $end = $pts[$pts.Count - 1]
    $nodeGlow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(60, $color.R, $color.G, $color.B))
    $nodeCore = New-Object System.Drawing.SolidBrush($color)
    $g.FillEllipse($nodeGlow, $end.X - 7, $end.Y - 7, 14, 14)
    $g.FillEllipse($nodeCore, $end.X - 3, $end.Y - 3, 6, 6)
    $nodeGlow.Dispose(); $nodeCore.Dispose()
}

# --- Scatter of faint "data" dots ---
for ($i = 0; $i -lt 90; $i++) {
    $c = [System.Drawing.Color]::FromArgb($rand.Next(25, 80), 120, 200, 255)
    $b = New-Object System.Drawing.SolidBrush($c)
    $g.FillEllipse($b, $rand.Next(0, $W), $rand.Next(0, $H), 2, 2)
    $b.Dispose()
}

# --- Dark scrim behind the title so text pops ---
$scrim = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(140, 3, 6, 18))
$g.FillRectangle($scrim, 0, [int]($H*0.28), $W, [int]($H*0.5))
$scrim.Dispose()

# --- Title text ---
$fontTitle = New-Object System.Drawing.Font('Consolas', 46, [System.Drawing.FontStyle]::Bold)
$fontSub   = New-Object System.Drawing.Font('Consolas', 15, [System.Drawing.FontStyle]::Regular)
$title = 'THE AI BRIEF'
$sub   = '>> your daily artificial intelligence briefing_'
$szT = $g.MeasureString($title, $fontTitle)
$tx = ($W - $szT.Width) / 2; $ty = ($H - $szT.Height) / 2 - 12

# glow shadow then bright text
$glowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(90, 56, 225, 255))
foreach ($off in @(-2, 2)) { $g.DrawString($title, $fontTitle, $glowBrush, $tx + $off, $ty); $g.DrawString($title, $fontTitle, $glowBrush, $tx, $ty + $off) }
$titleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 235, 250, 255))
$g.DrawString($title, $fontTitle, $titleBrush, $tx, $ty)

$szS = $g.MeasureString($sub, $fontSub)
$subBrush = New-Object System.Drawing.SolidBrush($cyan)
$g.DrawString($sub, $fontSub, $subBrush, ($W - $szS.Width) / 2, $ty + $szT.Height + 2)

$glowBrush.Dispose(); $titleBrush.Dispose(); $subBrush.Dispose()
$fontTitle.Dispose(); $fontSub.Dispose()

$g.Dispose()
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "Banner written: $out"
