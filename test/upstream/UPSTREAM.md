# Upstream pins

Byte-identical copies of the exchanges' files that `src/interfaces/` is checked against, where their licences allow.
Nothing in `src/` imports them and `foundry.toml` skips them. `script/check-signatures.sh` checks that every function
declared in `src/interfaces/`, other than ERC-20's, has the same signature here, and `test/Selectors.t.sol` pins every
selector.

## Vendored files

| Local file | Upstream | License |
|---|---|---|
| `aero/Pool.sol` | Aero volatile pool implementation, `V3/src/pools/Pool.sol` | GPL-3.0-or-later |
| `aero/IPool.sol` | Aero volatile pool implementation, `V3/src/interfaces/pools/IPool.sol` | MIT |
| `aero/PoolFactory.sol` | Aero volatile factory, `V3/src/factories/PoolFactory.sol` | GPL-3.0-or-later |
| `aero/IPoolFactory.sol` | Aero volatile factory, `V3/src/interfaces/factories/IPoolFactory.sol` | MIT |
| `aero/slipstream/CLPool.sol` | Aero CLPool implementation, `contracts/core/CLPool.sol` | GPL-2.0-or-later |
| `aero/slipstream/I*.sol` | Aero CLFactory, `contracts/core/interfaces/`: `ICLFactory.sol`, `pool/ICLPoolActions.sol`, `pool/ICLPoolConstants.sol`, `callback/ICLSwapCallback.sol` | GPL-2.0-or-later |
| `aero-lite/*.sol` | The same four paths as `aero/`, from Aero Lite's volatile pool implementation and volatile factory on Arc | the same as `aero/` |
| `aero-lite/slipstream/*.sol` | The same five paths as `aero/slipstream/`, from Aero Lite's CLPool implementation and CLFactory on Arc | GPL-2.0-or-later |
| `uniswap/v2/*.sol` | UniswapV2Factory, `contracts/UniswapV2Pair.sol`, `contracts/interfaces/IUniswapV2Factory.sol`, `contracts/interfaces/IUniswapV2Pair.sol` | GPL-3.0-or-later |
| `uniswap/v3/*.sol` | UniswapV3Factory, `contracts/interfaces/`: `IUniswapV3Factory.sol`, `pool/IUniswapV3PoolActions.sol`, `callback/IUniswapV3SwapCallback.sol` | GPL-2.0-or-later |
| `uniswap/v4/*.sol` | PoolManager, `lib/v4-core/src/`: `interfaces/IPoolManager.sol`, `interfaces/callback/IUnlockCallback.sol`, `types/PoolKey.sol`, `types/PoolOperation.sol` | MIT |
| `hydrex/Pair.sol` | Hydrex pair, `contracts/Pair.sol` | MIT |
| `hydrex/IPair.sol` | Hydrex pair, `contracts/interfaces/IPair.sol` | MIT |
| `hydrex/IPairFactory.sol` | Hydrex pair, `contracts/interfaces/IPairFactory.sol` | MIT |
| `hydrex/PairFactoryUpgradeable.sol` | Hydrex pair factory implementation, `contracts/factories/PairFactoryUpgradeable.sol` | MIT |
| `algebra/IAlgebraFactory.sol` | Algebra factory, `contracts/interfaces/IAlgebraFactory.sol` | GPL-2.0-or-later |
| `algebra/IAlgebraPoolActions.sol` | Algebra pool, `contracts/interfaces/pool/IAlgebraPoolActions.sol` | GPL-2.0-or-later |
| `algebra/IAlgebraSwapCallback.sol` | Algebra pool, `contracts/interfaces/callback/IAlgebraSwapCallback.sol` | GPL-2.0-or-later |

Uniswap v2's sources carry no SPDX header; `@uniswap/v2-core` is published under GPL-3.0-or-later.

| Source | Chain | Address | Sourcify | Compiler |
|---|---|---|---|---|
| Aero volatile pool implementation (`VolatilePool`) | Base | `0x0526cF035C1156b5C598b0d3c2445e38af2e8bDE` | [match](https://repo.sourcify.dev/8453/0x0526cF035C1156b5C598b0d3c2445e38af2e8bDE) | 0.8.36 |
| Aero volatile factory (`VolatilePoolFactory`) | Base | `0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2` | [match](https://repo.sourcify.dev/8453/0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2) | 0.8.36 |
| Aero CLFactory | Base | `0x9CB220581b91b0C83223012FE69688b92aD07a76` | [match](https://repo.sourcify.dev/8453/0x9CB220581b91b0C83223012FE69688b92aD07a76) | 0.7.6 |
| Aero CLPool implementation (`CLPool`) | Base | `0x1642634C8CB1C9f1B84c9a1a08534F8c3F4E89f8` | [match](https://repo.sourcify.dev/8453/0x1642634C8CB1C9f1B84c9a1a08534F8c3F4E89f8) | 0.7.6 |
| Aero Lite volatile pool implementation (`VolatilePool`) | Arc | `0x8B64A0B590815d54C11a4B49A82b0133c7f53f0E` | [exact match](https://repo.sourcify.dev/5042/0x8B64A0B590815d54C11a4B49A82b0133c7f53f0E) | 0.8.36 |
| Aero Lite volatile factory (`VolatilePoolFactory`) | Arc | `0x9bc8b3F60D349d687Fb44A018967025E3741F9a5` | [exact match](https://repo.sourcify.dev/5042/0x9bc8b3F60D349d687Fb44A018967025E3741F9a5) | 0.8.36 |
| Aero Lite CLFactory | Arc | `0xb89Df768aF2CFE637ceB352c587Fe8edAf491d03` | [match](https://repo.sourcify.dev/5042/0xb89Df768aF2CFE637ceB352c587Fe8edAf491d03) | 0.7.6 |
| Aero Lite CLPool implementation (`CLPool`) | Arc | `0x0Df9fc8730eeC048e9832B31B4bFf4351158e19B` | [match](https://repo.sourcify.dev/5042/0x0Df9fc8730eeC048e9832B31B4bFf4351158e19B) | 0.7.6 |
| UniswapV2Factory | Base | `0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6` | [exact match](https://repo.sourcify.dev/8453/0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6) | 0.5.16 |
| UniswapV3Factory | Base | `0x33128a8fC17869897dcE68Ed026d694621f6FDfD` | [match](https://repo.sourcify.dev/8453/0x33128a8fC17869897dcE68Ed026d694621f6FDfD) | 0.7.6 |
| PoolManager | Base | `0x498581fF718922c3f8e6A244956aF099B2652b2b` | [match](https://repo.sourcify.dev/8453/0x498581fF718922c3f8e6A244956aF099B2652b2b) | 0.8.26 |
| Hydrex pair (`Pair`), volatile HYDX/USDC | Base | `0x605abD1873737CA9a9Ec1CFa52CDfc8ef62c2E1d` | [match](https://repo.sourcify.dev/8453/0x605abD1873737CA9a9Ec1CFa52CDfc8ef62c2E1d) | 0.8.13 |
| Hydrex pair factory implementation (`PairFactoryUpgradeable`) | Base | `0x421656a4fc9943a2a7997d6f4f6c04eb2e336d18` | [match](https://repo.sourcify.dev/8453/0x421656a4fc9943a2a7997d6f4f6c04eb2e336d18) | 0.8.13 |
| Algebra factory (`AlgebraFactory`) | Base | `0x36077D39cdC65E1e3FB65810430E5b2c4D5fA29E` | [match](https://repo.sourcify.dev/8453/0x36077D39cdC65E1e3FB65810430E5b2c4D5fA29E) | 0.8.20 |
| Algebra pool (`AlgebraPool`), HYDX/USDC | Base | `0x51f0B932855986B0E621c9D4DB6Eee1f4644D3D2` | [match](https://repo.sourcify.dev/8453/0x51f0B932855986B0E621c9D4DB6Eee1f4644D3D2) | 0.8.20 |

A "match", unlike an "exact match", means the bytecode matches but the metadata hash differs, so comments may differ
from what was compiled. Sourcify's entries for UniswapV3Factory and PoolManager also hold unrelated copies of their
files; only the compilation target's own paths are vendored. The other chains run the same pool implementations as
Base, at the same addresses with the same code hashes, but for Aero Lite's, which only Arc has. The vendored files are
fetched with the commands below, and `SHA256SUMS` holds their hashes:

```
fetch() { curl -sS "https://sourcify.dev/server/v2/contract/$1/$2?fields=sources" > "/tmp/$2.json"; }
for a in 0x0526cF035C1156b5C598b0d3c2445e38af2e8bDE 0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2 0x9CB220581b91b0C83223012FE69688b92aD07a76 0x1642634C8CB1C9f1B84c9a1a08534F8c3F4E89f8 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6 0x33128a8fC17869897dcE68Ed026d694621f6FDfD 0x498581fF718922c3f8e6A244956aF099B2652b2b 0x605abD1873737CA9a9Ec1CFa52CDfc8ef62c2E1d 0x421656a4fc9943a2a7997d6f4f6c04eb2e336d18 0x36077D39cdC65E1e3FB65810430E5b2c4D5fA29E 0x51f0B932855986B0E621c9D4DB6Eee1f4644D3D2; do
  fetch 8453 $a
done
for a in 0x8B64A0B590815d54C11a4B49A82b0133c7f53f0E 0x9bc8b3F60D349d687Fb44A018967025E3741F9a5 0xb89Df768aF2CFE637ceB352c587Fe8edAf491d03 0x0Df9fc8730eeC048e9832B31B4bFf4351158e19B; do
  fetch 5042 $a
done
U=test/upstream
mkdir -p $U/aero/slipstream $U/aero-lite/slipstream $U/uniswap/v2 $U/uniswap/v3 $U/uniswap/v4 $U/hydrex $U/algebra
get() { jq -j --arg k "$2" '.sources[$k].content' "/tmp/$1.json" > "$U/$3"; }
aero() { # pool implementation, factory, CLFactory, CLPool implementation, directory
  get $1 V3/src/pools/Pool.sol $5/Pool.sol
  get $1 V3/src/interfaces/pools/IPool.sol $5/IPool.sol
  get $2 V3/src/factories/PoolFactory.sol $5/PoolFactory.sol
  get $2 V3/src/interfaces/factories/IPoolFactory.sol $5/IPoolFactory.sol
  for f in interfaces/ICLFactory.sol interfaces/pool/ICLPoolActions.sol interfaces/pool/ICLPoolConstants.sol interfaces/callback/ICLSwapCallback.sol; do
    get $3 contracts/core/$f $5/slipstream/"$(basename $f)"
  done
  get $4 contracts/core/CLPool.sol $5/slipstream/CLPool.sol
}
aero 0x0526cF035C1156b5C598b0d3c2445e38af2e8bDE 0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2 0x9CB220581b91b0C83223012FE69688b92aD07a76 0x1642634C8CB1C9f1B84c9a1a08534F8c3F4E89f8 aero
aero 0x8B64A0B590815d54C11a4B49A82b0133c7f53f0E 0x9bc8b3F60D349d687Fb44A018967025E3741F9a5 0xb89Df768aF2CFE637ceB352c587Fe8edAf491d03 0x0Df9fc8730eeC048e9832B31B4bFf4351158e19B aero-lite
for f in UniswapV2Pair.sol interfaces/IUniswapV2Factory.sol interfaces/IUniswapV2Pair.sol; do
  get 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6 contracts/$f uniswap/v2/"$(basename $f)"
done
for f in IUniswapV3Factory.sol pool/IUniswapV3PoolActions.sol callback/IUniswapV3SwapCallback.sol; do
  get 0x33128a8fC17869897dcE68Ed026d694621f6FDfD contracts/interfaces/$f uniswap/v3/"$(basename $f)"
done
for f in interfaces/IPoolManager.sol interfaces/callback/IUnlockCallback.sol types/PoolKey.sol types/PoolOperation.sol; do
  get 0x498581fF718922c3f8e6A244956aF099B2652b2b lib/v4-core/src/$f uniswap/v4/"$(basename $f)"
done
get 0x605abD1873737CA9a9Ec1CFa52CDfc8ef62c2E1d contracts/Pair.sol hydrex/Pair.sol
get 0x605abD1873737CA9a9Ec1CFa52CDfc8ef62c2E1d contracts/interfaces/IPair.sol hydrex/IPair.sol
get 0x605abD1873737CA9a9Ec1CFa52CDfc8ef62c2E1d contracts/interfaces/IPairFactory.sol hydrex/IPairFactory.sol
get 0x421656a4fc9943a2a7997d6f4f6c04eb2e336d18 contracts/factories/PairFactoryUpgradeable.sol hydrex/PairFactoryUpgradeable.sol
get 0x36077D39cdC65E1e3FB65810430E5b2c4D5fA29E contracts/interfaces/IAlgebraFactory.sol algebra/IAlgebraFactory.sol
get 0x51f0B932855986B0E621c9D4DB6Eee1f4644D3D2 contracts/interfaces/pool/IAlgebraPoolActions.sol algebra/IAlgebraPoolActions.sol
get 0x51f0B932855986B0E621c9D4DB6Eee1f4644D3D2 contracts/interfaces/callback/IAlgebraSwapCallback.sol algebra/IAlgebraSwapCallback.sol
(cd test/upstream && sha256sum -c SHA256SUMS)
```

## Not vendored

Their licences don't allow it, so only their code hashes are kept, in the tables below, with the interfaces written for
this repository:

- `LicenseRef-Dromos-Restricted-Use-1.0`: Aero's and Aero Lite's `FactoryRegistry`, fee modules, MEV tax modules and
  swap hooks, which the swapper never calls; and Aero's new AERO token, an ERC-20 the AERO swapper pays out, with no
  fee or hook on transfers.
- BUSL-1.1: Uniswap v3's `UniswapV3Pool` and `UniswapV3Factory`; Uniswap v4's `PoolManager`; Algebra's `AlgebraPool`.

## Addresses

`test/fork/<Chain>.t.sol` checks each of these at the block of `test/fixtures/<chain>.json`. It also checks that each
chain's Aero `FactoryRegistry` lists exactly the Aero factories that `script/Deploy.s.sol` gives that chain, and that
every Aero pool it swaps through is an EIP-1167 clone of its factory's implementation.

### Base, chain 8453, block 52,889,510

| Contract | Address | Code hash |
|---|---|---|
| Aero volatile factory, `AeroClassic` | `0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2` | `0x975417bdbc8e5df051479a271f5a03582df5f09f179771c68e2708dddeb56ef0` |
| Aero volatile pool implementation | `0x0526cF035C1156b5C598b0d3c2445e38af2e8bDE` | `0x15269fbb3aca4305485be2669a8394ec6a14c75181e1eb4c2d46c5b1ee2a7782` |
| Aero volatile fee module (`CustomFeeModule`) | `0x7949DE8d67E4F6b8509Bdbb43FF0503aF1247a7A` | `0xa56614fe447178e62c473ff1333d660c1dbb70965b4a059fae228bf52457c0f2` |
| Aero volatile MEV tax module (`PriorityFeeMevTaxModule`) | `0x830D07BDe136752BCefe0B59a14c2C7af07814AF` | `0x59de6c7ead685b6295ef7dccb7ee30cd2881c697267d09718790f998db3cf016` |
| Aero stable factory, `AeroClassic` | `0x78589E876edcEbdce72ee3436ab3c9AD3a7cEF2D` | `0x3b34cd7ed303be01986b097c49f1a29d211783ef63f5e920db0ffb9291396cc2` |
| Aero stable pool implementation | `0xf525988f88B7D8b64631D86070FEC5BFDc50C174` | `0x9d1476a920eac769acf23251d79fd656f5566538080c06fc05573e5946b64a91` |
| Aero stable fee module (`CustomFeeModule`) | `0x0195fC76Da986D66B2A468133a1be41E90893Da6` | `0xe0c19912c35391d5bd218fc0903c3116d9915dc36b4f0b93eb75cf19932c12ac` |
| Aero stable MEV tax module (`PriorityFeeMevTaxModule`) | `0x78ee48646a7e1507B79443a1d5494095D16AF3B8` | `0x59de6c7ead685b6295ef7dccb7ee30cd2881c697267d09718790f998db3cf016` |
| Aero CLFactory, `AeroSlipstream` | `0x9CB220581b91b0C83223012FE69688b92aD07a76` | `0x6c09090837ace0aefe6bfa24a3bc772d13a9775b7e3109c9fece534a0ce053a6` |
| Aero CLPool implementation | `0x1642634C8CB1C9f1B84c9a1a08534F8c3F4E89f8` | `0x041172c7cbffc45627f9dd52727a0124cd6eeb2b5830ab392df54f71a6948693` |
| Aero CL default swap hook (`DynamicSwapFeeHook`) | `0xC0ed888AfE87ed1AcF01D9f19bB850159e3ce434` | `0x198b45ce022f423a9852526890d236531333e97861078501357e1c72f0eeecbd` |
| Aero `FactoryRegistry`, listing the three Aero factories and no other | `0x7b2A2c12dC5Ea2a31455952a05031C3E4BB28F3E` | `0xcd0b88f96b36edf4d58c6b41119653e25d12bf52d1ea1cd7f636eab29cdb0bd1` |
| UniswapV2Factory, `UniswapV2` | `0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6` | `0xbab145d02e7005f0d84c6c1639d39b799b0ea16df99ebbdaf5a14d9da820b4e0` |
| UniswapV3Factory, `UniswapV3` | `0x33128a8fC17869897dcE68Ed026d694621f6FDfD` | `0x95707a4ac71f20181a63ef7d180e3c625be5d20fc8f6f980befa966bad568132` |
| PoolManager, `UniswapV4` | `0x498581fF718922c3f8e6A244956aF099B2652b2b` | `0x83b2af6e9f3158defc2811cbcb0db71ecf8b2ba2abea39c39e370ac5c6f43eb6` |
| Hydrex pair factory proxy, `HydrexClassic` | `0xC47F17c4fd96F50eFD2A2448ceDe5C185c084bf0` | `0xe9254068c76f9b19f4ab63f7a83b9f82f412362d41609faa232daa65f987bbac` |
| Hydrex pair factory implementation (ERC-1967 slot) | `0x421656a4fc9943a2a7997d6f4f6c04eb2e336d18` | `0x628fe0455fa1787ee8dd00677bccf958dd341f0d74039da40b0582080ac92f5e` |
| Hydrex pair factory `ProxyAdmin` (ERC-1967 slot), owned by a one-day timelock `0xdF52b5A03E3F5a4178E4F63e8BC51abE691B898F` | `0x6e25d241a3ba9e0278a296b398e9678e5ed8ad40` | `0xccdecaad56ab1bfab03e34ecf082661df958184c89254f7f2d5f31865abb90e0` |
| Algebra factory, `HydrexAlgebra` | `0x36077D39cdC65E1e3FB65810430E5b2c4D5fA29E` | `0x6f54720c3eb4326e8cf846308b98ab0c0d070a441ca11ba8cd00be0256af7084` |
| Algebra factory owner, an account without code | `0x74266f2b206D1359B83fc74949EF07176FB3AE03` | |
| AERO, Aero's token since its v3 (`Token`), the AERO swapper's output | `0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee` | `0x4a7a844a493b672816a8adadf8500083dd100dd25976803f3964c079a819d0b9` |

Aero's new AERO is the `TOKEN` of its root `Voter`, `0x49d7d4f17Ec56Ef8fA04E464AF5D1A4942CC31e6`, reached from Aero's
`FactoryRegistry` through its `LeafVoter`, the `LeafMessageOrchestrator`'s adapter and the `RootMessageOrchestrator`.
At the pinned block, its 2.127 billion tokens sit with its two migration contracts, and it trades in no pool yet.

Only the Hydrex pair factory has an ERC-1967 implementation slot set.

### Ethereum, chain 1, block 26,249,926

| Contract | Address | Code hash |
|---|---|---|
| Aero volatile factory, `AeroClassic` | `0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2` | `0x45c305d6825d576c93eeaf61da718391f70f80e3677caef2ebb26fbc94d0923c` |
| Aero volatile pool implementation | `0x0526cF035C1156b5C598b0d3c2445e38af2e8bDE` | `0x15269fbb3aca4305485be2669a8394ec6a14c75181e1eb4c2d46c5b1ee2a7782` |
| Aero stable factory, `AeroClassic` | `0x78589E876edcEbdce72ee3436ab3c9AD3a7cEF2D` | `0x128a5d36260b010f7cb09a83f01b4910a57fe680e273d4eb7fab81c05ed9ee1f` |
| Aero stable pool implementation | `0xf525988f88B7D8b64631D86070FEC5BFDc50C174` | `0x9d1476a920eac769acf23251d79fd656f5566538080c06fc05573e5946b64a91` |
| Aero CLFactory, `AeroSlipstream` | `0xF4Fd2E6c5B60c5b365cd1B96DD6245E6D60414c2` | `0x3e53af145d8106d91fad73c6dbbbfe3229c5aa96aab1e18a4bf49a705c773ef5` |
| Aero CLPool implementation | `0x1642634C8CB1C9f1B84c9a1a08534F8c3F4E89f8` | `0x041172c7cbffc45627f9dd52727a0124cd6eeb2b5830ab392df54f71a6948693` |
| Aero CL default swap hook | `0xC0ed888AfE87ed1AcF01D9f19bB850159e3ce434` | `0xd64b9e760431c312c53515167ffb260b357705388da9354f31095d974e19e449` |
| Aero `FactoryRegistry`, listing the three Aero factories and no other | `0xdd1705e23762F4D6e44D8C31BD8Ea80c54612239` | `0xcd0b88f96b36edf4d58c6b41119653e25d12bf52d1ea1cd7f636eab29cdb0bd1` |
| UniswapV2Factory, `UniswapV2` | `0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f` | `0xbab145d02e7005f0d84c6c1639d39b799b0ea16df99ebbdaf5a14d9da820b4e0` |
| UniswapV3Factory, `UniswapV3` | `0x1F98431c8aD98523631AE4a59f267346ea31F984` | `0x4d7b8525cd5d14343fa67a732fba5b24cddba11620ca88392f4ec6c52f91fd69` |
| PoolManager, `UniswapV4` | `0x000000000004444c5dc75cB358380D2e3dE08A90` | `0x785f1014552b7ce7d5fb7d0c970ca60edee94fd00425d7ca21609acac7ce1293` |

### OP Mainnet, chain 10, block 158,547,340

| Contract | Address | Code hash |
|---|---|---|
| Aero volatile factory, `AeroClassic` | `0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2` | `0xbb6f945479608857a220f9643db76e877f1e52844d953d980c18f5ea38d9574b` |
| Aero volatile pool implementation | `0x0526cF035C1156b5C598b0d3c2445e38af2e8bDE` | `0x15269fbb3aca4305485be2669a8394ec6a14c75181e1eb4c2d46c5b1ee2a7782` |
| Aero stable factory, `AeroClassic` | `0x78589E876edcEbdce72ee3436ab3c9AD3a7cEF2D` | `0xd3799dedbfe65478b3e321b709d9206e88243fbfa9064b9ca3a7d03a49989471` |
| Aero stable pool implementation | `0xf525988f88B7D8b64631D86070FEC5BFDc50C174` | `0x9d1476a920eac769acf23251d79fd656f5566538080c06fc05573e5946b64a91` |
| Aero CLFactory, `AeroSlipstream` | `0xfeaB42D90055db3a0616249f76B6002D72266778` | `0x68e96345f7fdc80c927fd25a04f6f5846cdd00173f031eae7517722a67103c7a` |
| Aero CLPool implementation | `0x1642634C8CB1C9f1B84c9a1a08534F8c3F4E89f8` | `0x041172c7cbffc45627f9dd52727a0124cd6eeb2b5830ab392df54f71a6948693` |
| Aero CL default swap hook | `0xC0ed888AfE87ed1AcF01D9f19bB850159e3ce434` | `0x3064a620b37842c2e0ff3ea7619d7eac49197bd4b247955e7250250dc1ae1239` |
| Aero `FactoryRegistry`, listing the three Aero factories and no other | `0xb6F9705A631CC1C0E8570FFde48882C95E2Df408` | `0xcd0b88f96b36edf4d58c6b41119653e25d12bf52d1ea1cd7f636eab29cdb0bd1` |
| UniswapV2Factory, `UniswapV2` | `0x0c3c1c532F1e39EdF36BE9Fe0bE1410313E074Bf` | `0xbab145d02e7005f0d84c6c1639d39b799b0ea16df99ebbdaf5a14d9da820b4e0` |
| UniswapV3Factory, `UniswapV3` | `0x1F98431c8aD98523631AE4a59f267346ea31F984` | `0x4d7b8525cd5d14343fa67a732fba5b24cddba11620ca88392f4ec6c52f91fd69` |
| PoolManager, `UniswapV4` | `0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3` | `0xa17a06da5d39984d2a3ef2704e090496d7f3658a65fda0b81c5cd6e809e5c5e4` |

### Robinhood Chain, chain 4663, block 95,317,324

| Contract | Address | Code hash |
|---|---|---|
| Aero volatile factory, `AeroClassic` | `0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2` | `0x45c305d6825d576c93eeaf61da718391f70f80e3677caef2ebb26fbc94d0923c` |
| Aero volatile pool implementation | `0x0526cF035C1156b5C598b0d3c2445e38af2e8bDE` | `0x15269fbb3aca4305485be2669a8394ec6a14c75181e1eb4c2d46c5b1ee2a7782` |
| Aero stable factory, `AeroClassic` | `0x78589E876edcEbdce72ee3436ab3c9AD3a7cEF2D` | `0x128a5d36260b010f7cb09a83f01b4910a57fe680e273d4eb7fab81c05ed9ee1f` |
| Aero stable pool implementation | `0xf525988f88B7D8b64631D86070FEC5BFDc50C174` | `0x9d1476a920eac769acf23251d79fd656f5566538080c06fc05573e5946b64a91` |
| Aero CLFactory, `AeroSlipstream` | `0xc63d7338c178e805c544B8f897066bD3BBcBE136` | `0x3e53af145d8106d91fad73c6dbbbfe3229c5aa96aab1e18a4bf49a705c773ef5` |
| Aero CLPool implementation | `0x1642634C8CB1C9f1B84c9a1a08534F8c3F4E89f8` | `0x041172c7cbffc45627f9dd52727a0124cd6eeb2b5830ab392df54f71a6948693` |
| Aero CL default swap hook | `0xC0ed888AfE87ed1AcF01D9f19bB850159e3ce434` | `0xcbeeeb0c4af5dec3426c4d6484190547ea03e88da5df3a78659a0451a4cf992f` |
| Aero `FactoryRegistry`, listing the three Aero factories and no other | `0xdd1705e23762F4D6e44D8C31BD8Ea80c54612239` | `0xcd0b88f96b36edf4d58c6b41119653e25d12bf52d1ea1cd7f636eab29cdb0bd1` |
| UniswapV2Factory, `UniswapV2` | `0x8bcEaA40B9AcdfAedF85AdF4FF01F5Ad6517937f` | `0xbab145d02e7005f0d84c6c1639d39b799b0ea16df99ebbdaf5a14d9da820b4e0` |
| UniswapV3Factory, `UniswapV3` | `0x1f7d7550B1b028f7571E69A784071F0205FD2EfA` | `0xec72b1abd1f2faee020cfea9c646bd8994f9fb389054f6e574f103a895091739` |
| PoolManager, `UniswapV4` | `0x8366a39CC670B4001A1121B8F6A443A643e40951` | `0xbd3881180b547f5fe817545743cfb4343e96b1bc6640dcd70c106b0066e95626` |

### Arc, chain 5042, block 27,325,357

| Contract | Address | Code hash |
|---|---|---|
| Aero volatile factory, `AeroClassic` | `0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2` | `0x9c0e0261ae27222603b3243d66a305513a832d8044b86dc27c49c5e1f491ec0a` |
| Aero volatile pool implementation | `0x0526cF035C1156b5C598b0d3c2445e38af2e8bDE` | `0x15269fbb3aca4305485be2669a8394ec6a14c75181e1eb4c2d46c5b1ee2a7782` |
| Aero stable factory, `AeroClassic` | `0x78589E876edcEbdce72ee3436ab3c9AD3a7cEF2D` | `0xfbd6234a243d9f7cf7965a13dc757b060a3870ea0d5bfe3ca7d32152e3e0aa21` |
| Aero stable pool implementation | `0xf525988f88B7D8b64631D86070FEC5BFDc50C174` | `0x9d1476a920eac769acf23251d79fd656f5566538080c06fc05573e5946b64a91` |
| Aero Lite volatile factory, `AeroClassic` | `0x9bc8b3F60D349d687Fb44A018967025E3741F9a5` | `0x82491cab7234b219a824f8964e4d32504ac046bcc792ca743bd3bcc7cfbb9ede` |
| Aero Lite volatile pool implementation | `0x8B64A0B590815d54C11a4B49A82b0133c7f53f0E` | `0x80ec6cbe60514c410211bdd097b61f738fe71cbf49cc9b1f36c73c7fb66ec1d3` |
| Aero Lite stable factory, `AeroClassic` | `0xaEd253F1aD84d99f2165256D701b2b481DD4CC16` | `0xfd96a6520f18a68b5e1c144bce46458cbb38a19ae8e439102eae633ddb164589` |
| Aero Lite stable pool implementation | `0x37D232368a22126a9584C7FF7643f26B2E276Ac8` | `0xe23c6b394862a2a198e7d21598d2b71d80a05f699ca58316b95686eff8bca3bf` |
| Aero CLFactory, `AeroSlipstream` | `0x7F83235643181E440433400a027618Cd50879751` | `0xa1e59904fa067e5c6dd0fb484a46a61a49eb583dac80777bb51c9544d551af77` |
| Aero CLPool implementation | `0x1642634C8CB1C9f1B84c9a1a08534F8c3F4E89f8` | `0x041172c7cbffc45627f9dd52727a0124cd6eeb2b5830ab392df54f71a6948693` |
| Aero CL default swap hook | `0xC0ed888AfE87ed1AcF01D9f19bB850159e3ce434` | `0x056d298da414cbec176a47008aa320ee36ca3ff40668fcf1cda093d2597fa065` |
| Aero Lite CLFactory, `AeroSlipstream` | `0xb89Df768aF2CFE637ceB352c587Fe8edAf491d03` | `0xfcb0b3e8be0294ebf546cc52702f2d1ed8981e64071f2d2e67175f01235ea9aa` |
| Aero Lite CLPool implementation | `0x0Df9fc8730eeC048e9832B31B4bFf4351158e19B` | `0x24af4ff3d49c0a4eeb1ca6aca081d865c0a889d7c239017bdb78fde920ae6e02` |
| Aero Lite CL default swap hook | `0xaAf164008441F112eB2858d9F7A2dB1B84b1E415` | `0x51cae5346f98a27fa8ced490328d85a172dee7c07efc3160f903964a414fa5f9` |
| Aero `FactoryRegistry`, listing the six Aero factories and no other | `0xCe44907DC45D3BFa3f5f6035B0e6E8B22D780A42` | `0x7b99eb4042fd62042cdb3e57683ff9beb485195a23177bf504dd213ddcbf2c07` |
| UniswapV2Factory, `UniswapV2` | `0x89e5DB8B5aA49aA85AC63f691524311AEB649eba` | `0xbab145d02e7005f0d84c6c1639d39b799b0ea16df99ebbdaf5a14d9da820b4e0` |
| UniswapV3Factory, `UniswapV3` | `0xf0db7b58379503491d857dB50AC9ece64c653918` | `0x621c4819f7b62d7ddb153206bc30950bcc3f5cc9d24c45661f8c2f31dcbd166d` |
| PoolManager, `UniswapV4` | `0x8366a39CC670B4001A1121B8F6A443A643e40951` | `0xbd3881180b547f5fe817545743cfb4343e96b1bc6640dcd70c106b0066e95626` |

### Arbitrum One, chain 42161, block 517,302,790

| Contract | Address | Code hash |
|---|---|---|
| Aero volatile factory, `AeroClassic` | `0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2` | `0x8fa15c35a133b821f880208b467be3224edba0811edcd002876bf8d53cf6ff35` |
| Aero volatile pool implementation | `0x0526cF035C1156b5C598b0d3c2445e38af2e8bDE` | `0x15269fbb3aca4305485be2669a8394ec6a14c75181e1eb4c2d46c5b1ee2a7782` |
| Aero stable factory, `AeroClassic` | `0x78589E876edcEbdce72ee3436ab3c9AD3a7cEF2D` | `0xb9e3a337a90bf6870d95f3394be419367c402027a877e4b5c178fe102b447f0c` |
| Aero stable pool implementation | `0xf525988f88B7D8b64631D86070FEC5BFDc50C174` | `0x9d1476a920eac769acf23251d79fd656f5566538080c06fc05573e5946b64a91` |
| Aero CLFactory, `AeroSlipstream` | `0x88a60ee77392577c355C0acb2A8d476D5a4EC03a` | `0x4cb82764ba4fd4a80c986952190a6052747a816a6dc5c7be3fc3a7a7b1bd0af4` |
| Aero CLPool implementation | `0x1642634C8CB1C9f1B84c9a1a08534F8c3F4E89f8` | `0x041172c7cbffc45627f9dd52727a0124cd6eeb2b5830ab392df54f71a6948693` |
| Aero CL default swap hook | `0xC0ed888AfE87ed1AcF01D9f19bB850159e3ce434` | `0xbc9d92d8836ab8e1216cec5321922fe861b31bc2aa4906bc934500aa0d2dad47` |
| Aero `FactoryRegistry`, listing the three Aero factories and no other | `0x9E635b2c689fC52201DF7eF1C9FA607c2F58f666` | `0xcd0b88f96b36edf4d58c6b41119653e25d12bf52d1ea1cd7f636eab29cdb0bd1` |
| UniswapV2Factory, `UniswapV2` | `0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9` | `0xbab145d02e7005f0d84c6c1639d39b799b0ea16df99ebbdaf5a14d9da820b4e0` |
| UniswapV3Factory, `UniswapV3` | `0x1F98431c8aD98523631AE4a59f267346ea31F984` | `0x4d7b8525cd5d14343fa67a732fba5b24cddba11620ca88392f4ec6c52f91fd69` |
| PoolManager, `UniswapV4` | `0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32` | `0xe4b2759e456c9c4ef763e3b4e257c5105e1ba283d7de8b131dd321197de794a4` |

### Ink, chain 57073, block 59,195,574

| Contract | Address | Code hash |
|---|---|---|
| Aero volatile factory, `AeroClassic` | `0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2` | `0x45c305d6825d576c93eeaf61da718391f70f80e3677caef2ebb26fbc94d0923c` |
| Aero volatile pool implementation | `0x0526cF035C1156b5C598b0d3c2445e38af2e8bDE` | `0x15269fbb3aca4305485be2669a8394ec6a14c75181e1eb4c2d46c5b1ee2a7782` |
| Aero stable factory, `AeroClassic` | `0x78589E876edcEbdce72ee3436ab3c9AD3a7cEF2D` | `0x128a5d36260b010f7cb09a83f01b4910a57fe680e273d4eb7fab81c05ed9ee1f` |
| Aero stable pool implementation | `0xf525988f88B7D8b64631D86070FEC5BFDc50C174` | `0x9d1476a920eac769acf23251d79fd656f5566538080c06fc05573e5946b64a91` |
| Aero CLFactory, `AeroSlipstream` | `0x7660BF2aDefC687C22906112ca323d60A00358cF` | `0x3e53af145d8106d91fad73c6dbbbfe3229c5aa96aab1e18a4bf49a705c773ef5` |
| Aero CLPool implementation | `0x1642634C8CB1C9f1B84c9a1a08534F8c3F4E89f8` | `0x041172c7cbffc45627f9dd52727a0124cd6eeb2b5830ab392df54f71a6948693` |
| Aero CL default swap hook | `0xC0ed888AfE87ed1AcF01D9f19bB850159e3ce434` | `0x09b696276cc3063d992898f47c6ba75391c3591e71b1a24ca27b4b6aba0cbd4f` |
| Aero `FactoryRegistry`, listing the three Aero factories and no other | `0xdd1705e23762F4D6e44D8C31BD8Ea80c54612239` | `0xcd0b88f96b36edf4d58c6b41119653e25d12bf52d1ea1cd7f636eab29cdb0bd1` |
| UniswapV2Factory, `UniswapV2` | `0xfe57A6BA1951F69aE2Ed4abe23e0f095DF500C04` | `0xbab145d02e7005f0d84c6c1639d39b799b0ea16df99ebbdaf5a14d9da820b4e0` |
| UniswapV3Factory, `UniswapV3` | `0x640887A9ba3A9C53Ed27D0F7e8246A4F933f3424` | `0x63cc169798967d476c6cddf442332f95c1a38c97457a5e1a6a46c7bee6bcef64` |
| PoolManager, `UniswapV4` | `0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32` | `0xe4b2759e456c9c4ef763e3b4e257c5105e1ba283d7de8b131dd321197de794a4` |

The Aero factories' code hashes differ from chain to chain, as do those of the swap hooks and of most Uniswap
factories, because their code holds immutables, such as the Aero factories' registry or the Uniswap contracts' own
address. Every chain's Aero pools clone the same
implementations as Base's, but for Aero Lite's on Arc.

## Facts the design depends on

Line numbers are in the vendored files, unless a Sourcify link is given.

1. **Factories vouch only for their own pools.** Aero's `isPool` is set only by `createPool`
   ([`PoolFactory.sol`](aero/PoolFactory.sol#L326-L337)), and the CLFactory's only by its own `createPool`
   ([`CLFactory.sol`](https://repo.sourcify.dev/8453/0x9CB220581b91b0C83223012FE69688b92aD07a76) line 123).
   Hydrex's `isPair` is set only by `createPair`
   ([`PairFactoryUpgradeable.sol`](hydrex/PairFactoryUpgradeable.sol#L122)). Uniswap v2's `getPair`, Uniswap v3's
   `getPool` and Algebra's `poolByPair` hold each pair's one pool, by fee for Uniswap v3. Anyone can create a pool for
   any two tokens.
2. **Concentrated pools pay first, then call back.** Each sends the output, then calls the callback on `msg.sender`
   with the two amounts, the positive one owed, and reverts unless its balance grew by that much
   ([`CLPool.sol`](aero/slipstream/CLPool.sol#L707-L720);
   [`AlgebraPool.sol`](https://repo.sourcify.dev/8453/0x51f0B932855986B0E621c9D4DB6Eee1f4644D3D2) lines 264-279,
   then `_afterSwap`, where Hydrex's plugin trades). With an exact input, the input owed is the whole amount unless the
   price limit stops the swap.
3. **Classic pools price what they received.** A Solidly-style `swap` sends the output, counts its input as its
   balance less its reserve, takes its fee on that, and checks its invariant
   ([`Pool.sol`](aero/Pool.sol#L143-L199), [`Pair.sol`](hydrex/Pair.sol#L356-L389)). `to` cannot be either token
   (line 154, line 365). `getAmountOut` prices with the same fee and the same reserves
   ([`Pair.sol`](hydrex/Pair.sol#L443-L447)). Uniswap v2 takes 0.3%
   ([`UniswapV2Pair.sol`](uniswap/v2/UniswapV2Pair.sol#L159-L187)). Anyone can call `sync`, which sets the reserves to
   the balances ([`Pool.sol`](aero/Pool.sol#L260-L262), [`UniswapV2Pair.sol`](uniswap/v2/UniswapV2Pair.sol#L198-L200),
   [`Pair.sol`](hydrex/Pair.sol#L399-L401)), so after it the only input is what is sent next.
4. **Aero's fee depends on the caller.** `swap` and `getAmountOutWithTotalFee` both ask the factory's `getFee` with
   `msg.sender`, so a quote the swapper asks for itself during its hop matches its swap, once the pool is synced:
   `swap` passes the fee module what it counts as input on both sides
   ([`Pool.sol`](aero/Pool.sol#L172), [`Pool.sol`](aero/Pool.sol#L389-L397),
   [`Pool.sol`](aero/Pool.sol#L548-L555)). `getAmountOut` asks `getBaseFee` with no caller and leaves the MEV tax out
   (lines 537-545). The MEV tax module reads the transaction's priority fee, and the total is capped at 20%
   ([`PoolFactory.sol`](aero/PoolFactory.sol#L282-L305)). A factory without a MEV tax module, as on Ethereum, Robinhood
   Chain and Aero Lite at their pinned blocks, adds none, but its admins can set one.
5. **Aero Lite runs Aero's code.** Its vendored files differ from Aero's only in the factories' constructors, the
   CLFactory's `positionManager`, a comment, and the classic pool's `skim` (`diff -r aero aero-lite`), none of which a
   swap runs. So facts 1, 2 and 4 hold for it at the same lines, but for `getFee`, at
   [`PoolFactory.sol`](aero-lite/PoolFactory.sol#L271-L294).
6. **Uniswap v4 settles at the end of `unlock`.** `swap` returns a `BalanceDelta`, negative for what the caller owes;
   `sync`, a transfer and `settle` pay; `take` collects; every currency's delta must be zero when the callback returns
   ([`IPoolManager.sol`](uniswap/v4/IPoolManager.sol)). A key with no hooks cannot have a dynamic fee, and `swap`
   reverts for a key that was never initialized.
7. **Hydrex's stable pairs can quote one wei more than they accept.** `getAmountOut` solves the curve with `_get_y`,
   which stops once a step is at most one wei, on either side of the solution
   ([`Pair.sol`](hydrex/Pair.sol#L411-L433), [`Pair.sol`](hydrex/Pair.sol#L449-L463)). `swap` then reverts with `K`
   if the invariant fell (line 384). So the swapper asks Hydrex's pairs for one wei less than they quote.
8. **Arc's USDC is its native currency.** `0x3600000000000000000000000000000000000000` is an ERC-20 view of native
   balances, in 6 decimals where the native currency has 18. Its `transfer` and `transferFrom` move native balances
   through a precompile at `0x1800000000000000000000000000000000000000`, after checking a blocklist at
   `0x1800000000000000000000000000000000000001`. The swapper uses it as any ERC-20, and counts it by `balanceOf`, which
   only moves by whole units of 10^12 wei. Foundry's EVM has neither precompile, so `test/fork/Arc.t.sol` puts
   [`ArcNativeCoin`](../mocks/ArcNativeCoin.sol) in their place: what the fork tests check about Arc's USDC rests on that
   stand-in.

## Selectors

`test/Selectors.t.sol` checks every row.

| Member | Selector | Declared in |
|---|---|---|
| `balanceOf(address)` | `0x70a08231` | ERC-20 |
| `allowance(address,address)` | `0xdd62ed3e` | ERC-20 |
| `transfer(address,uint256)` | `0xa9059cbb` | ERC-20 |
| `transferFrom(address,address,uint256)` | `0x23b872dd` | ERC-20 |
| `isPool(address)` | `0x5b16ebb7` | `IPoolFactory.sol`, `ICLFactory.sol` |
| `getPair(address,address)` | `0xe6a43905` | `IUniswapV2Factory.sol` |
| `getPool(address,address,uint24)` | `0x1698ee82` | `IUniswapV3Factory.sol` |
| `isPair(address)` | `0xe5e31b13` | `IPairFactory.sol` |
| `poolByPair(address,address)` | `0xd9a641e1` | `IAlgebraFactory.sol` |
| `token0()` | `0x0dfe1681` | `IPool.sol`, `ICLPoolConstants.sol`, `IPair.sol` |
| `token1()` | `0xd21220a7` | the same |
| `getReserves()` | `0x0902f1ac` | `IPool.sol`, `IUniswapV2Pair.sol`, `IPair.sol` |
| `getAmountOutWithTotalFee(uint256,address)` | `0x0ea099c1` | Aero's `IPool.sol` |
| `getAmountOut(uint256,address)` | `0xf140a35a` | `IPool.sol`, `IPair.sol` |
| `swap(uint256,uint256,address,bytes)` | `0x022c0d9f` | `IPool.sol`, `IUniswapV2Pair.sol`, `IPair.sol` |
| `sync()` | `0xfff6cae9` | `IPool.sol`, `IUniswapV2Pair.sol`, `Pair.sol` |
| `swap(address,bool,int256,uint160,bytes)` | `0x128acb08` | `ICLPoolActions.sol`, `IUniswapV3PoolActions.sol`, `IAlgebraPoolActions.sol` |
| `unlock(bytes)` | `0x48c89491` | `IPoolManager.sol` |
| `swap((address,address,uint24,int24,address),(bool,int256,uint160),bytes)` | `0xf3cd914c` | `IPoolManager.sol` |
| `sync(address)` | `0xa5841194` | `IPoolManager.sol` |
| `settle()` | `0x11da60b4` | `IPoolManager.sol` |
| `take(address,address,uint256)` | `0x0b0d9c09` | `IPoolManager.sol` |
| `uniswapV3SwapCallback(int256,int256,bytes)` | `0xfa461e33` | `ICLSwapCallback.sol`, `IUniswapV3SwapCallback.sol` |
| `unlockCallback(bytes)` | `0x91dd7346` | `IUnlockCallback.sol` |
| `algebraSwapCallback(int256,int256,bytes)` | `0x2c8958f6` | `IAlgebraSwapCallback.sol` |

## Refreshing

Hydrex's pair factory and its pools' plugins are upgradeable, and the exchanges' admins can change fees, modules and
hooks. If one changes, the fork tests still pass at their pinned blocks, so check the new code by hand: vendor its
files, run `script/check-signatures.sh`, regenerate the chain's fixture at a newer block with
`test/fixtures/generate.py <chain> [block]`, update the pins in `test/fork/<Chain>.t.sol`, and re-check the facts
above. A changed fact may need a new deployment.
