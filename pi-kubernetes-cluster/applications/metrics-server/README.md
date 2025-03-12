# Installing Metrics Server

## Add the chart
```sh
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
```

## Install the chart
```sh
helm upgrade --install metrics-server metrics-server/metrics-server --values values.yaml
```

## Links
[Helm Chart Github](https://github.com/kubernetes-sigs/metrics-server/tree/master/charts/metrics-server)