### Elastic Load Balancer

The service-design for this set of templates places the GitLab EC2 instance(s) into a protected/unrouted subnet. In order for Internet-hosted clients to access the service, a reverse-proxy is needed. The ELB templates ([standalone](/Templates/make_gitlab_ELB-autoscale.tmplt.json) & [autoscale](/Templates/make_gitlab_ELB-instance.tmplt.json)) take care of configuring the public-facing proxy to allow HTTPS and SSH-based interaction with the service (the latter being necessary to more-easily support 2FA).

Note: the HTTPS is actually SSL-terminated at the ELB. The EC2 host(s) only speak HTTP with the ELB.
