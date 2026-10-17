#!/usr/bin/env bash
# Installs the tools not covered by dev container features.
set -euo pipefail

KUBESEAL_VERSION=0.27.1

pip install --user --no-cache-dir ansible-core==2.17.5 ansible-lint==24.10.0 boto3 botocore pre-commit
pip install --user --no-cache-dir -r app/requirements-dev.txt
(cd ansible && ansible-galaxy collection install -r requirements.yml)

# AWS Session Manager plugin (Ansible SSM connection + port forwarding)
curl -fsSL "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" \
  -o /tmp/session-manager-plugin.deb
sudo dpkg -i /tmp/session-manager-plugin.deb
rm /tmp/session-manager-plugin.deb

# kubeseal (Sealed Secrets CLI)
curl -fsSL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz" \
  | sudo tar -xz -C /usr/local/bin kubeseal

sudo apt-get update && sudo apt-get install -y --no-install-recommends jq make shellcheck

pre-commit install
echo "SkyForge toolbox ready. Run 'make help'."
