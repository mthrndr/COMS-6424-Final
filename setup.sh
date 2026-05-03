#!/bin/bash
set -e

docker compose build hdl-shell

docker compose run --rm hdl-shell yosys -p "plugin -i slang; help read_slang" > /dev/null

echo "docker setup, run: ./run.sh"
