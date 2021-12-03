# SPARCRequest - Kubernetes

This reference project can be used to inform how your group could run SPARCRequest in a Kubernetes environment. The following is representative of how OCTRI chose to implement SPARCRequest.

## Considerations for running SPARCRequest in Kubernetes

### SPARCRequest Customization

By using a second image we are able to modify our instance of SPARCRequest without needing to maintain a separate branch in source control.

See the Image section below for a description of how we build and manage our SPARCRequest instance.

### Deployments

We have two deployment workloads defined; one for the main application and a second for the delayed job that performs background tasks like sending emails.

#### Main Deployment

The main SPARCRequest application generally runs well inside Kubernetes, a single process Puma web server running the rails app. As seen in the [`deployment`](./k8s/deployment.yaml) manifest, we specify the resources, configuration, liveness, initContainers and any volumes required for persistence.

The `initContainers` are used to perform database migrations and asset compilation.

The volumes persist the things like attachments. We use a NFS  `PersistentVolume` to preserve these files beyond the lifespan of a pod.

The `livenessProbe` informs the scheduler when the new pod is up and that it can terminate the old pod. This is important because the database migrations and asset compilation can take a bit of time and this reduces the time the application is unavailable.

#### Delayed Job

The challenging part of running SPARCRequest in a Kubernetes environment is running the Delayed Job as this is a separate process from SPARCRequest. To accommodate this process we run it as a [`Deployment`](./k8s/deployment_delayed_job.yaml) running the following command:

```bash
rails jobs:work
```

This can be seen in the [`deployment_delayed_job`](./k8s/deployment_delayed_job.yaml#L20) manifest. There is no reason it could not be a container in the same pod. We chose to run it as a separate pod to assist with troubleshooting and to isolate the main application in case the delayed job runs amok. This also means that we can restart it independently of the main application.


### Configuration

Much of SPARCRequest's configuration is performed via a number of files in the `config` directory. To minimize the amount of modification of the configuration files we converted them to rely on environment variables. See the [`database.yml`](./custom/deps/sparc/database.yml) file as an example. By externalizing the configuration we can use the same code in any environment, only updating configuration as needed.

Then by using a [`ConfigMap`](./k8s/config.yaml) and [`Secrets`](./k8s/secrets.yaml) we can deploy the same image to any of our environments (dev, stage, prod) and it will be configured appropriately. The [`Deployment`](./k8s/deployment.yaml) and other resources can then reference the same configuration. See the [`deployment.yaml`](./k8s/deployment.yaml#L38) for an example of how the configuration is referenced.


### Scheduled Tasks

#### RMID / IRB Service

MUSC operates another application that, among other things, synchronizes the IRB records associated with Protocols and Projects in SPARCRequest. This was an essential feature that OHSU needed to ensure that work performed for projects was in compliance with the IRB status. To that end, we built an API compatible application that allowed SPARCRequest to retrieve IRB information. We also run it as a daily scheduled task to ensure all IRB records in SPARCRequest are up to date. The [`cron_irb.yaml`](./k8s/cron_irb.yaml) is an example of running a scheduled task to retrieve the IRB records.

### Accessing the application in the cluster

Once SPARCRequest is running in the cluster it needs to be made available outside the cluster so users can access it. This is done with the [`Service`](./k8s/service.yaml) resource. This informs the cluster that the sparc deployment should be made externally available and which ports to access the application on.

The cluster will also need to have an Ingress resource defined, which is responsible for receiving requests outside the cluster and routing them to the appropriate service. That is out of scope for this project, but there are [lots of resources](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/) available to set this up.

## Images

We chose to use two images as our approach in order to maintain a clean separation between the standard SPARCRequest and our customized version. This allows us to isolate our changes from the main code for greater portability.

### SPARCRequest base image

The first step is to build the [base-image](./base-image/Dockerfile) which builds a container image directly from a SPARCRequest tag. We use [Docker](https://www.docker.com/) to build our images.

```bash
cd base-image
docker build --rm -t example.edu/sparc_request_base --pull .
```

If you want to target another version of SPARCRequest you can pass a build argument.

```bash
export SPARC_VERION=3.9.0
cd base-image
docker build --rm --build-arg SPARC_VERSION=${SPARC_VERION} -t example.edu/sparc_request_base:${SPARC_VERION} --pull .
```

We recommend tagging your image with the version of SPARCRequest to make it clear which version you are building with.

### Organization specific image

The customized image extends the base image with organization specific changes, including things like environment, locale, and extension files to the standard SPARCRequest version.

```bash
cd custom
docker build --rm -t example.edu/sparc_request --pull .
```

## Running SPARCRequest

We recommend that you have your Ingress and PersistentVolume resources setup to your satisfaction before attempting to run SPARCRequest in the cluster.

Once you have your images build you can deploy them to the cluster using the `kubectl` command line tool. The first time you attempt to deploy you should make sure to run it in the following order to ensure the deployments have everything they need.

```bash
kubectl apply -f ./k8s/config.yaml -f ./k8s/secrets.yaml -f service.yaml
kubectl apply -f ./k8s/deployment.yaml -f ./k8s/deployment_delayed_job.yaml
```

You can monitor the rollout with `kubectl` to see the deployment

```bash
kubectl get deployment

NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
...
sparc                   0/1     1            0           2s
...
```

and the pod as it starts up
```bash
kubectl get pod

NAME                                     READY   STATUS      RESTARTS      AGE
sparc-84796bdc44-vdl5l                   1/1     Running     0             15s
```

and review the logs
```bash
kubectl logs -f deploy/sparc

DEPRECATION WARNING: axlsx_rails has been renamed to caxlsx_rails. See http://github.com/caxlsx
=> Booting Puma
=> Rails 5.2.4.3 application starting in development
=> Run `rails server -h` for more startup options
No executable found at /usr/local/bin/wkhtmltopdf. Will fall back to
Puma starting in single mode...
* Version 5.0.0 (ruby 2.5.8-p224), codename: Spoony Bard
* Min threads: 5, max threads: 5
* Environment: development
* Listening on http://0.0.0.0:3000
```
