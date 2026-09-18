FROM registry.access.redhat.com/ubi9/ubi-minimal:9.6

ARG KUBECTL_VERSION=v1.32.4
ARG HELM_VERSION=v3.19.0

RUN microdnf install --nodocs --setopt=install_weak_deps=0 -y \
      bash ca-certificates curl gzip tar openssl \
    && microdnf clean all \
    && curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
      -o /usr/local/bin/kubectl \
    && chmod 0755 /usr/local/bin/kubectl \
    && curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" \
      | tar -xz -C /tmp \
    && mv /tmp/linux-amd64/helm /usr/local/bin/helm \
    && chmod 0755 /usr/local/bin/helm \
    && rm -rf /tmp/linux-amd64

COPY provider/vcluster/entrypoint.sh /usr/local/bin/provider
COPY scripts/deploy/bootstrap-vcluster.sh /usr/local/bin/bootstrap-vcluster
RUN chmod 0755 /usr/local/bin/provider /usr/local/bin/bootstrap-vcluster

ENTRYPOINT ["/usr/local/bin/provider"]
