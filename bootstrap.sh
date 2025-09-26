#!/usr/bin/env bash
python3 -m venv .ansible
source .ansible/bin/activate
pip3 install -q --upgrade pip
pip3 install -q 'ansible<12.0.0' netaddr
pip3 install -q jmespath --force
ansible-galaxy collection install ansible.utils --force
