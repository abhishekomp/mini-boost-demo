#!/bin/bash
# =============================================================================
# deploy.sh — The miniature dev-tools
#
# This script is a simplified version of what "dev-tools deploy manifest" does.
# It reads demo-manifest.json, finds the requested components, and calls
# "helm upgrade --install" for each one.
#
# Usage:
#   ./deploy.sh                                   Deploy ALL components
#   ./deploy.sh name-service                      Deploy only name-service
#   ./deploy.sh name-service,greeting-service     Deploy both (comma-separated)
#
# This is roughly what happens inside dev-tools when you run:
#   dev-tools deploy manifest -m 9.0.4 -i userpod,messagingpod
# =============================================================================

set -e  # Exit immediately if any command fails

MANIFEST="demo-manifest.json"
INCLUDE="${1:-all}"  # First argument = comma-separated list of components, or "all"

# ── Preflight checks ──────────────────────────────────────────────────────────
# Check required tools are available
command -v helm    >/dev/null 2>&1 || { echo "ERROR: helm is not installed. Run: brew install helm"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl is not installed. Run: brew install kubectl"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 is not installed"; exit 1; }

# Check the manifest file exists
if [ ! -f "$MANIFEST" ]; then
    echo "ERROR: Manifest file '$MANIFEST' not found."
    echo "Are you running this script from the phase5-the-manifest/ directory?"
    exit 1
fi

# Check Kubernetes is accessible
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "ERROR: Cannot connect to Kubernetes cluster."
    echo "Make sure Colima is running: colima start --kubernetes"
    exit 1
fi

echo "========================================"
echo "  mini-boost deploy.sh"
echo "  Manifest: $MANIFEST"
echo "  Include:  $INCLUDE"
echo "========================================"
echo ""

# ── Parse the manifest JSON ───────────────────────────────────────────────────
# We use Python (available on all Macs) to parse the JSON and extract:
# - component name       → the Helm release name
# - chart path           → the local path to the Helm chart directory
# - chart version        → informational only (NOTE: 'helm install' with a local
#                          directory path does not use --version; the chart
#                          version is read directly from Chart.yaml in the folder.
#                          In the real dev-tools, charts are pulled from a remote
#                          Helm repository and --version pins the exact chart.)
# - image name + tag     → passed to Helm as --set overrides, same as dev-tools
#                          passes image.digest=sha256:... to the real charts
COMPONENTS=$(python3 - <<EOF
import json, sys

with open('$MANIFEST') as f:
    manifest = json.load(f)

include_list = '$INCLUDE'.split(',') if '$INCLUDE' != 'all' else None

found = []
for service in manifest['services']:
    for component in service['components']:
        name = component['name']
        if include_list and name not in include_list:
            continue
        chart_name  = component['helm-chart']['name']
        chart_ver   = component['helm-chart']['version']
        image_name  = component['image']['name']
        image_tag   = component['image']['tag']
        found.append(f'{name}|{chart_name}|{chart_ver}|{image_name}|{image_tag}')

if not found:
    print("__NOTFOUND__")
else:
    for line in found:
        print(line)
EOF
)

if [ "$COMPONENTS" = "__NOTFOUND__" ] || [ -z "$COMPONENTS" ]; then
    echo "ERROR: No components found matching: $INCLUDE"
    echo "Available components in $MANIFEST:"
    python3 -c "
import json
with open('$MANIFEST') as f:
    m = json.load(f)
for s in m['services']:
    for c in s['components']:
        print('  -', c['name'])
"
    exit 1
fi

# ── Deploy each component ─────────────────────────────────────────────────────
echo "$COMPONENTS" | while IFS='|' read -r name chart_name chart_version image_name image_tag; do
    echo "---"
    echo "Deploying: $name"
    echo "  Chart:         $chart_name"
    echo "  Chart version: $chart_version  (from Chart.yaml in the local directory)"
    echo "  Image:         $image_name:$image_tag"
    echo ""

    # helm upgrade --install:
    #   - "upgrade" if the release already exists → updates it
    #   - "install" if the release does not exist → installs it fresh
    # This makes the command idempotent — safe to run multiple times.
    #
    # --set image.repository and --set image.tag override values.yaml defaults.
    # In the real dev-tools, this is where image.digest=sha256:... is also passed,
    # ensuring Kubernetes uses the exact pinned image regardless of tag mutability.
    if ! helm upgrade --install "$name" "./$chart_name" \
        --set image.repository="$image_name" \
        --set image.tag="$image_tag"; then
        echo "ERROR: helm upgrade --install failed for $name"
        exit 1
    fi

    echo "  ✓ $name deployed"
    echo ""
done

echo "========================================"
echo "  Deployment complete!"
echo ""
echo "  Check pod status:  kubectl get pods -w"
echo "  Check releases:    helm list"
echo "  Test the service:  curl http://localhost:30080/api/greet"
echo "========================================"
