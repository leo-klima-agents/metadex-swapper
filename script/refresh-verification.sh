#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

forge build
forge script script/Hashes.s.sol --sig 'record(string)' verification/bytecode-hashes.json
forge verify-contract --show-standard-json-input 0x0000000000000000000000000000000000000001 \
  src/ImmutableSwapper.sol:ImmutableSwapper > verification/ImmutableSwapper.standard-input.json
./script/check-verification.sh
