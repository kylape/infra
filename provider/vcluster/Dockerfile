FROM registry.access.redhat.com/ubi9/ubi-minimal:9.6

ARG VCLUSTER_VERSION=0.25.1
ARG KUBECTL_VERSION=v1.32.4

RUN microdnf install --nodocs --setopt=install_weak_deps=0 -y \
      bash ca-certificates curl gzip tar openssl \
    && microdnf clean all \
    && curl -fsSL "https://github.com/loft-sh/vcluster/releases/download/v${VCLUSTER_VERSION}/vcluster-linux-amd64" \
      -o /usr/local/bin/vcluster \
    && chmod 0755 /usr/local/bin/vcluster \
    && curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
      -o /usr/local/bin/kubectl \
    && chmod 0755 /usr/local/bin/kubectl

COPY entrypoint.sh /usr/local/bin/provider
RUN chmod 0755 /usr/local/bin/provider

ENTRYPOINT ["/usr/local/bin/provider"]
