#!/usr/bin/env bash
python3 -m venv .ansible
source .ansible/bin/activate
pip3 install -q --upgrade pip
# pin argcomplete to 3.7.0 in bootstrap script due to TypeError
pip3 install -q argcomplete==3.7.0
pip3 install -q 'ansible<12.0.0' netaddr
pip3 install -q jmespath --force
pip3 install -q yq
ansible-galaxy collection install ansible.utils --force
ansible-galaxy collection install containers.podman --upgrade
