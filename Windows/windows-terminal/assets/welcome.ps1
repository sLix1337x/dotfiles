# Welcome screen: the computer name in thin box-drawing letters, a tagline and
# the commands worth remembering. The profile shows it in every new shell, run
# `welcome` to see it again. Saved as UTF-8 with BOM so PowerShell 5.1 reads
# the glyphs right.

$e = [char]27
$dim, $txt, $hi, $off = "$e[90m", "$e[37m", "$e[97m", "$e[0m"
$tagline = if ($global:WelcomeTagline) { $global:WelcomeTagline } else { 'CREATE  BUILD  SHIP' }

# Three rows per character, three columns wide.
$font = @{
    'A' = '╭─╮', '├─┤', '╵ ╵';  'B' = '┌─╮', '├─┤', '└─╯';  'C' = '╭─╴', '│  ', '╰─╴'
    'D' = '┌─╮', '│ │', '└─╯';  'E' = '┌─╴', '├─ ', '└─╴';  'F' = '┌─╴', '├─ ', '╵  '
    'G' = '╭─╴', '│╶╮', '╰─╯';  'H' = '╷ ╷', '├─┤', '╵ ╵';  'I' = ' ╷ ', ' │ ', ' ╵ '
    'J' = '  ╷', '  │', '╰─╯';  'K' = '╷ ╱', '│╱ ', '╵╲ ';  'L' = '╷  ', '│  ', '└─╴'
    'M' = '┌┬┐', '│╵│', '╵ ╵';  'N' = '╷ ╷', '│╲│', '╵ ╵';  'O' = '╭─╮', '│ │', '╰─╯'
    'P' = '┌─╮', '├─╯', '╵  ';  'Q' = '╭─╮', '│ │', '╰─╲';  'R' = '┌─╮', '├─╯', '╵ ╲'
    'S' = '╭─╴', '╰─╮', '╶─╯';  'T' = '╶┬╴', ' │ ', ' ╵ ';  'U' = '╷ ╷', '│ │', '╰─╯'
    'V' = '╷ ╷', '╲ ╱', ' ╵ ';  'W' = '╷ ╷', '│╷│', '╰┴╯';  'X' = '╲ ╱', ' ╳ ', '╱ ╲'
    'Y' = '╲ ╱', ' │ ', ' ╵ ';  'Z' = '╶─┐', ' ╱ ', '└─╴';  '-' = '   ', '╶─╴', '   '
    '0' = '╭─╮', '│╱│', '╰─╯';  '1' = '╶┐ ', ' │ ', '╶┴╴';  '2' = '╶─╮', '╭─╯', '╰─╴'
    '3' = '╶─╮', ' ─┤', '╶─╯';  '4' = '╷ ╷', '╰─┤', '  ╵';  '5' = '┌─╴', '╰─╮', '╶─╯'
    '6' = '╭─╴', '├─╮', '╰─╯';  '7' = '╶─┐', '  │', '  ╵';  '8' = '╭─╮', '├─┤', '╰─╯'
    '9' = '╭─╮', '╰─┤', '╶─╯'
}

function Get-Spaced([string]$s) { ($s.ToCharArray() -join ' ') }

$name  = $env:COMPUTERNAME.ToUpper()
$width = try { $Host.UI.RawUI.WindowSize.Width } catch { 120 }
$known = @($name.ToCharArray() | Where-Object { -not $font.ContainsKey([string]$_) }).Count -eq 0

Write-Host ''
Write-Host "   $dim$(Get-Spaced 'Welcome to')$off"
Write-Host ''
if ($known -and (3 + 5 * $name.Length) -le $width) {
    foreach ($row in 0..2) {
        $line = ($name.ToCharArray() | ForEach-Object { $font[[string]$_][$row] }) -join '  '
        Write-Host "   $hi$line$off"
    }
} else {
    Write-Host "   $hi$(($name.ToCharArray() -join '   '))$off"
}
Write-Host ''
Write-Host "   $dim$(Get-Spaced $tagline)$off"
Write-Host ''

$items = @('dev',      'shell, git and monitor side by side', 'Ctrl+Alt+d'),
         @('panel',    'project tree and status',             'Ctrl+Alt+p'),
         @('y',        'browse files',                        ''),
         @('cd tree',  'jump to a project folder',            'Ctrl+Alt+z'),
         @('z <name>', 'jump to a folder you use often',      '')
foreach ($i in $items) {
    Write-Host ("   $dim→$off   $txt{0,-10}$off  $dim{1,-38}{2}$off" -f $i[0], $i[1], $i[2])
}
Write-Host ''
