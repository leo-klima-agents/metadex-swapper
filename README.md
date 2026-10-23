# metadex-swapper

`ImmutableSwapper` is a contract that swaps the tokens a holder picks to one output token in one call: small balances
left in a wallet, or rewards paid in many tokens. It swaps through the pools of the exchanges its deployment lists:
Aero and Uniswap on every chain, and Hydrex on Base. The caller picks the exchange and the pool of every hop, and the
contract checks each pick against that exchange's own factory. It sends 1% of the output to a fixed treasury.

It is deployed once for each chain and output token, which are fixed in that deployment's code, with the chain's
exchanges. The contract has no owner, no settings and no upgrade path. All of it is in
[`src/ImmutableSwapper.sol`](src/ImmutableSwapper.sol).

This is version 2. It takes each chain's exchanges as constructor arguments, so that it can be deployed beyond Base, and
it leaves out Aerodrome and Velodrome. It is not deployed yet. It will be deployed on Ethereum, Base, OP Mainnet,
Arbitrum One and Arc, at the addresses under [Chains](#chains).

Version 1 is deployed on Base, with Aerodrome among its exchanges: see [Version 1](#version-1).

## How it works

### Swapping

`swap(routes, deadline, skipFailed)` takes as many routes as fit in one transaction. Each route sells one token for the
output token, in 1 to 3 hops (`MAX_HOPS`):

```solidity
struct Hop {
    uint8 exchange; // an index into exchanges(), picked by the caller
    address pool; // zero for Uniswap v4
    address tokenOut; // the last hop's is the output token; zero is the native currency, between two hops of one Uniswap v4 manager only
    uint24 fee; // Uniswap v3 and v4 only
    int24 tickSpacing; // Uniswap v4 only
}

struct Route {
    address token; // never the output token, never the native currency
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
- Code that an exchange's admins control runs inside the swap, for `quote` as for `swap`: Aero's swap hook and
  Hydrex's plugins. It can skew a quote through those pools.

To see what a call will do, simulate `swap` itself, after its approvals, with `eth_simulateV1`.

### The exchanges

Each deployment fixes 1 to 12 exchanges: each is a factory, or Uniswap v4's manager, and its kind. No two can share a
factory. `exchanges()` returns them in order, and a hop names one by its index. The kind sets how the swapper checks a
pool, and how it pays it:

| `Kind` | A pool belongs to the exchange when |
| --- | --- |
| `AeroClassic` | `isPool(pool)`, and its tokens are the hop's |
| `AeroSlipstream` | `isPool(pool)`, and its tokens are the hop's |
| `UniswapV2` | `getPair(a, b) == pool` |
| `UniswapV3` | `getPool(a, b, fee) == pool` |
| `UniswapV4` | the key of the hop's tokens, `fee` and `tickSpacing`, with no hooks |
| `HydrexClassic` | `isPair(pool)`, and its tokens are the hop's |
| `HydrexAlgebra` | `poolByPair(a, b) == pool` |

Each chain's deployments list Uniswap's v2, v3 and v4, and every pool factory that the chain's Aero registry lists, but
for Aero Lite's three on Arc: see [Chains](#chains).

The swapper pays each kind of pool its own way:

- **Aero's classic pools, Uniswap v2's pairs and Hydrex's pairs** are synced, then sent the input. The swapper counts
  what the pool received, prices it with Aero's `getAmountOutWithTotalFee`, Uniswap v2's 0.3% formula, or Hydrex's
  `getAmountOut`, and asks for that much. Hydrex's stable pairs can quote one wei more than they accept, so it asks
  Hydrex's pairs for one wei less.
- **Slipstream, Uniswap v3 and Algebra pools** send their output, then call the swapper back to be paid. The swapper
  pays only the pool it is swapping through, only during that swap, only once, and only exactly the hop's amount of the
  hop's token. A pool that takes less than the whole amount, a partial fill, reverts the route.
- **Uniswap v4:** consecutive hops through the same manager run in one `unlock`. Each must take exactly the whole
  amount. Then the swapper pays the first token and takes the last, which must be another token. The native currency
  can only pass between two such hops, so it never leaves the manager.

Uniswap v4 hops name no pool: the swapper builds every key with no hooks. Hooks run inside every swap and can do
anything there, so tokens that trade only in pools with hooks, as many launchpad tokens do, are out of reach.

## Chains

Each chain has one swapper for each output token, and lists its own exchanges. Aero's classic factories have the same
addresses on every chain; its `CLFactory` and Uniswap's contracts have their own on most.

### Ethereum

Chain ID 1. cirBTC is Circle's bitcoin. Aero's classic pools have no MEV tax module here.

| Output | Token | Swapper |
| --- | --- | --- |
| WETH | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` | `0x2FbEe80FFCA668D8B79181d1eCc9632ef0f20969` |
| USDC | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | `0x5F38452bA25ddA761ac09F9b527A8AE8AB124C05` |
| EURC | `0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c` | `0x936EC799146523C60Ba6CDaB568C326542fe33d1` |
| cirBTC | `0x72DFB2E44f59C5AD2bAFE84314E5b99a7cd5075E` | `0x25fa8fAb45c399422F52404F25D0B94B1B43b5Ff` |
| cbBTC | `0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf` | `0x0663228082f5dFac237d6530adC7dEB0cf30119A` |

| Index | `Kind` | Factory, or manager |
| --- | --- | --- |
| 0 | `AeroClassic` | Aero volatile pools, `0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2` |
| 1 | `AeroClassic` | Aero stable pools, `0x78589E876edcEbdce72ee3436ab3c9AD3a7cEF2D` |
| 2 | `AeroSlipstream` | Aero `CLFactory`, `0xF4Fd2E6c5B60c5b365cd1B96DD6245E6D60414c2` |
| 3 | `UniswapV2` | `UniswapV2Factory`, `0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f` |
| 4 | `UniswapV3` | `UniswapV3Factory`, `0x1F98431c8aD98523631AE4a59f267346ea31F984` |
| 5 | `UniswapV4` | `PoolManager`, `0x000000000004444c5dc75cB358380D2e3dE08A90` |

### Base

Chain ID 8453. Only Base has Hydrex.

| Output | Token | Swapper |
| --- | --- | --- |
| WETH | `0x4200000000000000000000000000000000000006` | `0xFA88C5dEd6F338D2762E7929Cc8C5551dff0B9a6` |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | `0xb1ed455Cd2A475B4E4A57b8D32260aCCc795D1dD` |
| EURC | `0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42` | `0x6b37f100B6DD61077201371c1Aae029D740d51da` |
| cbBTC | `0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf` | `0x79B309317Fa2D36E6354d27D7EFeC5E120123f2B` |
| AERO | `0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee` | `0xC6281eE146FFE754771356339F2594A8955Cffe3` |
| HYDX | `0x00000e7efa313F4E11Bfff432471eD9423AC6B30` | `0xf34FE34945e38F58D5F19C02eB767225efbD33DB` |

| Index | `Kind` | Factory, or manager |
| --- | --- | --- |
| 0 | `AeroClassic` | Aero volatile pools, `0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2` |
| 1 | `AeroClassic` | Aero stable pools, `0x78589E876edcEbdce72ee3436ab3c9AD3a7cEF2D` |
| 2 | `AeroSlipstream` | Aero `CLFactory`, `0x9CB220581b91b0C83223012FE69688b92aD07a76` |
| 3 | `UniswapV2` | `UniswapV2Factory`, `0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6` |
| 4 | `UniswapV3` | `UniswapV3Factory`, `0x33128a8fC17869897dcE68Ed026d694621f6FDfD` |
| 5 | `UniswapV4` | `PoolManager`, `0x498581fF718922c3f8e6A244956aF099B2652b2b` |
| 6 | `HydrexClassic` | Hydrex pair factory, `0xC47F17c4fd96F50eFD2A2448ceDe5C185c084bf0` |
| 7 | `HydrexAlgebra` | Hydrex's Algebra Integral factory, `0x36077D39cdC65E1e3FB65810430E5b2c4D5fA29E` |

### OP Mainnet

Chain ID 10.

| Output | Token | Swapper |
| --- | --- | --- |
| WETH | `0x4200000000000000000000000000000000000006` | `0x96F1A279E7d8332d60C0490E3F96471968fe1612` |
| USDC | `0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85` | `0x646A8869e42653c61C2A5ae3bCA803EC7DBd9ad0` |

| Index | `Kind` | Factory, or manager |
| --- | --- | --- |
| 0 | `AeroClassic` | Aero volatile pools, `0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2` |
| 1 | `AeroClassic` | Aero stable pools, `0x78589E876edcEbdce72ee3436ab3c9AD3a7cEF2D` |
| 2 | `AeroSlipstream` | Aero `CLFactory`, `0xfeaB42D90055db3a0616249f76B6002D72266778` |
| 3 | `UniswapV2` | `UniswapV2Factory`, `0x0c3c1c532F1e39EdF36BE9Fe0bE1410313E074Bf` |
| 4 | `UniswapV3` | `UniswapV3Factory`, `0x1F98431c8aD98523631AE4a59f267346ea31F984` |
| 5 | `UniswapV4` | `PoolManager`, `0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3` |

### Arbitrum One

Chain ID 42161.

| Output | Token | Swapper |
| --- | --- | --- |
| WETH | `0x82aF49447D8a07e3bd95BD0d56f35241523fBab1` | `0x36348651d797cecc225A58C64f9b2C2b29091B26` |
| USDC | `0xaf88d065e77c8cC2239327C5EDb3A432268e5831` | `0x2BE19Ee701Cb109416481283E56Df7C70e47821C` |
| cbBTC | `0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf` | `0xbE293Bae0e90EC5405f9b9E8794B8288282aEA6F` |

| Index | `Kind` | Factory, or manager |
| --- | --- | --- |
| 0 | `AeroClassic` | Aero volatile pools, `0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2` |
| 1 | `AeroClassic` | Aero stable pools, `0x78589E876edcEbdce72ee3436ab3c9AD3a7cEF2D` |
| 2 | `AeroSlipstream` | Aero `CLFactory`, `0x88a60ee77392577c355C0acb2A8d476D5a4EC03a` |
| 3 | `UniswapV2` | `UniswapV2Factory`, `0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9` |
| 4 | `UniswapV3` | `UniswapV3Factory`, `0x1F98431c8aD98523631AE4a59f267346ea31F984` |
| 5 | `UniswapV4` | `PoolManager`, `0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32` |

### Arc

Chain ID 5042. WETH is the bridged WETH that Arc's documentation lists: it is minted on Arc against WETH locked on
Ethereum, through the `CrossChainTokenService` at `0x431871229103b780868f8C6BB820cd16ECf942BC`. A look-alike WETH trades
on Arc at `0x41d5379e2fCcE2c28802aA9f2536541B0Ab9F938`. USDC is Arc's native currency, through an ERC-20 at `0x3600…`.
See [Trust and limitations](#trust-and-limitations) for both.

| Output | Token | Swapper |
| --- | --- | --- |
| WETH | `0x128cC466B61f542da60c70e3aA11c10e19B84EDB` | `0x43C7BdA82e136608D3FA422d064aC8FED43d3E87` |
| USDC | `0x3600000000000000000000000000000000000000` | `0xbc9B081906620588228B3c44E9804048A5E5bD31` |
| EURC | `0xbEf5f6d51CB62b58e6A8f77868681825C6fe21c1` | `0x4CAD9fa41D498686261Bb7EC4db7D7291e550686` |
| cirBTC | `0x171A4217b86A807A64eB94757Db6849fb4bDbAA0` | `0x7A19943AA36Ca7e365142Fe10023CB182A25153c` |

| Index | `Kind` | Factory, or manager |
| --- | --- | --- |
| 0 | `AeroClassic` | Aero volatile pools, `0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2` |
| 1 | `AeroClassic` | Aero stable pools, `0x78589E876edcEbdce72ee3436ab3c9AD3a7cEF2D` |
| 2 | `AeroSlipstream` | Aero `CLFactory`, `0x7F83235643181E440433400a027618Cd50879751` |
| 3 | `UniswapV2` | `UniswapV2Factory`, `0x89e5DB8B5aA49aA85AC63f691524311AEB649eba` |
| 4 | `UniswapV3` | `UniswapV3Factory`, `0xf0db7b58379503491d857dB50AC9ece64c653918` |
| 5 | `UniswapV4` | `PoolManager`, `0x8366a39CC670B4001A1121B8F6A443A643e40951` |

## What each exchange's admins can change

| Exchange | Held by | What it can change in a swap |
| --- | --- | --- |
| Aero | A 3-of-7 Safe, `0x42255e3C2d0b71a0b006243148fdF1a71d054cE0`, on every chain | Pause classic pools. Their fee, up to 20% with the MEV tax, which they can set where there is none. The Slipstream pools' swap hook and its fee, capped at 10%. Discounts for chosen callers. |
| Uniswap | The owners of the v3 factory and of the v4 manager, in the table below | v2 and v3: nothing that changes what a swap costs. v4: a protocol fee of up to 0.1%. |
| Hydrex, on Base | `0x74266f2b206D1359B83fc74949EF07176FB3AE03`, a single key, owns the Algebra factory. A one-day timelock, `0xdF52b5A03E3F5a4178E4F63e8BC51abE691B898F`, owns the pair factory's proxy admin. A 2-of-4 Safe, `0x1aE3753d9b60743A89159CcFF8E251C60B560311`, manages the pairs' fees. The plugins have their own admins. | Fees: the pairs', up to 2.5%. The pair factory's code, and the plugins' code. Not fully checked. |

| Chain | Uniswap v3 factory's owner | Uniswap v4 manager's owner |
| --- | --- | --- |
| Ethereum | `0xf2371551Fe3937Db7c750f4DfABe5c2fFFdcBf5A` | `0x1a9C8182C09F50C8318d769245beA52c32BE35BC`, Uniswap's timelock |
| Base | `0xaBEA76658b205696d49B5F91b2a03536cB8A3bE1` | `0x31FAfd4889FA1269F7a13A66eE0fB458f27D72A9` |
| OP Mainnet | `0xec23Cf5A1db3dcC6595385D28B2a4D9B52503Be4` | `0xa1dD330d602c32622AA270Ea73d078B803Cb3518` |
| Arbitrum One | `0xFF7aD5dA31fECdC678796c88B05926dB896b0699` | `0x2BAD8182C09F50c8318d769245beA52C32Be46CD`, the timelock's L2 alias |
| Arc | `0xa59FfbB55D91Fc32b44A06F0b9cc6036a4afbcE2` | `0xbCA30b5429935205037069cF5b8A165F55d05a75` |

None of them can take the swapper's tokens, given how it pays pools. The worst they can do is a worse price, down to the
route's minimum, a wrong quote, or a revert.

## For holders

1. Quote your routes with `quote`, and leave out those that fail, or that are worth less than their gas.
2. Approve each token for the exact amount. There is no `permit`, no Permit2 and no signature of any kind.
3. Call `swap` with each route's `minPaid` a little under its quote, a deadline, and `skipFailed` set. Check quotes
   through Aero's Slipstream pools and Hydrex's Algebra pools against another price first.

The fee is 1% of the output each route returns, rounded down, paid in the output token to the 2-of-3 Safe
`0x450c72de8c0079B49AcedF294a13011bd09D125B` on each swap. It is fixed in the code: nobody can change it. The pools'
fees, price impact and gas come on top.

Keep the priority fee low. Where Aero's classic pools have a MEV tax module, it adds a tax of up to 10% above a tip set
by the module, that a quote from `eth_call` doesn't see: on Base, above 1 gwei, or 2 gwei for stable pools. The swapper
prices Aero's pools with the tax, so the swap goes through, at a worse price, down to your minimum: on the fork of Base,
with a 2 gwei tip, 1 WETH fetched 2,175 USDC instead of 2,415.

Gas used by whole transactions on a fork of Base, intrinsic and calldata gas included. It is counted after refunds, so a
transaction's limit must cover up to a quarter more. The caller and the treasury already held some of the output token:
paying either of them for the first time costs up to 17,100 more. The pools and tokens matter more than the output: USDC
to WETH costs about what WETH to USDC does.

| Route | Gas |
| --- | --- |
| Aero v3, on pools the tests seed | 290,000 to 352,000 |
| Uniswap v2, v3 or v4, WETH to USDC | 162,000 to 167,000 |
| Uniswap v4, cbBTC to ETH to USDC | ~223,000 |
| Hydrex classic, HYDX to USDC | ~230,000 |
| Hydrex Algebra, WETH to USDC | ~1,622,000 |
| HYDX to WETH on Hydrex Algebra, then to USDC on Uniswap v3 | ~1,914,000 |
| 20 routes of 3 Uniswap v2 hops | ~3,427,000 |
| 4 routes of 3 Hydrex Algebra hops | ~13,525,000 |

There is no limit on the number of routes: a chain's cap on the gas of a transaction is the limit, 16,777,216 on Base.
Hydrex's Algebra pools cost the most: after each swap, the pool's plugin looks for an arbitrage across other exchanges,
and about 12 such hops fit. So estimate gas and split large batches.

Send a generous gas limit: unused gas costs nothing. A route that runs short of gas fails like any other: with
`skipFailed`, it is skipped, or the whole call reverts if too little is left to finish. Hydrex's plugin does less when
it gets less gas, so a tight limit can also make a route through it go through, without the plugin's arbitrage. A gas
estimate only looks for a limit at which the call doesn't revert, and a skipped route doesn't revert it, so check the
results of `eth_call` at the limit you send.

## Trust and limitations

- Nobody can change the swapper. A new factory means a new deployment on its chain. A new kind of exchange, fee or
  treasury means a new version.
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
- A token that charges a fee on transfers works through classic pools and Uniswap v2. Through Slipstream, Uniswap v3
  and v4, and Algebra pools, its route reverts, though `quote` prices it.
- `skipFailed` can't skip a token or pool that burns all the gas its route gets, 63/64 of what is left, or that
  reverts with a reason too big to copy. Either reverts the whole call, for the caller who included that route only.
- WETH on Arbitrum One is upgradeable, though it blocks nobody. USDC, EURC, cirBTC and cbBTC are upgradeable, and can
  block addresses. A caller that the output token blocks can't be paid, so their swaps revert, and so would everyone's
  if it blocked the treasury. WETH on Ethereum, Base and OP Mainnet, AERO and HYDX can't block anyone.
- WETH on Arc is minted against WETH locked on Ethereum, by a `CrossChainTokenService` that a single key can upgrade on
  each chain. Another single key owns the token: it can pause it, and add minters, which could mint WETH that nothing
  backs. The token also checks a denylist, so it can block addresses. The WETH swapper on Arc pays out a token only as
  sound as those keys.
- On Arc, USDC is the native currency, and `0x3600000000000000000000000000000000000000` is the ERC-20 that moves it,
  in 6 decimals where the native balance has 18. The swapper treats it as any ERC-20: it can take it and pay it, and
  counts it by `balanceOf`. Foundry can't run the precompiles that this ERC-20 calls, so the fork tests of Arc run it
  against a stand-in, [`test/mocks/ArcNativeCoin.sol`](test/mocks/ArcNativeCoin.sol).
- Tokens sent to the swapper by mistake stay there. Every amount is counted within the call, so they are never paid to
  anyone.
- Left out on purpose: the native currency in or out of a route; signatures; routers and aggregators; a recipient other
  than the caller; Algebra's custom pools; Aerodrome and Velodrome; choosing routes; claiming rewards.

## Deployment

Version 2 is not deployed yet. `script/Deploy.s.sol` holds each chain's exchanges and output tokens. It deploys the
swappers of the chain it runs on, and stops on a chain it doesn't know, or where the treasury, an exchange or an output
token has no code.

| | |
|---|---|
| Networks | Ethereum, Base, OP Mainnet, Arbitrum One, Arc |
| Addresses | one swapper for each chain and output token, under [Chains](#chains) |
| Exchanges | each chain's, under [Chains](#chains), in that order |
| Treasury | `0x450c72de8c0079B49AcedF294a13011bd09D125B`, a 2-of-3 Safe, fixed in the source. It must exist on a chain before a deployment there |
| Fee | 1% (`FEE_BPS = 100`), fixed in the source |
| Method | CREATE2 through `0x4e59b44847b379578588920cA78FbF26c0B4956C`, salt `keccak256("metadex.cafe/ImmutableSwapper/v2")` for all; the chain's exchanges and the output token set them apart |

Deployment steps, for each chain:

1. Install Foundry v1.8.5, the version CI uses, with `foundryup --install v1.8.5`. Another version can compile
   different bytecode.
2. Run `forge test` with the chain's RPC set: `ETHEREUM_RPC_URL`, `BASE_RPC_URL`, `OPTIMISM_RPC_URL`,
   `ARBITRUM_RPC_URL` or `ARC_RPC_URL`. Then run `script/check-verification.sh`.
3. Do a dry run of `script/Deploy.s.sol`, and check that it logs the chain's addresses under [Chains](#chains). It
   stops where the treasury doesn't exist yet, and skips any swapper already deployed.
4. Deploy, then verify each swapper on Sourcify, and on the chain's explorer with the verifier it takes:

```
CHAIN=arc RPC=$ARC_RPC_URL # the chain's key in verification/bytecode-hashes.json, and its RPC
forge script script/Deploy.s.sol --rpc-url $RPC --broadcast --ledger
H=verification/bytecode-hashes.json
ID=$(jq -j ".chains.$CHAIN.chainId" $H)
for s in $(jq -r ".chains.$CHAIN.deployments | keys[]" $H); do
  ADDRESS=$(jq -j ".chains.$CHAIN.deployments.$s.address" $H)
  ARGS=$(jq -j ".chains.$CHAIN.deployments.$s.constructorArgs" $H)
  forge verify-contract $ADDRESS src/ImmutableSwapper.sol:ImmutableSwapper --chain $ID --verifier sourcify \
    --constructor-args $ARGS --skip-is-verified-check --watch
done
```

## Verification

To check that a deployed swapper is this repository's code, compare its code hash with the one recorded in
`verification/bytecode-hashes.json`, which `script/check-verification.sh` checks against a build of this repository.
Each swapper's code holds its output token and its chain's exchanges, so each has its own hash:

```
cast keccak $(cast code 0xb1ed455Cd2A475B4E4A57b8D32260aCCc795D1dD --rpc-url $BASE_RPC_URL)
jq -j .chains.base.deployments.USDC.runtimeKeccak verification/bytecode-hashes.json
```

The same file records each chain's exchanges, in order, as `exchanges()` returns them.

## Version 1

Version 1 is deployed on Base, for the same six output tokens. It fixes twelve exchanges in its code: Base's eight
above, and Aerodrome's classic factory and three Slipstream factories. A hop names one of them by its place in that
list. Its source is at commit [`86ce3d0`](https://github.com/leo-klima-agents/metadex-swapper/tree/86ce3d0), and its
records in [`verification/v1/`](verification/v1/). It was deployed on 2026-10-21 by the transactions below, with the
salt `keccak256("metadex.cafe/ImmutableSwapper/v1")`. Each source is verified on BaseScan and Sourcify as an exact
match.

| Output | Swapper | Transaction | Source |
| --- | --- | --- | --- |
| USDC | [`0x31791f453d2100e728E012c9e189C0828adf4b6F`](https://basescan.org/address/0x31791f453d2100e728E012c9e189C0828adf4b6F#code) | [`0x4ef3…382a`](https://basescan.org/tx/0x4ef3fa97cc025a34bd03e08df9994781e25bef5ea182b90dab2deb9c1df9382a) | [BaseScan](https://basescan.org/address/0x31791f453d2100e728E012c9e189C0828adf4b6F#code), [Sourcify](https://repo.sourcify.dev/8453/0x31791f453d2100e728E012c9e189C0828adf4b6F) |
| EURC | [`0x2cd8019d4F98e2fE2Ba705d8E7D38284c2a1450E`](https://basescan.org/address/0x2cd8019d4F98e2fE2Ba705d8E7D38284c2a1450E#code) | [`0x87f6…ec2a`](https://basescan.org/tx/0x87f61b2d13f77faa51da27d504f6158adc97d58f14fc6bf683025ee88500ec2a) | [BaseScan](https://basescan.org/address/0x2cd8019d4F98e2fE2Ba705d8E7D38284c2a1450E#code), [Sourcify](https://repo.sourcify.dev/8453/0x2cd8019d4F98e2fE2Ba705d8E7D38284c2a1450E) |
| WETH | [`0xe5cbD828c2227E17f7FF8BD54C7A1e6012694Ff2`](https://basescan.org/address/0xe5cbD828c2227E17f7FF8BD54C7A1e6012694Ff2#code) | [`0x7eb8…940a`](https://basescan.org/tx/0x7eb8d356413a4fe3a7f352c5cdac08dd4ec29271b883634461f0399dcea6940a) | [BaseScan](https://basescan.org/address/0xe5cbD828c2227E17f7FF8BD54C7A1e6012694Ff2#code), [Sourcify](https://repo.sourcify.dev/8453/0xe5cbD828c2227E17f7FF8BD54C7A1e6012694Ff2) |
| cbBTC | [`0x54805B6E6266c952627E47B8ADe4ae65c5DEA7d0`](https://basescan.org/address/0x54805B6E6266c952627E47B8ADe4ae65c5DEA7d0#code) | [`0x6422…003d`](https://basescan.org/tx/0x642220ca25c5e2bc4df3dae8ba1ef0647d64f05daf6d8697f94372a2d208003d) | [BaseScan](https://basescan.org/address/0x54805B6E6266c952627E47B8ADe4ae65c5DEA7d0#code), [Sourcify](https://repo.sourcify.dev/8453/0x54805B6E6266c952627E47B8ADe4ae65c5DEA7d0) |
| AERO | [`0xdd575A498C625AF96ac89efE578Dc68f4c9aB963`](https://basescan.org/address/0xdd575A498C625AF96ac89efE578Dc68f4c9aB963#code) | [`0x4db4…e46b`](https://basescan.org/tx/0x4db43c8745609ff0bdd7393c7bcdfa453e7d66b64ce72886fbc145b7bcc6e46b) | [BaseScan](https://basescan.org/address/0xdd575A498C625AF96ac89efE578Dc68f4c9aB963#code), [Sourcify](https://repo.sourcify.dev/8453/0xdd575A498C625AF96ac89efE578Dc68f4c9aB963) |
| HYDX | [`0xC629B1A13a0E1d4F0C38cD80d22E4AAC363cc8bC`](https://basescan.org/address/0xC629B1A13a0E1d4F0C38cD80d22E4AAC363cc8bC#code) | [`0x9005…ef23`](https://basescan.org/tx/0x90051331fd42eefe7836da478e54468fc62b79d7dcfa7d54d2fce3377d83ef23) | [BaseScan](https://basescan.org/address/0xC629B1A13a0E1d4F0C38cD80d22E4AAC363cc8bC#code), [Sourcify](https://repo.sourcify.dev/8453/0xC629B1A13a0E1d4F0C38cD80d22E4AAC363cc8bC) |

Aerodrome's admins, a 3-of-7 Safe, `0xE6A41fE61E7a1996B59d508661e3f524d6A32075`, can pause its classic pools, set
their fee up to 3%, and set Slipstream fees up to 10% through a fee module.


## Development

You need [Foundry](https://getfoundry.sh). The fork tests and `test/fixtures/generate.py` also need an archive RPC for
each chain, in `ETHEREUM_RPC_URL`, `BASE_RPC_URL`, `OPTIMISM_RPC_URL`, `ARBITRUM_RPC_URL` and `ARC_RPC_URL`. Public
RPCs often keep too little history: Arbitrum's own no longer serves the state at its fixture's block.

- `forge test` runs the unit tests, and the fork tests of each chain whose RPC is set. Each chain's fork tests,
  [`test/fork/<Chain>.t.sol`](test/fork/), run against that chain at the block recorded in
  [`test/fixtures/<chain>.json`](test/fixtures/). They deploy the chain's swappers with `script/Deploy.s.sol`, with a
  stand-in for the treasury where it doesn't exist yet, and swap through a real pool of each exchange, and into each
  output token. They pin the code of the exchanges' factories and of what they rely on. Some of Aero's pools
  hold no liquidity yet, so the fork tests add their own.
- `test/fixtures/generate.py <chain> [block]` rewrites a chain's fixture: a pool of each exchange, a holder of each
  token, and each route's quote at that block, from the exchanges' own quotes.
- `script/check-signatures.sh` checks the interfaces in `src/interfaces/` against the exchanges' sources vendored in
  `test/upstream/`.
- `script/check-verification.sh` checks that `verification/` matches the build and `script/Deploy.s.sol`, and that
  this README shows every swapper's address.
- `script/refresh-verification.sh` regenerates `verification/` after a change to the source or the deploy script. It
  leaves `verification/v1/` alone.

[`test/upstream/UPSTREAM.md`](test/upstream/UPSTREAM.md) records the contracts the swapper is written against, their
code hashes on each chain, and the behaviour it relies on.

The contract compiles with solc 0.8.37 for `prague`, via-IR, with 1,000,000 optimizer runs. Builds are reproducible.

## License

MIT. `REUSE.toml` records the copyright and license of every file.
