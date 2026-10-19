# --- UTF-8 console (needed for Fastfetch icons/glyphs) ---
try {
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    chcp 65001 > $null
} catch {}

# Throws when the host has no real console (redirected output, some CI hosts).
try { Clear-Host } catch { }

# --- PATH ---
$env:PATH = "$env:PATH;$env:USERPROFILE\bin"

# --- Starship Prompt ---
# starship.exe is unsigned like zoxide (FACEIT AC tax on unsigned exe launches),
# and its init script is static, so cache it the same way instead of invoking
# starship.exe on every shell startup.
if (Get-Command starship -ErrorAction SilentlyContinue) {
    $ENV:STARSHIP_CONFIG = "$HOME\.config\starship.toml"
    $starshipCacheDir = "$HOME\.cache\pwsh-init"
    $starshipCache = "$starshipCacheDir\starship.ps1"
    if (-not (Test-Path $starshipCache)) {
        New-Item -ItemType Directory -Path $starshipCacheDir -Force | Out-Null
        starship init powershell | Out-File -FilePath $starshipCache -Encoding utf8
    }
    elseif (((Get-Date) - (Get-Item $starshipCache).LastWriteTime).TotalDays -gt 7) {
        Start-Job -ScriptBlock {
            param($f) (starship init powershell) | Out-File -FilePath $f -Encoding utf8
        } -ArgumentList $starshipCache | Out-Null
    }
    Invoke-Expression (Get-Content $starshipCache -Raw)

    # Collapse previous prompts to a simple "❯" after you press Enter, keeping
    # scrollback clean while the active prompt still shows the full context.
    try { Enable-TransientPrompt } catch { }

    # --- Windows Terminal CWD propagation (OSC 9;9) ---
    # Lets Windows Terminal know the real working directory so duplicate tab,
    # open in terminal, etc. use the current folder instead of the profile default.
    if ($host.Name -eq 'ConsoleHost') {
        $existingPrompt = Get-Item function:global:prompt -ErrorAction SilentlyContinue
        if ($existingPrompt -and $existingPrompt.ScriptBlock) {
            $global:OriginalStarshipPrompt = $existingPrompt.ScriptBlock
            function global:prompt {
                $cwd = $PWD.Path
                $esc = [char]27
                $osc = "$esc]9;9;`"$cwd`"$esc\"
                "$osc$( & $global:OriginalStarshipPrompt )"
            }
        }
    }
}

# --- zoxide (smarteres cd) ---
# zoxide.exe is unsigned, and the FACEIT AC driver adds an ~8s tax to every
# unsigned exe launch. Cache the generated init script instead of invoking
# zoxide.exe on every shell startup; refresh the cache in the background.
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    $zoxideCacheDir = "$HOME\.cache\pwsh-init"
    $zoxideCache = "$zoxideCacheDir\zoxide.ps1"
    if (-not (Test-Path $zoxideCache)) {
        New-Item -ItemType Directory -Path $zoxideCacheDir -Force | Out-Null
        zoxide init powershell | Out-File -FilePath $zoxideCache -Encoding utf8
    }
    elseif (((Get-Date) - (Get-Item $zoxideCache).LastWriteTime).TotalDays -gt 7) {
        Start-Job -ScriptBlock {
            param($f) (zoxide init powershell) | Out-File -FilePath $f -Encoding utf8
        } -ArgumentList $zoxideCache | Out-Null
    }
    Invoke-Expression (Get-Content $zoxideCache -Raw)

    # z <teil-des-pfads>  springt zum haeufigsten Treffer
    # zi <teil-des-pfads> oeffnet die Trefferliste zur Auswahl (braucht fzf)
}

# --- Intelligentes cd: Teilnamen, Frecency-Spruenge, Verzeichnis-Tabulator ---
# cd web          -> ...\website                (Praefix)
# cd proj/web     -> ...\projects\website      (jedes Segment einzeln aufgeloest)
# cd proj         -> ...\somewhere\proj         (zoxide-Frecency, unabhaengig vom cwd)
# cd ...          -> zwei Ebenen hoch
# cd -            -> zurueck zum vorherigen Ordner
# cd proj<Tab>    -> listet nur Verzeichnisse, zaehlt als Teilpfad weiter
# z git<Tab>      -> zoxide-Treffer als Vorschlag
#
# cd tree [text]  -> fzf-Auswahl aus dem Verzeichnisbaum der Hauptordner
# cd dev|docs|desktop|...  -> Direktsprung auf einen davon

# Hauptordner. Kurzer Name -> Pfad; als erstes Pfadsegment nutzbar
# (cd dev/myproject) und ueber Ctrl+Alt+1..9 direkt ansteuerbar. Die
# Reihenfolge bestimmt die Tastenbelegung. Trag hier deine eigenen
# Projektordner ein; was auf diesem Rechner nicht existiert, wird
# uebersprungen.
$global:CdRoots = [ordered]@{
    'dev'       = "$HOME\dev"
    'docs'      = [Environment]::GetFolderPath('MyDocuments')
    'desktop'   = [Environment]::GetFolderPath('Desktop')
    'downloads' = "$HOME\Downloads"
    'home'      = $HOME
    'c'         = "$env:SystemDrive\"
}
foreach ($tag in @($global:CdRoots.Keys)) {
    if (-not (Test-Path -LiteralPath $global:CdRoots[$tag] -PathType Container)) { $global:CdRoots.Remove($tag) }
}
$global:CdTreeDepth = 3

# Trennzeichen im Baum. U+2192 (Pfeil rechts) statt U+279C: deutlich mehr
# Schriften kennen ihn, auch cmd und WSL. Als [char]-Code geschrieben und nicht
# als Literal, damit die Datei auch ohne BOM korrekt eingelesen wird.
# Fuer reines ASCII: '-'
$global:CdSep = [string][char]0x2192

$global:CdTreeCache = $null
$global:CdTreeStamp = $null

# Verzeichnisse, die im Baum nichts zu bieten haben und den Scan aufblaehen.
# Die Systemordner sind nicht nur Muell: C:\ auf Tiefe 3 ergibt ohne sie
# 21947 Ordner in knapp einer Sekunde, mit ihnen 179 in 23ms.
$global:CdTreeNoise = @(
    '.git', '.github', '.claude', '.vs', '.vscode', '.idea', '.venv', '.next',
    '.astro', '.superpowers', '__pycache__', 'node_modules', 'bin', 'obj',
    'dist', 'dist-electron', 'build', 'target', 'vendor', 'cache', 'tmp', '.pytest_cache',
    'Windows', 'Windows.old', 'Program Files', 'Program Files (x86)', 'ProgramData',
    'AppData', '$Recycle.Bin', '$RECYCLE.BIN', 'System Volume Information',
    'PerfLogs', 'Recovery', '$WinREAgent', 'Config.Msi', '.pnpm-store', '$RECYCLE.BIN'
)

function global:Get-CdTree {
    param([switch]$Force)

    if (-not $Force -and $null -ne $global:CdTreeCache -and $global:CdTreeStamp -and
        ((Get-Date) - $global:CdTreeStamp).TotalSeconds -lt 300) {
        return $global:CdTreeCache
    }

    $rows = [System.Collections.Generic.List[object]]::new()

    # Pfade aller Roots, damit ein Ordner, der selbst eine Root ist, nicht
    # doppelt im Baum auftaucht (Documents waere sonst sowohl unter 'home' als
    # auch unter 'docs' sichtbar).
    $rootPaths = @{}
    foreach ($rp in $global:CdRoots.Values) { $rootPaths[$rp.ToLowerInvariant().TrimEnd('\')] = $true }

    function Add-CdSubtree {
        param([string]$Root, [string]$Tag, [int]$Depth)

        # Key bleibt der interne Navigationsschluessel (tag/rel, mit '/'), Label
        # ist das, was fzf anzeigt: Grossbuchstaben-Wurzel, Trennzeichen
        # zwischen den Ebenen und ein abschliessender Backslash an der Wurzel,
        # damit der Baum wie ein echter Windows-Pfad liest:
        #   Wurzel  ->  DEV\ <sep>
        #   Ebene 2 ->  DEV <sep> GAME-DEV
        $rows.Add([pscustomobject]@{ Key = $Tag; Label = ConvertTo-CdLabel $Tag; Path = $Root })

        # Eigene Warteschlange statt Get-ChildItem -Recurse: nur so lassen sich
        # .git/node_modules wirklich abschneiden, statt sie aufzulisten und
        # danach wegzuwerfen.
        $queue = [System.Collections.Generic.Queue[object]]::new()
        $queue.Enqueue([pscustomobject]@{ Dir = $Root; Rel = ''; Level = 0 })

        while ($queue.Count -gt 0) {
            $node = $queue.Dequeue()
            if ($node.Level -ge $Depth) { continue }
            $kids = @(Get-ChildItem -LiteralPath $node.Dir -Directory -Force -ErrorAction SilentlyContinue)
            foreach ($kid in $kids) {
                if ($global:CdTreeNoise -contains $kid.Name) { continue }
                if ($rootPaths.ContainsKey($kid.FullName.ToLowerInvariant().TrimEnd('\'))) { continue }
                $rel = if ($node.Rel) { "$($node.Rel)/$($kid.Name)" } else { $kid.Name }
                $rows.Add([pscustomobject]@{
                    Key   = "$Tag/$rel"
                    Label = ConvertTo-CdLabel "$Tag/$rel"
                    Path  = $kid.FullName
                })
                $queue.Enqueue([pscustomobject]@{ Dir = $kid.FullName; Rel = $rel; Level = $node.Level + 1 })
            }
        }
    }

    foreach ($tag in $global:CdRoots.Keys) {
        $root = $global:CdRoots[$tag]
        if (Test-Path -LiteralPath $root -PathType Container) {
            Add-CdSubtree -Root $root -Tag $tag -Depth $global:CdTreeDepth
        }
    }

    # Reserve: falls das aktuelle Verzeichnis unter keiner Root liegt, mit
    # aufnehmen. Seit 'c' und 'd' Roots sind, ist das auf lokalen Laufwerken
    # nicht mehr erreichbar und bleibt nur als Netzwerklaufwerk-Sicherung.
    # Die Root-Pfade werden vorher am Schlash normalisiert: bei 'C:\' ergibt
    # sonst ein naeherliegendes StartsWith('C:\\') nie true.
    $cwd = if ($PWD.Provider.Name -eq 'FileSystem') { $PWD.ProviderPath } else { $null }
    if ($cwd) {
        $cwdNorm = $cwd.TrimEnd('\')
        $under = $false
        foreach ($root in $global:CdRoots.Values) {
            $r = $root.TrimEnd('\')
            if ($cwdNorm -eq $r -or $cwdNorm.StartsWith("$r\")) { $under = $true; break }
        }
        if (-not $under) { Add-CdSubtree -Root $cwd -Tag '.' -Depth 2 }
    }

    $global:CdTreeCache = $rows.ToArray()
    $global:CdTreeStamp = Get-Date
    return $global:CdTreeCache
}

# Verzeichnisbaum mit fzf, Ebene fuer Ebene: zuerst nur die Entwicklungsordner,
# erst beim Bestätigen werden deren Unterordner sichtbar. Statt 870 Zeilen auf
# einmal also immer nur die direkten Kinder des aktuellen Ordners.
#
#   Enter / ->    hinein in den markierten Ordner
#   <-  / ..      eine Ebene zurück
#   Strg+O        direkt in den markierten Ordner wechseln
#   Esc           alles abbrechen
#
# Gibt den absoluten Pfad zurueck, oder $null wenn abgebrochen wurde.
function global:Invoke-CdTreePicker {
    param([string]$Query = '')

    $rows = @(Get-CdTree)
    if ($rows.Count -eq 0) { return $null }

    $lookup = @{}
    foreach ($row in $rows) { $lookup[$row.Label] = $row }

    $prefix = ''      # '' = Wurzelansicht; sonst der interne Key (tag/rel)
    $hint = 'Enter: hinein    <-: zurueck    Strg+O: hierhin'

    while ($true) {
        $entries = @($rows | Where-Object {
            $k = $_.Key
            if ($prefix -eq '') { $k -notmatch '/' }
            else { $k.StartsWith("$prefix/") -and -not $k.Substring($prefix.Length + 1).Contains('/') }
        })

        $lines = [System.Collections.Generic.List[string]]::new()
        if ($prefix) { $lines.Add('..') }
        foreach ($entry in $entries) { $lines.Add($entry.Label) }
        if ($lines.Count -eq 0) { return $null }

        $crumb = if ($prefix) { ConvertTo-CdLabel $prefix } else { 'Entwicklungsordner' }
        $fzfArgs = @(
            '--expect=ctrl-o,enter,left', '--prompt=cd> ', '--height=60%', '--reverse', '--border',
            '--info=inline', '--tiebreak=index', '--cycle', "--header=$crumb    |    $hint"
        )
        # Der Filter gilt nur fuer die Wurzelansicht, sonst liefe man bei
        # 'cd tree psx' in den tieferen Ebenen ins Leere.
        if ($Query) { $fzfArgs += "--query=$Query"; $Query = '' }

        $raw = @($lines | & fzf @fzfArgs)
        $key = if ($raw.Count -ge 1) { $raw[0] } else { '' }
        $pick = if ($raw.Count -ge 2) { $raw[1] } else { '' }
        if (-not $key -and -not $pick) { return $null }   # Esc

        if ($key -eq 'left') { $prefix = Get-CdParent $prefix; continue }

        if ($pick -eq '..') {
            $prefix = if ($key -eq 'ctrl-o') { $prefix } else { Get-CdParent $prefix }
            continue
        }

        $row = $lookup[$pick]
        if (-not $row) { continue }
        if ($key -eq 'ctrl-o') { return $row.Path }
        $prefix = $row.Key
    }
}

# Interner Key -> Anzeige mit Trennzeichen ($global:CdSep, Voreinstellung "->"):
#   'dev'                 -> 'DEV\ <sep>'
#   'dev/666CLI'          -> 'DEV <sep> 666CLI'
#   'dev/GAME-DEV/PSX'    -> 'DEV <sep> GAME-DEV <sep> PSX'
# Nur das erste Segment (der Alias) wird grossgeschrieben, die echten
# Ordnernamen behalten ihre Schreibweise von der Platte.
function global:ConvertTo-CdLabel {
    param([string]$Key)
    if (-not $Key) { return '' }
    $sep = $global:CdSep
    $parts = $Key.Split('/')
    $name = $parts[$parts.Count - 1]
    if ($parts.Count -eq 1) { return "$($name.ToUpper())\ $sep" }
    $head = @($parts[0..($parts.Count - 2)])
    $head[0] = $head[0].ToUpper()
    return (($head -join " $sep ") + " $sep " + $name)
}

# 'dev/GAME-DEV' -> 'dev',  'dev' -> ''
function global:Get-CdParent {
    param([string]$Display)
    if (-not $Display) { return '' }
    $slash = $Display.LastIndexOf('/')
    if ($slash -lt 0) { return '' }
    return $Display.Substring(0, $slash)
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {

    # zoxide.exe ist unsigniert (FACEIT-AC-Taxe auf jeden Start), daher die
    # Frecency-Liste pro Shell cachen statt sie pro 'cd' neu abzufragen.
    $global:CdIndex = @()
    $global:CdIndexStamp = $null

    function global:Get-CdIndex {
        param([switch]$Force)
        if (-not $Force -and $global:CdIndexStamp -and ((Get-Date) - $global:CdIndexStamp).TotalSeconds -lt 60) {
            return $global:CdIndex
        }
        $paths = @()
        try { $paths = @(__zoxide_bin query -l 2>$null) } catch { }
        $global:CdIndex = @($paths | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) })
        $global:CdIndexStamp = Get-Date
        return $global:CdIndex
    }

    # Ein Segment gegen die direkten Unterordner von $Parent aufloesen:
    # exakter Name, dann eindeutiger Praefix, dann eindeutiger Teilstring.
    # Mehrdeutige Treffer liefern bewusst $null, damit die normale Fehlermeldung
    # und die Tab-Vorschlaege sichtbar bleiben statt still etwas Falsches zu waehlen.
    function global:Find-CdChild {
        param([string]$Parent, [string]$Segment)
        if (-not $Parent) { return $null }
        if (-not (Test-Path -LiteralPath $Parent -PathType Container)) { return $null }
        $needle = $Segment.ToLowerInvariant()
        try { $kids = @(Get-ChildItem -LiteralPath $Parent -Directory -Force -ErrorAction Stop) } catch { return $null }

        $hit = @($kids | Where-Object { $_.Name.ToLowerInvariant() -eq $needle })
        if ($hit.Count -eq 1) { return $hit[0].FullName }

        $hit = @($kids | Where-Object { $_.Name.ToLowerInvariant().StartsWith($needle) } |
                 Sort-Object -Property @{ Expression = { $_.Name.Length } }, Name)
        if ($hit.Count -eq 1) { return $hit[0].FullName }

        $hit = @($kids | Where-Object { $_.Name.ToLowerInvariant().Contains($needle) } |
                 Sort-Object -Property @{ Expression = { $_.Name.Length } }, Name)
        if ($hit.Count -eq 1) { return $hit[0].FullName }

        return $null
    }

    # Dasselbe gegen die zoxide-Frecency: ermoeglicht Spruenge aus jedem Ordner.
    function global:Find-CdFrecency {
        param([string]$Segment)
        $needle = $Segment.ToLowerInvariant()
        $index = @(Get-CdIndex)
        if ($index.Count -eq 0) { return $null }
        $hit = @($index | Where-Object { (Split-Path -Leaf $_).ToLowerInvariant().StartsWith($needle) })
        if ($hit.Count -eq 0) {
            $hit = @($index | Where-Object { (Split-Path -Leaf $_).ToLowerInvariant().Contains($needle) })
        }
        if ($hit.Count -eq 1) { return $hit[0] }
        return $null
    }

    # Mehrsegmentpfad Stueck fuer Stueck aufloesen; segment 0 darf auf die
    # Frecency ausweichen, die weiteren Segmente nicht (das waere geraten).
    function global:Resolve-CdPath {
        param([string]$InputPath)
        if ([string]::IsNullOrWhiteSpace($InputPath)) { return $null }
        if ($PWD.Provider.Name -ne 'FileSystem') { return $null }
        if ($InputPath.StartsWith('~')) { return $null }
        if ($InputPath.Contains(':')) { return $null }
        if ($InputPath.StartsWith('\\')) { return $null }

        $segments = @($InputPath.Split([char[]]@('/', '\'), [System.StringSplitOptions]::RemoveEmptyEntries))
        if ($segments.Count -eq 0) { return $null }

        $current = $null
        for ($i = 0; $i -lt $segments.Count; $i++) {
            $root = if ($i -eq 0) { $PWD.ProviderPath } else { $current }

            # Ein bekannter Entwicklungsordner schlaegt immer die lokale Aufloesung.
            $resolved = $null
            if ($i -eq 0 -and $global:CdRoots.Contains($segments[$i])) {
                $resolved = $global:CdRoots[$segments[$i]]
            }

            if (-not $resolved) { $resolved = Find-CdChild -Parent $root -Segment $segments[$i] }
            if (-not $resolved -and $i -eq 0) { $resolved = Find-CdFrecency -Segment $segments[$i] }
            if (-not $resolved) { return $null }
            $current = $resolved
        }
        return $current
    }

    Remove-Item -Path 'Alias:cd' -Force -ErrorAction SilentlyContinue

    # Set-Location-Schalter mit eigenem Wert. Ohne diese Liste wuerde das 'Stop'
    # aus 'cd -ErrorAction Stop rob' als Zielpfad missverstanden.
    $global:CdValuedFlags = @(
        '-ErrorAction', '-WarningAction', '-InformationAction', '-ProgressAction',
        '-ErrorVariable', '-WarningVariable', '-InformationVariable', '-OutVariable',
        '-OutBuffer', '-PipelineVariable', '-Credential', '-UseTransaction',
        '-StackName', '-WhatIf', '-Confirm'
    )

    function global:cd {
        # Bewusst ohne [CmdletBinding()]: nur so landen alle Argumente unveraendert
        # in $args und koennen 1:1 an das echte Set-Location weitergereicht werden.
        $from = if ($PWD.Provider.Name -eq 'FileSystem') { $PWD.ProviderPath } else { $null }
        $flags = @()
        $target = $null
        $extra = @()
        $isTree = $false
        $list = @($args)
        for ($i = 0; $i -lt $list.Count; $i++) {
            $a = $list[$i]
            if ($a -is [string] -and $a.StartsWith('-')) {
                # '-Schalter:$wert' kommt als zwei Argumente an (-Schalter:, Wert)
                # und muss vor dem Weiterreichen wieder zusammengeklebt werden.
                if ($a.EndsWith(':') -and $i + 1 -lt $list.Count) {
                    $flags += "$a$($list[++$i])"
                    continue
                }
                $flags += $a
                if ($global:CdValuedFlags -contains $a) {
                    if ($i + 1 -lt $list.Count) { $flags += $list[++$i] }
                }
                continue
            }
            if ($null -eq $target) {
                # 'cd tree' bzw. 'cd tree psx' oeffnet den Verzeichnisbaum
                # statt einen Ordner namens "tree" zu suchen.
                if ($a -eq 'tree') { $isTree = $true } else { $target = $a }
            }
            else { $extra += $a }
        }

        if ($isTree) {
            $picked = Invoke-CdTreePicker -Query ($extra -join ' ').Trim()
            if ($picked) {
                Microsoft.PowerShell.Management\Set-Location -LiteralPath $picked @flags
                if ($?) { $global:CdPrevious = $from }
            }
            return
        }
        $flags += $extra

        $literal = ($flags -contains '-LiteralPath')
        $resolved = $null

        if ($target -is [string] -and $target -and -not $literal) {
            if ($target -eq '-') {
                # Eigenes Mergewisse statt __zoxide_oldpwd: letzteres wird nur ueber
                # den zoxide-Prompt-Hook gepflegt und ist in Skripten nicht verlaesslich.
                $resolved = $global:CdPrevious
                if (-not $resolved) { $resolved = $global:__zoxide_oldpwd }
            }
            elseif ($target -match '^\.\.+$') {
                $base = $PWD.ProviderPath
                for ($n = 1; $n -lt $target.Length; $n++) { $base = Split-Path -Path $base -Parent }
                if ($base) { $resolved = $base }
            }
            else {
                $resolved = Resolve-CdPath -InputPath $target
                if (-not $resolved) {
                    # Erstversuch verfehlt: Index neu laden und einmal wiederholen,
                    # sonst bleiben frisch besuchte Ordner unsichtbar.
                    $null = Get-CdIndex -Force
                    $resolved = Resolve-CdPath -InputPath $target
                }
            }
        }

        if ($resolved) {
            Microsoft.PowerShell.Management\Set-Location -LiteralPath $resolved @flags
        }
        elseif ($null -ne $target) {
            Microsoft.PowerShell.Management\Set-Location @flags $target
        }
        else {
            Microsoft.PowerShell.Management\Set-Location @flags
        }

        if ($? -and $from) { $global:CdPrevious = $from }
    }

    Register-ArgumentCompleter -Native -CommandName cd -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)

        $prefix = ''
        $leaf = $wordToComplete
        $cut = $wordToComplete.LastIndexOfAny([char[]]@('\', '/'))
        if ($cut -ge 0) {
            $prefix = $wordToComplete.Substring(0, $cut + 1)
            $leaf = $wordToComplete.Substring($cut + 1)
        }

        # Ohne Trennzeichen zuerst die Entwicklungsordner anbieten; danach erst
        # der Inhalt des aktuellen Verzeichnisses, sonst wird die Liste zu lang.
        if ($cut -lt 0 -and $global:CdRoots) {
            $needle = $leaf.ToLowerInvariant()
            foreach ($tag in $global:CdRoots.Keys) {
                if ($tag.StartsWith($needle)) {
                    [System.Management.Automation.CompletionResult]::new(
                        "$tag\", "$tag\", 'ProviderContainer', $global:CdRoots[$tag])
                }
            }
        }

        $searchRoot = $PWD.ProviderPath
        if ($cut -ge 0) {
            $partial = $prefix.TrimEnd('\', '/')
            $candidate = $null
            if ($partial -and $global:CdRoots.Contains($partial)) {
                $candidate = $global:CdRoots[$partial]
            }
            if (-not $candidate -and $partial) {
                $try = Join-Path -Path $searchRoot -ChildPath $partial
                if (Test-Path -LiteralPath $try -PathType Container) { $candidate = (Get-Item -LiteralPath $try).FullName }
            }
            if (-not $candidate -and $partial) { $candidate = Resolve-CdPath -InputPath $partial }
            if (-not $candidate) { return }
            $searchRoot = $candidate
        }

        $needle = $leaf.ToLowerInvariant()
        Get-ChildItem -LiteralPath $searchRoot -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name.ToLowerInvariant().StartsWith($needle) } |
            Sort-Object Name |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    "$prefix$($_.Name)\",
                    "$_.Name\",
                    'ProviderContainer',
                    $_.FullName)
            }
    }

    Register-ArgumentCompleter -Native -CommandName z, zi -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)

        if ($wordToComplete.Contains(':') -or $wordToComplete.StartsWith('\\')) { return }
        $needle = $wordToComplete.ToLowerInvariant()
        $index = @(Get-CdIndex)
        if ($index.Count -eq 0) { return }

        $hit = @($index | Where-Object { $_.ToLowerInvariant().StartsWith($needle) -or $_.ToLowerInvariant().Contains($needle) })
        $hit | Select-Object -First 40 | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ProviderContainer', $_)
        }
    }

    $null = Get-CdIndex
}

# --- PSReadLine: Syntax-Highlighting, Vorschlaege & Autovervollstaendigung ---
$newestPSReadLine = Get-Module -ListAvailable -Name PSReadLine | Sort-Object Version -Descending | Select-Object -First 1
if ($newestPSReadLine) {
    # PSReadLine is already autoloaded by the host at startup; only pay for a
    # reimport when a newer version than what's loaded is actually available.
    $loadedPSReadLine = Get-Module -Name PSReadLine
    if (-not $loadedPSReadLine -or $loadedPSReadLine.Version -ne $newestPSReadLine.Version) {
        Import-Module PSReadLine -RequiredVersion $newestPSReadLine.Version -Force -ErrorAction SilentlyContinue
    }

    if ($newestPSReadLine.Version -ge [Version]'2.2.0') {
        # CompletionPredictor turns tab-completion results into inline
        # suggestions, so proposals cover more than just past commands.
        $havePredictor = Get-Module -ListAvailable -Name CompletionPredictor -ErrorAction SilentlyContinue
        if ($havePredictor) {
            Import-Module CompletionPredictor -ErrorAction SilentlyContinue
        }

        try {
            if ($havePredictor) {
                Set-PSReadLineOption -PredictionSource HistoryAndPlugin -ErrorAction Stop
            } else {
                Set-PSReadLineOption -PredictionSource History -ErrorAction Stop
            }
            Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction Stop
        } catch { }
    }

    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -MaximumHistoryCount 32767
    Set-PSReadLineOption -HistoryNoDuplicates
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -BellStyle None
    Set-PSReadLineOption -ShowToolTips

    $colors = @{
        Command   = 'Cyan'
        Parameter = 'DarkCyan'
        Operator  = 'Magenta'
        Variable  = 'Green'
        String    = 'Yellow'
        Number    = 'DarkYellow'
        Type      = 'DarkGreen'
        Comment   = 'DarkGray'
        Keyword   = 'Blue'
        Error     = 'Red'
    }
    if ($newestPSReadLine.Version -ge [Version]'2.2.0') {
        $colors['InlinePrediction'] = 'DarkGray'
    }
    Set-PSReadLineOption -Colors $colors

    # Tab  -> Menue mit allen Treffern
    # Up/Down -> durchsucht die History nach dem bereits Getippten
    Set-PSReadLineKeyHandler -Key Tab       -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # Rechts-Pfeil am Zeilenende uebernimmt den grauen Vorschlag,
    # Ctrl+Rechts nur das naechste Wort davon.
    Set-PSReadLineKeyHandler -Key RightArrow      -Function ForwardChar
    Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord
    Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow  -Function BackwardWord

    # F2 schaltet zwischen Inline- und Listenansicht der Vorschlaege um.
    if ($newestPSReadLine.Version -ge [Version]'2.2.0') {
        Set-PSReadLineKeyHandler -Key F2 -Function SwitchPredictionView
    }

    # Klammern/Anfuehrungszeichen um markierten Text setzen
    Set-PSReadLineKeyHandler -Key Alt+w -Function CopyOrCancelLine
    Set-PSReadLineKeyHandler -Key Ctrl+d -Function DeleteCharOrExit
}

# --- fzf: unscharfe Suche fuer History, Dateien und Verzeichnisse ---
# Ctrl+r  History durchsuchen
# Ctrl+t  Datei auswaehlen und in die Zeile einfuegen
# Alt+c   Verzeichnis auswaehlen und hinspringen
if ((Get-Module -ListAvailable -Name PSFzf) -and (Get-Command fzf -ErrorAction SilentlyContinue)) {
    Import-Module PSFzf -ErrorAction SilentlyContinue
    try {
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' `
                        -PSReadlineChordReverseHistory 'Ctrl+r' `
                        -EnableAliasFuzzyEdit `
                        -EnableAliasFuzzyKillProcess
        Set-PSReadLineKeyHandler -Key Alt+c -ScriptBlock {
            Invoke-FuzzySetLocation
            [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
        }
        # Ctrl+Alt+z  Verzeichnis-Auswahl aus dem Baum aller Hauptordner
        Set-PSReadLineKeyHandler -Key Ctrl+Alt+z -ScriptBlock {
            $picked = Invoke-CdTreePicker
            if ($picked) {
                $from = $PWD.ProviderPath
                Microsoft.PowerShell.Management\Set-Location -LiteralPath $picked
                if ($?) { $global:CdPrevious = $from }
            }
        }
        # Ctrl+Alt+1..9 Direktsprung auf die ersten neun Wurzeln. Mehr gibt es
        # nicht: 'Ctrl+Alt+10' ist kein gueltiger PSReadLine-Akkoord.
        $slot = 0
        foreach ($tag in $global:CdRoots.Keys) {
            if ($slot -ge 9) { break }
            $slot++
            $target = $global:CdRoots[$tag]
            Set-PSReadLineKeyHandler -Key "Ctrl+Alt+$slot" -ScriptBlock {
                Microsoft.PowerShell.Management\Set-Location -LiteralPath $target
            }.GetNewClosure()
        }
    } catch { }
}

# --- Built-in Ersatz fuer ls/ll/la/tree/cat/grep ---
# eza/bat/rg are unsigned; the FACEIT AC driver taxes every unsigned exe launch
# by ~8s while it is running. Using signed, built-in PowerShell equivalents
# avoids that entirely (ls/cat already fall back to their default aliases).
function ll { Get-ChildItem @args }
function la { Get-ChildItem -Force @args }
function tree { & "$env:SystemRoot\System32\tree.com" /F @args }
function grep {
    if ($MyInvocation.ExpectingInput) { $input | Select-String @args }
    else { Select-String @args }
}

# --- Dev-Layout und Dateimanager ---
# dev [dir]   teilt den aktuellen Windows-Terminal-Tab: Shell links, lazygit oben
#             rechts (yazi, wenn der Ordner kein Git-Repo ist), btop unten rechts.
# Ctrl+Alt+d  dasselbe fuer den aktuellen Ordner.
# y [dir]     yazi; beim Beenden landet die Shell im zuletzt offenen Ordner.
# Alle drei sind unsigniert, laufen also nur auf Abruf, nie beim Shell-Start.
if (Test-Path "$env:ProgramFiles\Git\usr\bin\file.exe") {
    # yazi erkennt Dateitypen fuer die Vorschau ueber file(1).
    $env:YAZI_FILE_ONE = "$env:ProgramFiles\Git\usr\bin\file.exe"
}

function dev {
    param([string]$Path = $PWD.ProviderPath)
    if (-not $env:WT_SESSION) { Write-Warning 'dev braucht Windows Terminal.'; return }
    $dir = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $isRepo = (git -C $dir rev-parse --is-inside-work-tree 2>$null) -eq 'true'
    # Volle Pfade: neue Panes erben die Umgebung von Windows Terminal, und die
    # kennt den winget-Links-Ordner nicht, wenn WT vor der Installation lief.
    $top  = (Get-Command $(if ($isRepo) { 'lazygit' } else { 'yazi' }) -ErrorAction Stop).Source
    $btop = (Get-Command btop -ErrorAction Stop).Source
    # wt can only split to the right, so split, swap the new pane to the left,
    # then split it again for btop and hand focus back to the shell.
    wt -w 0 sp -V -s 0.7 -d $dir $top `; swap-pane left `; sp -H -s 0.4 -d $dir $btop `; mf right
}

function y {
    $tmp = (New-TemporaryFile).FullName
    yazi @args --cwd-file="$tmp"
    $cwd = Get-Content -LiteralPath $tmp -Encoding UTF8
    Remove-Item -LiteralPath $tmp
    if ($cwd -and $cwd -ne $PWD.ProviderPath) {
        $from = $PWD.ProviderPath
        Microsoft.PowerShell.Management\Set-Location -LiteralPath $cwd
        if ($?) { $global:CdPrevious = $from }
    }
}

# panel       Seitenleiste rechts: Projektbaum, Git- und Port-Status, Tasten.
# Ctrl+Alt+p  dasselbe. Das Panel folgt jedem cd dieser Shell.
function panel {
    if (-not $env:WT_SESSION) { Write-Warning 'panel braucht Windows Terminal.'; return }
    $script = "$HOME\.config\wt\panel.ps1"
    if (-not (Test-Path -LiteralPath $script)) { Write-Warning "$script fehlt."; return }
    if (-not $global:PanelCwdFile) {
        # Der Prompt schreibt ab jetzt den aktuellen Ordner fuer das Panel mit.
        $global:PanelCwdFile = Join-Path ([IO.Path]::GetTempPath()) "wt-panel-$PID.txt"
        $global:PanelInnerPrompt = (Get-Item function:prompt).ScriptBlock
        function global:prompt {
            $out = & $global:PanelInnerPrompt
            if ($PWD.ProviderPath -ne $global:PanelLastCwd) {
                $global:PanelLastCwd = $PWD.ProviderPath
                [IO.File]::WriteAllText($global:PanelCwdFile, $global:PanelLastCwd)
            }
            $out
        }
    }
    $global:PanelLastCwd = $PWD.ProviderPath
    [IO.File]::WriteAllText($global:PanelCwdFile, $global:PanelLastCwd)
    $shell = (Get-Process -Id $PID).Path
    wt -w 0 sp -V -s 0.25 -d $PWD.ProviderPath $shell -NoLogo -NoProfile -File $script `
        -CwdFile $global:PanelCwdFile -ShellPid $PID `; mf left
}

if ($env:WT_SESSION -and (Get-Command Set-PSReadLineKeyHandler -ErrorAction SilentlyContinue)) {
    Set-PSReadLineKeyHandler -Key Ctrl+Alt+d -BriefDescription DevLayout -ScriptBlock { dev }
    Set-PSReadLineKeyHandler -Key Ctrl+Alt+p -BriefDescription SidePanel -ScriptBlock { panel }
}

# --- Farbige ls/dir-Ausgabe als Fallback, falls eza fehlt (PS 7.2+) ---
if ($PSStyle) {
    $PSStyle.FileInfo.Directory = "`e[1;34m"
}


# --- Begruessung ---
# Rechnername in duennen Rahmenlinien-Buchstaben plus die wichtigsten Befehle,
# in jeder neuen Shell. Ersetzt das Fastfetch-Banner, `fastfetch` geht weiter
# von Hand.
function welcome {
    $script = "$HOME\.config\wt\welcome.ps1"
    if (Test-Path -LiteralPath $script) { & $script }
}
if (-not $env:CLAUDECODE) { welcome }
