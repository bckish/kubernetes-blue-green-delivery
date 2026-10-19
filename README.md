# Kubernetes Blue-Green Delivery

An original Kubernetes delivery pattern that keeps a stable Service endpoint while switching traffic between blue and green application versions.

## How it works

- `blue.yaml` and `green.yaml` deploy two independently versioned workloads.
- `service.yaml` selects the active color with `release: blue` or `release: green`.
- `scripts/promote.sh` performs the selector change and waits for ready endpoints.

## Local test with kind

```bash
kind create cluster --name blue-green
kubectl apply -f k8s/
kubectl get pods -l app=demo-api
./scripts/promote.sh green
kubectl get service demo-api -o jsonpath='{.spec.selector.release}'
```

The workloads use `nginx:1.27-alpine` so they can run locally. In a production service, add progressive verification, synthetic checks, rollback automation, and approval controls.
