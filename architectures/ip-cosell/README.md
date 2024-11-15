# Intent

Many ISV's are interested in achieving [Azure IP co-sell eligible status](https://learn.microsoft.com/en-us/partner-center/referrals/co-sell-requirements#requirements-for-azure-ip-co-sell-eligible-status).  One of the [requirements](https://learn.microsoft.com/en-us/partner-center/referrals/co-sell-requirements#requirements-for-azure-ip-co-sell-eligible-status) is to provide a [reference architecture diagram](https://learn.microsoft.com/en-us/partner-center/referrals/reference-architecture-diagram).

This page is designed to provide an example reference architecture diagram using [Draw.io](https://draw.io/) for Azure IP co-sell eligible status.  You can take this diagram and use it as a starting point to describe your architecture before submitting.

# Example Architecture

This architecture is an example SaaS architecture where a customer (also in Azure) uses Private Endpoint to connect to the ISV's API.

This example diagram references:
* Azure Subscription
    * AKS
        * Ingress Controller
        * App pod (IP)
        * Data pod (IP)
    * Azure Load Balancer
    * CosmosDB
    * Storage Account
    * Azure Key Vault
* Customer Subscription (optional)

__NOTE__: The red boxes are the ISV's Intellectual Property (IP) and are used to signify where it runs.

You can modify this reference architecture by [downloading the Draw.io file for this image](sample-reference-architecture.drawio) and modifying it to reflect your architecture.

![](sample-reference-architecture.png)
