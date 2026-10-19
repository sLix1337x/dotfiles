<#
.SYNOPSIS
    Installs the Windows terminal setup: CLI tools, Nerd Font, PowerShell
    profile, Starship, Fastfetch and Windows Terminal configuration.

.DESCRIPTION
    Idempotent - safe to re-run. Existing files are backed up with a timestamp
    before being replaced. Administrator rights are not required; the font is
    installed per-user.

    The AI CLI configs in ai\ are opt-in: pass -AI to install them.

.EXAMPLE
    .\install.ps1
    .\install.ps1 -SkipTools -SkipFont
    .\install.ps1 -AI
    .\install.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$SkipTools,
    [switch]$SkipFont,
    [switch]$SkipTerminal,
    [switch]$AI,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
$Stamp    = Get-Date -Format 'yyyyMMdd-HHmmss'
$Summary  = [System.Collections.Generic.List[object]]::new()

# ---------------------------------------------------------------- output ----
function Write-Step { param($m) Write-Host "`n==> $m" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "    [ok]   $m" -ForegroundColor Green }
function Write-Skip { param($m) Write-Host "    [skip] $m" -ForegroundColor DarkGray }
function Write-Note { param($m) Write-Host "    [warn] $m" -ForegroundColor Yellow }
function Write-Fail { param($m) Write-Host "    [fail] $m" -ForegroundColor Red }

function Add-Result {
    param($Name, $Status, $Detail = '')
    $Summary.Add([pscustomobject]@{ Item = $Name; Status = $Status; Detail = $Detail })
}

function Sync-Path {
    # Pull PATH back out of the registry so tools installed during this run
    # resolve without opening a new shell.
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:PATH = (@($machine, $user, "$env:USERPROFILE\bin") | Where-Object { $_ }) -join ';'
}

function Backup-File {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    $bak = "$Path.$Stamp.bak"
    if ($PSCmdlet.ShouldProcess($Path, 'back up')) {
        Copy-Item $Path $bak -Force
        Write-Ok "backed up existing -> $(Split-Path -Leaf $bak)"
    }
}

function Install-Config {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Source, [string]$Dest, [string]$Label)

    if (-not (Test-Path $Source)) {
        Write-Fail "$Label - source missing: $Source"
        Add-Result $Label 'FAILED' 'source missing'
        return
    }
    if (-not $PSCmdlet.ShouldProcess($Dest, "install $Label")) { return }

    New-Item -ItemType Directory -Force (Split-Path -Parent $Dest) | Out-Null
    Backup-File $Dest
    Copy-Item $Source $Dest -Force
    Write-Ok "$Label -> $Dest"
    Add-Result $Label 'installed' $Dest
}

Write-Host @"

  dotfiles - Windows setup
  repo: $RepoRoot

"@ -ForegroundColor Magenta

# ----------------------------------------------------------------- tools ----
if (-not $SkipTools) {
    Write-Step 'CLI tools (winget)'

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Fail 'winget not found. Install "App Installer" from the Microsoft Store, then re-run.'
        Add-Result 'winget' 'MISSING' 'install App Installer'
    }
    else {
        # id  = winget package id
        # cmd = executable that must resolve once the install finishes
        $tools = @(
            # Windows Terminal opens PowerShell 7 by default. Its MSI asks for
            # UAC; decline and the terminal falls back to 5.1 (see below).
            @{ id = 'Microsoft.PowerShell';    cmd = 'pwsh'      }
            @{ id = 'Starship.Starship';       cmd = 'starship'  }
            @{ id = 'ajeetdsouza.zoxide';      cmd = 'zoxide'    }
            @{ id = 'Fastfetch-cli.Fastfetch'; cmd = 'fastfetch' }
            @{ id = 'eza-community.eza';       cmd = 'eza'       }
            @{ id = 'sharkdp.bat';             cmd = 'bat'       }
            @{ id = 'junegunn.fzf';            cmd = 'fzf'       }
            @{ id = 'BurntSushi.ripgrep.MSVC'; cmd = 'rg'        }
            @{ id = 'dandavison.delta';        cmd = 'delta'     }
            @{ id = 'JesseDuffield.lazygit';   cmd = 'lazygit'   }
            @{ id = 'sxyazi.yazi';             cmd = 'yazi'      }
            @{ id = 'aristocratos.btop4win';   cmd = 'btop'      }
        )

        foreach ($t in $tools) {
            Sync-Path
            if ((Get-Command $t.cmd -ErrorAction SilentlyContinue) -and -not $Force) {
                Write-Skip "$($t.cmd) already installed"
                Add-Result $t.cmd 'present'
                continue
            }
            if (-not $PSCmdlet.ShouldProcess($t.id, 'winget install')) { continue }

            Write-Host "    installing $($t.id) ..." -ForegroundColor DarkGray

            # Try twice: winget can report success for a dependency while the
            # package itself never lands (seen with sharkdp.bat). Verifying the
            # executable is the only reliable signal.
            $ok = $false
            foreach ($attempt in 1..2) {
                & winget install --id $t.id -e --source winget `
                    --accept-package-agreements --accept-source-agreements `
                    --disable-interactivity 2>&1 | Out-Null
                Sync-Path
                if (Get-Command $t.cmd -ErrorAction SilentlyContinue) { $ok = $true; break }
                if ($attempt -eq 1) { Write-Note "$($t.cmd) did not resolve, retrying" }
            }

            if ($ok) { Write-Ok $t.cmd; Add-Result $t.cmd 'installed' }
            else     { Write-Fail "$($t.cmd) still not on PATH"; Add-Result $t.cmd 'FAILED' 'not on PATH' }
        }
    }
}
else {
    Write-Step 'CLI tools'
    Write-Skip 'skipped (-SkipTools)'
}

# ------------------------------------------------------------ PSReadLine ----
Write-Step 'PSReadLine (2.2+ enables history prediction)'
$have = Get-Module -ListAvailable PSReadLine |
        Sort-Object Version -Descending | Select-Object -First 1

if ($have -and $have.Version -ge [Version]'2.2.0' -and -not $Force) {
    Write-Skip "PSReadLine $($have.Version) already sufficient"
    Add-Result 'PSReadLine' 'present' "$($have.Version)"
}
elseif ($PSCmdlet.ShouldProcess('PSReadLine', 'install from PSGallery')) {
    try {
        if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
        }
        try { Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop } catch { }

        Install-Module PSReadLine -Force -Scope CurrentUser -AllowClobber -SkipPublisherCheck -ErrorAction Stop
        $new = (Get-Module -ListAvailable PSReadLine |
                Sort-Object Version -Descending | Select-Object -First 1).Version
        Write-Ok "PSReadLine $new"
        Add-Result 'PSReadLine' 'installed' "$new"
    }
    catch {
        Write-Note "PSReadLine update failed: $($_.Exception.Message)"
        Write-Note 'The prompt still works; history prediction stays off.'
        Add-Result 'PSReadLine' 'FAILED' $_.Exception.Message
    }
}

# -------------------------------------------------------- suggestion mods ----
Write-Step 'Suggestion modules'

# PSFzf drives the fuzzy Ctrl+r / Ctrl+t / Alt+c bindings and works on 5.1.
# CompletionPredictor needs the predictor subsystem introduced in PowerShell
# 7.2, so on 5.1 the profile falls back to history-only suggestions.
function Install-PSModule {
    param([string]$Name, [string]$Host7 = $null)
    try {
        if ($Host7) {
            & $Host7 -NoProfile -Command "Install-Module $Name -Force -Scope CurrentUser -AllowClobber -SkipPublisherCheck -AcceptLicense -ErrorAction Stop" 2>&1 | Out-Null
            Write-Ok "$Name (PowerShell 7)"
            Add-Result "$Name (PS7)" 'installed'
        }
        else {
            Install-Module $Name -Force -Scope CurrentUser -AllowClobber -SkipPublisherCheck -ErrorAction Stop
            Write-Ok $Name
            Add-Result $Name 'installed'
        }
    }
    catch {
        Write-Note "$Name failed: $($_.Exception.Message)"
        Add-Result $Name 'FAILED' $_.Exception.Message
    }
}

if ($PSCmdlet.ShouldProcess('PSFzf', 'install')) {
    if (Get-Module -ListAvailable PSFzf) { Write-Skip 'PSFzf already installed'; Add-Result 'PSFzf' 'present' }
    else { Install-PSModule 'PSFzf' }
}

$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pwsh) {
    if ($PSCmdlet.ShouldProcess('CompletionPredictor', 'install into PowerShell 7')) {
        Install-PSModule 'CompletionPredictor' $pwsh.Source
        Install-PSModule 'PSFzf' $pwsh.Source
    }
}
else {
    Write-Skip 'PowerShell 7 not found - completion-based suggestions unavailable'
    Write-Note 'For richer suggestions install it:  winget install Microsoft.PowerShell'
    Add-Result 'PowerShell 7' 'absent' 'history-only suggestions'
}

# ------------------------------------------------------------------ font ----
if (-not $SkipFont) {
    Write-Step 'JetBrainsMono Nerd Font (per-user, no admin needed)'
    $fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    $fontKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    $already = @(Get-ChildItem $fontDir -Filter '*NerdFontMono*.ttf' -ErrorAction SilentlyContinue)

    if ($already.Count -ge 12 -and -not $Force) {
        Write-Skip "$($already.Count) faces already installed"
        Add-Result 'Nerd Font' 'present' "$($already.Count) faces"
    }
    elseif ($PSCmdlet.ShouldProcess('JetBrainsMono Nerd Font Mono', 'download and install')) {
        $tmp = Join-Path $env:TEMP "nerdfont-$Stamp"
        try {
            New-Item -ItemType Directory -Force $tmp, $fontDir | Out-Null
            New-Item -Path $fontKey -Force | Out-Null
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

            $zip = Join-Path $tmp 'JetBrainsMono.zip'
            Write-Host '    downloading from github.com/ryanoasis/nerd-fonts ...' -ForegroundColor DarkGray
            Invoke-WebRequest -UseBasicParsing -OutFile $zip `
                -Uri 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip'
            Expand-Archive $zip -DestinationPath (Join-Path $tmp 'x') -Force

            Add-Type -AssemblyName System.Drawing
            if (-not ('FontRes' -as [type])) {
                Add-Type @'
using System;
using System.Runtime.InteropServices;
public class FontRes {
    [DllImport("gdi32.dll")] public static extern int AddFontResource(string f);
}
'@
            }

            $n = 0
            foreach ($f in Get-ChildItem (Join-Path $tmp 'x') -Filter '*NerdFontMono*.ttf') {
                $target = Join-Path $fontDir $f.Name
                Copy-Item $f.FullName $target -Force

                $pfc = New-Object System.Drawing.Text.PrivateFontCollection
                $pfc.AddFontFile($target)
                $family = $pfc.Families[0].Name
                $pfc.Dispose()

                # Weight variants (Light/SemiLight/SemiBold/ExtraLight) already
                # carry the weight inside the family name - appending it again
                # produces "NFM SemiBold Semi Bold". Only Bold and Italic are
                # genuine styles of the base family.
                $full = $family
                if ($f.BaseName -match '-Bold(Italic)?$') { $full = "$family Bold" }
                if ($f.BaseName -match 'Italic$')         { $full = "$full Italic" }

                New-ItemProperty -Path $fontKey -Name "$full (TrueType)" -Value $target `
                                 -PropertyType String -Force | Out-Null
                [FontRes]::AddFontResource($target) | Out-Null
                $n++
            }
            Write-Ok "$n faces installed (JetBrainsMono Nerd Font Mono)"
            Add-Result 'Nerd Font' 'installed' "$n faces"
        }
        catch {
            Write-Fail "font install failed: $($_.Exception.Message)"
            Add-Result 'Nerd Font' 'FAILED' $_.Exception.Message
        }
        finally {
            Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
else {
    Write-Step 'Nerd Font'
    Write-Skip 'skipped (-SkipFont)'
}

# --------------------------------------------------------------- configs ----
Write-Step 'Shell and tool configs'

# One profile serves both hosts - it feature-detects at runtime - so deploy it
# to the 5.1 and the 7 location regardless of which host is running this.
$docs = [Environment]::GetFolderPath('MyDocuments')
Install-Config "$RepoRoot\Microsoft.PowerShell_profile.ps1" `
               "$docs\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" 'profile (PS 5.1)'
Install-Config "$RepoRoot\Microsoft.PowerShell_profile.ps1" `
               "$docs\PowerShell\Microsoft.PowerShell_profile.ps1" 'profile (PS 7)'
Install-Config "$RepoRoot\config\starship\starship.toml" "$env:USERPROFILE\.config\starship.toml" 'starship'
# ~/.config/git/config is read alongside ~/.gitconfig, so this never touches
# an existing name/email.
Install-Config "$RepoRoot\config\git\config" "$env:USERPROFILE\.config\git\config" 'git config'

$ffDir = "$env:USERPROFILE\.config\fastfetch"
if ($PSCmdlet.ShouldProcess($ffDir, 'install fastfetch config')) {
    New-Item -ItemType Directory -Force $ffDir | Out-Null
    Copy-Item "$RepoRoot\config\fastfetch\*" $ffDir -Force
    Write-Ok "fastfetch -> $ffDir"
    Add-Result 'fastfetch config' 'installed' $ffDir
}

# lazygit reads %LOCALAPPDATA%\lazygit on Windows, not ~\.config.
Install-Config "$RepoRoot\config\lazygit\config.yml" "$env:LOCALAPPDATA\lazygit\config.yml" 'lazygit'

# btop4win only looks for btop.conf and themes\ next to its own exe, which
# winget keeps in a package folder behind the Links shim. Follow the shim.
$btop = Get-Command btop -ErrorAction SilentlyContinue
if ($btop) {
    $btopExe = @((Get-Item $btop.Source).Target)[0]
    if (-not $btopExe) { $btopExe = $btop.Source }
    $btopDir = Split-Path -Parent $btopExe
    Install-Config "$RepoRoot\config\btop\themes\rose-pine.theme" "$btopDir\themes\rose-pine.theme" 'btop theme'

    $conf = "$btopDir\btop.conf"
    if ($PSCmdlet.ShouldProcess($conf, 'set btop theme')) {
        # btop rewrites the file on exit and keeps any keys it finds, so only
        # these three get replaced. No theme background lets the WT blur through.
        $keep = if (Test-Path $conf) {
            Backup-File $conf
            @(Get-Content $conf | Where-Object { $_ -notmatch '^(color_theme|theme_background|rounded_corners)\s*=' })
        } else { @() }
        $keep + 'color_theme = "rose-pine"', 'theme_background = False', 'rounded_corners = True' |
            Set-Content $conf -Encoding ASCII
        Write-Ok "btop -> $conf"
        Add-Result 'btop config' 'installed' $conf
    }
} else {
    Write-Note 'btop not on PATH - skipping its theme.'
}

# ------------------------------------------------------- windows terminal ----
if (-not $SkipTerminal) {
    Write-Step 'Windows Terminal'
    $wtDir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"

    if (-not (Test-Path $wtDir)) {
        Write-Note 'Windows Terminal is not installed - skipping its settings.'
        Write-Note 'Install it with:  winget install Microsoft.WindowsTerminal'
        Add-Result 'Windows Terminal' 'skipped' 'not installed'
    }
    elseif ($PSCmdlet.ShouldProcess($wtDir, 'install settings.json')) {
        if (Get-Process WindowsTerminal -ErrorAction SilentlyContinue) {
            Write-Note 'Windows Terminal is running - restart it to pick up the new settings.'
        }

        # Assets live next to the other configs so no profile points into a
        # personal folder like Documents.
        $assetDir = "$env:USERPROFILE\.config\wt"
        New-Item -ItemType Directory -Force $assetDir | Out-Null
        Copy-Item "$RepoRoot\windows-terminal\assets\*" $assetDir -Force
        Write-Ok "assets -> $assetDir"

        # settings.json ships with %USERPROFILE% placeholders so the file in git
        # stays account-independent; expand them on the way in. Backslashes have
        # to be doubled because the value is being written into JSON.
        $raw     = Get-Content "$RepoRoot\windows-terminal\settings.json" -Raw
        $homeEsc = $env:USERPROFILE -replace '\\', '\\'
        $raw     = $raw -replace '%USERPROFILE%', $homeEsc

        # Without PowerShell 7 the default profile fails to launch, so point
        # it at Windows PowerShell 5.1 instead. Same look, same profile script.
        Sync-Path
        if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
            Write-Note 'PowerShell 7 not found - the default profile runs Windows PowerShell 5.1.'
            Write-Note 'Install 7 later with:  winget install Microsoft.PowerShell, then re-run this.'
            $raw = $raw.Replace('"pwsh.exe -NoLogo"',
                                '"%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -NoLogo"').
                        Replace('"PowerShell 7"', '"Windows PowerShell"')
        }

        $valid = $true
        try { $null = $raw | ConvertFrom-Json }
        catch {
            Write-Fail "generated settings.json is not valid JSON: $($_.Exception.Message)"
            Add-Result 'Windows Terminal' 'FAILED' 'invalid JSON'
            $valid = $false
        }

        if ($valid) {
            $wtFile = Join-Path $wtDir 'settings.json'
            Backup-File $wtFile
            [IO.File]::WriteAllText($wtFile, $raw, (New-Object Text.UTF8Encoding $false))
            Write-Ok "settings.json -> $wtFile"
            Add-Result 'Windows Terminal' 'installed' $wtFile
        }
    }
}
else {
    Write-Step 'Windows Terminal'
    Write-Skip 'skipped (-SkipTerminal)'
}

# ------------------------------------------------------------ ai configs ----
if ($AI) {
    Write-Step 'AI CLI configs (Claude Code, Kimi)'
    $aiRoot = "$RepoRoot\ai"

    Install-Config "$aiRoot\AGENTS.md" "$env:USERPROFILE\.claude\CLAUDE.md"           'agent rules (Claude)'
    Install-Config "$aiRoot\AGENTS.md" "$env:USERPROFILE\.kimi-code\AGENTS.md"        'agent rules (Kimi)'
    Install-Config "$aiRoot\claude\statusline.py"      "$env:USERPROFILE\.claude\statusline.py"       'Claude status line'
    Install-Config "$aiRoot\claude\hooks\mode-hook.js" "$env:USERPROFILE\.claude\hooks\mode-hook.js"  'Claude mode hook'
    Install-Config "$aiRoot\claude\hooks\read-guard.js" "$env:USERPROFILE\.claude\hooks\read-guard.js" 'Claude read guard'
    Install-Config "$aiRoot\kimi\config.toml" "$env:USERPROFILE\.kimi-code\config.toml" 'Kimi config'
    Install-Config "$aiRoot\kimi\tui.toml"    "$env:USERPROFILE\.kimi-code\tui.toml"    'Kimi TUI config'

    # settings.json carries %USERPROFILE% placeholders in the hook and status
    # line commands - same treatment as the Windows Terminal settings.
    $claudeSettings = "$env:USERPROFILE\.claude\settings.json"
    if ($PSCmdlet.ShouldProcess($claudeSettings, 'install Claude settings.json')) {
        $raw = (Get-Content "$aiRoot\claude\settings.json" -Raw) `
               -replace '%USERPROFILE%', ($env:USERPROFILE -replace '\\', '\\')
        try {
            $null = $raw | ConvertFrom-Json
            New-Item -ItemType Directory -Force (Split-Path -Parent $claudeSettings) | Out-Null
            Backup-File $claudeSettings
            [IO.File]::WriteAllText($claudeSettings, $raw, (New-Object Text.UTF8Encoding $false))
            Write-Ok "Claude settings -> $claudeSettings"
            Add-Result 'Claude settings' 'installed' $claudeSettings
        }
        catch {
            Write-Fail "generated settings.json is not valid JSON: $($_.Exception.Message)"
            Add-Result 'Claude settings' 'FAILED' 'invalid JSON'
        }
    }

    Write-Note 'Codex: merge ai\codex\config.toml into ~\.codex\config.toml by hand.'
    Write-Note 'Then install the modes:  /plugin marketplace add DietrichGebert/ponytail'
}

# --------------------------------------------------------------- summary ----
Write-Host ''
Write-Host '  Summary' -ForegroundColor Magenta
Write-Host '  -------' -ForegroundColor Magenta
$Summary | Format-Table Item, Status, Detail -AutoSize | Out-String | Write-Host

$failed = @($Summary | Where-Object { $_.Status -eq 'FAILED' })
if ($failed.Count) {
    Write-Host "  $($failed.Count) item(s) failed - see above." -ForegroundColor Red
}
else {
    Write-Host '  All done. Restart Windows Terminal to load the new profile and font.' -ForegroundColor Green
}
Write-Host ''
