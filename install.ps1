<#
.SYNOPSIS
    Entry point - runs the Windows installer in Windows\install.ps1.

.DESCRIPTION
    All arguments are forwarded, so anything the real installer accepts works
    here too: -SkipTools, -SkipFont, -SkipTerminal, -Force, -WhatIf.

.EXAMPLE
    .\install.ps1
    .\install.ps1 -SkipTools -WhatIf
#>

# No param block on purpose: $args forwards named switches faithfully, which
# ValueFromRemainingArguments does not.
& (Join-Path $PSScriptRoot 'Windows\install.ps1') @args
