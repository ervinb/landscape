# Kubernetes desired-state configuration repo

- Secrets pulled in from Hashicorp Vault
- Can be applied locally (via minikube) or in GCE (via kops)
- Use branches for different deployed apps / configs / secrets

## Usage
 - install prerequisites
 - `git clone https://github.com/shaneramey/landscape`
 - `cd landscape`
 - `make`

## Features
 - Compare branches to compare environments
 - Sign off on production changes using GitHub approve workflow

## Core Charts
 - [common-chart](https://github.com/shaneramey/common-chart)
       defines templates that can be used by all charts
 - [vault](https://github.com/shaneramey/helm-charts/tree/master/vault)
      back-end for Kubernetes secrets (including CA PKI)
 - [cfssl](https://github.com/shaneramey/helm-charts/tree/master/cfssl)
      optional;alternatively use k8s CertificateSigningRequests for auto-signing
 - [nssetup](https://github.com/shaneramey/helm-charts/tree/master/nssetup)
      Provides per-namespace resources (e.g., LimitRanges + ResourceQuotas)
 - [389ds](https://github.com/shaneramey/helm-charts/tree/master/389ds)
      LDAP server
 - [nginx](https://github.com/shaneramey/helm-charts/tree/master/nginx)
      nginx front-end for services that auto-submits a CSR / loads TLS cert
 - [helm-chart-publisher](https://github.com/shaneramey/helm-charts/tree/master/helm-chart-publisher)
      curl-able API to publish Helm charts to a HTTP Helm chart repo
 - [monocular](https://github.com/shaneramey/helm-charts/tree/master/monocular)
      GUI to view installed/available charts
 - [jenkins](https://github.com/shaneramey/helm-charts/tree/master/jenkins)
      back-end for secrets
 - [fluentd](https://github.com/shaneramey/helm-charts/tree/master/fluentd)
      DaemonSet to collect logs from each k8s node
 - [elasticsearch](https://github.com/shaneramey/helm-charts/tree/master/elasticsearch)
      PetSet with PersistentVolumeProvisioner support
 - [kibana](https://github.com/shaneramey/helm-charts/tree/master/kibana)
      Deployment with LDAP login front-end
 - [openvpn](https://github.com/shaneramey/helm-charts/tree/master/openvpn)
      Provides remote access
 - [heapster](https://github.com/shaneramey/helm-charts/tree/master/heapster)
      Deployment with LDAP login front-end
 - [influxdb](https://github.com/shaneramey/helm-charts/tree/master/influxdb)
      Deployment with LDAP login front-end

## Application Charts
 - [postgresql](https://github.com/shaneramey/helm-charts/tree/master/postgresql)
       defines templates that can be used by all charts
 - [redis](https://github.com/shaneramey/helm-charts/tree/master/redis)
       defines templates that can be used by all charts
 - [django](https://github.com/shaneramey/helm-charts/tree/master/django)
       defines templates that can be used by all charts
 - [django-nginx-redis-postgresql](https://github.com/shaneramey/helm-charts/tree/master/django-nginx-redis-postgresql)
       Chart that wraps (requires) django + nginx + redis + postgresql charts
 - [nodejs-nginx-redis-postgresql](https://github.com/shaneramey/helm-charts/tree/master/nodejs-nginx-redis-postgresql)
       Chart that wraps (requires) nodejs + nginx + redis + postgresql charts

## Docs
 - [limitations](docs/limitations.md)
 - [prerequisites](docs/prerequisites.md)
 - [lastpass](docs/lastpass.md)
 - [forking](docs/forking.md)
 - [secrets](docs/secrets.md)
 - [deployment](docs/deployment.md)
 - [targets](docs/targets.md)
 - [pki](docs/pki.md)
 - [storageclasses](docs/storageclasses.md)
 - [init-containers](docs/init-containers.md)
 - [troubleshooting](docs/troubleshooting.md)
 - [design-doc](docs/design-doc.md)
 - [open-questions](docs/open-questions.md)

## Requirements
- [Kubernetes Helm](https://github.com/kubernetes/helm)
- [Landscaper](https://github.com/Eneco/landscaper)
- [envconsul](https://github.com/hashicorp/envconsul)
- [Hashicorp Vault](https://www.vaultproject.io) client `vault` command
- (optional) [lastpass-cli](https://github.com/lastpass/lastpass-cli) for secrets backups
- (minikube deploys) [minikube](https://github.com/kubernetes/minikube)
- (minikube deploys) [docker vault container](https://hub.docker.com/_/vault/)


## Wiping the cluster
WARNING: this will wipe out everything in your current KUBERNETES_CONTEXT! 

All data on your KUBERNETES_CONTEXT will be lost!

Make sure you're not running this against the wrong target!

Decommission cluster:
```
make PURGE_ALL=yes purge
```
