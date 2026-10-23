#!/usr/bin/env python3
"""Writes test/fixtures/<chain>.json: each route's pools at a block, and their own quote.

Usage: test/fixtures/generate.py <chain> [block]. Needs the chain's RPC in its variable, below, and `cast`.
Each chain's exchanges come from verification/bytecode-hashes.json, so a hop names its exchange by kind, and by
which one of that kind when a chain lists several, in the order Deploy.s.sol lists them.
"""
import functools
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
HASHES = os.path.join(HERE, "..", "..", "verification", "bytecode-hashes.json")
ETH = "0x0000000000000000000000000000000000000000"
CONCENTRATED = {"AeroSlipstream", "UniswapV3", "HydrexAlgebra"}
# A swap callback that reverts with the two amounts the pool passes it, which are the pool's own quote.
PROBE = "0x00000000000000000000000000000000000c0de1"
PROBE_CODE = "0x6040600460003760406000fd"
MIN_SQRT_RATIO = 4295128739
MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342


def hop(kind, out, n=0, fee=0, spacing=0, seed=None, seeded=False):
    """A hop through the n-th exchange of a kind. `seed` (amount in, amount out) makes the test add that much to the
    pool, and create it if missing; `seeded` marks a pool the test fills itself."""
    return {"kind": kind, "n": n, "out": out, "fee": fee, "spacing": spacing, "seed": seed, "seeded": seeded}


E = {
    "WETH": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    "USDC": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    "EURC": "0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c",
    "cirBTC": "0x72DFB2E44f59C5AD2bAFE84314E5b99a7cd5075E",
    "cbBTC": "0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf",
    "USDT": "0xdAC17F958D2ee523a2206206994597C13D831ec7",
}
B = {
    "WETH": "0x4200000000000000000000000000000000000006",
    "USDC": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    "EURC": "0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42",
    "cbBTC": "0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf",
    "AERO": "0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee",
    "HYDX": "0x00000e7efa313F4E11Bfff432471eD9423AC6B30",
}
MORPHO = "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb"
HYDX_VE = "0x25B2ED7149fb8A05f6eF9407d9c8F878f59cd1e1"
O = {
    "WETH": "0x4200000000000000000000000000000000000006",
    "USDC": "0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85",
    "USDT": "0x94b008aA00579c1307B0EF2c499aD98a8ce58e58",
}
A = {
    "WETH": "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1",
    "USDC": "0xaf88d065e77c8cC2239327C5EDb3A432268e5831",
    "cbBTC": "0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf",
    "USDT0": "0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9",
}
C = {
    "WETH": "0x128cC466B61f542da60c70e3aA11c10e19B84EDB",
    "USDC": "0x3600000000000000000000000000000000000000",
    "EURC": "0xbEf5f6d51CB62b58e6A8f77868681825C6fe21c1",
    "cirBTC": "0x171A4217b86A807A64eB94757Db6849fb4bDbAA0",
}

# Each route: (holder, token, amount, hops). Without a holder, the test funds one of its own.
CHAINS = {
    "ethereum": {
        "rpc": "ETHEREUM_RPC_URL",
        "quoter": "0x99bd42B2B22e531f283b7F8a86dFf631EB16A9D1",
        "routes": {
            "aeroVolatile": (
                None, E["WETH"], 10**17, [hop("AeroClassic", E["USDC"], seed=(100 * 10**18, 300_000 * 10**6))]
            ),
            "aeroStable": (
                None, E["USDT"], 10**8, [hop("AeroClassic", E["USDC"], n=1, seed=(100_000 * 10**6, 100_000 * 10**6))]
            ),
            "aeroSlipstream": (None, E["WETH"], 10**17, [hop("AeroSlipstream", E["USDC"], spacing=50)]),
            "uniswapV2": (None, E["WETH"], 10**17, [hop("UniswapV2", E["USDC"])]),
            "uniswapV3": (None, E["WETH"], 10**17, [hop("UniswapV3", E["USDC"], fee=500)]),
            "uniswapV4": (None, E["WETH"], 10**17, [hop("UniswapV4", E["USDC"], fee=500, spacing=10)]),
            "uniswapV4Native": (
                None,
                E["cbBTC"],
                10**5,
                [hop("UniswapV4", ETH, fee=3000, spacing=60), hop("UniswapV4", E["USDC"], fee=500, spacing=10)],
            ),
            "usdcToWeth": (None, E["USDC"], 10**8, [hop("UniswapV3", E["WETH"], fee=500)]),
            "usdcToEurc": (None, E["USDC"], 10**8, [hop("UniswapV3", E["EURC"], fee=500)]),
            "wethToCirBtc": (None, E["WETH"], 10**17, [hop("UniswapV3", E["cirBTC"], fee=100)]),
            "wethToCbBtc": (None, E["WETH"], 10**17, [hop("UniswapV3", E["cbBTC"], fee=3000)]),
        },
    },
    "base": {
        "rpc": "BASE_RPC_URL",
        "quoter": "0xE1A6C5803e3c44368b171BD680c7D32dfc92CA47",
        "routes": {
            "aeroVolatile": (
                MORPHO, B["WETH"], 10**17, [hop("AeroClassic", B["USDC"], seed=(100 * 10**18, 244_737_355_000))]
            ),
            "aeroStable": (
                MORPHO, B["EURC"], 10**8, [hop("AeroClassic", B["USDC"], n=1, seed=(100_000 * 10**6, 100_000 * 10**6))]
            ),
            "aeroSlipstream": (MORPHO, B["WETH"], 10**17, [hop("AeroSlipstream", B["USDC"], spacing=100, seeded=True)]),
            "uniswapV2": (MORPHO, B["WETH"], 10**17, [hop("UniswapV2", B["USDC"])]),
            "uniswapV3": (MORPHO, B["WETH"], 10**17, [hop("UniswapV3", B["USDC"], fee=500)]),
            "uniswapV4": (MORPHO, B["WETH"], 10**17, [hop("UniswapV4", B["USDC"], fee=3000, spacing=60)]),
            "uniswapV4Native": (
                MORPHO,
                B["cbBTC"],
                10**5,
                [hop("UniswapV4", ETH, fee=500, spacing=10), hop("UniswapV4", B["USDC"], fee=3000, spacing=60)],
            ),
            "hydrexClassic": (HYDX_VE, B["HYDX"], 10**21, [hop("HydrexClassic", B["USDC"])]),
            "hydrexAlgebra": (MORPHO, B["WETH"], 10**16, [hop("HydrexAlgebra", B["USDC"])]),
            "hydxThroughWeth": (
                HYDX_VE, B["HYDX"], 10**21, [hop("HydrexAlgebra", B["WETH"]), hop("UniswapV3", B["USDC"], fee=500)]
            ),
            "usdcToWeth": (MORPHO, B["USDC"], 10**8, [hop("UniswapV3", B["WETH"], fee=500)]),
            "cbBtcToWeth": (MORPHO, B["cbBTC"], 10**5, [hop("UniswapV3", B["WETH"], fee=500)]),
            "wethToEurc": (MORPHO, B["WETH"], 10**16, [hop("HydrexAlgebra", B["EURC"])]),
            "usdcToEurc": (MORPHO, B["USDC"], 10**7, [hop("UniswapV3", B["EURC"], fee=500)]),
            "wethToCbBtc": (MORPHO, B["WETH"], 10**17, [hop("UniswapV3", B["cbBTC"], fee=500)]),
            "usdcToCbBtc": (MORPHO, B["USDC"], 10**8, [hop("UniswapV2", B["cbBTC"])]),
            "wethToAero": (
                MORPHO, B["WETH"], 10**17, [hop("AeroClassic", B["AERO"], seed=(100 * 10**18, 296_000 * 10**18))]
            ),
            "wethToHydx": (MORPHO, B["WETH"], 10**16, [hop("HydrexAlgebra", B["HYDX"])]),
            "usdcToHydx": (MORPHO, B["USDC"], 10**7, [hop("HydrexClassic", B["HYDX"])]),
            "gasCheapest": (
                MORPHO,
                B["WETH"],
                10**12,
                [hop("UniswapV2", B["cbBTC"]), hop("UniswapV2", B["WETH"]), hop("UniswapV2", B["USDC"])],
            ),
            "gasDearest": (
                MORPHO,
                B["WETH"],
                10**12,
                [hop("HydrexAlgebra", B["cbBTC"]), hop("HydrexAlgebra", B["WETH"]), hop("HydrexAlgebra", B["USDC"])],
            ),
        },
    },
    "optimism": {
        "rpc": "OPTIMISM_RPC_URL",
        "quoter": "0xd673F731EDFe5AaF1bDa7FD43D13Bbb5150B87Ca",
        "routes": {
            "aeroVolatile": (
                None, O["WETH"], 10**17, [hop("AeroClassic", O["USDC"], seed=(100 * 10**18, 300_000 * 10**6))]
            ),
            "aeroStable": (
                None, O["USDT"], 10**8, [hop("AeroClassic", O["USDC"], n=1, seed=(100_000 * 10**6, 100_000 * 10**6))]
            ),
            "aeroSlipstream": (None, O["WETH"], 10**17, [hop("AeroSlipstream", O["USDC"], spacing=100)]),
            "uniswapV2": (None, O["WETH"], 10**15, [hop("UniswapV2", O["USDC"])]),
            "uniswapV3": (None, O["WETH"], 10**17, [hop("UniswapV3", O["USDC"], fee=3000)]),
            "uniswapV4": (None, O["WETH"], 10**14, [hop("UniswapV4", O["USDC"], fee=500, spacing=10)]),
            "usdcToWeth": (None, O["USDC"], 10**8, [hop("UniswapV3", O["WETH"], fee=3000)]),
        },
    },
    "arbitrum": {
        "rpc": "ARBITRUM_RPC_URL",
        "quoter": "0x8928074CA1b241D8Ec02815881c1Af11E8bC5219",
        "routes": {
            "aeroVolatile": (
                None, A["WETH"], 10**17, [hop("AeroClassic", A["USDC"], seed=(100 * 10**18, 300_000 * 10**6))]
            ),
            "aeroStable": (
                None, A["USDT0"], 10**8, [hop("AeroClassic", A["USDC"], n=1, seed=(100_000 * 10**6, 100_000 * 10**6))]
            ),
            "aeroSlipstream": (None, A["WETH"], 10**17, [hop("AeroSlipstream", A["USDC"], spacing=100)]),
            "uniswapV2": (None, A["WETH"], 10**17, [hop("UniswapV2", A["USDC"])]),
            "uniswapV3": (None, A["WETH"], 10**17, [hop("UniswapV3", A["USDC"], fee=500)]),
            "uniswapV4": (None, A["WETH"], 10**17, [hop("UniswapV4", A["USDC"], fee=500, spacing=10)]),
            "usdcToWeth": (None, A["USDC"], 10**8, [hop("UniswapV3", A["WETH"], fee=500)]),
            "wethToCbBtc": (None, A["WETH"], 10**16, [hop("UniswapV3", A["cbBTC"], fee=3000)]),
        },
    },
    "arc": {
        "rpc": "ARC_RPC_URL",
        "quoter": "0x8Dc178eFB8111BB0973Dd9d722ebeFF267c98F94",
        "routes": {
            "aeroVolatile": (
                None, C["cirBTC"], 10**6, [hop("AeroClassic", C["USDC"], seed=(10**8, 100_000 * 10**6))]
            ),
            "aeroStable": (
                None, C["EURC"], 10**8, [hop("AeroClassic", C["USDC"], n=1, seed=(100_000 * 10**6, 100_000 * 10**6))]
            ),
            "aeroSlipstream": (None, C["EURC"], 10**8, [hop("AeroSlipstream", C["USDC"], spacing=1)]),
            "uniswapV2": (
                None, C["EURC"], 10**8, [hop("UniswapV2", C["USDC"], seed=(10_000 * 10**6, 11_000 * 10**6))]
            ),
            "uniswapV3": (None, C["EURC"], 10**8, [hop("UniswapV3", C["USDC"], fee=500)]),
            "uniswapV4": (None, C["EURC"], 10**7, [hop("UniswapV4", C["USDC"], fee=500, spacing=10)]),
            "usdcToWeth": (None, C["USDC"], 10**8, [hop("AeroSlipstream", C["WETH"], spacing=50)]),
            "usdcToEurc": (None, C["USDC"], 10**8, [hop("AeroSlipstream", C["EURC"], spacing=1)]),
            "usdcToCirBtc": (None, C["USDC"], 10**7, [hop("UniswapV3", C["cirBTC"], fee=100)]),
        },
    },
}

LOOKUP = {
    "AeroClassic": ("getPool(address,address)", lambda h: []),
    "AeroSlipstream": ("getPool(address,address,int24)", lambda h: [h["spacing"]]),
    "UniswapV2": ("getPair(address,address)", lambda h: []),
    "UniswapV3": ("getPool(address,address,uint24)", lambda h: [h["fee"]]),
    "HydrexClassic": ("getPair(address,address,bool)", lambda h: [False]),
    "HydrexAlgebra": ("poolByPair(address,address)", lambda h: []),
}


def rpc(url, method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    for attempt in range(6):
        try:
            headers = {"content-type": "application/json", "user-agent": "metadex-swapper-fixtures"}
            req = urllib.request.Request(url, body, headers)
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


def words(res):
    if "error" in res:
        raise RuntimeError(res["error"])
    r = res["result"][2:]
    return [int(r[64 * k : 64 * (k + 1)], 16) for k in range(len(r) // 64)]


def signed(n):
    return n - (1 << 256) if n >> 255 else n


def addr(n):
    return "0x" + format(n, "040x")


class Chain:
    def __init__(self, name, block):
        self.name = name
        self.spec = CHAINS[name]
        self.url = os.environ[self.spec["rpc"]]
        exchanges = json.load(open(HASHES))["chains"][name]
        self.exchanges = list(zip(exchanges["kinds"], exchanges["factories"]))
        latest = int(rpc(self.url, "eth_blockNumber", [])["result"], 16)
        self.block = block if block is not None else latest - 5

    def call(self, to, signature, *args, overrides=None, sender=None):
        tx = {"to": to, "data": calldata(signature, *args)}
        if sender:
            tx["from"] = sender
        return rpc(self.url, "eth_call", [tx, hex(self.block)] + ([overrides] if overrides else []))

    def factory(self, h):
        of_kind = [f for k, f in self.exchanges if k == h["kind"]]
        return of_kind[h["n"]]

    def pool_of(self, h, token_in):
        if h["kind"] == "UniswapV4":
            return ETH
        signature, extra = LOOKUP[h["kind"]]
        pool = addr(words(self.call(self.factory(h), signature, token_in, h["out"], *extra(h)))[0])
        return pool if int(pool, 16) else ETH

    def has_liquidity(self, h, pool):
        if pool == ETH:
            return False
        if h["kind"] in CONCENTRATED:
            return words(self.call(pool, "liquidity()"))[0] > 0
        return min(words(self.call(pool, "getReserves()"))[:2]) > 0

    def quote_hop(self, h, pool, token_in, amount):
        token_out = h["out"]
        zero_for_one = int(token_in, 16) < int(token_out, 16)
        if h["kind"] in CONCENTRATED:
            limit = MIN_SQRT_RATIO + 1 if zero_for_one else MAX_SQRT_RATIO - 1
            data = ("swap(address,bool,int256,uint160,bytes)", PROBE, zero_for_one, amount, limit, "0x")
            res = self.call(pool, *data, overrides={PROBE: {"code": PROBE_CODE}}, sender=PROBE)
            delta = res["error"]["data"]
            return -signed(int(delta[66:130] if zero_for_one else delta[2:66], 16))
        if h["kind"] == "UniswapV2":
            r0, r1, _ = words(self.call(pool, "getReserves()"))
            r_in, r_out = (r0, r1) if zero_for_one else (r1, r0)
            return amount * 997 * r_out // (r_in * 1000 + amount * 997)
        signature = "getAmountOutWithTotalFee" if h["kind"] == "AeroClassic" else "getAmountOut"
        out = words(self.call(pool, signature + "(uint256,address)", amount, token_in))[0]
        return out - 1 if h["kind"] == "HydrexClassic" and out else out

    def quote_v4(self, token_in, amount, hops):
        path = ",".join(f"({h['out']},{h['fee']},{h['spacing']},{ETH},0x)" for h in hops)
        signature = "quoteExactInput((address,(address,uint24,int24,address,bytes)[],uint128))"
        return words(self.call(self.spec["quoter"], signature, f"({token_in},[{path}],{amount})"))[0]

    def route(self, name, holder, token, amount, hops):
        if holder:
            balance = words(self.call(token, "balanceOf(address)", holder))[0]
            assert balance >= 20 * amount, f"{name}: holder has too little"
        pools, quote, token_in, seeded = [], amount, token, False
        if any(h["kind"] == "UniswapV4" for h in hops):
            assert all(h["kind"] == "UniswapV4" for h in hops), f"{name}: mixes Uniswap v4 with other hops"
            pools = [ETH] * len(hops)
            quote = self.quote_v4(token, amount, hops)
        else:
            for h in hops:
                pool = self.pool_of(h, token_in)
                pools.append(pool)
                if h["seed"] or h["seeded"]:
                    assert len(hops) == 1, f"{name}: a seeded pool must be the route's only hop"
                    seeded = True
                    break
                assert self.has_liquidity(h, pool), f"{name}: no pool with liquidity"
                quote = self.quote_hop(h, pool, token_in, quote)
                token_in = h["out"]
        route = {
            "token": token,
            "amount": str(amount),
            "factories": [self.factory(h) for h in hops],
            "pools": pools,
            "tokensOut": [h["out"] for h in hops],
            "fees": [h["fee"] for h in hops],
            "tickSpacings": [h["spacing"] for h in hops],
            "seedsIn": [str(h["seed"][0]) if h["seed"] else "0" for h in hops],
            "seedsOut": [str(h["seed"][1]) if h["seed"] else "0" for h in hops],
            "quote": "0" if seeded else str(quote),
        }
        if holder:
            route = {"holder": holder, **route}
        return route


def main():
    name = sys.argv[1]
    chain = Chain(name, int(sys.argv[2]) if len(sys.argv) > 2 else None)
    routes = {}
    for route_name, (holder, token, amount, hops) in chain.spec["routes"].items():
        routes[route_name] = chain.route(route_name, holder, token, amount, hops)
        print(f"{name} {route_name}: {routes[route_name]['quote']}")
    out = os.path.join(HERE, f"{name}.json")
    with open(out, "w") as f:
        json.dump({"block": chain.block, "routes": routes}, f, indent=2)
        f.write("\n")
    print(f"wrote {out} at block {chain.block}")


if __name__ == "__main__":
    main()
