# vCluster runner build

This Pipeline builds the custom provider image used by the single Infra
vCluster flavor. It does not build the Infra server image.

The Pipeline expects a Tekton workspace containing a Docker registry auth
Secret with a `.dockerconfigjson` key. The Secret is intentionally not
included in this repository.

Example `PipelineRun` shape:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: infra-vcluster-runner-build-
  namespace: infra
spec:
  pipelineRef:
    name: infra-vcluster-runner-build
  params:
    - name: git-url
      value: https://github.com/kylape/infra.git
    - name: git-revision
      value: codex/vcluster-provider-poc
    - name: image
      value: quay.io/kylape/infra-vcluster-runner:0.1.0
  workspaces:
    - name: source
      volumeClaimTemplate:
        spec:
          accessModes: [ReadWriteOnce]
          resources:
            requests:
              storage: 1Gi
    - name: registry-auth
      secret:
        secretName: replace-with-registry-auth-secret
```

After the image is published, set `vcluster.runnerImage` in
`chart/infra-server/values.yaml` to the immutable image tag or digest before
deploying Infra.
