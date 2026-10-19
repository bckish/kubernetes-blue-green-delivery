#!/usr/bin/env bash
set -euo pipefail

target="${1:-}"
if [[ "$target" != "blue" && "$target" != "green" ]]; then
  echo "Usage: $0 <blue|green>" >&2
  exit 2
fi

kubectl rollout status "deployment/demo-api-${target}" --timeout=90s
kubectl patch service demo-api --type merge -p "{\"spec\":{\"selector\":{\"app\":\"demo-api\",\"release\":\"${target}\"}}}"
kubectl get endpoints demo-api
echo "Traffic promoted to ${target}."
