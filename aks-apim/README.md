## Overview

## Existing AKS Documentation

There are 3 options listed here: https://docs.microsoft.com/en-us/azure/api-management/api-management-kubernetes
* APIM + Public AKS Service, no shared Vnet
* APIM + Public AKS Ingress, no shared Vnet
* APIM + Private AKS in same Vnet, no ingress

A missing scenario is: 
* APIM + Private AKS in same Subnet, with ingress

This example is designed to walk through this example

## Install this example

To use this example, perform the following:

Create ingress similiar to template below
* The /$2 is important to remove the APIM URL suffix as it comes through since your app is likely not expecting it.

Create an ingress controller with an internal LB:

```
helm install nginx-ingress stable/nginx-ingress \
    --namespace ingress-basic \
    -f internal-ingress.yaml \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux
```

Create the kuard and podinfo deployment, service and ingress rules

```
kubectl apply -f podinfo.yaml
```

Create the APIM instance and create the API's pointing to the AKS Ingress

1. Create APIM instance
1. Create Blank API for podinfo
    * API URL suffix: 
      * e.g. podinfo
    * Web service: http://<IP of Ingress>/<same value as API URL Suffix>
        * e.g. http://10.240.0.42/podinfo
    * Disable "Subscription Required"
1. Create an Operation for the API
    * URL: `/*`


Verify APIM works

```
$ curl https://tmfflux.azure-api.net/podinfo

{
  "hostname": "podinfo-55b4659b75-s8tj2",
  "version": "4.0.3",
  "revision": "a2f9216fe43849c3b4844032771ba632307d8738",
  "color": "#34577c",
  "logo": "https://raw.githubusercontent.com/stefanprodan/podinfo/gh-pages/cuddle_clap.gif",
  "message": "greetings from podinfo v4.0.3",
  "goos": "linux",
  "goarch": "amd64",
  "runtime": "go1.14.4",
  "num_goroutine": "8",
  "num_cpu": "2"
}


```