#!/usr/bin/env bash
# Install and update uv
if [ ! $(which uv) ]; then curl -LsSf https://astral.sh/uv/install.sh | sh; fi
uv self update

# Create and populate virtual environment
uv venv --clear --force .ansible --python 3.12
uv pip install --python .ansible/bin/python \
'ansible<12.0.0' \
'argcomplete<3.7.0' \
netaddr \
jmespath \
yq

# Activate virtual environment
source .ansible/bin/activate

# Configure Ansible Collections
ansible-galaxy collection install ansible.utils --force
ansible-galaxy collection install containers.podman --upgrade
