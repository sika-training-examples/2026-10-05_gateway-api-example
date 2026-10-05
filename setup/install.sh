#!/bin/sh
# Cluster prerequisites (one-time, platform team):
#   Gateway API CRDs (standard, with ListenerSet), Envoy Gateway, cert-manager
set -e

ENVOY_GATEWAY_VERSION=v1.9.2   # bundles Gateway API v1.6.1 CRDs
CERT_MANAGER_VERSION=v1.21.2

# Gateway API CRDs (standard channel incl. ListenerSet) + Envoy Gateway CRDs.
# --force-conflicts takes over CRDs pre-installed by the cloud provider (e.g. DOKS).
helm template eg-crds oci://docker.io/envoyproxy/gateway-crds-helm \
  --version $ENVOY_GATEWAY_VERSION \
  --set crds.gatewayAPI.enabled=true \
  --set crds.gatewayAPI.channel=standard \
  --set crds.envoyGateway.enabled=true \
  | kubectl apply --server-side --force-conflicts -f -

# Envoy Gateway controller (CRDs installed above)
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --version $ENVOY_GATEWAY_VERSION \
  --namespace envoy-gateway-system --create-namespace \
  --skip-crds \
  --wait

# cert-manager with Gateway API + ListenerSet support
helm upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.21.2 \
  --namespace cert-manager --create-namespace \
  --values "./cert-manager-values.yaml" \
  --wait
