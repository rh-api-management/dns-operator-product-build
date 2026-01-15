#!/usr/bin/env bash
#
# Generate DNS Operator bundle variants using yq
#
# This script takes the upstream DNS operator bundle and transforms it
# into RHCL bundles for dev, stage, and prod environments.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."
UPSTREAM_BUNDLE="${PROJECT_ROOT}/dns-operator/bundle"
IMAGE_PULLSPECS="${PROJECT_ROOT}/image-pullspecs.yaml"
DNS_CONFIG="${SCRIPT_DIR}/dns-operator.yaml"

# Check dependencies
if ! command -v yq &> /dev/null; then
    echo "Error: yq is not installed"
    echo "Install: https://github.com/mikefarah/yq#install"
    exit 1
fi

# Verify config files exist
if [[ ! -f "$DNS_CONFIG" ]]; then
    echo "Error: DNS config not found at $DNS_CONFIG"
    exit 1
fi

if [[ ! -f "$IMAGE_PULLSPECS" ]]; then
    echo "Error: Image pullspecs not found at $IMAGE_PULLSPECS"
    exit 1
fi

echo "========================================"
echo "Loading configuration from:"
echo "  Config:      $DNS_CONFIG"
echo "  Pullspecs:   $IMAGE_PULLSPECS"
echo "========================================"

# Read image pullspecs
OPERATOR_IMAGE=$(yq '.images.operator' "$IMAGE_PULLSPECS")

echo ""
echo "Image pullspecs:"
echo "  operator: $OPERATOR_IMAGE"

# Extract SHA from the quay.io image
OPERATOR_SHA="${OPERATOR_IMAGE##*@}"

# Read DNS configuration values
CSV_NAME=$(yq '.csv.name' "$DNS_CONFIG")
CSV_VERSION=$(yq '.csv.version' "$DNS_CONFIG")
DISPLAY_NAME=$(yq '.csv.displayName' "$DNS_CONFIG")
DESCRIPTION=$(yq '.csv.description' "$DNS_CONFIG")
ICON_BASE64=$(yq '.csv.icon[0].base64data' "$DNS_CONFIG")
ICON_MEDIATYPE=$(yq '.csv.icon[0].mediatype' "$DNS_CONFIG")
DOC_URL=$(yq '.links.documentation' "$DNS_CONFIG")
REPO_URL=$(yq '.links.repository' "$DNS_CONFIG")
VALID_SUBSCRIPTION=$(yq '.validSubscription' "$DNS_CONFIG")

echo ""
echo "DNS configuration:"
echo "  CSV name:     $CSV_NAME"
echo "  Version:      $CSV_VERSION"
echo "  Display name: $DISPLAY_NAME"

# Build registry mappings for each environment
get_operator_image() {
    local env=$1
    if [[ "$env" == "dev" ]]; then
        echo "$OPERATOR_IMAGE"
    else
        local registry=$(yq ".registries.${env}.operator" "$DNS_CONFIG")
        echo "${registry}@${OPERATOR_SHA}"
    fi
}

# Generate bundle for each environment
for env in dev stage prod; do
    output_dir="${PROJECT_ROOT}/$(yq ".outputDirs.${env}" "$DNS_CONFIG")"
    manifests_dir="${output_dir}/manifests"
    metadata_dir="${output_dir}/metadata"

    echo ""
    echo "========================================"
    echo "Generating ${env} bundle"
    echo "Output: ${output_dir}"
    echo "========================================"

    # Clean and create output directories
    rm -rf "${output_dir}"
    mkdir -p "${manifests_dir}" "${metadata_dir}"

    # Copy manifests from upstream, but use local annotations.yaml
    cp "${UPSTREAM_BUNDLE}/manifests/"*.yaml "${manifests_dir}/"
    cp "${SCRIPT_DIR}/annotations.yaml" "${metadata_dir}/"

    CSV_FILE="${manifests_dir}/dns-operator.clusterserviceversion.yaml"

    # Get the image reference for this environment
    operator_image=$(get_operator_image "$env")

    echo "  Operator: ${operator_image}"

    # Update CSV: operator container image
    yq -i '(.spec.install.spec.deployments[] | select(.name == "dns-operator-controller-manager") | .spec.template.spec.containers[] | select(.name == "manager") | .image) = "'"${operator_image}"'"' "${CSV_FILE}"

    # Update CSV: containerImage annotation
    yq -i '.metadata.annotations.containerImage = "'"${operator_image}"'"' "${CSV_FILE}"

    # Update CSV: Add RHCL-specific feature annotations from config
    yq -i '.metadata.annotations["features.operators.openshift.io/disconnected"] = "'"$(yq '.features.disconnected' "$DNS_CONFIG")"'"' "${CSV_FILE}"
    yq -i '.metadata.annotations["features.operators.openshift.io/fips-compliant"] = "'"$(yq '.features.fips-compliant' "$DNS_CONFIG")"'"' "${CSV_FILE}"
    yq -i '.metadata.annotations["features.operators.openshift.io/proxy-aware"] = "'"$(yq '.features.proxy-aware' "$DNS_CONFIG")"'"' "${CSV_FILE}"
    yq -i '.metadata.annotations["features.operators.openshift.io/tls-profiles"] = "'"$(yq '.features.tls-profiles' "$DNS_CONFIG")"'"' "${CSV_FILE}"
    yq -i '.metadata.annotations["features.operators.openshift.io/token-auth-aws"] = "'"$(yq '.features.token-auth-aws' "$DNS_CONFIG")"'"' "${CSV_FILE}"
    yq -i '.metadata.annotations["features.operators.openshift.io/token-auth-azure"] = "'"$(yq '.features.token-auth-azure' "$DNS_CONFIG")"'"' "${CSV_FILE}"
    yq -i '.metadata.annotations["features.operators.openshift.io/token-auth-gcp"] = "'"$(yq '.features.token-auth-gcp' "$DNS_CONFIG")"'"' "${CSV_FILE}"
    yq -i '.metadata.annotations["features.operators.openshift.io/cnf"] = "'"$(yq '.features.cnf' "$DNS_CONFIG")"'"' "${CSV_FILE}"
    yq -i '.metadata.annotations["features.operators.openshift.io/cni"] = "'"$(yq '.features.cni' "$DNS_CONFIG")"'"' "${CSV_FILE}"
    yq -i '.metadata.annotations["features.operators.openshift.io/csi"] = "'"$(yq '.features.csi' "$DNS_CONFIG")"'"' "${CSV_FILE}"

    # Update CSV: valid subscription
    yq -i '.metadata.annotations["operators.openshift.io/valid-subscription"] = "[\"'"${VALID_SUBSCRIPTION}"'\"]"' "${CSV_FILE}"

    # Update CSV: Add architecture labels from config
    yq -i '.metadata.labels["operatorframework.io/os.linux"] = "'"$(yq '.architectures."os.linux"' "$DNS_CONFIG")"'"' "${CSV_FILE}"
    yq -i '.metadata.labels["operatorframework.io/arch.amd64"] = "'"$(yq '.architectures.amd64' "$DNS_CONFIG")"'"' "${CSV_FILE}"
    yq -i '.metadata.labels["operatorframework.io/arch.arm64"] = "'"$(yq '.architectures.arm64' "$DNS_CONFIG")"'"' "${CSV_FILE}"

    # Update CSV: Set display name, description, and icon
    yq -i ".spec.displayName = \"${DISPLAY_NAME}\"" "${CSV_FILE}"
    yq -i ".spec.description = \"${DESCRIPTION}\"" "${CSV_FILE}"
    yq -i ".spec.icon[0].base64data = \"${ICON_BASE64}\"" "${CSV_FILE}"
    yq -i ".spec.icon[0].mediatype = \"${ICON_MEDIATYPE}\"" "${CSV_FILE}"

    # Update CSV: Set documentation and repository links
    yq -i '.metadata.annotations.repository = "'"${REPO_URL}"'"' "${CSV_FILE}"
    yq -i '(.spec.links[] | select(.name == "DNS Operator") | .url) = "'"${DOC_URL}"'"' "${CSV_FILE}"

    # Update CSV: Remove replaces and skipRange (managed in catalog repo)
    yq -i 'del(.spec.replaces)' "${CSV_FILE}"
    yq -i 'del(.spec.skipRange)' "${CSV_FILE}"

    # Update CSV: Remove openshift versions annotation (managed in file-based catalog)
    yq -i 'del(.metadata.annotations["com.redhat.openshift.versions"])' "${CSV_FILE}"

    echo "  Done!"
done

echo ""
echo "========================================"
echo "All bundles generated successfully!"
echo "========================================"
echo ""
echo "Output directories:"
echo "  - bundle/       (production)"
echo "  - bundle-dev/   (development)"
echo "  - bundle-stage/ (staging)"
echo ""
