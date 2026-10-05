# Gateway API Example - Shared Gateway

One shared Gateway (like an ingress-nginx controller) in namespace `gw`,
two apps (`app-a`, `app-b`) in their own namespaces attaching to it.
HTTPS certs from Let's Encrypt via cert-manager, HTTP-01 validation through the Gateway.

Nothing in `gw` is app specific - adding an app never touches it.

```
gw/clusterissuer.yaml  # ClusterIssuer letsencrypt-gw (HTTP-01 solver via Gateway)
gw/gw.yaml             # ns gw + shared Gateway + HTTP->HTTPS redirect
app-a/app-a.yaml       # ns + Deployment + Service + ListenerSet + HTTPRoute
app-b/app-b.yaml       # ns + Deployment + Service + ListenerSet + HTTPRoute
```

| Ingress world             | Gateway API world                            |
| ------------------------- | -------------------------------------------- |
| IngressClass              | GatewayClass                                 |
| ingress-nginx controller  | Gateway (`gw/gw`)                            |
| Ingress `tls:` (app ns)   | ListenerSet (app ns) - hostname + cert       |
| Ingress `rules:` (app ns) | HTTPRoute (app ns) attached to ListenerSet   |
| cert-manager annotation   | same annotation, on the ListenerSet          |

## How it works

- Gateway `gw/gw`
  - listener `http` (port 80, any host, routes from all namespaces)
    - cert-manager attaches temporary ACME challenge HTTPRoutes here
    - everything else is redirected to HTTPS (`gw/https-redirect`)
  - `allowedListeners: All` - any namespace can add listeners via ListenerSet
- ListenerSet `app-x/app-x`
  - adds an HTTPS listener (port 443, `x.gw.sikademo.com`) to the shared Gateway
  - `cert-manager.io/cluster-issuer` annotation - cert-manager issues
    the cert into secret `app-x-tls` in the app namespace
  - `acme.cert-manager.io/http01-parentreffallback: "true"` - the ListenerSet is
    HTTPS only, so the HTTP-01 challenge goes via the Gateway's `http` listener
- HTTPRoute `app-x/app-x` attaches to the ListenerSet (`kind: ListenerSet`, `sectionName: https`)

## Adding a new app

Create a namespace with Deployment, Service, ListenerSet and HTTPRoute - copy `app-a/`.

## Requirements

- Gateway API CRDs >= v1.5 (standard channel) - ListenerSet is GA since v1.5
- Gateway controller with ListenerSet support, e.g. Cilium >= 1.20
  (install ListenerSet CRD before starting cilium-operator, or restart it)
- cert-manager >= 1.21 with Gateway API + ListenerSet enabled, Helm values:

  ```yaml
  config:
    apiVersion: controller.config.cert-manager.io/v1alpha1
    kind: ControllerConfiguration
    gatewayAPI:
      enabled: true
      enableListenerSet: true
    featureGates:
      ListenerSets: true
  ```

  (restart cert-manager if Gateway API CRDs were installed after it)
- DNS `*.gw.sikademo.com` pointing to the Gateway address

## Deploy

```
kubectl apply -f gw/
kubectl apply -f app-a/ -f app-b/
```

## Test

```
kubectl get gateway -n gw gw
kubectl get listenerset -A
kubectl get certificate -A
curl -I http://a.gw.sikademo.com    # 301 -> https
curl https://a.gw.sikademo.com
curl https://b.gw.sikademo.com
```
