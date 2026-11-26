#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 2 || ( "$2" != blue && "$2" != green ) ]]; then
  echo "Usage: $0 /path/to/local-kind.kubeconfig <blue|green>" >&2
  exit 2
fi
kubeconfig=$1
target=$2
context=$(kubectl --kubeconfig "$kubeconfig" config current-context)
server=$(kubectl --kubeconfig "$kubeconfig" config view --minify -o jsonpath='{.clusters[0].cluster.server}')
if [[ $context != kind-* || $server != https://127.0.0.1:* ]]; then
  echo "This lab only supports a disposable local Kind cluster." >&2
  exit 2
fi
k() { kubectl --kubeconfig "$kubeconfig" --namespace blue-green-lab "$@"; }
previous=$(k get service demo-api -o jsonpath='{.spec.selector.release}')
[[ $previous == blue || $previous == green ]] || { echo "Unexpected current selector" >&2; exit 1; }
k rollout status "deployment/demo-api-${target}" --timeout=90s
replicas=$(k get "deployment/demo-api-${target}" -o jsonpath='{.spec.replicas}')
[[ $replicas =~ ^[1-9][0-9]*$ ]] || { echo "Target has no desired replicas; refusing promotion." >&2; exit 1; }
patch_color() { k patch service demo-api --type merge -p "{\"spec\":{\"selector\":{\"app\":\"demo-api\",\"release\":\"$1\"}}}"; }
patch_color "$target"

# EndpointSlice reconciliation is asynchronous. Only accept ready targets of the desired color.
for _ in {1..30}; do
  if endpoints=$(k get endpointslice -l kubernetes.io/service-name=demo-api -o json) && printf '%s' "$endpoints" | python3 -c 'import json,sys; target=sys.argv[1]; e=[x for s in json.load(sys.stdin)["items"] for x in s["endpoints"] if x["conditions"].get("ready") is True]; assert len(e) >= int(sys.argv[2]) > 0 and all(x["targetRef"]["name"].startswith("demo-api-"+target+"-") for x in e)' "$target" "$replicas" 2>/dev/null; then
    echo "Traffic promoted to ${target}."
    exit 0
  fi
  sleep 2
done
echo "Endpoint verification failed; restoring ${previous}." >&2
patch_color "$previous"
exit 1
