# Deploy Uptime Kuma

## Create directory on Worker node
```sh
sudo mkdir -p /data/uptime-kuma
sudo chmod 755 /data/uptime-kuma
```

## Create PV
```sh
kubectl create -f pv.yaml
```

## Install Helm Chart
```sh
helm upgrade uptime-kuma uptime-kuma/uptime-kuma --install --namespace monitoring --create-namespace --values values.yaml
```