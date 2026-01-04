param(
    [Parameter(Mandatory = $true)]
    [string] $Repo,          # org/repo[@version]

    [string] $BinaryName,    # name OR asset:target

    [string] $InstallDir     # optional
)

$ErrorActionPreference = "Stop"

# =========================================================
# PARSE REPO + VERSION (PURE)
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

$Separator = if ($env:BINARY_SEPARATOR -and $env:BINARY_SEPARATOR -ne "") {
    $env:BINARY_SEPARATOR
} else {
    "-"
}

# =========================================================
# RESOLVE BINARY NAMES
# =========================================================

if (-not $BinaryName) {
    $AssetName  = $RepoName
    $TargetName = $RepoName
}
elseif ($BinaryName -like "*:*") {
    $parts = $BinaryName -split ":", 2
    $AssetName  = $parts[0]
    $TargetName = $parts[1]
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
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$IsAdmin = Test-Admin

if (-not $IsAdmin) {
    Write-Host "Running without admin rights → using User PATH if needed"
}

# =========================================================
# ARCH DETECTION
# =========================================================

$archRaw = if ($env:PROCESSOR_ARCHITEW6432) {
    $env:PROCESSOR_ARCHITEW6432
} else {
    $env:PROCESSOR_ARCHITECTURE
}

$Arch = if ($archRaw -eq "ARM64") { "aarch64" } else { "x86_64" }

# =========================================================
# DOWNLOAD
# =========================================================

$BinaryFileName = "$AssetName${Separator}windows${Separator}$Arch.exe"

$BinaryUrl = if ($Version -eq "latest") {
    "https://github.com/$RepoNameFull/releases/latest/download/$BinaryFileName"
} else {
    "https://github.com/$RepoNameFull/releases/download/$Version/$BinaryFileName"
}

Write-Host "Repo        : $RepoNameFull"
Write-Host "Version     : $Version"
Write-Host "Architecture: $Arch"
Write-Host "Binary URL  : $BinaryUrl"

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Invoke-RestMethod -Uri $BinaryUrl -OutFile $TargetBinaryPath

# =========================================================
# PATH HANDLING (ENVIRONMENT API ONLY)
# =========================================================

function Add-ToPath {
    param(
        [string] $Dir,
        [string] $Scope   # "Machine" or "User"
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

# Immediate usability in this session
$env:PATH = "$InstallDir;$env:PATH"

# =========================================================
# UNINSTALL SCRIPT (MINIMAL, ENV API ONLY)
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
