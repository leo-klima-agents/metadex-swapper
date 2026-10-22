#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

U=test/upstream
I=src/interfaces
status=0
checked=()

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
      head = j ? substr(rest, 1, j - 1) : rest
      m = "nonpayable"
      if (head ~ /(^|[ \t])view([ \t]|$)/) m = "view"
      else if (head ~ /(^|[ \t])pure([ \t]|$)/) m = "pure"
      else if (head ~ /(^|[ \t])payable([ \t]|$)/) m = "payable"
      printf "%s(%s)(%s) %s\n", name, types(args), types(ret), m
    }' "$1"
}

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
  ours=$(fields "$I/IPoolManager.sol" "$name") || true
  theirs=$(fields "$U/$upstream" "$name") || true
  if [ -z "$ours" ] || [ "$ours" != "$theirs" ]; then
    echo "::error::struct $name: $I/IPoolManager.sol has ($ours), $upstream has ($theirs)" >&2
    status=1
  else
    echo "struct $name ($ours) ok ($upstream)"
  fi
}

check IPoolFactory.sol isPool aero/IPoolFactory.sol
check IPoolFactory.sol isPool aero/slipstream/ICLFactory.sol
check IPoolFactory.sol isPool aero-lite/IPoolFactory.sol
check IPoolFactory.sol isPool aero-lite/slipstream/ICLFactory.sol
check IUniswapV2Factory.sol getPair uniswap/v2/IUniswapV2Factory.sol
check IUniswapV3Factory.sol getPool uniswap/v3/IUniswapV3Factory.sol
check IPairFactory.sol isPair hydrex/IPairFactory.sol
check IAlgebraFactory.sol poolByPair algebra/IAlgebraFactory.sol

for name in token0 token1 getReserves getAmountOut swap; do
  check IClassicPool.sol "$name" aero/IPool.sol
  check IClassicPool.sol "$name" aero-lite/IPool.sol
  check IClassicPool.sol "$name" hydrex/IPair.sol
done
check IClassicPool.sol getAmountOutWithTotalFee aero/IPool.sol
check IClassicPool.sol getAmountOutWithTotalFee aero-lite/IPool.sol
check IClassicPool.sol sync aero/IPool.sol
check IClassicPool.sol sync aero-lite/IPool.sol
check IClassicPool.sol sync uniswap/v2/IUniswapV2Pair.sol
check IClassicPool.sol swap uniswap/v2/IUniswapV2Pair.sol
check IClassicPool.sol sync hydrex/Pair.sol
# Uniswap v2's getReserves returns smaller types, but each fills a whole word, so IClassicPool reads them as uint256.
v2=$(sig "$U/uniswap/v2/IUniswapV2Pair.sol" getReserves) || v2=missing
if [ "$v2" != "getReserves()(uint112,uint112,uint32) view" ]; then
  echo "::error::uniswap/v2/IUniswapV2Pair.sol has $v2" >&2
  status=1
else
  echo "$v2 ok (uniswap/v2/IUniswapV2Pair.sol, read as uint256)"
fi

for name in token0 token1; do
  check IClassicPool.sol "$name" aero/slipstream/ICLPoolConstants.sol
  check IClassicPool.sol "$name" aero-lite/slipstream/ICLPoolConstants.sol
done
check IConcentratedPool.sol swap aero/slipstream/ICLPoolActions.sol
check IConcentratedPool.sol swap aero-lite/slipstream/ICLPoolActions.sol
check IConcentratedPool.sol swap uniswap/v3/IUniswapV3PoolActions.sol
check IConcentratedPool.sol swap algebra/IAlgebraPoolActions.sol

for name in unlock swap sync settle take; do
  check IPoolManager.sol "$name" uniswap/v4/IPoolManager.sol
done
check_struct PoolKey uniswap/v4/PoolKey.sol
check_struct SwapParams uniswap/v4/PoolOperation.sol

check IUniswapV3SwapCallback.sol uniswapV3SwapCallback aero/slipstream/ICLSwapCallback.sol
check IUniswapV3SwapCallback.sol uniswapV3SwapCallback aero-lite/slipstream/ICLSwapCallback.sol
check IUniswapV3SwapCallback.sol uniswapV3SwapCallback uniswap/v3/IUniswapV3SwapCallback.sol
check IUnlockCallback.sol unlockCallback uniswap/v4/IUnlockCallback.sol
check IAlgebraSwapCallback.sol algebraSwapCallback algebra/IAlgebraSwapCallback.sol

declared=$(grep -ohE 'function [A-Za-z0-9_]+\(' "$I"/*.sol | sed -E 's/function |\(//g' | sort -u)
erc20=(balanceOf allowance transfer transferFrom)
unchecked=$(comm -23 <(echo "$declared") <(printf '%s\n' "${checked[@]}" "${erc20[@]}" | sort -u) || true)
if [ -n "$unchecked" ]; then
  echo "::error::not checked against upstream: $unchecked" >&2
  status=1
fi

exit $status
