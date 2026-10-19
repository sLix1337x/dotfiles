# Side panel for Windows Terminal: project tree, git and dev-server status,
# quick keys. Opened by `panel` / Ctrl+Alt+p from the profile, which also keeps
# $CwdFile pointed at the shell's current folder so the panel follows `cd`.
# q or Ctrl+c closes it, and it closes itself when the shell next to it exits.
# Saved as UTF-8 with BOM so PowerShell 5.1 reads the glyphs right.
param(
    [string]$CwdFile,
    [int]$ShellPid
)

# Runs with -NoProfile, so the console is still on the OEM code page, which
# turns every glyph outside it into '?'.
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$e = [char]27
$dim, $txt, $hi, $ok, $warn, $off = "$e[90m", "$e[37m", "$e[97m", "$e[32m", "$e[33m", "$e[0m"
# Ports a local dev server usually sits on.
$devPorts = 3000, 3001, 4200, 5000, 5173, 5432, 6379, 8000, 8080, 8081, 8888, 9000, 27017

function Get-Spaced([string]$s) { ($s.ToCharArray() -join ' ') }

function Get-Frame([string]$dir, [int]$w, [int]$h) {
    $quick = @(
        @('Ctrl+Alt+d', 'dev layout'), @('y', 'browse files'),
        @('Ctrl+Shift+g', 'glow on / off'), @('q', 'close panel')
    )
    $lines = New-Object System.Collections.Generic.List[string]

    # Git and ports first: their height is fixed, the tree gets what is left.
    $status = New-Object System.Collections.Generic.List[string]
    $st = @(git -C $dir status --porcelain=v1 -b 2>$null)
    if ($LASTEXITCODE -eq 0 -and $st.Count) {
        $m = [regex]::Match($st[0], '^## (?:No commits yet on )?([^.\s]+)(?:\.\.\.\S+)?(?: \[(.+)\])?')
        $info = $m.Groups[1].Value
        if ($m.Groups[2].Success) { $info += '  ' + ($m.Groups[2].Value -replace 'ahead ', '↑' -replace 'behind ', '↓' -replace ', ', ' ') }
        $changed = $st.Count - 1
        $dot = if ($changed) { $warn } else { $ok }
        $info += if ($changed) { "  $changed changed" } else { '  clean' }
        $status.Add((" $dot●$off  $dim{0,-8}$off $txt{1}$off" -f 'Git', $info))
    } else {
        $status.Add((" $dim●  {0,-8} not a repo$off" -f 'Git'))
    }
    $listening = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners() |
        ForEach-Object Port | Where-Object { $devPorts -contains $_ } | Sort-Object -Unique
    if ($listening) {
        $status.Add((" $ok●$off  $dim{0,-8}$off $txt{1}$off" -f 'Ports', (($listening | ForEach-Object { ":$_" }) -join ' ')))
    } else {
        $status.Add((" $dim●  {0,-8} no dev server$off" -f 'Ports'))
    }

    $boxW  = [Math]::Max(20, $w - 3)
    $fixed = 4 + 3 + $status.Count + 3 + 3 * $quick.Count

    $lines.Add('')
    $lines.Add(" $dim$(Get-Spaced 'PROJECT')$off")
    $shown = if ($dir.Length -gt $w - 4) { '…' + $dir.Substring($dir.Length - ($w - 5)) } else { $dir }
    $lines.Add(" $dim─ $off$txt$shown$off")
    $lines.Add('')

    $items = @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue |
        Where-Object Name -ne '.git' | Sort-Object { -not $_.PSIsContainer }, Name)
    $room = [Math]::Max(1, $h - $fixed)
    $list = if ($items.Count -gt $room) { $items[0..($room - 2)] } else { $items }
    foreach ($i in $list) {
        $n = $i.Name
        if ($n.Length -gt $w - 9) { $n = $n.Substring(0, [Math]::Max(1, $w - 10)) + '…' }
        if ($i.PSIsContainer) { $lines.Add(" $dim▸ $off $hi$([char]0xF114)  $n/$off") }
        else                  { $lines.Add("    $txt$([char]0xF016)  $n$off") }
    }
    if ($items.Count -gt $list.Count) { $lines.Add("    $dim… $($items.Count - $list.Count) more$off") }
    while ($lines.Count -lt $h - ($fixed - 4)) { $lines.Add('') }

    $lines.Add('')
    $lines.Add(" $dim$(Get-Spaced 'STATUS')$off")
    $lines.Add('')
    $status | ForEach-Object { $lines.Add($_) }
    $lines.Add('')
    $lines.Add(" $dim$(Get-Spaced 'QUICK')$off")
    $lines.Add('')
    foreach ($q in $quick) {
        $label = (" ▷  {0,-13}{1}" -f $q[0], $q[1])
        $label = $label.PadRight($boxW - 2).Substring(0, $boxW - 2)
        $lines.Add(" $dim╭$('─' * ($boxW - 2))╮$off")
        $lines.Add(" $dim│$off$txt$label$off$dim│$off")
        $lines.Add(" $dim╰$('─' * ($boxW - 2))╯$off")
    }
    $lines
}

$dir = (Get-Location).ProviderPath
$last = ''
[Console]::Write("$e[?25l")
try {
    while ($true) {
        if ($ShellPid -and -not (Get-Process -Id $ShellPid -ErrorAction SilentlyContinue)) { break }
        if ($CwdFile -and (Test-Path -LiteralPath $CwdFile)) {
            $want = (Get-Content -LiteralPath $CwdFile -TotalCount 1 -Encoding UTF8 -ErrorAction SilentlyContinue)
            if ($want -and (Test-Path -LiteralPath $want -PathType Container)) { $dir = $want }
        }
        $size  = $Host.UI.RawUI.WindowSize
        $frame = (Get-Frame $dir $size.Width $size.Height) -join "$e[K`n"
        if ($frame -ne $last) {
            [Console]::Write("$e[H$frame$e[K$e[J")
            $last = $frame
        }
        # Wake every 100 ms for q, redraw every 2 s.
        for ($t = 0; $t -lt 20; $t++) {
            if ([Console]::KeyAvailable -and [Console]::ReadKey($true).KeyChar -eq 'q') { return }
            Start-Sleep -Milliseconds 100
        }
    }
} finally {
    [Console]::Write("$e[?25h")
    if ($CwdFile) { Remove-Item -LiteralPath $CwdFile -ErrorAction SilentlyContinue }
}
