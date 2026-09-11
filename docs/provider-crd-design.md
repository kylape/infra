# Provider CRD design

## Purpose

Infra should keep its user-facing API and Argo Workflows integration, while
moving provider-specific provisioning details out of the server's static flavor
catalog. Users continue to request clusters through Infra's UI, API, or CLI.
They do not create request CRs.

An administrator configures a provider using a Kubernetes custom resource. The
Infra backend reconciles that provider configuration and, once it is usable,
submits an Argo Workflow for the user request.

```text
Infra UI/API/CLI
        |
        | user request
        v
Infra backend
        |
        | reconcile provider configuration and credentials
        v
Argo Workflow
        |
        | provider runner image
        v
Provider automation
```

## Provider resource

The initial shape should describe the contract needed to render an Argo
Workflow rather than expose every Argo implementation detail:

```yaml
apiVersion: infra.example.com/v1alpha1
kind: Provider
metadata:
  name: vcluster
spec:
  runner:
    image: quay.io/example/infra-vcluster-runner:0.1.0
    command: ["/usr/local/bin/provider"]
    createArgs: ["create"]
    deleteArgs: ["delete"]

  credentials:
    - name: host-cluster
      secretRef:
        name: host-cluster-credentials

  parameters:
    - name: name
      type: string
      required: true

  artifacts:
    - name: kubeconfig
      path: /outputs/kubeconfig
```

The backend should validate the provider before submitting a workflow. The
provider status can report credential resolution, runner availability, and
validation errors. A user request remains an Infra API operation whose
execution record is represented by the resulting Argo Workflow.

## Mapping the current workflow model

The existing static files are complete Argo `Workflow` objects. They combine
four concerns:

* lifecycle orchestration: create, wait, and destroy;
* provider-specific runner image and command line;
* provider credentials and environment variables;
* artifact collection and output paths.

The CRD should make the last three concerns configurable. The generic cluster
service can continue to submit, monitor, suspend, resume, and inspect Argo
Workflows. This avoids introducing a second workflow engine or a user-facing
request CRD.

## vCluster proof of concept

The first provider is intentionally hard-coded as a single `vcluster` flavor.
Its runner image contains the vCluster CLI, `kubectl`, and a small entrypoint
that:

* builds an in-cluster kubeconfig from the workflow service account;
* runs `vcluster create` in the host cluster;
* exports a kubeconfig artifact;
* deletes the vCluster during workflow cleanup.

The runner is built by Tekton so the image can be replaced independently of
the Infra server image. The workflow keeps the existing Infra lifecycle model:
the create step runs first, a suspend step keeps the environment available,
and the exit handler destroys it when the operation ends.

## Image strategy

The existing StackRox flavor images are private and provider-specific. Infra
should not build or own those images as part of the generic server. A provider
definition should reference its runner image.

For the vCluster proof of concept, we own one custom runner image and build it
with Tekton. Future providers can supply their own runner image while retaining
the same provider contract.

## Deferred work

The following are deliberately outside the first proof of concept:

* dynamic provider discovery and reconciliation;
* a durable request database;
* provider-specific workflow templating beyond the single vCluster workflow;
* BigQuery audit integration;
* public per-vCluster ingress and externally routable kubeconfigs.

