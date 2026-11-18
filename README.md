# scripts

```shell
$ curl -s https://scripts.zer0.hu/lv | sh -s bitnami-labs/sealed-secrets
$ curl -s https://scripts.zer0.hu/install | sudo sh -s zer0go/netguard-client ngclient:ng
```

```shell
$ source bash_functions/_wget.sh | _wget https://google.com
```

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
$env:BINARY_SEPARATOR = "-" # default
$env:BINARY_TEMPLATE = "{Binary}{Sep}{Os}{Sep}{Arch}{Ext}" # default
$env:ARCH_FORMAT = "linux" # default (supported: linux, go)
iex "& {$(irm https://scripts.zer0.hu/install.ps1)} zer0go/netguard-client ngclient:ng C:\netguard"
```

To install and configure the Windows OpenSSH server with a GitHub user's public
keys for administrator accounts, run PowerShell as Administrator and use:

```powershell
iex "& {$(irm https://scripts.zer0.hu/ssh-setup.ps1)} zerosuxx"
```

Replace `zerosuxx` with the GitHub username whose public keys should be allowed.
