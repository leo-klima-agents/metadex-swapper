# Upstream pins

Byte-identical copies of the exchanges' files that `src/interfaces/` is checked against, where their licences allow.
Nothing in `src/` imports them and `foundry.toml` skips them. `script/check-signatures.sh` checks that every function
declared in `src/interfaces/`, other than ERC-20's, has the same signature here, and `test/Selectors.t.sol` pins every
selector.

## Vendored files

| Local file | Upstream | License |
|---|---|---|
| `algebra/IAlgebraFactory.sol` | Algebra factory, `contracts/interfaces/IAlgebraFactory.sol` | GPL-2.0-or-later |
| `algebra/IAlgebraPoolActions.sol` | Algebra pool, `contracts/interfaces/pool/IAlgebraPoolActions.sol` | GPL-2.0-or-later |
| `algebra/IAlgebraSwapCallback.sol` | Algebra pool, `contracts/interfaces/callback/IAlgebraSwapCallback.sol` | GPL-2.0-or-later |
| `hydrex/Pair.sol` | Hydrex pair, `contracts/Pair.sol` | MIT |
| `hydrex/IPair.sol` | Hydrex pair, `contracts/interfaces/IPair.sol` | MIT |
| `hydrex/IPairFactory.sol` | Hydrex pair, `contracts/interfaces/IPairFactory.sol` | MIT |
| `hydrex/PairFactoryUpgradeable.sol` | Hydrex pair factory implementation, `contracts/factories/PairFactoryUpgradeable.sol` | MIT |
| `aero/Pool.sol` | Aero volatile pool implementation, `V3/src/pools/Pool.sol` | GPL-3.0-or-later |
| `aero/IPool.sol` | Aero volatile pool implementation, `V3/src/interfaces/pools/IPool.sol` | MIT |
| `aero/PoolFactory.sol` | Aero volatile factory, `V3/src/factories/PoolFactory.sol` | GPL-3.0-or-later |
| `aero/IPoolFactory.sol` | Aero volatile factory, `V3/src/interfaces/factories/IPoolFactory.sol` | MIT |
| `aero/slipstream/*.sol` | Aero CLFactory, `contracts/core/interfaces/`: `ICLFactory.sol`, `pool/ICLPoolActions.sol`, `pool/ICLPoolConstants.sol`, `callback/ICLSwapCallback.sol` | GPL-2.0-or-later |
| `aerodrome/slipstream/*.sol` | Aerodrome's first CLPool implementation, `contracts/core/CLPool.sol` and the same four interfaces | GPL-2.0-or-later |
| `aerodrome/slipstream3/ICLFactory.sol` | Aerodrome's third CLPool implementation, `contracts/core/interfaces/ICLFactory.sol`; the second's is identical | GPL-2.0-or-later |
| `uniswap/v2/*.sol` | UniswapV2Factory, `contracts/UniswapV2Pair.sol`, `contracts/interfaces/IUniswapV2Factory.sol`, `contracts/interfaces/IUniswapV2Pair.sol` | GPL-3.0-or-later |
| `uniswap/v3/*.sol` | UniswapV3Factory, `contracts/interfaces/`: `IUniswapV3Factory.sol`, `pool/IUniswapV3PoolActions.sol`, `pool/IUniswapV3PoolImmutables.sol`, `callback/IUniswapV3SwapCallback.sol` | GPL-2.0-or-later |
| `uniswap/v4/*.sol` | PoolManager, `lib/v4-core/src/`: `interfaces/IPoolManager.sol`, `interfaces/callback/IUnlockCallback.sol`, `types/PoolKey.sol`, `types/PoolOperation.sol` | MIT |

Uniswap v2's sources carry no SPDX header; `@uniswap/v2-core` is published under GPL-3.0-or-later.

| Source | Address | Sourcify | Compiler |
|---|---|---|---|
| Algebra factory (`AlgebraFactory`) | `0x36077D39cdC65E1e3FB65810430E5b2c4D5fA29E` | [match](https://repo.sourcify.dev/8453/0x36077D39cdC65E1e3FB65810430E5b2c4D5fA29E) | 0.8.20 |
| Algebra pool (`AlgebraPool`), HYDX/USDC | `0x51f0B932855986B0E621c9D4DB6Eee1f4644D3D2` | [match](https://repo.sourcify.dev/8453/0x51f0B932855986B0E621c9D4DB6Eee1f4644D3D2) | 0.8.20 |
| Hydrex pair (`Pair`), volatile HYDX/USDC | `0x605abD1873737CA9a9Ec1CFa52CDfc8ef62c2E1d` | [match](https://repo.sourcify.dev/8453/0x605abD1873737CA9a9Ec1CFa52CDfc8ef62c2E1d) | 0.8.13 |
| Hydrex pair factory implementation (`PairFactoryUpgradeable`) | `0x421656a4fc9943a2a7997d6f4f6c04eb2e336d18` | [match](https://repo.sourcify.dev/8453/0x421656a4fc9943a2a7997d6f4f6c04eb2e336d18) | 0.8.13 |
| Aero volatile pool implementation (`VolatilePool`) | `0x8B64A0B590815d54C11a4B49A82b0133c7f53f0E` | [match](https://repo.sourcify.dev/8453/0x8B64A0B590815d54C11a4B49A82b0133c7f53f0E) | 0.8.36 |
| Aero volatile factory (`VolatilePoolFactory`) | `0x9bc8b3F60D349d687Fb44A018967025E3741F9a5` | [match](https://repo.sourcify.dev/8453/0x9bc8b3F60D349d687Fb44A018967025E3741F9a5) | 0.8.36 |
| Aero CLFactory | `0xC6bdE6e9F0CD71013E5FcF2dAAE2fA1c71Bb2F25` | [match](https://repo.sourcify.dev/8453/0xC6bdE6e9F0CD71013E5FcF2dAAE2fA1c71Bb2F25) | 0.7.6 |
| Aerodrome's first CLPool implementation | `0xeC8E5342B19977B4eF8892e02D8DAEcfa1315831` | [match](https://repo.sourcify.dev/8453/0xeC8E5342B19977B4eF8892e02D8DAEcfa1315831) | 0.7.6 |
| Aerodrome's third CLPool implementation | `0xc770898522D2A9c8Da7A10D63989b6b58305B665` | [exact match](https://repo.sourcify.dev/8453/0xc770898522D2A9c8Da7A10D63989b6b58305B665) | 0.7.6 |
| UniswapV2Factory | `0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6` | [exact match](https://repo.sourcify.dev/8453/0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6) | 0.5.16 |
| UniswapV3Factory | `0x33128a8fC17869897dcE68Ed026d694621f6FDfD` | [match](https://repo.sourcify.dev/8453/0x33128a8fC17869897dcE68Ed026d694621f6FDfD) | 0.7.6 |
| PoolManager | `0x498581fF718922c3f8e6A244956aF099B2652b2b` | [match](https://repo.sourcify.dev/8453/0x498581fF718922c3f8e6A244956aF099B2652b2b) | 0.8.26 |

A "match", unlike an "exact match", means the bytecode matches but the metadata hash differs, so comments may differ
from what was compiled. Sourcify's entries for UniswapV3Factory and PoolManager also hold unrelated copies of their
files; only the compilation target's own paths are vendored. The vendored files are fetched with the commands below,
and `SHA256SUMS` holds their hashes:

```
for a in 0x36077D39cdC65E1e3FB65810430E5b2c4D5fA29E 0x51f0B932855986B0E621c9D4DB6Eee1f4644D3D2 0x605abD1873737CA9a9Ec1CFa52CDfc8ef62c2E1d 0x421656a4fc9943a2a7997d6f4f6c04eb2e336d18 0x8B64A0B590815d54C11a4B49A82b0133c7f53f0E 0x9bc8b3F60D349d687Fb44A018967025E3741F9a5 0xC6bdE6e9F0CD71013E5FcF2dAAE2fA1c71Bb2F25 0xeC8E5342B19977B4eF8892e02D8DAEcfa1315831 0xc770898522D2A9c8Da7A10D63989b6b58305B665 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6 0x33128a8fC17869897dcE68Ed026d694621f6FDfD 0x498581fF718922c3f8e6A244956aF099B2652b2b; do
  curl -sS "https://sourcify.dev/server/v2/contract/8453/$a?fields=sources" > /tmp/$a.json
done
U=test/upstream
mkdir -p $U/algebra $U/hydrex $U/aero/slipstream $U/aerodrome/slipstream $U/aerodrome/slipstream3 $U/uniswap/v2 $U/uniswap/v3 $U/uniswap/v4
get() { jq -j --arg k "$2" '.sources[$k].content' "/tmp/$1.json" > "$U/$3"; }
get 0x36077D39cdC65E1e3FB65810430E5b2c4D5fA29E contracts/interfaces/IAlgebraFactory.sol algebra/IAlgebraFactory.sol
get 0x51f0B932855986B0E621c9D4DB6Eee1f4644D3D2 contracts/interfaces/pool/IAlgebraPoolActions.sol algebra/IAlgebraPoolActions.sol
get 0x51f0B932855986B0E621c9D4DB6Eee1f4644D3D2 contracts/interfaces/callback/IAlgebraSwapCallback.sol algebra/IAlgebraSwapCallback.sol
get 0x605abD1873737CA9a9Ec1CFa52CDfc8ef62c2E1d contracts/Pair.sol hydrex/Pair.sol
get 0x605abD1873737CA9a9Ec1CFa52CDfc8ef62c2E1d contracts/interfaces/IPair.sol hydrex/IPair.sol
get 0x605abD1873737CA9a9Ec1CFa52CDfc8ef62c2E1d contracts/interfaces/IPairFactory.sol hydrex/IPairFactory.sol
get 0x421656a4fc9943a2a7997d6f4f6c04eb2e336d18 contracts/factories/PairFactoryUpgradeable.sol hydrex/PairFactoryUpgradeable.sol
get 0x8B64A0B590815d54C11a4B49A82b0133c7f53f0E V3/src/pools/Pool.sol aero/Pool.sol
get 0x8B64A0B590815d54C11a4B49A82b0133c7f53f0E V3/src/interfaces/pools/IPool.sol aero/IPool.sol
get 0x9bc8b3F60D349d687Fb44A018967025E3741F9a5 V3/src/factories/PoolFactory.sol aero/PoolFactory.sol
get 0x9bc8b3F60D349d687Fb44A018967025E3741F9a5 V3/src/interfaces/factories/IPoolFactory.sol aero/IPoolFactory.sol
for f in interfaces/ICLFactory.sol interfaces/pool/ICLPoolActions.sol interfaces/pool/ICLPoolConstants.sol interfaces/callback/ICLSwapCallback.sol; do
  get 0xC6bdE6e9F0CD71013E5FcF2dAAE2fA1c71Bb2F25 contracts/core/$f aero/slipstream/"$(basename $f)"
  get 0xeC8E5342B19977B4eF8892e02D8DAEcfa1315831 contracts/core/$f aerodrome/slipstream/"$(basename $f)"
done
get 0xeC8E5342B19977B4eF8892e02D8DAEcfa1315831 contracts/core/CLPool.sol aerodrome/slipstream/CLPool.sol
get 0xc770898522D2A9c8Da7A10D63989b6b58305B665 contracts/core/interfaces/ICLFactory.sol aerodrome/slipstream3/ICLFactory.sol
for f in UniswapV2Pair.sol interfaces/IUniswapV2Factory.sol interfaces/IUniswapV2Pair.sol; do
  get 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6 contracts/$f uniswap/v2/"$(basename $f)"
done
for f in IUniswapV3Factory.sol pool/IUniswapV3PoolActions.sol pool/IUniswapV3PoolImmutables.sol callback/IUniswapV3SwapCallback.sol; do
  get 0x33128a8fC17869897dcE68Ed026d694621f6FDfD contracts/interfaces/$f uniswap/v3/"$(basename $f)"
done
for f in interfaces/IPoolManager.sol interfaces/callback/IUnlockCallback.sol types/PoolKey.sol types/PoolOperation.sol; do
  get 0x498581fF718922c3f8e6A244956aF099B2652b2b lib/v4-core/src/$f uniswap/v4/"$(basename $f)"
done
(cd test/upstream && sha256sum -c SHA256SUMS)
```

## Not vendored

Their licences don't allow it, so only their code hashes are kept, in the table below, with the interfaces written for
this repository:

- BUSL-1.1: Aerodrome's `Pool` and `PoolFactory`, whose sources on Sourcify are a single flattened file; Algebra's
  `AlgebraPool`; Uniswap v3's `UniswapV3Pool` and `UniswapV3Factory`; Uniswap v4's `PoolManager`. Aerodrome's classic
  pools declare the same functions as Aero's and Hydrex's, which `script/check-signatures.sh` checks, and
  `test/Fork.t.sol` swaps through one.
- `LicenseRef-Dromos-Restricted-Use-1.0`: Aero's `FactoryRegistry`, fee modules, MEV tax modules and swap hook, which
  the swapper never calls; and Aero's new AERO token, an ERC-20 the AERO swapper pays out, with no fee or hook on
  transfers.
- Aero's CLPool implementation is verified only on Basescan, not on Sourcify.

## Addresses

`test/Fork.t.sol` checks each of these at block 52,855,000 (2026-10-20).

| Contract | Address | Code hash |
|---|---|---|
| Algebra factory, `HydrexAlgebra` | `0x36077D39cdC65E1e3FB65810430E5b2c4D5fA29E` | `0x6f54720c3eb4326e8cf846308b98ab0c0d070a441ca11ba8cd00be0256af7084` |
| Hydrex pair factory proxy, `HydrexClassic` | `0xC47F17c4fd96F50eFD2A2448ceDe5C185c084bf0` | `0xe9254068c76f9b19f4ab63f7a83b9f82f412362d41609faa232daa65f987bbac` |
| Hydrex pair factory implementation (ERC-1967 slot) | `0x421656a4fc9943a2a7997d6f4f6c04eb2e336d18` | `0x628fe0455fa1787ee8dd00677bccf958dd341f0d74039da40b0582080ac92f5e` |
| Hydrex pair factory `ProxyAdmin` (ERC-1967 slot), owned by a one-day timelock `0xdF52b5A03E3F5a4178E4F63e8BC51abE691B898F` | `0x6e25d241a3ba9e0278a296b398e9678e5ed8ad40` | `0xccdecaad56ab1bfab03e34ecf082661df958184c89254f7f2d5f31865abb90e0` |
| Aero volatile factory, `AeroVolatile` | `0x9bc8b3F60D349d687Fb44A018967025E3741F9a5` | `0x3ea9d13b9a7ecfa2c5ff590b0b5605cb3571373572cf4e161c0173baaf018759` |
| Aero volatile pool implementation | `0x8B64A0B590815d54C11a4B49A82b0133c7f53f0E` | `0x15269fbb3aca4305485be2669a8394ec6a14c75181e1eb4c2d46c5b1ee2a7782` |
| Aero stable factory, `AeroStable` | `0xaEd253F1aD84d99f2165256D701b2b481DD4CC16` | `0x7778ded3b75ecadd23f8fc322b1879a57cbbb0d7e3f548c3143eb9542ba4b8a2` |
| Aero stable pool implementation | `0x37D232368a22126a9584C7FF7643f26B2E276Ac8` | `0x9d1476a920eac769acf23251d79fd656f5566538080c06fc05573e5946b64a91` |
| Aero CLFactory, `AeroSlipstream` | `0xC6bdE6e9F0CD71013E5FcF2dAAE2fA1c71Bb2F25` | `0x725fdf87a8c681853acfc3b222120d01d603281f1e1d4377c4dac17054c76456` |
| Aero CLPool implementation, verified on Basescan | `0x0Df9fc8730eeC048e9832B31B4bFf4351158e19B` | `0x94f56a671c80e4670074161c0c5b4d032949d68bfa07191264dc11ed2b18db45` |
| Aero `FactoryRegistry`, listing the three Aero factories and no other | `0x7b2A2c12dC5Ea2a31455952a05031C3E4BB28F3E` | `0xcd0b88f96b36edf4d58c6b41119653e25d12bf52d1ea1cd7f636eab29cdb0bd1` |
| Aero volatile fee module (`CustomFeeModule`) | `0xEc4b9100C60B54579d44eA38165a152865840597` | `0x8826beb783dc6b6c44a392fac83a4a02cceb84bb2ae1e60fc70193565f15c44f` |
| Aero volatile MEV tax module (`PriorityFeeMevTaxModule`) | `0x1d52180B9049cb16f7db490bF1bB0ABEb992593d` | `0x59de6c7ead685b6295ef7dccb7ee30cd2881c697267d09718790f998db3cf016` |
| Aero stable fee module (`CustomFeeModule`) | `0x39CF8E719bae01C9ab6F9eA5b97DC7D74C76e422` | `0xf247ee419fe1dcfedf09c9939822a2276de0c9d2d45fd30330998a448345e803` |
| Aero stable MEV tax module (`PriorityFeeMevTaxModule`) | `0xA9Af4985CD8456d9aFf3185c31d9D66e53184d7B` | `0x59de6c7ead685b6295ef7dccb7ee30cd2881c697267d09718790f998db3cf016` |
| Aero CL default swap hook (`DynamicSwapFeeHook`) | `0xaAf164008441F112eB2858d9F7A2dB1B84b1E415` | `0xbc4dcb6544ee340d248fd21ccf8bc9c22261cdc7a011b053cfdca9b77981841f` |
| Aerodrome `PoolFactory`, `AerodromeClassic` | `0x420DD381b31aEf6683db6B902084cB0FFECe40Da` | `0xe2a176e5d2bcfb214b784ec6d6733708a6376a464f203cc265c284c9f349fea3` |
| Aerodrome pool implementation | `0xA4e46b4f701c62e14DF11B48dCe76A7d793CD6d7` | `0xd22754a0a3b39db7298dbbc2be1e34b34320988ea67065c85fa28ae66c02d31e` |
| Aerodrome CLFactory, `AerodromeSlipstream` | `0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A` | `0x7340cf80843bd721bcaefbfc050e38304cb4174c239e6e914e3056f27f39b11c` |
| Its CLPool implementation | `0xeC8E5342B19977B4eF8892e02D8DAEcfa1315831` | `0x772fb5c610b40a122036f544e5b9b5bce6becb19db9524331289d1aaed2d5888` |
| Aerodrome CLFactory, `AerodromeSlipstream2` | `0xaDe65c38CD4849aDBA595a4323a8C7DdfE89716a` | `0x0e72100f63ce8e32c95370fa9636d38c8cf434a820f2a7a69985e50930d2cb85` |
| Its CLPool implementation | `0x942e97a4c6FdC38B4CD1c0298D37d81fDD8E5A16` | `0x916bc5496cc07ea86289bc3a08a90f93dcae34686be6634f6e89ef260c3df4fa` |
| Aerodrome CLFactory, `AerodromeSlipstream3` | `0xf8f2eB4940CFE7d13603DDDD87f123820Fc061Ef` | `0x4961963494e47f363617ab9a0f3999a28b33c519e51392952db06350cce700bd` |
| Its CLPool implementation | `0xc770898522D2A9c8Da7A10D63989b6b58305B665` | `0xe63484f408c701770737a3c40e435c8183c66b1663f3a8777ce44dd73aff339b` |
| Aerodrome `FactoryRegistry`, listing the four Aerodrome factories and no other | `0x5C3F18F06CC09CA1910767A34a20F771039E37C0` | `0xd4a9f98ebd41e4c4e7ae646f1a1f8eaa1205100906f34299a3cd7e4ed567c929` |
| UniswapV2Factory, `UniswapV2` | `0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6` | `0xbab145d02e7005f0d84c6c1639d39b799b0ea16df99ebbdaf5a14d9da820b4e0` |
| UniswapV3Factory, `UniswapV3` | `0x33128a8fC17869897dcE68Ed026d694621f6FDfD` | `0x95707a4ac71f20181a63ef7d180e3c625be5d20fc8f6f980befa966bad568132` |
| PoolManager, `UniswapV4` | `0x498581fF718922c3f8e6A244956aF099B2652b2b` | `0x83b2af6e9f3158defc2811cbcb0db71ecf8b2ba2abea39c39e370ac5c6f43eb6` |
| Algebra factory owner, an account without code | `0x74266f2b206D1359B83fc74949EF07176FB3AE03` | |
| AERO, Aero's token since its v3 (`Token`), the AERO swapper's output | `0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee` | `0x4a7a844a493b672816a8adadf8500083dd100dd25976803f3964c079a819d0b9` |

Aero's new AERO is the `TOKEN` of its root `Voter`, `0x49d7d4f17Ec56Ef8fA04E464AF5D1A4942CC31e6`, reached from Aero's
`FactoryRegistry` through its `LeafVoter`, the `LeafMessageOrchestrator`'s adapter and the `RootMessageOrchestrator`.
At the pinned block, its 2.127 billion tokens sit with its two migration contracts, and it trades in no pool yet.

Only the Hydrex pair factory has an ERC-1967 implementation slot set. Aero's and Aerodrome's pools are EIP-1167 clones
of their factory's implementation: `test/Fork.t.sol` checks Aerodrome's four pools that it swaps through.

## Facts the design depends on

Line numbers are in the vendored files, unless a Sourcify link is given.

1. **Factories vouch only for their own pools.** Hydrex's `isPair` is set only by `createPair`
   ([`PairFactoryUpgradeable.sol`](hydrex/PairFactoryUpgradeable.sol#L122)); Aero's `isPool` only by `createPool`
   ([`PoolFactory.sol`](aero/PoolFactory.sol#L315-L326)). Algebra's `poolByPair`, Uniswap v2's `getPair` and Uniswap
   v3's `getPool` hold each pair's one pool, by fee for Uniswap v3. Anyone can create a pool for any two tokens.
2. **Concentrated pools pay first, then call back.** Each sends the output, then calls the callback on `msg.sender`
   with the two amounts, the positive one owed, and reverts unless its balance grew by that much
   ([`CLPool.sol`](aerodrome/slipstream/CLPool.sol#L854-L866);
   [`AlgebraPool.sol`](https://repo.sourcify.dev/8453/0x51f0B932855986B0E621c9D4DB6Eee1f4644D3D2) lines 264-279,
   then `_afterSwap`, where Hydrex's plugin trades). With an exact input, the input owed is the whole amount unless the
   price limit stops the swap.
3. **Classic pools price what they received.** A Solidly-style `swap` sends the output, counts its input as its
   balance less its reserve, takes its fee on that, and checks its invariant
   ([`Pair.sol`](hydrex/Pair.sol#L356-L389), [`Pool.sol`](aero/Pool.sol#L143-L199)). `to` cannot be either token
   (line 365, line 154). `getAmountOut` prices with the same fee and the same reserves
   ([`Pair.sol`](hydrex/Pair.sol#L443-L447)). Uniswap v2 takes 0.3%
   ([`UniswapV2Pair.sol`](uniswap/v2/UniswapV2Pair.sol#L159-L187)).
4. **Aero's fee depends on the caller.** `swap` and `getAmountOutWithTotalFee` both ask the factory's `getFee` with
   `msg.sender`, so a quote the swapper asks for itself during its hop matches its swap
   ([`Pool.sol`](aero/Pool.sol#L172), [`Pool.sol`](aero/Pool.sol#L389-L397),
   [`Pool.sol`](aero/Pool.sol#L548-L555)). `getAmountOut` asks `getBaseFee` with no caller and leaves the MEV tax out
   (lines 537-545). The MEV tax module reads the transaction's priority fee, and the total is capped at 20%
   ([`PoolFactory.sol`](aero/PoolFactory.sol#L271-L294)).
5. **Uniswap v4 settles at the end of `unlock`.** `swap` returns a `BalanceDelta`, negative for what the caller owes;
   `sync`, a transfer and `settle` pay; `take` collects; every currency's delta must be zero when the callback returns
   ([`IPoolManager.sol`](uniswap/v4/IPoolManager.sol)). A key with no hooks cannot have a dynamic fee, and `swap`
   reverts for a key that was never initialized.

## Selectors

`test/Selectors.t.sol` checks every row.

| Member | Selector | Declared in |
|---|---|---|
| `balanceOf(address)` | `0x70a08231` | ERC-20 |
| `allowance(address,address)` | `0xdd62ed3e` | ERC-20 |
| `transfer(address,uint256)` | `0xa9059cbb` | ERC-20 |
| `transferFrom(address,address,uint256)` | `0x23b872dd` | ERC-20 |
| `poolByPair(address,address)` | `0xd9a641e1` | `IAlgebraFactory.sol` |
| `isPair(address)` | `0xe5e31b13` | `IPairFactory.sol` |
| `isPool(address)` | `0x5b16ebb7` | `IPoolFactory.sol`, `ICLFactory.sol` |
| `getPair(address,address)` | `0xe6a43905` | `IUniswapV2Factory.sol` |
| `getPool(address,address,uint24)` | `0x1698ee82` | `IUniswapV3Factory.sol` |
| `token0()` | `0x0dfe1681` | `IPair.sol`, `IPool.sol`, `ICLPoolConstants.sol`, `IUniswapV3PoolImmutables.sol` |
| `token1()` | `0xd21220a7` | the same |
| `getReserves()` | `0x0902f1ac` | `IPair.sol`, `IPool.sol`, `IUniswapV2Pair.sol` |
| `getAmountOut(uint256,address)` | `0xf140a35a` | `IPair.sol`, `IPool.sol` |
| `getAmountOutWithTotalFee(uint256,address)` | `0x0ea099c1` | Aero's `IPool.sol` |
| `swap(uint256,uint256,address,bytes)` | `0x022c0d9f` | `IPair.sol`, `IPool.sol`, `IUniswapV2Pair.sol` |
| `fee()` | `0xddca3f43` | `IUniswapV3PoolImmutables.sol` |
| `swap(address,bool,int256,uint160,bytes)` | `0x128acb08` | `IAlgebraPoolActions.sol`, `ICLPoolActions.sol`, `IUniswapV3PoolActions.sol` |
| `unlock(bytes)` | `0x48c89491` | `IPoolManager.sol` |
| `swap((address,address,uint24,int24,address),(bool,int256,uint160),bytes)` | `0xf3cd914c` | `IPoolManager.sol` |
| `sync(address)` | `0xa5841194` | `IPoolManager.sol` |
| `settle()` | `0x11da60b4` | `IPoolManager.sol` |
| `take(address,address,uint256)` | `0x0b0d9c09` | `IPoolManager.sol` |
| `algebraSwapCallback(int256,int256,bytes)` | `0x2c8958f6` | `IAlgebraSwapCallback.sol` |
| `uniswapV3SwapCallback(int256,int256,bytes)` | `0xfa461e33` | `ICLSwapCallback.sol`, `IUniswapV3SwapCallback.sol` |
| `unlockCallback(bytes)` | `0x91dd7346` | `IUnlockCallback.sol` |

## Refreshing

Hydrex's pair factory and its pools' plugins are upgradeable, and the exchanges' admins can change fees, modules and
hooks. If one changes, `test/Fork.t.sol` still passes at its pinned block, so check the new code by hand: vendor its
files, run `script/check-signatures.sh`, regenerate `test/fixtures/fork.json` at a newer block with
`test/fixtures/generate.py`, and re-check the facts above. A changed fact may need a new deployment.
