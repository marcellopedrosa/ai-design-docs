param(
    [ValidateSet('Lock', 'Unlock', 'Status')]
    [string]$Action = 'Status',
    [string]$TargetPath = (Join-Path $PSScriptRoot '..\spec-kit')
)

$ErrorActionPreference = 'Stop'
$target = (Resolve-Path -LiteralPath $TargetPath).Path
if (-not (Test-Path -LiteralPath $target -PathType Container)) {
    throw "Target must be an existing directory: $target"
}

$sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
$rights = [System.Security.AccessControl.FileSystemRights]::Write -bor
    [System.Security.AccessControl.FileSystemRights]::Delete -bor
    [System.Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles
$inheritance = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
    [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
$propagation = [System.Security.AccessControl.PropagationFlags]::None
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $sid, $rights, $inheritance, $propagation,
    [System.Security.AccessControl.AccessControlType]::Deny
)

$acl = Get-Acl -LiteralPath $target
$matching = @($acl.Access | Where-Object {
    -not $_.IsInherited -and
    $_.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Deny -and
    $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value -eq $sid.Value -and
    ($_.FileSystemRights -band $rights) -eq $rights -and
    $_.InheritanceFlags -eq $inheritance
})

switch ($Action) {
    'Lock' {
        if ($matching.Count -eq 0) {
            $acl.AddAccessRule($rule)
            Set-Acl -LiteralPath $target -AclObject $acl
        }
    }
    'Unlock' {
        foreach ($entry in $matching) {
            [void]$acl.RemoveAccessRuleSpecific($entry)
        }
        if ($matching.Count -gt 0) {
            Set-Acl -LiteralPath $target -AclObject $acl
        }
    }
}

$current = Get-Acl -LiteralPath $target
$locked = @($current.Access | Where-Object {
    -not $_.IsInherited -and
    $_.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Deny -and
    $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value -eq $sid.Value -and
    ($_.FileSystemRights -band $rights) -eq $rights -and
    $_.InheritanceFlags -eq $inheritance
}).Count -gt 0

Write-Output "Target: $target"
Write-Output "Locked for current user: $locked"
