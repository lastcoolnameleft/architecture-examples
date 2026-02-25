# Multi-tenant deployment

This example is for a single-tenant application deployed to provide multi-tenancy using Kubernetes Namespaces and Ingress.  It expects the following requirements:

* Single tenant application, in a single container image
* Each instance of the application is logically separated from the others
* Each instance of the application is publicly available once the deployment is complete

## Architecture

![](multi-tenant.svg)

## Overview

This example contains a bash script and Helm chart for deploying a single-tenant application as a multi-tenant environemnt.  For this example, I use [kuard](https://github.com/kubernetes-up-and-running/kuard) because it's easy to see which container the application is routing to.

## Prereq

To use, you must first have an Ingress Controller installed.  For example:

```shell
helm install stable/nginx-ingress --namespace kube-system
```

### Customization / DNS

This uses my personal domain `multi-tenant.lastcoolnameleft.com`; however, you can substitute your own domain and then modify your `/etc/hosts` file to make the $TENANT.$YOUR-DOMAIN routable.

## Add a tenant

Adding a tenant is simply running `deploy_tenant.sh` with the name of the new tenant.

This will copy a templated Helm Values file and create a new values file for the tenant:

* Create new Namespace
* Create a Deployment inside the Namespace
* Create a Service (Type=ClusterIP) which points to the deployment
* Create a Ingress Rule inside the Namespace (which points to the service)

```shell
./deploy_tenant.sh lastcoolnameleft
```

## Validation

After the new tenant Helm chart has been deployed, you can go to the URL at `$TENANT.$YOUR-DOMAIN`.  Make sure you have DNS setup to point to the public IP address.