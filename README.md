# metadex-swapper

`ImmutableSwapper` is a contract on Base that swaps the tokens a holder picks to one output token in one call: small
balances left in a wallet, or rewards paid in many tokens. It swaps through the pools of four exchanges: Hydrex, Aero,
Aerodrome and Uniswap. The caller picks the exchange and the pool of every hop, and the contract checks each pick against
that exchange's own factory. It sends 1% of the output to a fixed treasury.

It is deployed once for each output token, which is fixed in that deployment's code. The contract has no owner, no
settings and no upgrade path. All of it is in [`src/ImmutableSwapper.sol`](src/ImmutableSwapper.sol). The six
swappers are deployed on Base, and verified on Basescan and Sourcify with exact matches:

| Output | Token | Swapper |
| --- | --- | --- |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | [`0x31791f453d2100e728E012c9e189C0828adf4b6F`](https://basescan.org/address/0x31791f453d2100e728E012c9e189C0828adf4b6F#code) |
| EURC | `0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42` | [`0x2cd8019d4F98e2fE2Ba705d8E7D38284c2a1450E`](https://basescan.org/address/0x2cd8019d4F98e2fE2Ba705d8E7D38284c2a1450E#code) |
| WETH | `0x4200000000000000000000000000000000000006` | [`0xe5cbD828c2227E17f7FF8BD54C7A1e6012694Ff2`](https://basescan.org/address/0xe5cbD828c2227E17f7FF8BD54C7A1e6012694Ff2#code) |
| cbBTC | `0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf` | [`0x54805B6E6266c952627E47B8ADe4ae65c5DEA7d0`](https://basescan.org/address/0x54805B6E6266c952627E47B8ADe4ae65c5DEA7d0#code) |
| AERO | `0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee` | [`0xdd575A498C625AF96ac89efE578Dc68f4c9aB963`](https://basescan.org/address/0xdd575A498C625AF96ac89efE578Dc68f4c9aB963#code) |
| HYDX | `0x00000e7efa313F4E11Bfff432471eD9423AC6B30` | [`0xC629B1A13a0E1d4F0C38cD80d22E4AAC363cc8bC`](https://basescan.org/address/0xC629B1A13a0E1d4F0C38cD80d22E4AAC363cc8bC#code) |

## How it works

### Swapping

`swap(routes, deadline, skipFailed)` takes as many routes as fit in one transaction. Each route sells one token for the
output token, in 1 to 3 hops (`MAX_HOPS`):

```solidity
struct Hop {
    Exchange exchange; // picked by the caller
    address pool; // zero for Uniswap v4
    address tokenOut; // the last hop's is the output token; zero is native ETH, between two Uniswap v4 hops only
    uint24 fee; // Uniswap v3 and v4 only
    int24 tickSpacing; // Uniswap v4 only
}

struct Route {
    address token; // never the output token, never native ETH
    uint256 amount; // type(uint256).max: the caller's balance, up to the allowance given
    uint256 minPaid; // the least of the output token this route must pay the caller, after the fee
    Hop[] hops;
}
```

For each route, the swapper:

1. checks the path: only the last hop ends in the output token, and each hop's pool belongs to the exchange the hop
   names;
2. pulls the token from the caller with `transferFrom`, and counts what arrived;
3. swaps hop by hop, and counts each hop's output by the change in its own balance;
4. takes 1% of the output, rounded down, and reverts unless the rest is at least `minPaid`.

Each route runs in a call of its own, so a route that fails undoes everything it did, including the pull of its token.
A route that goes through is reported in a `RouteSwapped` event. With `skipFailed`, a route that fails is skipped and
reported in a `RouteFailed` event, and its token stays with the caller. Without it, the whole call reverts with the
route's reason. After the last route, the swapper sends the fees to the treasury and the rest to the caller, and emits
`Swapped`. It reverts after `deadline`.

The contract never picks a route, and it never pays anyone but the caller and the treasury. It only pulls tokens from
the caller, so nobody's approval can be used by anyone else.

### Quoting

`quote(routes)` runs the same checks, and returns what `swap` would. Call it with `eth_call`: it moves nothing, and
needs no allowance. With `type(uint256).max`, it quotes the caller's whole balance. A route that fails comes back with
`done` false and its reason.

It asks the pools without trading: concentrated pools and Uniswap v4 run their swap up to the payment, and classic
pools are only asked for their price. So `quote` and `swap` can differ:

- Each route is priced against the pools as they are, so two routes through the same pool both get the first one's
  price. Each route's minimum covers this.
- A classic pool that its exchange paused still quotes.
- A token that charges a fee on transfers is quoted as if it didn't.
- `swap` syncs a classic pool before sending it the input, so what the pool holds beyond its reserves joins them.
  `quote` prices with the reserves as they are, so the two differ when a pool holds such tokens.
- Code that an exchange's admins control runs inside the swap, for `quote` as for `swap`: Hydrex's plugins and Aero's
  swap hook. It can skew a quote through those pools.

To see what a call will do, simulate `swap` itself, after its approvals, with `eth_simulateV1`.

### The exchanges

Twelve kinds of pool, from four exchanges, fixed at deployment. For Aero and Aerodrome, they are every pool factory
that their registries list.

| `Exchange` | Factory, or manager | A pool belongs to it when |
| --- | --- | --- |
| `HydrexAlgebra` | Algebra Integral, `0x36077D39cdC65E1e3FB65810430E5b2c4D5fA29E` | `poolByPair(a, b) == pool` |
| `HydrexClassic` | Pair factory, `0xC47F17c4fd96F50eFD2A2448ceDe5C185c084bf0` | `isPair(pool)`, and its tokens are the hop's |
| `AeroVolatile` | `0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2` | `isPool(pool)`, and its tokens are the hop's |
| `AeroStable` | `0x78589E876edcEbdce72ee3436ab3c9AD3a7cEF2D` | `isPool(pool)`, and its tokens are the hop's |
| `AeroSlipstream` | `CLFactory`, `0x9CB220581b91b0C83223012FE69688b92aD07a76` | `isPool(pool)`, and its tokens are the hop's |
| `AerodromeClassic` | `PoolFactory`, `0x420DD381b31aEf6683db6B902084cB0FFECe40Da` | `isPool(pool)`, and its tokens are the hop's |
| `AerodromeSlipstream` | `CLFactory`, `0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A` | `isPool(pool)`, and its tokens are the hop's |
| `AerodromeSlipstream2` | `CLFactory`, `0xaDe65c38CD4849aDBA595a4323a8C7DdfE89716a` | `isPool(pool)`, and its tokens are the hop's |
| `AerodromeSlipstream3` | `CLFactory`, `0xf8f2eB4940CFE7d13603DDDD87f123820Fc061Ef` | `isPool(pool)`, and its tokens are the hop's |
| `UniswapV2` | `UniswapV2Factory`, `0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6` | `getPair(a, b) == pool` |
| `UniswapV3` | `UniswapV3Factory`, `0x33128a8fC17869897dcE68Ed026d694621f6FDfD` | `getPool(a, b, fee) == pool` |
| `UniswapV4` | `PoolManager`, `0x498581fF718922c3f8e6A244956aF099B2652b2b` | the key of the hop's tokens, `fee` and `tickSpacing`, with no hooks |

`exchanges()` returns these addresses, in this order. The swapper pays each kind of pool its own way:

- **Algebra, Slipstream and Uniswap v3 pools** send their output, then call the swapper back to be paid. The swapper
  pays only the pool it is swapping through, only during that swap, only once, and only exactly the hop's amount of the
  hop's token. A pool that takes less than the whole amount, a partial fill, reverts the route.
- **Hydrex's pairs, Aero's and Aerodrome's classic pools, and Uniswap v2's pairs** are synced, then sent the input. The
  swapper counts what the pool received, prices it with the pool's `getAmountOut`, Aero's `getAmountOutWithTotalFee`,
  or Uniswap v2's 0.3% formula, and asks for that much. Hydrex's stable pairs can quote one wei more than they accept,
  so it asks Hydrex's pairs for one wei less.
- **Uniswap v4:** consecutive hops run in one `unlock`. Each must take exactly the whole amount. Then the swapper pays
  the first token and takes the last, which must be another token. Native ETH can only pass between two such hops, so
  it never leaves the manager.

Uniswap v4 hops name no pool: the swapper builds every key with no hooks. Hooks run inside every swap and can do
anything there, so tokens that trade only in pools with hooks, as many launchpad tokens do, are out of reach.

## What each exchange's admins can change

| Exchange | Held by | What it can change in a swap |
| --- | --- | --- |
| Hydrex | `0x74266f2b206D1359B83fc74949EF07176FB3AE03`, a single key, owns the Algebra factory. A one-day timelock, `0xdF52b5A03E3F5a4178E4F63e8BC51abE691B898F`, owns the pair factory's proxy admin. A 2-of-4 Safe, `0x1aE3753d9b60743A89159CcFF8E251C60B560311`, manages the pairs' fees. The plugins have their own admins. | Fees: the pairs', up to 2.5%. The pair factory's code, and the plugins' code. Not fully checked. |
| Aero | A 3-of-7 Safe, `0x42255e3C2d0b71a0b006243148fdF1a71d054cE0` | Pause classic pools. Their fee, up to 20% with the MEV tax. The Slipstream pools' swap hook and its fee, capped at 10%. Discounts for chosen callers. |
| Aerodrome | A 3-of-7 Safe, `0xE6A41fE61E7a1996B59d508661e3f524d6A32075` | Pause classic pools. Their fee, up to 3%. Slipstream fees, up to 10%, through a fee module. |
| Uniswap | The owners of the v3 factory, `0xaBEA76658b205696d49B5F91b2a03536cB8A3bE1`, and of the v4 manager, `0x31FAfd4889FA1269F7a13A66eE0fB458f27D72A9` | v2 and v3: nothing that changes what a swap costs. v4: a protocol fee of up to 0.1%. |

None of them can take the swapper's tokens, given how it pays pools. The worst they can do is a worse price, down to the
route's minimum, a wrong quote, or a revert.

## For holders

1. Quote your routes with `quote`, and leave out those that fail, or that are worth less than their gas.
2. Approve each token for the exact amount. There is no `permit`, no Permit2 and no signature of any kind.
3. Call `swap` with each route's `minPaid` a little under its quote, a deadline, and `skipFailed` set. Check quotes
   through Hydrex's Algebra pools and Aero's Slipstream pools against another price first.

The fee is 1% of the output each route returns, rounded down, paid in the output token to the 2-of-3 Safe
`0x450c72de8c0079B49AcedF294a13011bd09D125B` on each swap. It is fixed in the code: nobody can change it. The pools'
fees, price impact and gas come on top.

Keep the priority fee low. Above a tip of 1 gwei, or 2 gwei for stable pools, Aero's classic pools add an MEV tax, up to
10%, that a quote from `eth_call` doesn't see. The swapper prices Aero's pools with the tax, so the swap goes through,
at a worse price, down to your minimum: on the fork, with a 2 gwei tip, 1 WETH fetched 2,175 USDC instead of 2,415.

Gas used by whole transactions on a fork of Base, intrinsic and calldata gas included. It is counted after refunds, so a
transaction's limit must cover up to a quarter more. The caller and the treasury already held some of the output token:
paying either of them for the first time costs up to 17,100 more. The pools and tokens matter more than the output: USDC
to WETH costs about what WETH to USDC does.

| Route | Gas |
| --- | --- |
| Uniswap v2, v3 or v4, WETH to USDC | 162,000 to 167,000 |
| Uniswap v4, cbBTC to ETH to USDC | ~221,000 |
| Aerodrome, classic or Slipstream, WETH to USDC | 205,000 to 270,000 |
| Hydrex classic, HYDX to USDC | ~229,000 |
| Aero v3, on pools the tests seed | 290,000 to 352,000 |
| Hydrex Algebra, WETH to USDC | ~1,612,000 |
| HYDX to WETH on Hydrex Algebra, then to USDC on Uniswap v3 | ~1,913,000 |
| Each further token, to USDC on Aerodrome classic | 153,000 to 292,000, ~220,000 on average |
| Each further token, to WETH then USDC on Aerodrome classic | 205,000 to 344,000, ~272,000 on average |
| 20 routes of 3 Uniswap v2 hops | ~3,419,000 |
| 5 routes of 3 Hydrex Algebra hops | ~15,212,000 |

There is no limit on the number of routes: Base's cap of 16,777,216 gas on a transaction is the limit. About 64 tokens
fit in one call when each has a pool against USDC, and about 47 when each goes through WETH. Hydrex's Algebra pools cost
the most: after each swap, the pool's plugin looks for an arbitrage across other exchanges, and about 15 such hops fit.
So estimate gas and split large batches.

Send a generous gas limit: on Base, unused gas costs nothing. A route that runs short of gas fails like any other: with
`skipFailed`, it is skipped, or the whole call reverts if too little is left to finish. Hydrex's plugin does less when
it gets less gas, so a tight limit can also make a route through it go through, without the plugin's arbitrage. A gas
estimate only looks for a limit at which the call doesn't revert, and a skipped route doesn't revert it, so check the
results of `eth_call` at the limit you send.

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
  Uniswap v3 and v4 pools, its route reverts, though `quote` prices it.
- `skipFailed` can't skip a token or pool that burns all the gas its route gets, 63/64 of what is left, or that
  reverts with a reason too big to copy. Either reverts the whole call, for the caller who included that route only.
- USDC, EURC and cbBTC are upgradeable, and can block addresses. A caller that the output token blocks can't be paid, so
  their swaps revert, and so would everyone's if it blocked the treasury. WETH, AERO and HYDX can't block anyone.
- Tokens sent to the swapper by mistake stay there. Every amount is counted within the call, so they are never paid to
  anyone.
- Left out on purpose: native ETH in or out of a route; signatures; routers and aggregators; a recipient other than
  the caller; Algebra's custom pools; choosing routes; claiming rewards.

## Deployment

The six swappers were deployed on 21 October 2026, in Base block 52,894,916, from
`0x85674b49dCD5976cF430D3F35f0AD45c4401A213`. The transactions are recorded in
[`broadcast/Deploy.s.sol/8453/run-latest.json`](broadcast/Deploy.s.sol/8453/run-latest.json):

| Output | Transaction |
| --- | --- |
| USDC | [`0x4ef3fa97cc025a34bd03e08df9994781e25bef5ea182b90dab2deb9c1df9382a`](https://basescan.org/tx/0x4ef3fa97cc025a34bd03e08df9994781e25bef5ea182b90dab2deb9c1df9382a) |
| EURC | [`0x87f61b2d13f77faa51da27d504f6158adc97d58f14fc6bf683025ee88500ec2a`](https://basescan.org/tx/0x87f61b2d13f77faa51da27d504f6158adc97d58f14fc6bf683025ee88500ec2a) |
| WETH | [`0x7eb8d356413a4fe3a7f352c5cdac08dd4ec29271b883634461f0399dcea6940a`](https://basescan.org/tx/0x7eb8d356413a4fe3a7f352c5cdac08dd4ec29271b883634461f0399dcea6940a) |
| cbBTC | [`0x642220ca25c5e2bc4df3dae8ba1ef0647d64f05daf6d8697f94372a2d208003d`](https://basescan.org/tx/0x642220ca25c5e2bc4df3dae8ba1ef0647d64f05daf6d8697f94372a2d208003d) |
| AERO | [`0x4db43c8745609ff0bdd7393c7bcdfa453e7d66b64ce72886fbc145b7bcc6e46b`](https://basescan.org/tx/0x4db43c8745609ff0bdd7393c7bcdfa453e7d66b64ce72886fbc145b7bcc6e46b) |
| HYDX | [`0x90051331fd42eefe7836da478e54468fc62b79d7dcfa7d54d2fce3377d83ef23`](https://basescan.org/tx/0x90051331fd42eefe7836da478e54468fc62b79d7dcfa7d54d2fce3377d83ef23) |

Each swapper was created on Base through the CREATE2 deployer `0x4e59b44847b379578588920cA78FbF26c0B4956C`, with the
salt `keccak256("metadex.cafe/ImmutableSwapper/v1")`. Their constructor arguments, the output token and then the
exchanges in the order of `Exchange`, set their addresses apart.

They were deployed with these steps:

1. Install Foundry v1.8.5, the version CI uses, with `foundryup --install v1.8.5`. Another version can compile
   different bytecode.
2. Run `forge test` with `BASE_RPC_URL` set, then `script/check-verification.sh`.
3. Do a dry run with `forge script script/Deploy.s.sol --rpc-url $BASE_RPC_URL`, and check that it logs the six
   addresses in the table at the top. It skips any that is already deployed.
4. Deploy, verify each contract, and commit `broadcast/Deploy.s.sol/8453/run-latest.json`:

```
forge script script/Deploy.s.sol --rpc-url $BASE_RPC_URL --broadcast --ledger
H=verification/bytecode-hashes.json
for s in USDC EURC WETH cbBTC AERO HYDX; do
  ADDRESS=$(jq -j ".deployments.$s.address" $H)
  ARGS=$(jq -j ".deployments.$s.constructorArgs" $H)
  forge verify-contract $ADDRESS src/ImmutableSwapper.sol:ImmutableSwapper --chain base \
    --constructor-args $ARGS --license-type MIT --watch
done
```

## Verification

To check that a deployed swapper is this repository's code, compare its code hash with the one recorded in
`verification/bytecode-hashes.json`, which `script/check-verification.sh` checks against a build of this repository.
Each swapper's code holds its output token, so each has its own hash:

```
cast keccak $(cast code 0x31791f453d2100e728E012c9e189C0828adf4b6F --rpc-url $BASE_RPC_URL)
jq -j .deployments.USDC.runtimeKeccak verification/bytecode-hashes.json
```

## Development

You need [Foundry](https://getfoundry.sh). The fork tests and `test/fixtures/generate.py` also need a Base archive RPC
in `BASE_RPC_URL`.

- `forge test` runs the unit tests, and the fork tests too when `BASE_RPC_URL` is set. The fork tests run against
  Base at the block recorded in [`test/fixtures/fork.json`](test/fixtures/fork.json). They swap through a real pool of
  each exchange, and into each output token. Aero's pools hold no liquidity yet, so the fork tests add their own.
- `test/fixtures/generate.py [block]` rewrites that fixture: a pool of each exchange, a holder of each token, and each
  route's quote at that block, from the exchanges' own quotes.
- `script/check-signatures.sh` checks the interfaces in `src/interfaces/` against the exchanges' sources vendored in
  `test/upstream/`.
- `script/check-verification.sh` checks that `verification/` matches the build and `script/Deploy.s.sol`.
- `script/refresh-verification.sh` regenerates `verification/` after a change to the source or the deploy script.

[`test/upstream/UPSTREAM.md`](test/upstream/UPSTREAM.md) records the contracts the swapper is written against, their
code hashes, and the behaviour it relies on.

The contract compiles with solc 0.8.37 for `prague`, via-IR, with 1,000,000 optimizer runs. Builds are reproducible.

## License

MIT. `REUSE.toml` records the copyright and license of every file.
