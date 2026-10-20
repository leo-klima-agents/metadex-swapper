#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

U=test/upstream
I=src/interfaces
status=0
checked=()

# Prints name(argument types)(return types) as declared in a Solidity file.
sig() {
  awk -v name="$2" '
    { gsub(/\r/, ""); sub(/\/\/.*/, ""); src = src " " $0 }
    function types(list,   n, parts, i, out, t) {
      n = split(list, parts, ",")
      out = ""
      for (i = 1; i <= n; i++) {
        t = parts[i]
        gsub(/^[ \t]+/, "", t)
        sub(/[ \t].*$/, "", t)
        if (t == "uint") t = "uint256"
        if (t == "Currency" || t == "IHooks") t = "address"
        if (t == "BalanceDelta") t = "int256"
        if (t != "") out = out (out == "" ? "" : ",") t
      }
      return out
    }
    END {
      i = index(src, "function " name "(")
      if (i == 0) exit 1
      s = substr(src, i + length("function " name "("))
      args = substr(s, 1, index(s, ")") - 1)
      rest = substr(s, index(s, ")") + 1)
      rest = substr(rest, 1, match(rest, /[;{]/) - 1)
      ret = ""
      j = index(rest, "returns")
      if (j) {
        r = substr(rest, j)
        r = substr(r, index(r, "(") + 1)
        ret = substr(r, 1, index(r, ")") - 1)
      }
      printf "%s(%s)(%s)\n", name, types(args), types(ret)
    }' "$1"
}

# Prints a struct's field types.
fields() {
  tr -d '\r' < "$1" | sed 's://.*$::' | tr -s '[:space:]' ' ' | grep -oE "struct $2 \{[^}]*\}" | sed -E "s/struct $2 \{//; s/\}//" |
    tr ';' '\n' | sed -E 's/^ +//; s/ .*//; s/^(Currency|IHooks)$/address/' | grep -v '^$' | paste -sd, -
}

check() {
  local iface=$1 name=$2 upstream=$3 ours theirs
  checked+=("$name")
  ours=$(sig "$I/$iface" "$name") || { echo "::error::$name not declared in $I/$iface" >&2; status=1; return; }
  theirs=$(sig "$U/$upstream" "$name") || theirs=missing
  if [ "$ours" != "$theirs" ]; then
    echo "::error::$name: $I/$iface has $ours, $upstream has $theirs" >&2
    status=1
  else
    echo "$ours ok ($upstream)"
  fi
}

check_struct() {
  local name=$1 upstream=$2 ours theirs
  ours=$(fields "$I/IPoolManager.sol" "$name")
  theirs=$(fields "$U/$upstream" "$name")
  if [ -z "$ours" ] || [ "$ours" != "$theirs" ]; then
    echo "::error::struct $name: $I/IPoolManager.sol has ($ours), $upstream has ($theirs)" >&2
    status=1
  else
    echo "struct $name ($ours) ok ($upstream)"
  fi
}

check IAlgebraFactory.sol poolByPair algebra/IAlgebraFactory.sol
check IPairFactory.sol isPair hydrex/IPairFactory.sol
check IPoolFactory.sol isPool aero/IPoolFactory.sol
check IPoolFactory.sol isPool aero/slipstream/ICLFactory.sol
check IPoolFactory.sol isPool aerodrome/slipstream/ICLFactory.sol
check IPoolFactory.sol isPool aerodrome/slipstream3/ICLFactory.sol
check IUniswapV2Factory.sol getPair uniswap/v2/IUniswapV2Factory.sol
check IUniswapV3Factory.sol getPool uniswap/v3/IUniswapV3Factory.sol

for name in token0 token1 getReserves getAmountOut swap; do
  check IClassicPool.sol "$name" hydrex/IPair.sol
  check IClassicPool.sol "$name" aero/IPool.sol
done
check IClassicPool.sol getAmountOutWithTotalFee aero/IPool.sol
check IUniswapV2Pair.sol getReserves uniswap/v2/IUniswapV2Pair.sol
check IUniswapV2Pair.sol swap uniswap/v2/IUniswapV2Pair.sol

for name in token0 token1; do
  check IConcentratedPool.sol "$name" aero/slipstream/ICLPoolConstants.sol
  check IConcentratedPool.sol "$name" aerodrome/slipstream/ICLPoolConstants.sol
  check IConcentratedPool.sol "$name" uniswap/v3/IUniswapV3PoolImmutables.sol
done
check IConcentratedPool.sol fee uniswap/v3/IUniswapV3PoolImmutables.sol
check IConcentratedPool.sol swap algebra/IAlgebraPoolActions.sol
check IConcentratedPool.sol swap aero/slipstream/ICLPoolActions.sol
check IConcentratedPool.sol swap aerodrome/slipstream/ICLPoolActions.sol
check IConcentratedPool.sol swap uniswap/v3/IUniswapV3PoolActions.sol

for name in unlock swap sync settle take; do
  check IPoolManager.sol "$name" uniswap/v4/IPoolManager.sol
done
check_struct PoolKey uniswap/v4/PoolKey.sol
check_struct SwapParams uniswap/v4/PoolOperation.sol

check IAlgebraSwapCallback.sol algebraSwapCallback algebra/IAlgebraSwapCallback.sol
check IUniswapV3SwapCallback.sol uniswapV3SwapCallback aero/slipstream/ICLSwapCallback.sol
check IUniswapV3SwapCallback.sol uniswapV3SwapCallback aerodrome/slipstream/ICLSwapCallback.sol
check IUniswapV3SwapCallback.sol uniswapV3SwapCallback uniswap/v3/IUniswapV3SwapCallback.sol
check IUnlockCallback.sol unlockCallback uniswap/v4/IUnlockCallback.sol

declared=$(grep -ohE 'function [A-Za-z0-9_]+\(' "$I"/*.sol | sed -E 's/function |\(//g' | sort -u)
erc20=(balanceOf allowance transfer transferFrom)
unchecked=$(comm -23 <(echo "$declared") <(printf '%s\n' "${checked[@]}" "${erc20[@]}" | sort -u) || true)
if [ -n "$unchecked" ]; then
  echo "::error::not checked against upstream: $unchecked" >&2
  status=1
fi

exit $status
