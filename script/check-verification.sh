#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

HASHES=verification/bytecode-hashes.json
INPUT=verification/ImmutableSwapper.standard-input.json
[ -f "$HASHES" ] || { echo "::error::$HASHES missing; run script/refresh-verification.sh" >&2; exit 1; }
[ -f "$INPUT" ] || { echo "::error::$INPUT missing; run script/refresh-verification.sh" >&2; exit 1; }
FRESH=verification/.fresh.json
trap 'rm -f "$FRESH"' EXIT
status=0

forge script script/Hashes.s.sol --sig 'record(string)' "$FRESH" >/dev/null
if ! diff <(jq -S . "$HASHES") <(jq -S . "$FRESH") >&2; then
  echo "::error::$HASHES is stale; run script/refresh-verification.sh" >&2
  status=1
else
  echo "$HASHES ok"
fi

projection='del(.settings.outputSelection)'
current=$(forge verify-contract --show-standard-json-input 0x0000000000000000000000000000000000000001 src/ImmutableSwapper.sol:ImmutableSwapper | jq -S "$projection")
if [ "$current" != "$(jq -S "$projection" "$INPUT")" ]; then
  echo "::error::$INPUT is stale" >&2
  status=1
else
  echo "$INPUT ok"
fi

for address in $(jq -r '.chains[].deployments[].address' "$HASHES"); do
  if grep -qF "\`$address\`" README.md; then
    echo "README.md shows $address"
  else
    echo "::error::README.md does not show $address" >&2
    status=1
  fi
done

exit $status
