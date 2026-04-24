#Requires -Version 7.0
<#
Session-ownership gate for ${CLAUDE_PLUGIN_DATA}/divergence_logs/.

Policy:
  - Write by any session to a path under the protected dir records ownership
    (session_id, resolved file_path) in the ledger and is allowed.
  - Read/Edit/NotebookEdit by the session that wrote a file is allowed; any
    other session is denied.
  - Grep/Glob anywhere under the protected dir is denied (no enumeration).
  - Bash referencing the protected dir by any form (literal path, env-var
    spelling, 'divergence_logs' substring) is denied.
  - WebFetch of file:// URLs under the protected dir is denied.
  - MCP tool calls whose string arguments resolve under or reference the
    protected dir are denied.
  - The ledger file itself is not readable, writable, or editable via any tool.

Any tool call not touching the protected dir passes through with no decision.
#>

$ErrorActionPreference = 'Stop'

# Platform guard: Windows only. The bash peer handles macOS/Linux.
if (-not $IsWindows) { exit 0 }

function Emit-PassThrough { exit 0 }

function Emit-Decision {
    param(
        [Parameter(Mandatory)] [ValidateSet('allow','deny','ask')] [string]$Decision,
        [Parameter(Mandatory)] [string]$Reason
    )
    $obj = @{
        hookSpecificOutput = @{
            hookEventName = 'PreToolUse'
            permissionDecision = $Decision
            permissionDecisionReason = $Reason
        }
    }
    ($obj | ConvertTo-Json -Compress -Depth 6) | Write-Output
    exit 0
}

$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { Emit-PassThrough }

try {
    $payload = $raw | ConvertFrom-Json -AsHashtable
} catch {
    Emit-PassThrough
}

if ($payload.hook_event_name -ne 'PreToolUse') { Emit-PassThrough }

$sessionId = [string]$payload.session_id
$toolName  = [string]$payload.tool_name
$ti        = $payload.tool_input

$pluginData = $env:CLAUDE_PLUGIN_DATA
if ([string]::IsNullOrWhiteSpace($pluginData)) { Emit-PassThrough }

try {
    $protectedDir = [System.IO.Path]::GetFullPath((Join-Path $pluginData 'divergence_logs'))
} catch {
    Emit-PassThrough
}
$ledgerPath = [System.IO.Path]::GetFullPath((Join-Path $protectedDir '.ownership.jsonl'))

function Resolve-PathSafe {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    try {
        $expanded = [Environment]::ExpandEnvironmentVariables($Path)
        # Also expand ${CLAUDE_PLUGIN_DATA} / ${CLAUDE_PLUGIN_ROOT} style
        $expanded = [regex]::Replace($expanded, '\$\{([A-Z_]+)\}', {
            param($m)
            $v = [Environment]::GetEnvironmentVariable($m.Groups[1].Value)
            if ($null -eq $v) { return $m.Value } else { return $v }
        })
        $expanded = [regex]::Replace($expanded, '\$([A-Z_]+)', {
            param($m)
            $v = [Environment]::GetEnvironmentVariable($m.Groups[1].Value)
            if ($null -eq $v) { return $m.Value } else { return $v }
        })
        if (-not [System.IO.Path]::IsPathRooted($expanded)) {
            $expanded = Join-Path (Get-Location).Path $expanded
        }
        return [System.IO.Path]::GetFullPath($expanded)
    } catch { return $null }
}

function Test-UnderProtected {
    param([string]$ResolvedPath)
    if ([string]::IsNullOrWhiteSpace($ResolvedPath)) { return $false }
    $sep = [System.IO.Path]::DirectorySeparatorChar
    $a = $ResolvedPath.TrimEnd($sep, [System.IO.Path]::AltDirectorySeparatorChar)
    $b = $protectedDir.TrimEnd($sep, [System.IO.Path]::AltDirectorySeparatorChar)
    if ([string]::Equals($a, $b, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $a.StartsWith($b + $sep, [StringComparison]::OrdinalIgnoreCase)
}

function Test-IsLedger {
    param([string]$ResolvedPath)
    return [string]::Equals($ResolvedPath, $ledgerPath, [StringComparison]::OrdinalIgnoreCase)
}

function Record-Ownership {
    param([string]$ResolvedFilePath)
    try {
        if (-not (Test-Path -LiteralPath $protectedDir)) {
            New-Item -ItemType Directory -Path $protectedDir -Force | Out-Null
        }
        $line = @{
            session_id = $sessionId
            file_path  = $ResolvedFilePath
            ts         = (Get-Date).ToUniversalTime().ToString('o')
        } | ConvertTo-Json -Compress
        Add-Content -LiteralPath $ledgerPath -Value $line -Encoding utf8
    } catch {
        # If the ledger can't be written, fail closed on subsequent reads by
        # not recording — but don't block the Write itself. The agent still
        # gets its file on disk; cross-session reads remain denied since no
        # ownership entry exists.
    }
}

function Test-Ownership {
    param([string]$ResolvedFilePath)
    if (-not (Test-Path -LiteralPath $ledgerPath)) { return $false }
    try {
        $lines = Get-Content -LiteralPath $ledgerPath -Encoding utf8
    } catch { return $false }
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $entry = $line | ConvertFrom-Json
        } catch { continue }
        if ($entry.session_id -eq $sessionId -and
            [string]::Equals([string]$entry.file_path, $ResolvedFilePath, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Test-BashTouchesProtected {
    param([string]$Command)
    if ([string]::IsNullOrWhiteSpace($Command)) { return $false }
    $needles = @(
        'divergence_logs',
        '${CLAUDE_PLUGIN_DATA}',
        '$CLAUDE_PLUGIN_DATA',
        '$env:CLAUDE_PLUGIN_DATA',
        '%CLAUDE_PLUGIN_DATA%',
        $protectedDir
    )
    foreach ($n in $needles) {
        if ([string]::IsNullOrWhiteSpace($n)) { continue }
        if ($Command.IndexOf($n, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            return $true
        }
    }
    return $false
}

switch ($toolName) {

    'Write' {
        $p = Resolve-PathSafe $ti.file_path
        if (-not (Test-UnderProtected $p)) { Emit-PassThrough }
        if (Test-IsLedger $p) { Emit-Decision 'deny' 'The ownership ledger is not writable by the agent.' }
        Record-Ownership $p
        Emit-Decision 'allow' "Recorded session ownership of $([System.IO.Path]::GetFileName($p))."
    }

    'Edit' {
        $p = Resolve-PathSafe $ti.file_path
        if (-not (Test-UnderProtected $p)) { Emit-PassThrough }
        if (Test-IsLedger $p) { Emit-Decision 'deny' 'The ownership ledger is not editable by the agent.' }
        if (Test-Ownership $p) { Emit-Decision 'allow' 'Session owns this file.' }
        Emit-Decision 'deny' 'divergence_logs entries are editable only by the session that wrote them.'
    }

    'Read' {
        $p = Resolve-PathSafe $ti.file_path
        if (-not (Test-UnderProtected $p)) { Emit-PassThrough }
        if (Test-IsLedger $p) { Emit-Decision 'deny' 'The ownership ledger is not readable by the agent.' }
        if (Test-Ownership $p) { Emit-Decision 'allow' 'Session owns this file.' }
        Emit-Decision 'deny' 'divergence_logs entries are readable only by the session that wrote them.'
    }

    'NotebookEdit' {
        $p = Resolve-PathSafe $ti.notebook_path
        if (-not (Test-UnderProtected $p)) { Emit-PassThrough }
        if (Test-Ownership $p) { Emit-Decision 'allow' 'Session owns this notebook.' }
        Emit-Decision 'deny' 'divergence_logs entries are editable only by the session that wrote them.'
    }

    'Grep' {
        $p = Resolve-PathSafe $ti.path
        if (-not (Test-UnderProtected $p)) { Emit-PassThrough }
        Emit-Decision 'deny' 'Grep is not permitted in divergence_logs (no enumeration across sessions).'
    }

    'Glob' {
        $p = Resolve-PathSafe $ti.path
        if (-not (Test-UnderProtected $p)) { Emit-PassThrough }
        Emit-Decision 'deny' 'Glob is not permitted in divergence_logs (no enumeration across sessions).'
    }

    'Bash' {
        if (Test-BashTouchesProtected ([string]$ti.command)) {
            Emit-Decision 'deny' 'Bash access to divergence_logs is not permitted. Use the Write tool to create artifact files.'
        }
        Emit-PassThrough
    }

    'WebFetch' {
        $url = [string]$ti.url
        if ($url -and $url -match '^file://') {
            if ($url.IndexOf('divergence_logs', [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                Emit-Decision 'deny' 'file:// URLs under divergence_logs are not permitted.'
            }
            $stripped = $url -replace '^file://',''
            # file:///C:/... on Windows → strip extra leading slash before drive letter
            if ($stripped -match '^/[A-Za-z]:[/\\]') { $stripped = $stripped.Substring(1) }
            $p = Resolve-PathSafe $stripped
            if (Test-UnderProtected $p) {
                Emit-Decision 'deny' 'file:// URLs under divergence_logs are not permitted.'
            }
        }
        Emit-PassThrough
    }

    default {
        if ($toolName -like 'mcp__*' -and $ti -is [System.Collections.IDictionary]) {
            foreach ($kv in $ti.GetEnumerator()) {
                $v = $kv.Value
                if ($v -is [string]) {
                    if ($v.IndexOf('divergence_logs', [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                        Emit-Decision 'deny' 'MCP tool reference to divergence_logs is not permitted.'
                    }
                    $rp = Resolve-PathSafe $v
                    if ($rp -and (Test-UnderProtected $rp)) {
                        Emit-Decision 'deny' 'MCP tool reference to divergence_logs is not permitted.'
                    }
                }
            }
        }
        Emit-PassThrough
    }
}
