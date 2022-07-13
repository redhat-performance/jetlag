#!/usr/bin/env bash
python3 -m venv .ansible
source .ansible/bin/activate
pip3 install --upgrade pip
pip3 install ansible netaddr
pip3 install jmespath
ansible-galaxy collection install ansible.utils
