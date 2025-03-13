# Twingate Kubernetes Operator

## 1. Get API token from admin console and save as K8s secret
```sh
kubectl create secret generic twingate-api-token -n twingate \
    --from-literal=api-token='yourapitoken'
```

## 2. Deploy operator with values.yaml
```sh
helm upgrade twop oci://ghcr.io/twingate/helmcharts/twingate-operator --install --wait -f ./values.yaml -n twingate --create-namespace
```

## 3. Deploy your Connector, a Resource, and ResourceAccess
[Documentation](https://github.com/Twingate/kubernetes-operator/wiki/Getting-Started)