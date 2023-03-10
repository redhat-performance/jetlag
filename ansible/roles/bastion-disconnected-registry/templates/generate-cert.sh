#!/usr/bin/env bash

host_fqdn=$(hostname --long)
cert_c="US"             # Country Name (C, 2 letter code)
cert_s="North Carolina" # Certificate State (S)
cert_l="Raleigh"        # Certificate Locality (L)
cert_o="RedHat"         # Certificate Organization (O)
cert_ou=""              # Certificate Organizational Unit (OU)
cert_cn="${host_fqdn}"  # Certificate Common Name (CN)

openssl req \
    -newkey rsa:4096 \
    -nodes \
    -sha256 \
    -keyout {{ registry_path }}/certs/domain.key \
    -x509 \
    -days 365 \
    -out {{ registry_path }}/certs/domain.crt \
    -addext "subjectAltName = DNS:${host_fqdn}" \
    -subj "/C=${cert_c}/ST=${cert_s}/L=${cert_l}/O=${cert_o}/OU=${cert_ou}/CN=${cert_cn}"
