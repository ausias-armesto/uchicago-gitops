# Git Ops Repository

This repository holds the Kubernetes manifests of the apps to be deployed on Kubernetes. It uses [Flux CD](https://fluxcd.io/) as a continuous delivery tool over Kubernetes.

## Prerequisites

- Installed Kubectl v1.23.1
- Installed Fluxcd 0.25.2
- Installed kubeseal v0.17.2

## Apps Installed on the Repository

- **Flux CD**: Contains the [Flux CD](https://fluxcd.io/) manifests that governs the Kluster
- **Prometheus and Grafana**: On the _monitoring_ folder are stored the manifest to deploy Prometheus and Grafana.
- **Security**: As the Cluster needs to be recreated in case of disaster, in the folder _security_ it is stored the secrets that will be managed by [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- **Wordpress**: Contains the Helm Release for Wordpress
- **Load Test**: The folder Load Test contains the configuration to add Horizontal Pod Autoscaler feature to the Wordpress Helm Release, and besides starts running a deployment that will inject load into the Wordpress App.



## Local Deployment Procedure

* `make encrypt-sealed-private-key env=dev`: Encrypts the master Sealed Secret. It has to be used only once to create the encrypted master sealed secret and push it to the repository. It requires the file .vaul_pass to exist.
* `make decrypt-sealed-private-key env=dev`: Decrypts the encrypted master Sealed Secret pushed to the repository. It requires the file .vaul_pass to exist.
* Install all the apps on the Kubernetes cluster (FluxCD, Sealed Secrets, Prometheus, Grafana, Wordpress). Change the _ghuser_ with the name of your Github forked repository user.
```
export GITHUB_USER=ausias-armesto
export GITHUB_TOKEN=<my-github-credentials-token>
export EFS_ID=$(aws efs describe-file-systems --query "FileSystems[0].FileSystemId" --output text)
sed -i.back 's/_EFS-ID_/'$EFS_ID'/' ./clusters/k8s-dev/wordpress/wordpress.yaml
make flux-bootstrap env=dev ghuser=ausias-armesto

```
* `make flux-secret-mysql env=dev`: Gets the MySql password from AWS and stores it as a Sealed secret on the cluster.
* `make flux-secret-wordpress env=dev`: Gets the Admin wordpress password from AWS and stores it as a Sealed secret on the cluster.
* `make flux-security env=dev`: Resets the master Sealed secrets by using the encrypted one stored in the repository, and then starts creating seals secrets with the new master sealed secret. 
```
k config set-context --current --namespace=wordpress
k scale deployment wordpress --replicas=0
k scale deployment wordpress --replicas=1
```
* `make flux-uninstall`: Deletes all Kubernetes resources installed on the cluster.



## Screenshots

### Initialize Kubernetes

![Flux](./images/k8s_flux.png)


### Wordpress

![Wordpress App](./images/app_wordpress.png)

![Wordpress K8s resources](./images/k8s_wordpress.png)

### Prometheus and Grafana

![Prometheus K8s resources](./images/k8s_prometheus.png)

![Grafana App](./images/app_grafana.png)
