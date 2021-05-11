# SSL Notes

```
curl -k -H 'Host:<host>' https://<endpoint-fqdn>.cloudapp.azure.com/some/path/in/your/service

openssl s_client -connect <endpoint-fqdn>.cloudapp.azure.com:443 -servername <host>
```
