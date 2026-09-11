# Pirate deployment

This directory is a first-pass Argo CD deployment definition for running
Infra on the Pirate OpenShift cluster.

## Current scope

The Application deploys the existing `chart/infra-server` chart from this
fork and adds an OpenShift `Route` with passthrough TLS. The Application is
deliberately manual-sync for now.

The public values file contains no credentials. The current chart still
requires confidential values for `infra-server-secrets`, including:

* OIDC configuration;
* the Infra service configuration;
* TLS certificate and key;
* registry credentials; and
* the chart's cloud-provider configuration.

Do not add those values to Git. Before syncing this Application, choose a
secret delivery mechanism available on Pirate, such as an External Secrets
integration or a supported Argo CD secrets plugin. The chart will need a
small follow-up change to consume an existing Secret instead of rendering
these values directly from Helm values.

## OpenShift follow-up

The current chart was written for the existing GKE deployment. In particular,
its default service and ingress templates contain GKE-specific assumptions.
The Route here is sufficient as a manifest for the initial deployment design,
but the chart should eventually make the following explicit values:

* service type and TLS mode;
* whether the GKE Ingress and ManagedCertificate are enabled; and
* whether the OpenShift Route is enabled.

## Intended workflow

1. Register `git@github.com:kylape/infra.git` with Argo CD.
2. Provision the confidential configuration outside Git.
3. Sync `infra-pirate` manually.
4. Confirm the Route and Infra health endpoint.
5. Log in through the configured OIDC provider.
6. Use Infra to provision a disposable vCluster on Pirate.

The vCluster kubeconfig should be delivered by Infra to the authenticated
developer. It should not be copied into this repository or managed as a
GitOps Secret.
