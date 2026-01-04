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
iex "& {$(irm https://scripts.zer0.hu/install.ps1)} zer0go/netguard-client ngclient:ng C:\netguard"
```
