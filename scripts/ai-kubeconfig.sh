#!/bin/bash
# Mint a short-lived, read-only kubeconfig for AI assistants.
#
# Run this yourself, logged in as a cluster admin. It creates a bound token for
# the ai-access/ai-cluster-reader ServiceAccount (components/ai-access) and
# writes a kubeconfig that contains only that token, so the assistant never
# sees your own credentials. Re-run it when the token expires.

set -euo pipefail

DURATION="${1:-8h}"
OUT="${AI_KUBECONFIG:-$HOME/.config/ai-cluster-reader/kubeconfig}"
NAMESPACE=ai-access
SERVICE_ACCOUNT=ai-cluster-reader

server=$(oc whoami --show-server)
ca=$(oc config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
token=$(oc create token -n "${NAMESPACE}" "${SERVICE_ACCOUNT}" --duration="${DURATION}")

mkdir -p "$(dirname "${OUT}")"
rm -f "${OUT}"
(umask 077 && touch "${OUT}")

export KUBECONFIG="${OUT}"
oc config set-cluster ai --server="${server}" >/dev/null
if [ -n "${ca}" ]; then
  oc config set clusters.ai.certificate-authority-data "${ca}" >/dev/null
fi
oc config set-credentials "${SERVICE_ACCOUNT}" --token="${token}" >/dev/null
oc config set-context ai --cluster=ai --user="${SERVICE_ACCOUNT}" >/dev/null
oc config use-context ai >/dev/null

echo "Wrote ${OUT}"
echo "  server:   ${server}"
echo "  identity: $(oc whoami)"
echo "  expires:  in ${DURATION}"
