# metadex-swapper

`ImmutableSwapper` is a contract on Base that swaps the tokens a holder picks to USDC in one call: small balances left
in a wallet, or rewards paid in many tokens. It swaps through the pools of four exchanges: Hydrex, Aero, Aerodrome and
Uniswap. The caller picks the exchange and the pool of every hop, and the contract checks each pick against that
exchange's own factory. It sends 1% of the USDC to a fixed treasury.

The contract has no owner, no settings and no upgrade path. All of it is in
[`src/ImmutableSwapper.sol`](src/ImmutableSwapper.sol). It is not deployed yet. Deployed as described under
[Deployment](#deployment), it will be at `0xC61940460A1a0383f23985ffa50c4D00Cab25913`.

## How it works

### Swapping

`swap(routes, deadline, skipFailed)` takes 1 to 20 routes (`MAX_ROUTES`). Each route sells one token for USDC, in 1 to
3 hops (`MAX_HOPS`):

```solidity
struct Hop {
    Exchange exchange; // picked by the caller
    address pool; // zero for Uniswap v4
    address tokenOut; // the last hop's is USDC; zero is native ETH, between two Uniswap v4 hops only
    uint24 fee; // Uniswap v4 only
    int24 tickSpacing; // Uniswap v4 only
}

struct Route {
    address token; // never USDC, never native ETH
    uint256 amount; // type(uint256).max: the caller's balance, up to the allowance given
    uint256 minPaid; // the least USDC this route must pay the caller, after the fee
    Hop[] hops;
}
```

For each route, the swapper:

1. checks the path: only the last hop ends in USDC, and each hop's pool belongs to the exchange the hop names;
2. pulls the token from the caller with `transferFrom`, and counts what arrived;
3. swaps hop by hop, and counts each hop's output by the change in its own balance;
4. takes 1% of the USDC, rounded down, and reverts unless the rest is at least `minPaid`.

Each route runs in a call of its own, so a route that fails undoes everything it did, including the pull of its token.
With `skipFailed`, the route is skipped and reported in a `RouteFailed` event, and its token stays with the caller.
Without it, the whole call reverts with the route's reason. After the last route, the swapper sends the fees to the
treasury and the rest to the caller, and emits `Swapped`. It reverts after `deadline`.

The contract never picks a route, and it never pays anyone but the caller and the treasury. It only pulls tokens from
the caller, so nobody's approval can be used by anyone else.

### Quoting

`quote(routes)` runs the same checks and swaps, and returns what `swap` would. Call it with `eth_call`: it moves
nothing, and needs no allowance. With `type(uint256).max`, it quotes the caller's whole balance. A route that fails
comes back with `done` false and its reason.

Each route is quoted against the pools as they are. So two routes through the same pool both get the first one's
price, and a token that charges a fee on transfers is quoted as if it didn't. Each route's minimum covers this.

### The exchanges

Twelve kinds of pool, from four exchanges, fixed at deployment. For Aero and Aerodrome, they are every pool factory
that their registries list.

| `Exchange` | Factory, or manager | A pool belongs to it when |
| --- | --- | --- |
| `HydrexAlgebra` | Algebra Integral, `0x36077D39cdC65E1e3FB65810430E5b2c4D5fA29E` | `poolByPair(a, b) == pool` |
| `HydrexClassic` | Pair factory, `0xC47F17c4fd96F50eFD2A2448ceDe5C185c084bf0` | `isPair(pool)`, and its tokens are the hop's |
| `AeroVolatile` | `0x9bc8b3F60D349d687Fb44A018967025E3741F9a5` | `isPool(pool)`, and its tokens are the hop's |
| `AeroStable` | `0xaEd253F1aD84d99f2165256D701b2b481DD4CC16` | `isPool(pool)`, and its tokens are the hop's |
| `AeroSlipstream` | `CLFactory`, `0xC6bdE6e9F0CD71013E5FcF2dAAE2fA1c71Bb2F25` | `isPool(pool)`, and its tokens are the hop's |
| `AerodromeClassic` | `PoolFactory`, `0x420DD381b31aEf6683db6B902084cB0FFECe40Da` | `isPool(pool)`, and its tokens are the hop's |
| `AerodromeSlipstream` | `CLFactory`, `0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A` | `isPool(pool)`, and its tokens are the hop's |
| `AerodromeSlipstream2` | `CLFactory`, `0xaDe65c38CD4849aDBA595a4323a8C7DdfE89716a` | `isPool(pool)`, and its tokens are the hop's |
| `AerodromeSlipstream3` | `CLFactory`, `0xf8f2eB4940CFE7d13603DDDD87f123820Fc061Ef` | `isPool(pool)`, and its tokens are the hop's |
| `UniswapV2` | `UniswapV2Factory`, `0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6` | `getPair(a, b) == pool` |
| `UniswapV3` | `UniswapV3Factory`, `0x33128a8fC17869897dcE68Ed026d694621f6FDfD` | `getPool(a, b, pool.fee()) == pool` |
| `UniswapV4` | `PoolManager`, `0x498581fF718922c3f8e6A244956aF099B2652b2b` | the key of the hop's tokens, `fee` and `tickSpacing`, with no hooks |

`exchanges()` returns these addresses, in this order. The swapper pays each kind of pool its own way:

- **Algebra, Slipstream and Uniswap v3 pools** send their output, then call the swapper back to be paid. The swapper
  pays only the pool it is swapping through, only during that swap, only once, and only exactly the hop's amount of the
  hop's token. A pool that takes less than the whole amount, a partial fill, reverts the route.
- **Hydrex's pairs, Aero's and Aerodrome's classic pools, and Uniswap v2's pairs** are sent the input first. The
  swapper counts what the pool received, prices it with the pool's `getAmountOut`, Aero's `getAmountOutWithTotalFee`,
  or Uniswap v2's 0.3% formula, and asks for that much.
- **Uniswap v4:** consecutive hops run in one `unlock`. Each must take exactly the whole amount. Then the swapper pays
  the first token and takes the last. Native ETH can only pass between two such hops, so it never leaves the manager.

Uniswap v4 hops name no pool: the swapper builds every key with no hooks. Hooks run inside every swap and can do
anything there, so tokens that trade only in pools with hooks, as many launchpad tokens do, are out of reach.

## What each exchange's admins can change

| Exchange | Held by | What it can change in a swap |
| --- | --- | --- |
| Hydrex | `0x74266f2b206D1359B83fc74949EF07176FB3AE03`, a single key, owns the Algebra factory. A one-day timelock, `0xdF52b5A03E3F5a4178E4F63e8BC51abE691B898F`, owns the pair factory's proxy admin. A 2-of-4 Safe, `0x1aE3753d9b60743A89159CcFF8E251C60B560311`, manages the pairs' fees. The plugins have their own admins. | Fees: the pairs', up to 2.5%. The pair factory's code, and the plugins' code. Not fully checked. |
| Aero | A 3-of-7 Safe, `0x42255e3C2d0b71a0b006243148fdF1a71d054cE0` | Pause classic pools. Their fee, up to 20% with the MEV tax. The Slipstream pools' swap hook and its fee, capped at 10%. Discounts for chosen callers. |
| Aerodrome | A 3-of-7 Safe, `0xE6A41fE61E7a1996B59d508661e3f524d6A32075` | Pause classic pools. Their fee, up to 3%. Slipstream fees, up to 10%, through a fee module. |
| Uniswap | The owners of the v3 factory, `0xaBEA76658b205696d49B5F91b2a03536cB8A3bE1`, and of the v4 manager, `0x31FAfd4889FA1269F7a13A66eE0fB458f27D72A9` | v2 and v3: nothing that changes what a swap costs. v4: a protocol fee of up to 0.1%. |

None of them can take the swapper's tokens: it pays only the pool, or the manager, that it called, only the token the
hop owes, and only up to the hop's amount. The worst an exchange's admins can do is a worse price, down to the route's
minimum, or a revert.

## For holders

1. Quote your routes with `quote`, and leave out those that fail, or that are worth less than their gas.
2. Approve each token for the exact amount. There is no `permit`, no Permit2 and no signature of any kind.
3. Call `swap` with each route's `minPaid` a little under its quote, a deadline, and `skipFailed` set.

The fee is 1% of the USDC each route returns, rounded down, and goes to the 2-of-3 Safe
`0x450c72de8c0079B49AcedF294a13011bd09D125B` on each swap. It is fixed in the code: nobody can change it. The pools'
fees, price impact and gas come on top.

Keep the priority fee low. Above a tip of 1 gwei, or 2 gwei for stable pools, Aero's classic pools add an MEV tax, up to
10%, that a quote from `eth_call` doesn't see. The swapper prices Aero's pools with the tax, so the swap goes through, at a worse price, down to
your minimum: on the fork, with a 2 gwei tip, 1 WETH fetched 2,123 USDC instead of 2,357.

Gas, measured on a fork of Base for a whole call of one route, from a cold start:

| Route | Gas |
| --- | --- |
| Uniswap v2, v3 or v4, WETH to USDC | ~230,000 |
| Uniswap v4, cbBTC to ETH to USDC | ~292,000 |
| Aerodrome, classic or Slipstream, WETH to USDC | 273,000 to 319,000 |
| Hydrex classic, HYDX to USDC | ~312,000 |
| Aero v3, on pools the test creates | 334,000 to 374,000 |
| Hydrex Algebra, WETH to USDC | ~1,335,000 |
| HYDX to WETH on Hydrex Algebra, then to USDC on Uniswap v3 | ~2,098,000 |
| 20 routes of 3 Uniswap v2 hops | ~3,823,000 |
| 20 routes of 3 Hydrex Algebra hops | ~62,020,000 |

Hydrex's Algebra pools cost the most: after each swap, the pool's plugin looks for an arbitrage across other exchanges.
The limits on routes and hops don't keep a call under Base's cap of 16,777,216 gas, so estimate gas and split large
batches.

## Trust and limitations

- Nobody can change the swapper. A new exchange, factory, fee or treasury means a new deployment.
- The swapper fixes each exchange's factories rather than asking its registry, whose admin could add a factory that
  vouches for any contract. A factory added later needs a new deployment.
- Anyone can create a pool of a listed factory, for any two tokens. Such a pool runs its exchange's code, but its tokens
  can be anything, including tokens that misbehave. The swapper only calls tokens, pools that their factory vouches for,
  and Uniswap v4's manager.
- Hydrex's pair factory is an upgradeable proxy, behind a one-day timelock. An upgrade could make `isPair` vouch for
  any address, which would then receive a classic hop's input and could keep it. The route's minimum would revert the
  route, the transfer included.
- Hydrex's Algebra pools call their plugin before and after each swap. The plugin, and the contracts it calls, are
  upgradeable. Its arbitrage runs after the swapper is paid, so `quote` doesn't see it, and a later hop of the same
  route can find a pool it has moved. Its code even calls Foundry's console address on Base, which only costs gas.
- A token that charges a fee on transfers works through classic pools and Uniswap v2. Through Algebra, Slipstream,
  Uniswap v3 and v4 pools, its route reverts.
- USDC can block addresses. A caller that USDC blocks can't be paid, so their swaps revert.
- Tokens sent to the swapper by mistake stay there. Every amount is counted within the call, so they are never paid to
  anyone.
- Left out on purpose: native ETH in or out of a route; signatures; routers and aggregators; a recipient other than
  the caller; Algebra's custom pools; Uniswap v4 pools with hooks; choosing routes; claiming rewards.

## Deployment

The swapper is not deployed yet. Once it is, this section will record the transaction.

| | |
|---|---|
| Network | Base |
| Address | `0xC61940460A1a0383f23985ffa50c4D00Cab25913` |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Exchanges | the table above, in the order of `Exchange` |
| Treasury | `0x450c72de8c0079B49AcedF294a13011bd09D125B`, a 2-of-3 Safe, fixed in the source |
| Fee | 1% (`FEE_BPS = 100`), fixed in the source |
| Limits | 20 routes (`MAX_ROUTES`), 3 hops each (`MAX_HOPS`) |
| Method | CREATE2 through `0x4e59b44847b379578588920cA78FbF26c0B4956C`, salt `keccak256("metadex.cafe/ImmutableSwapper/v1")` |

Deployment steps:

1. Install Foundry v1.8.5, the version CI uses, with `foundryup --install v1.8.5`. Another version can compile
   different bytecode.
2. Run `forge test` with `BASE_RPC_URL` set, then `script/check-verification.sh`.
3. Do a dry run with `forge script script/Deploy.s.sol --rpc-url $BASE_RPC_URL`, and check that it logs the address
   in the table above.
4. Deploy, then verify the contract on Basescan and Sourcify, and commit `broadcast/Deploy.s.sol/8453/run-latest.json`:

```
forge script script/Deploy.s.sol --rpc-url $BASE_RPC_URL --broadcast --ledger
ARGS=$(jq -j .deployment.constructorArgs verification/bytecode-hashes.json)
forge verify-contract 0xC61940460A1a0383f23985ffa50c4D00Cab25913 src/ImmutableSwapper.sol:ImmutableSwapper --chain base \
  --constructor-args $ARGS --license-type MIT --watch
forge verify-contract 0xC61940460A1a0383f23985ffa50c4D00Cab25913 src/ImmutableSwapper.sol:ImmutableSwapper --chain base \
  --constructor-args $ARGS --verifier sourcify
```

## Verification

To check that the deployed contract is this repository's code, compare its code hash with the one recorded in
`verification/bytecode-hashes.json`, which `script/check-verification.sh` checks against a build of this repository:

```
cast keccak $(cast code 0xC61940460A1a0383f23985ffa50c4D00Cab25913 --rpc-url $BASE_RPC_URL)
jq -j .deployment.runtimeKeccak verification/bytecode-hashes.json
```

## Development

You need [Foundry](https://getfoundry.sh). The fork tests and `test/fixtures/generate.py` also need a Base archive RPC
in `BASE_RPC_URL`.

- `forge test` runs the unit tests, and the fork tests too when `BASE_RPC_URL` is set. The fork tests run against
  Base at the block recorded in [`test/fixtures/fork.json`](test/fixtures/fork.json), and swap through a real pool of
  each exchange. Aero's factories have no pools yet, so the fork tests create their own.
- `test/fixtures/generate.py [block]` rewrites that fixture: a pool of each exchange, a holder of each token, and each
  route's quote at that block, from the exchanges' own quotes.
- `script/check-signatures.sh` checks the interfaces in `src/interfaces/` against the exchanges' sources vendored in
  `test/upstream/`.
- `script/check-verification.sh` checks that `verification/` matches the build.
- `script/refresh-verification.sh` regenerates `verification/` after a change to the source or the deploy script.

[`test/upstream/UPSTREAM.md`](test/upstream/UPSTREAM.md) records the contracts the swapper is written against, their
code hashes, and the behaviour it relies on.

The contract compiles with solc 0.8.37 for `prague`, via-IR, with 1,000,000 optimizer runs. Builds are reproducible.

## License

MIT. `REUSE.toml` records the copyright and license of every file.
