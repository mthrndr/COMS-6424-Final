#!/bin/bash
set -e

git submodule update --init --recursive

docker compose build hdl-shell

docker compose run --rm hdl-shell yosys -p "plugin -i slang; help read_slang" > /dev/null

make apply-patches

make change-core-ver

echo "docker setup, run: ./run.sh"
