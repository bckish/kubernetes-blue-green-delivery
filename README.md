# Kubernetes Blue-Green Delivery

An original Kubernetes delivery pattern that keeps a stable Service endpoint while switching traffic between blue and green application versions.

## How it works

- `blue.yaml` and `green.yaml` deploy two independently versioned workloads.
- `service.yaml` selects the active color with `release: blue` or `release: green`.
- Each version returns its own color, making the traffic switch observable.
- `scripts/promote.sh` validates target readiness, switches the stable Service, verifies ready EndpointSlices and reverts the selector if endpoint verification times out.

## Local test with kind

```bash
kind create cluster --name blue-green --image kindest/node:v1.34.3 --kubeconfig ./blue-green.kubeconfig
kubectl --kubeconfig ./blue-green.kubeconfig create namespace blue-green-lab
kubectl --kubeconfig ./blue-green.kubeconfig -n blue-green-lab apply -k k8s/
kubectl --kubeconfig ./blue-green.kubeconfig -n blue-green-lab rollout status deployment/demo-api-blue
kubectl --kubeconfig ./blue-green.kubeconfig -n blue-green-lab exec deployment/demo-api-blue -- wget -qO- http://demo-api
bash scripts/promote.sh ./blue-green.kubeconfig green
kubectl --kubeconfig ./blue-green.kubeconfig -n blue-green-lab exec deployment/demo-api-blue -- wget -qO- http://demo-api
bash scripts/promote.sh ./blue-green.kubeconfig blue
kind delete cluster --name blue-green --kubeconfig ./blue-green.kubeconfig
```

Requires Docker, Kind, kubectl and Python 3. The workloads use `nginx:1.27-alpine` and run locally. The script deliberately rejects remote contexts; it is not an Argo Rollouts controller or a production zero-downtime guarantee. For production, add traffic metrics, synthetic gates, approval controls and a validated rollout controller.

## Verified results — 26 November 2026

Kind Kubernetes v1.34.3: both deployments reached two Ready replicas; the stable Service returned `blue`, then `green` after promotion, and `blue` after rollback. Bash syntax and Kustomize rendering passed. The test did not measure continuous traffic loss or provision any cloud infrastructure.

A second safety test scaled the inactive green deployment to zero; promotion was refused, the Service selector remained blue, and live HTTP traffic still returned blue. The inactive deployment was then restored.
