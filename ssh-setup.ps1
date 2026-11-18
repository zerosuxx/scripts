param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidatePattern('^[A-Za-z0-9-]+$')]
    [string] $GitHubUser
)

$ErrorActionPreference = 'Stop'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run PowerShell as Administrator.'
}

$capability = Get-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
if ($capability.State -ne 'Installed') {
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
}

$sshDir = Join-Path $env:ProgramData 'ssh'
$configPath = Join-Path $sshDir 'sshd_config'
$keysPath = Join-Path $sshDir 'administrators_authorized_keys'
New-Item -ItemType Directory -Force -Path $sshDir | Out-Null

$response = Invoke-WebRequest -Uri "https://github.com/$GitHubUser.keys"
$keys = @($response.Content -split "`r?`n" | Where-Object { $_.Trim() })
if ($keys.Count -eq 0) {
    throw "No public SSH keys found for GitHub user '$GitHubUser'."
}
$keys | Set-Content -Path $keysPath -Encoding ascii
icacls.exe $keysPath /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not set permissions on administrators_authorized_keys.' }

Set-Service -Name sshd -StartupType Automatic
Start-Service -Name sshd

$config = Get-Content -Path $configPath -Raw
if ($config -notmatch '(?m)^\s*Match\s+Group\s+administrators\s*$') {
    Add-Content -Path $configPath -Value "`nMatch Group administrators`n    AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys"
}

Restart-Service -Name sshd

if (-not (Get-NetFirewallRule -Name OpenSSH-Server-In-TCP -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name OpenSSH-Server-In-TCP `
        -DisplayName 'OpenSSH Server (sshd)' `
        -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
}

Get-Service -Name sshd
