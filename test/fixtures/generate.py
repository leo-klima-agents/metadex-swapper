#!/usr/bin/env python3
import functools
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

RPC = os.environ["BASE_RPC_URL"]
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fork.json")

USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
WETH = "0x4200000000000000000000000000000000000006"
CBBTC = "0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf"
HYDX = "0x00000e7efa313F4E11Bfff432471eD9423AC6B30"
EURC = "0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42"
NEW_AERO = "0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee"
ETH = "0x0000000000000000000000000000000000000000"
MORPHO = "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb"
HYDX_VE = "0x25B2ED7149fb8A05f6eF9407d9c8F878f59cd1e1"
V4_QUOTER = "0x0d5e0F971ED27FBfF6c2837bf31316121532048D"

EXCHANGES = [
    ("HydrexAlgebra", "0x36077D39cdC65E1e3FB65810430E5b2c4D5fA29E"),
    ("HydrexClassic", "0xC47F17c4fd96F50eFD2A2448ceDe5C185c084bf0"),
    ("AeroVolatile", "0x9bc8b3F60D349d687Fb44A018967025E3741F9a5"),
    ("AeroStable", "0xaEd253F1aD84d99f2165256D701b2b481DD4CC16"),
    ("AeroSlipstream", "0xC6bdE6e9F0CD71013E5FcF2dAAE2fA1c71Bb2F25"),
    ("AerodromeClassic", "0x420DD381b31aEf6683db6B902084cB0FFECe40Da"),
    ("AerodromeSlipstream", "0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A"),
    ("AerodromeSlipstream2", "0xaDe65c38CD4849aDBA595a4323a8C7DdfE89716a"),
    ("AerodromeSlipstream3", "0xf8f2eB4940CFE7d13603DDDD87f123820Fc061Ef"),
    ("UniswapV2", "0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6"),
    ("UniswapV3", "0x33128a8fC17869897dcE68Ed026d694621f6FDfD"),
    ("UniswapV4", "0x498581fF718922c3f8e6A244956aF099B2652b2b"),
]
INDEX = {name: i for i, (name, _) in enumerate(EXCHANGES)}
FACTORY = dict(EXCHANGES)
CONCENTRATED = {"HydrexAlgebra", "AeroSlipstream", "AerodromeSlipstream", "AerodromeSlipstream2"}
CONCENTRATED |= {"AerodromeSlipstream3", "UniswapV3"}
AERO_V3 = {"AeroVolatile", "AeroStable", "AeroSlipstream"}

# Where a pool is found: (factory call, arguments). Uniswap v4 hops are keys: (fee, tick spacing).
LOOKUP = {
    "HydrexAlgebra": ("poolByPair(address,address)", []),
    "HydrexClassic": ("getPair(address,address,bool)", [False]),
    "AeroVolatile": ("getPool(address,address)", []),
    "AeroStable": ("getPool(address,address)", []),
    "AeroSlipstream": ("getPool(address,address,int24)", [100]),
    "AerodromeClassic": ("getPool(address,address,bool)", [False]),
    "AerodromeSlipstream": ("getPool(address,address,int24)", [100]),
    "AerodromeSlipstream2": ("getPool(address,address,int24)", [50]),
    "AerodromeSlipstream3": ("getPool(address,address,int24)", [50]),
    "UniswapV2": ("getPair(address,address)", []),
    "UniswapV3": ("getPool(address,address,uint24)", [500]),
}

# name: (holder, token, amount, [(exchange, token out, (fee, tick spacing) for Uniswap v4)]). Each route goes through the
# swapper that pays out in its last token.
ROUTES = {
    "hydrexAlgebra": (MORPHO, WETH, 10**16, [("HydrexAlgebra", USDC)]),
    "hydrexClassic": (HYDX_VE, HYDX, 10**21, [("HydrexClassic", USDC)]),
    "aeroVolatile": (MORPHO, WETH, 10**17, [("AeroVolatile", USDC)]),
    "aeroStable": (MORPHO, EURC, 10**8, [("AeroStable", USDC)]),
    "aeroSlipstream": (MORPHO, WETH, 10**17, [("AeroSlipstream", USDC)]),
    "aerodromeClassic": (MORPHO, WETH, 10**17, [("AerodromeClassic", USDC)]),
    "aerodromeSlipstream": (MORPHO, WETH, 10**17, [("AerodromeSlipstream", USDC)]),
    "aerodromeSlipstream2": (MORPHO, WETH, 10**16, [("AerodromeSlipstream2", USDC)]),
    "aerodromeSlipstream3": (MORPHO, WETH, 10**17, [("AerodromeSlipstream3", USDC)]),
    "uniswapV2": (MORPHO, WETH, 10**17, [("UniswapV2", USDC)]),
    "uniswapV3": (MORPHO, WETH, 10**17, [("UniswapV3", USDC)]),
    "uniswapV4": (MORPHO, WETH, 10**17, [("UniswapV4", USDC, (3000, 60))]),
    "uniswapV4Native": (MORPHO, CBBTC, 10**5, [("UniswapV4", ETH, (500, 10)), ("UniswapV4", USDC, (3000, 60))]),
    "hydxThroughWeth": (HYDX_VE, HYDX, 10**21, [("HydrexAlgebra", WETH), ("UniswapV3", USDC)]),
    "usdcToWeth": (MORPHO, USDC, 10**8, [("UniswapV3", WETH)]),
    "cbBtcToWeth": (MORPHO, CBBTC, 10**5, [("AerodromeSlipstream", WETH)]),
    "wethToCbBtc": (MORPHO, WETH, 10**17, [("UniswapV3", CBBTC)]),
    "usdcToCbBtc": (MORPHO, USDC, 10**8, [("AerodromeSlipstream", CBBTC)]),
    "wethToHydx": (MORPHO, WETH, 10**16, [("HydrexAlgebra", HYDX)]),
    "usdcToHydx": (MORPHO, USDC, 10**7, [("HydrexClassic", HYDX)]),
    "wethToAero": (MORPHO, WETH, 10**17, [("AeroVolatile", NEW_AERO)]),
    # For gas: three hops through the cheapest exchange, and through the dearest.
    "gasCheapest": (MORPHO, WETH, 10**12, [("UniswapV2", CBBTC), ("UniswapV2", WETH), ("UniswapV2", USDC)]),
    "gasDearest": (MORPHO, WETH, 10**12, [("HydrexAlgebra", CBBTC), ("HydrexAlgebra", WETH), ("HydrexAlgebra", USDC)]),
}

MIN_SQRT_RATIO = 4295128739
MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342
# Called back by a concentrated pool, it reverts with the two amounts: the pool's own quote.
PROBE = "0x00000000000000000000000000000000000c0de1"
PROBE_CODE = "0x6040600460003760406000fd"


def rpc(method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    for attempt in range(6):
        try:
            req = urllib.request.Request(RPC, body, {"content-type": "application/json"})
            res = json.load(urllib.request.urlopen(req, timeout=60))
            if "limit" not in res.get("error", {}).get("message", ""):
                return res
            failure = res
        except urllib.error.HTTPError as e:
            if e.code != 429 and e.code < 500:
                raise
            failure = e
        except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
            failure = e
        time.sleep(2**attempt)
    raise RuntimeError(failure)


@functools.cache
def calldata(signature, *args):
    return subprocess.check_output(["cast", "calldata", signature, *[str(a).lower() for a in args]], text=True).strip()


def call(block, to, signature, *args, overrides=None, sender=None):
    tx = {"to": to, "data": calldata(signature, *args)}
    if sender:
        tx["from"] = sender
    params = [tx, hex(block)] + ([overrides] if overrides else [])
    return rpc("eth_call", params)


def words(res):
    if "error" in res:
        raise RuntimeError(res["error"])
    r = res["result"][2:]
    return [int(r[64 * k : 64 * (k + 1)], 16) for k in range(len(r) // 64)]


def signed(n):
    return n - (1 << 256) if n >> 255 else n


def addr(n):
    return "0x" + format(n, "040x")


def pool_of(block, exchange, token_in, token_out):
    signature, extra = LOOKUP[exchange]
    pool = addr(words(call(block, FACTORY[exchange], signature, token_in, token_out, *extra))[0])
    return pool if int(pool, 16) else ETH


def has_liquidity(block, exchange, pool):
    if pool == ETH:
        return False
    if exchange in CONCENTRATED:
        return words(call(block, pool, "liquidity()"))[0] > 0
    return min(words(call(block, pool, "getReserves()"))[:2]) > 0


def quote_hop(block, exchange, pool, token_in, token_out, amount):
    zero_for_one = int(token_in, 16) < int(token_out, 16)
    if exchange in CONCENTRATED:
        limit = MIN_SQRT_RATIO + 1 if zero_for_one else MAX_SQRT_RATIO - 1
        data = ("swap(address,bool,int256,uint160,bytes)", PROBE, zero_for_one, amount, limit, "0x")
        res = call(block, pool, *data, overrides={PROBE: {"code": PROBE_CODE}}, sender=PROBE)
        delta = res["error"]["data"]
        out = signed(int(delta[66:130] if zero_for_one else delta[2:66], 16))
        return -out
    if exchange == "UniswapV2":
        r0, r1, _ = words(call(block, pool, "getReserves()"))
        r_in, r_out = (r0, r1) if zero_for_one else (r1, r0)
        return amount * 997 * r_out // (r_in * 1000 + amount * 997)
    signature = "getAmountOutWithTotalFee" if exchange in AERO_V3 else "getAmountOut"
    out = words(call(block, pool, signature + "(uint256,address)", amount, token_in))[0]
    # The swapper asks Hydrex's pairs for one wei less than they quote.
    return out - 1 if exchange == "HydrexClassic" and out else out


def quote_v4(block, token_in, amount, hops):
    path = ",".join(f"({out},{fee},{spacing},{ETH},0x)" for _, out, (fee, spacing) in hops)
    signature = "quoteExactInput((address,(address,uint24,int24,address,bytes)[],uint128))"
    return words(call(block, V4_QUOTER, signature, f"({token_in},[{path}],{amount})"))[0]


def main():
    latest = int(rpc("eth_blockNumber", [])["result"], 16)
    block = int(sys.argv[1]) if len(sys.argv) > 1 else latest - 2

    routes = {}
    for name, (holder, token, amount, hops) in ROUTES.items():
        balance = words(call(block, token, "balanceOf(address)", holder))[0]
        assert balance >= 20 * amount, f"{name}: holder has too little"
        pools, quote, token_in, created = [], amount, token, False
        v4 = [h for h in hops if h[0] == "UniswapV4"]
        if v4:
            assert len(v4) == len(hops)
            pools = [ETH] * len(hops)
            quote = quote_v4(block, token, amount, hops)
        else:
            for exchange, token_out in hops:
                pool = pool_of(block, exchange, token_in, token_out)
                if not has_liquidity(block, exchange, pool):
                    # Aero's pools are new: the fork test creates its own.
                    assert exchange in AERO_V3 and len(hops) == 1, f"{name}: no pool"
                    pools.append(ETH)
                    created = True
                    break
                pools.append(pool)
                quote = quote_hop(block, exchange, pool, token_in, token_out, quote)
                token_in = token_out
        routes[name] = {
            "holder": holder,
            "token": token,
            "amount": str(amount),
            "exchanges": [INDEX[h[0]] for h in hops],
            "pools": pools,
            "tokensOut": [h[1] for h in hops],
            "fees": [h[2][0] if len(h) > 2 else 0 for h in hops],
            "tickSpacings": [h[2][1] if len(h) > 2 else 0 for h in hops],
            "quote": "0" if created else str(quote),
        }
        print(f"{name}: {routes[name]['quote']}")

    with open(OUT, "w") as f:
        json.dump({"block": block, "routes": routes}, f, indent=2)
        f.write("\n")
    print(f"wrote {OUT} at block {block}")


if __name__ == "__main__":
    main()
