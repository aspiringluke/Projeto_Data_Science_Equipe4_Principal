#!/usr/bin/bash

# depois eu ajusto isso daqui, vou só fazer

cd iac
echo yes | tofu destroy

for i in {1..255}; do ((ssh-keygen -R 192.168.122.${i})); done > /dev/null

cd ..
./build_infra.sh