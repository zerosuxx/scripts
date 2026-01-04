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
$env:BINARY_SEPARATOR = "-"
& {
  Invoke-RestMethod https://scripts.zer0.hu/install.ps1 | Invoke-Expression
} "zer0go/netguard-client" "ngclient:ng" "C:\Tools\netguard"
```
