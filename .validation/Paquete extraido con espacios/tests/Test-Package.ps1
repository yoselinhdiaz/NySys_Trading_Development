#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$FixtureParent)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$package = Split-Path -Parent $PSScriptRoot
$install = Join-Path $package 'install-nysys-skills.ps1'
$verify = Join-Path $package 'verify-installation.ps1'
$uninstall = Join-Path $package 'uninstall-nysys-skills.ps1'
$fixture = Join-Path (Resolve-Path -LiteralPath $FixtureParent).Path ([guid]::NewGuid().ToString('N'))
$project = Join-Path $fixture 'Project con espacios'
[IO.Directory]::CreateDirectory($project) | Out-Null
$manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $package 'MANIFEST.json') | ConvertFrom-Json
$first = 'nysys-mql5-development'
$second = 'nysys-trading-risk-guard'
$codexRoot = Join-Path $project '.agents/skills'
$claudeRoot = Join-Path $project '.claude/skills'

function Require([bool]$Condition, [string]$Message) {
    if (!$Condition) { throw $Message }
}
function Expect-Failure([scriptblock]$Operation, [string]$MessagePattern) {
    try { & $Operation }
    catch {
        if ($_.Exception.Message -like $MessagePattern) { return }
        throw
    }
    throw "Expected failure matching $MessagePattern"
}
function Snapshot([string]$Root) {
    @(Get-ChildItem -LiteralPath $Root -Force -Recurse | Sort-Object FullName | ForEach-Object {
        if ($_.PSIsContainer) { $_.FullName }
        else { "$($_.FullName) $((Get-FileHash -LiteralPath $_.FullName).Hash)" }
    }) -join "\n"
}

foreach ($script in @(Get-ChildItem -LiteralPath $package -Filter '*.ps1' -File) +
                    @(Get-ChildItem -LiteralPath (Join-Path $package 'adapters') -Filter '*.ps1' -File) +
                    @(Get-Item -LiteralPath $PSCommandPath)) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$errors) | Out-Null
    Require ($errors.Count -eq 0) "Parse errors: $($script.Name)"
}
Require ($manifest.skills.Count -eq 9) 'Unexpected skill count.'
'PASS 1 - PowerShell parser and manifest inventory'

$before = Snapshot $project
& $install -ProjectPath $project -DryRun
Require ((Snapshot $project) -ceq $before) 'Install dry run changed the project.'
'PASS 2 - Full dry run has no writes'

& $install -ProjectPath $project -Agent Claude -Name $first,$second
& $verify -ProjectPath $project -Agent Claude -Name $first,$second
Require (!(Test-Path -LiteralPath $codexRoot)) 'Unexpected Codex installation.'
Require (@(Get-ChildItem -LiteralPath $claudeRoot -Directory).Count -eq 2) 'Unexpected skill installed.'
'PASS 3 - Agent and skill selection'

& $install -ProjectPath $project
& $verify -ProjectPath $project
foreach ($skill in $manifest.skills) {
    $left = Join-Path $codexRoot "$($skill.name)/SKILL.md"
    $right = Join-Path $claudeRoot "$($skill.name)/SKILL.md"
    Require ((Get-FileHash -LiteralPath $left).Hash -ceq (Get-FileHash -LiteralPath $right).Hash) 'Different agent content.'
}
$before = Snapshot $project
& $install -ProjectPath $project
Require ((Snapshot $project) -ceq $before) 'Idempotent install changed files.'
'PASS 4 - Complete dual-agent install, byte equality and idempotency'

& $uninstall -ProjectPath $project -DryRun
Require ((Snapshot $project) -ceq $before) 'Uninstall dry run changed files.'
'PASS 5 - Uninstall dry run has no writes'

$altered = Join-Path $codexRoot "$first/SKILL.md"
$original = [IO.File]::ReadAllBytes($altered)
Add-Content -LiteralPath $altered -Value 'fixture edit'
$before = Snapshot $project
Expect-Failure { & $verify -ProjectPath $project } '*SHA-256 mismatch*'
Expect-Failure { & $uninstall -ProjectPath $project } '*SHA-256 mismatch*'
Require ((Snapshot $project) -ceq $before) 'Tampered files were changed.'
[IO.File]::WriteAllBytes($altered, $original)
'PASS 6 - Tamper rejection and preservation'

& $uninstall -ProjectPath $project
Require (@(Get-ChildItem -LiteralPath $codexRoot -Force).Count -eq 0) 'Codex still has skills.'
Require (@(Get-ChildItem -LiteralPath $claudeRoot -Force).Count -eq 0) 'Claude still has skills.'
$backupSkills = @(Get-ChildItem -LiteralPath $project -Force -Recurse -Filter 'SKILL.md' -File)
Require ($backupSkills.Count -eq 18) 'Unexpected number of backed-up skills.'
foreach ($backup in $backupSkills) {
    $skill = $manifest.skills | Where-Object name -CEQ $backup.Directory.Name
    Require ((Get-FileHash -LiteralPath $backup.FullName).Hash -ceq $skill.files.'SKILL.md') 'Invalid backup.'
}
Expect-Failure { & $verify -ProjectPath $project } '*Missing installation*'
$before = Snapshot $project
& $uninstall -ProjectPath $project
Require ((Snapshot $project) -ceq $before) 'Repeated uninstall changed files.'
'PASS 7 - Uninstall, 18 intact backups and repeated uninstall'

$foreign = Join-Path $claudeRoot $first
[IO.Directory]::CreateDirectory($foreign) | Out-Null
[IO.File]::WriteAllText((Join-Path $foreign 'SKILL.md'), 'fixture foreign skill')
$before = Snapshot $project
Expect-Failure { & $install -ProjectPath $project -Name $first } '*Foreign or modified*'
Require ((Snapshot $project) -ceq $before) 'Conflict caused partial installation.'
Expect-Failure { & $install -ProjectPath $project -Name nonexistent-demo } '*Unknown skill*'
'PASS 8 - Foreign collision and unknown selection'

$parentSkill = Join-Path $fixture ".agents/skills/$second"
[IO.Directory]::CreateDirectory($parentSkill) | Out-Null
Expect-Failure { & $install -ProjectPath $project -Agent Codex -Name $second -DryRun } '*Name conflict in another scope*'
'PASS 9 - Same-name ancestor conflict'

$bad = Join-Path $fixture 'changed-package'
[IO.Directory]::CreateDirectory($bad) | Out-Null
foreach ($file in @('MANIFEST.json','adapters','skills','install-nysys-skills.ps1')) {
    Copy-Item -LiteralPath (Join-Path $package $file) -Destination $bad -Recurse
}
$badInstaller = Join-Path $bad 'install-nysys-skills.ps1'
$badSkill = Join-Path $bad "skills/nysys-custom/$first/SKILL.md"
Add-Content -LiteralPath $badSkill -Value 'fixture corruption'
Expect-Failure { & $badInstaller -ProjectPath $project -DryRun } '*SHA-256 mismatch*'
'PASS 10 - Package corruption rejected before installation'

$changedManifest = Join-Path $bad 'MANIFEST.json'
[IO.File]::WriteAllBytes($badSkill, $original)
$manifest.skills += $manifest.skills[0]
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $changedManifest -Encoding UTF8
Expect-Failure { & $badInstaller -ProjectPath $project -DryRun } '*Invalid or duplicate skill*'
'PASS 11 - Duplicate manifest names rejected'
"Fixtures retained: $fixture"
