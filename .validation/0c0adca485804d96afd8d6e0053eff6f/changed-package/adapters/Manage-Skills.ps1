#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Install','Verify','Uninstall')][string]$Mode,
    [ValidateSet('Codex','Claude','Both')][string]$Agent = 'Both',
    [ValidateSet('Project','User')][string]$Scope = 'Project',
    [string]$ProjectPath,
    [string[]]$Name,
    [switch]$DryRun
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$package = Split-Path -Parent $PSScriptRoot
$marker = '.nysys-trading-development.json'

function Assert-PlainPath([string]$Path, [switch]$Directory) {
    $cursor = [IO.Path]::GetFullPath($Path)
    $mustBeDirectory = $Directory.IsPresent
    while ($cursor) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($item -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
                ($mustBeDirectory -and !$item.PSIsContainer))) {
            throw "Unsafe path: $cursor"
        }
        $cursor = [IO.Path]::GetDirectoryName($cursor)
        $mustBeDirectory = $true
    }
}

function Get-Receipt($Skill) {
    [ordered]@{ package = 'NySys Trading Development'; version = '1.0'; name = $Skill.name
        sha256 = $Skill.files.'SKILL.md' } | ConvertTo-Json -Compress
}

function Assert-Skill($Skill, [string]$Path, [switch]$Installed) {
    Assert-PlainPath $Path -Directory
    $expected = @('SKILL.md')
    if ($Skill.kind -eq 'upstream') { $expected += 'LICENSE.txt' }
    if (Compare-Object $expected @($Skill.files.PSObject.Properties.Name) -CaseSensitive) {
        throw "Invalid manifest files for $($Skill.name)"
    }
    $inventory = @($expected)
    if ($Installed) { $inventory += $marker }
    $actual = @(Get-ChildItem -LiteralPath $Path -Force | ForEach-Object Name)
    if (Compare-Object $inventory $actual -CaseSensitive) {
        throw "Foreign or modified directory: $Path"
    }
    foreach ($file in $expected) {
        $item = Join-Path $Path $file
        Assert-PlainPath $item
        if (!(Test-Path -LiteralPath $item -PathType Leaf) -or
            (Get-FileHash -LiteralPath $item -Algorithm SHA256).Hash -ne $Skill.files.$file) {
            throw "SHA-256 mismatch: $item"
        }
    }
    $markdown = [IO.File]::ReadAllText((Join-Path $Path 'SKILL.md'))
    $metadata = [regex]::Match($markdown, "\A---\r?\nname: ([a-z0-9-]+)\r?\ndescription: '([^'\r\n]+)'\r?\n---\r?\n")
    if (!$metadata.Success -or $metadata.Groups[1].Value -cne $Skill.name -or
        $metadata.Groups[2].Length -gt 1024 -or
        $markdown -match '(?m)^\s*!\x60|(?i)\b(?:allowed-tools|hooks):') {
        throw "Invalid portable skill: $Path"
    }
    if ($Installed) {
        $receipt = Join-Path $Path $marker
        Assert-PlainPath $receipt
        if ([IO.File]::ReadAllText($receipt) -cne (Get-Receipt $Skill)) {
            throw "Foreign installation: $Path"
        }
    }
}

function Write-Audit([string]$Message) {
    Write-Host $Message
    if ($log) {
        Add-Content -LiteralPath $log -Encoding UTF8 -Value "$([DateTimeOffset]::UtcNow.ToString('o')) $Message"
    }
}

$log = $null
try {
    $manifestPath = Join-Path $package 'MANIFEST.json'
    Assert-PlainPath $manifestPath
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.schema -ne 1 -or $manifest.version -cne '1.0') { throw 'Unsupported manifest.' }
    $byName = @{}
    foreach ($skill in $manifest.skills) {
        if ($skill.name -cnotmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$' -or $skill.name.Length -gt 64 -or
            $skill.kind -cnotin @('upstream','nysys-custom') -or $byName.ContainsKey($skill.name)) {
            throw "Invalid or duplicate skill: $($skill.name)"
        }
        $byName.Add($skill.name, $skill)
        if ($Mode -ne 'Uninstall') {
            Assert-Skill $skill (Join-Path $package "skills/$($skill.kind)/$($skill.name)")
        }
    }
    if (!$byName.Count) { throw 'Empty manifest.' }
    $selected = @($manifest.skills)
    if ($Name) {
        foreach ($requested in $Name) {
            if (!$byName.ContainsKey($requested)) { throw "Unknown skill: $requested" }
        }
        $selected = @($selected | Where-Object { $_.name -in $Name })
    }

    $profilePath = [Environment]::GetFolderPath('UserProfile')
    $root = $profilePath
    if ($Scope -eq 'Project') {
        if (!$ProjectPath) { throw 'Pass -ProjectPath for project scope.' }
        $root = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ProjectPath)
    } elseif ($ProjectPath) { throw 'Omit -ProjectPath for user scope.' }
    if (!$root -or !(Test-Path -LiteralPath $root -PathType Container)) { throw "Missing destination: $root" }
    Assert-PlainPath $root -Directory
    $targets = @($Agent.ToLowerInvariant())
    if ($Agent -eq 'Both') { $targets = @('codex','claude') }

    $plan = @(
        foreach ($target in $targets) {
            $adapter = Join-Path $PSScriptRoot "$target/roots.json"
            Assert-PlainPath $adapter
            $paths = Get-Content -LiteralPath $adapter -Raw -Encoding UTF8 | ConvertFrom-Json
            $expectedRoot = @{ codex = '.agents/skills'; claude = '.claude/skills' }[$target]
            if ($paths.project -cne $expectedRoot -or $paths.user -cne $expectedRoot) { throw "Invalid adapter: $target" }
            if (!(Get-Command $target -ErrorAction SilentlyContinue)) { Write-Host "[$target] CLI not found on PATH." }
            $relative = $paths.($Scope.ToLowerInvariant())
            $skillsRoot = Join-Path $root $relative
            $work = Join-Path (Split-Path -Parent $skillsRoot) 'nysys-trading-development'
            Assert-PlainPath $skillsRoot -Directory
            Assert-PlainPath $work -Directory
            foreach ($skill in $selected) {
                $destination = Join-Path $skillsRoot $skill.name
                Assert-PlainPath $destination -Directory
                $exists = Test-Path -LiteralPath $destination
                if ($exists) { Assert-Skill $skill $destination -Installed }
                if ($Mode -eq 'Verify' -and !$exists) { throw "Missing installation: $destination" }
                if ($Mode -eq 'Install' -and $Scope -eq 'Project') {
                    $bases = @($profilePath)
                    $parent = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($root))
                    while ($parent) {
                        $bases += $parent
                        $parent = [IO.Path]::GetDirectoryName($parent)
                    }
                    foreach ($base in $bases | Select-Object -Unique) {
                        if (!$base -or $base -eq $root) { continue }
                        $other = Join-Path $base "$relative/$($skill.name)"
                        if (Test-Path -LiteralPath $other) { throw "Name conflict in another scope: $other" }
                    }
                }
                [pscustomobject]@{ Skill = $skill; Path = $destination; Work = $work; Exists = $exists }
            }
        }
    )
    foreach ($entry in $plan) {
        $log = $null
        if ($Mode -eq 'Verify') { Write-Audit "Verified $($entry.Path)"; continue }
        if (($Mode -eq 'Install' -and $entry.Exists) -or ($Mode -eq 'Uninstall' -and !$entry.Exists)) {
            Write-Audit "No change: $($entry.Path)"
            continue
        }
        if ($DryRun) { Write-Audit "DryRun $Mode $($entry.Path)"; continue }
        $operation = Join-Path $entry.Work ([guid]::NewGuid().ToString('N'))
        Assert-PlainPath $operation -Directory
        [IO.Directory]::CreateDirectory($operation) | Out-Null
        $log = Join-Path $operation 'operation.log'
        $staged = Join-Path $operation $entry.Skill.name
        Write-Audit "Begin $Mode $($entry.Path)"
        if ($Mode -eq 'Install') {
            [IO.Directory]::CreateDirectory((Split-Path -Parent $entry.Path)) | Out-Null
            [IO.Directory]::CreateDirectory($staged) | Out-Null
            $source = Join-Path $package "skills/$($entry.Skill.kind)/$($entry.Skill.name)"
            foreach ($file in $entry.Skill.files.PSObject.Properties.Name) {
                [IO.File]::Copy((Join-Path $source $file), (Join-Path $staged $file))
            }
            [IO.File]::WriteAllText((Join-Path $staged $marker), (Get-Receipt $entry.Skill))
            Assert-Skill $entry.Skill $staged -Installed
            [IO.Directory]::Move($staged, $entry.Path)
        } else {
            Assert-Skill $entry.Skill $entry.Path -Installed
            [IO.Directory]::Move($entry.Path, $staged)
            Write-Audit "Backup: $staged"
        }
        Write-Audit "Complete $Mode $($entry.Path)"
    }
} catch {
    $failure = $_
    try { Write-Audit "Failed: $($failure.Exception.Message)" }
    catch { Write-Warning "Could not write audit log: $($_.Exception.Message)" }
    throw $failure
}
