# Install Prometheus in Kubernetes cluster

## Create directory and ownership on Worker node
```sh
sudo mkdir -p /data/prometheus
sudo chown -R 65534:65534 /data/prometheus
```

### Create PVs
```sh
sudo create -f prometheus-pv.yaml
```

### Install Helm chart with values.yaml
```sh
helm install prometheus prometheus-community/prometheus --namespace monitoring --create-namespace -f values.yaml
```