$ErrorActionPreference = "Stop"

# =========================================================
# ARGUMENTS (Scoop-style invocation)
# =========================================================

$Repo       = $args[0]
$BinaryName = $args[1]
$InstallDir = $args[2]

if (-not $Repo) {
    throw "Usage: install.ps1 <org/repo[@version]> [asset:binary] [installDir]"
}

# =========================================================
# PARSE REPO + VERSION
# =========================================================

if ($Repo -match '^(.+?)@(.+)$') {
    $RepoNameFull = $matches[1]
    $Version      = $matches[2]
} else {
    $RepoNameFull = $Repo
    $Version      = "latest"
}

$RepoName = ($RepoNameFull -split "/")[-1]

# =========================================================
# CONSTANTS
# =========================================================

$ProgramFilesX86 = ${Env:ProgramFiles(x86)}
$Os  = "windows"
$Ext = ".exe"

$Separator = if ($env:BINARY_SEPARATOR) { $env:BINARY_SEPARATOR } else { "-" }

$Template = if ($env:BINARY_TEMPLATE) {
    $env:BINARY_TEMPLATE
} else {
    "{Binary}{Sep}{Os}{Sep}{Arch}{Ext}"
}

# =========================================================
# RESOLVE ASSET / TARGET NAMES
# =========================================================

if (-not $BinaryName) {
    $AssetName  = $RepoName
    $TargetName = $RepoName
}
elseif ($BinaryName -like "*:*") {
    $p = $BinaryName -split ":", 2
    $AssetName  = $p[0]
    $TargetName = $p[1]
}
else {
    $AssetName  = $BinaryName
    $TargetName = $BinaryName
}

if (-not $InstallDir) {
    $InstallDir = Join-Path $ProgramFilesX86 $RepoName
}

$TargetBinaryPath = Join-Path $InstallDir "$TargetName.exe"

# =========================================================
# ADMIN CHECK
# =========================================================

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$IsAdmin = Test-Admin

# =========================================================
# ARCH DETECTION (ARCH_FORMAT)
# =========================================================

$CpuArch = if ($env:PROCESSOR_ARCHITEW6432) {
    $env:PROCESSOR_ARCHITEW6432
} else {
    $env:PROCESSOR_ARCHITECTURE
}

$ArchFormat = if ($env:ARCH_FORMAT) {
    $env:ARCH_FORMAT.ToLower()
} else {
    "linux"
}

switch ($ArchFormat) {
    "go" {
        if ($CpuArch -eq "ARM64") {
            $Arch = "arm64"
        } else {
            $Arch = "amd64"
        }
    }
    default {
        if ($CpuArch -eq "ARM64") {
            $Arch = "aarch64"
        } else {
            $Arch = "x86_64"
        }
    }
}

# =========================================================
# BUILD ASSET FILENAME (TEMPLATE)
# =========================================================

$BinaryFileName = $Template `
    -replace '\{Binary\}', $AssetName `
    -replace '\{Sep\}',    $Separator `
    -replace '\{Os\}',     $Os `
    -replace '\{Arch\}',   $Arch `
    -replace '\{Ext\}',    $Ext

# =========================================================
# DOWNLOAD
# =========================================================

$BinaryUrl = if ($Version -eq "latest") {
    "https://github.com/$RepoNameFull/releases/latest/download/$BinaryFileName"
} else {
    "https://github.com/$RepoNameFull/releases/download/$Version/$BinaryFileName"
}

Write-Host "Repo        : $RepoNameFull"
Write-Host "Version     : $Version"
Write-Host "OS          : $Os"
Write-Host "CPU arch    : $CpuArch"
Write-Host "Arch format : $ArchFormat"
Write-Host "Asset arch  : $Arch"
Write-Host "Asset file  : $BinaryFileName"
Write-Host "Binary URL  : $BinaryUrl"

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Invoke-RestMethod -Uri $BinaryUrl -OutFile $TargetBinaryPath

# =========================================================
# PATH HANDLING (Environment API ONLY)
# =========================================================

function Add-ToPath {
    param(
        [string] $Dir,
        [string] $Scope  # Machine | User
    )

    $current = [Environment]::GetEnvironmentVariable("Path", $Scope)
    if (-not $current) { $current = "" }

    if ($current -notlike "*$Dir*") {
        [Environment]::SetEnvironmentVariable(
            "Path",
            "$current;$Dir",
            $Scope
        )
        Write-Host "Added to $Scope PATH"
        return $true
    }

    return $false
}

$PathAdded = $false

if ($IsAdmin) {
    $PathAdded = Add-ToPath -Dir $InstallDir -Scope "Machine"
}

if (-not $PathAdded) {
    Add-ToPath -Dir $InstallDir -Scope "User" | Out-Null
}

# Immediate usability
$env:PATH = "$InstallDir;$env:PATH"

# =========================================================
# UNINSTALL SCRIPT (MINIMAL)
# =========================================================

$UninstallScript = @"
`$InstallDir = "$InstallDir"

Remove-Item -Recurse -Force `$InstallDir -ErrorAction SilentlyContinue

foreach (`$scope in 'Machine','User') {
    `$path = [Environment]::GetEnvironmentVariable('Path', `$scope)
    if (`$path) {
        `$new = (`$path -split ';') | Where-Object { `$_ -and (`$_ -ne `$InstallDir) }
        [Environment]::SetEnvironmentVariable('Path', (`$new -join ';'), `$scope)
    }
}
"@

$UninstallScript | Set-Content -Encoding UTF8 (Join-Path $InstallDir "uninstall.ps1")

# =========================================================
# DONE
# =========================================================

Write-Host ""
Write-Host "$TargetName installed successfully."
Write-Host "Location: $TargetBinaryPath"
