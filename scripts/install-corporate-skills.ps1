param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,
    [ValidateSet('Codex', 'Claude', 'Both')]
    [string]$Agent = 'Both',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath $ProjectRoot).Path
if (-not (Test-Path -LiteralPath $project -PathType Container)) {
    throw "ProjectRoot must be an existing directory: $project"
}

$source = Join-Path $PSScriptRoot '..\corporate-presets\skills'
$source = (Resolve-Path -LiteralPath $source).Path
$core = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\spec-kit')).Path
if ($project -eq $core -or $project.StartsWith($core + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'ProjectRoot cannot be inside the protected spec-kit core.'
}

$skills = @(Get-ChildItem -LiteralPath $source -Directory | Sort-Object Name)
foreach ($skill in $skills) {
    if ($skill.Name -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$' -or $skill.Name.StartsWith('speckit-')) {
        throw "Invalid or reserved skill name: $($skill.Name)"
    }
    $manifest = Join-Path $skill.FullName 'SKILL.md'
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
        throw "Missing SKILL.md: $manifest"
    }
}

$agents = if ($Agent -eq 'Both') { @('Codex', 'Claude') } else { @($Agent) }
$operations = @()
foreach ($runtime in $agents) {
    $relative = if ($runtime -eq 'Codex') { '.agents\skills' } else { '.claude\skills' }
    $destinationRoot = Join-Path $project $relative
    foreach ($skill in $skills) {
        $destination = Join-Path $destinationRoot $skill.Name
        if ((Test-Path -LiteralPath $destination) -and -not $Force) {
            throw "Skill already installed; use -Force to update: $destination"
        }
        $operations += [pscustomobject]@{ Source = $skill.FullName; Root = $destinationRoot; Destination = $destination; Runtime = $runtime }
    }
}

foreach ($operation in $operations) {
    New-Item -ItemType Directory -Path $operation.Root -Force | Out-Null
    if (Test-Path -LiteralPath $operation.Destination) {
        # Preserve unrelated files that might have been added to an installed skill.
        Copy-Item -Path (Join-Path $operation.Source '*') -Destination $operation.Destination -Recurse -Force
    } else {
        Copy-Item -LiteralPath $operation.Source -Destination $operation.Destination -Recurse
    }
    Write-Output "$($operation.Runtime): $($operation.Destination)"
}
