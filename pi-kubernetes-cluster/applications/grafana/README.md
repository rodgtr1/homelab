# Deploying Grafana in Kubernetes

## 1. Create folder on Worker node
```sh
sudo mkdir -p /data/grafana-data
sudo chown -R 472:472 /data/grafana-data
sudo chmod 755 /data/grafana-data
```

## 2. Create Persistent Volume
```sh
k create -f grafana-pv.yaml
```

## Install Grafana via Helm
```sh
helm install grafana grafana/grafana -n monitoring -f grafana-values.yaml --create-namespace
```