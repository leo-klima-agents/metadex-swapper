// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {stdJson} from "forge-std/StdJson.sol";
import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {Deploy} from "../../script/Deploy.s.sol";
import {Treasury} from "../../script/Treasury.s.sol";
import {ImmutableSwapper} from "../../src/ImmutableSwapper.sol";

interface IViews {
    function implementation() external view returns (address);
    function poolImplementation() external view returns (address);
    function defaultSwapHook() external view returns (address);
    function factoryRegistry() external view returns (address);
    function targetFactories() external view returns (address[] memory);
    function getOwners() external view returns (address[] memory);
    function getThreshold() external view returns (uint256);
}

interface IPoolSetup {
    function createPool(address tokenA, address tokenB) external returns (address);
    function createPair(address tokenA, address tokenB) external returns (address);
    function mint(address to) external returns (uint256);
}

// Forks a chain at its fixture's block, recreates the treasury there if it is missing, deploys that chain's swappers
// with script/Deploy.s.sol, and swaps each fixture route through them. Each chain's test names its pins and routes.
abstract contract ForkTest is Test {
    using stdJson for string;

    struct Pin {
        address target;
        bytes32 codehash;
    }

    bytes32 internal constant SAFE_PROXY_CODEHASH = 0x4e381985ca68b3e5d27b4425fa581c19cf33146d3f887a3cfca96f55528ea46f;

    string internal fx;
    Deploy internal d;
    mapping(address output => ImmutableSwapper) internal swappers;

    function _chainId() internal pure virtual returns (uint256);
    function _name() internal pure virtual returns (string memory);
    function _rpcVar() internal pure virtual returns (string memory);
    function _pins() internal pure virtual returns (Pin[] memory);

    function setUp() public virtual {
        string memory rpc = vm.envOr(_rpcVar(), string(""));
        vm.skip(bytes(rpc).length == 0);
        fx = vm.readFile(string.concat("test/fixtures/", _name(), ".json"));
        vm.createSelectFork(rpc, fx.readUint(".block"));
        assertEq(block.chainid, _chainId());
        _beforeDeploy();
        new Treasury().run();
        d = new Deploy();
        address[] memory deployed = d.run();
        Deploy.Output[] memory o = d.config(_chainId()).outputs;
        for (uint256 i; i < o.length; ++i) {
            swappers[o[i].token] = ImmutableSwapper(deployed[i]);
        }
    }

    function _beforeDeploy() internal virtual {}

    function test_pin_codeHashes() public view {
        Pin[] memory p = _pins();
        for (uint256 i; i < p.length; ++i) {
            assertEq(p[i].target.codehash, p[i].codehash, vm.toString(p[i].target));
        }
        ImmutableSwapper.Exchange[] memory e = d.config(_chainId()).exchanges;
        for (uint256 i; i < e.length; ++i) {
            assertTrue(_isPinned(e[i].factory), "every exchange is pinned");
        }
    }

    function test_pin_aeroRegistryListsEveryAeroFactory() public view {
        ImmutableSwapper.Exchange[] memory e = d.config(_chainId()).exchanges;
        address registry = IViews(e[0].factory).factoryRegistry();
        assertTrue(_isPinned(registry), "the registry is pinned");
        address[] memory listed = IViews(registry).targetFactories();
        uint256 aero;
        for (uint256 i; i < e.length; ++i) {
            if (e[i].kind != ImmutableSwapper.Kind.AeroClassic && e[i].kind != ImmutableSwapper.Kind.AeroSlipstream) {
                continue;
            }
            ++aero;
            assertEq(IViews(e[i].factory).factoryRegistry(), registry);
            bool found;
            for (uint256 j; j < listed.length; ++j) {
                found = found || listed[j] == e[i].factory;
            }
            assertTrue(found, "the registry lists it");
            if (e[i].kind == ImmutableSwapper.Kind.AeroClassic) {
                assertTrue(_isPinned(IViews(e[i].factory).implementation()), "its pools' code is pinned");
            } else {
                assertTrue(_isPinned(IViews(e[i].factory).poolImplementation()), "its pools' code is pinned");
                assertTrue(_isPinned(IViews(e[i].factory).defaultSwapHook()), "its swap hook is pinned");
            }
        }
        assertEq(listed.length, aero, "and no other factory");
    }

    function test_pin_aeroPoolsAreClonesOfTheImplementations() public view {
        string[] memory names = vm.parseJsonKeys(fx, ".routes");
        for (uint256 n; n < names.length; ++n) {
            (ImmutableSwapper.Route memory r,,) = _fixture(names[n]);
            for (uint256 i; i < r.hops.length; ++i) {
                (ImmutableSwapper.Kind kind, address factory) = _exchange(r.hops[i].exchange);
                if (r.hops[i].pool == address(0)) continue;
                if (kind == ImmutableSwapper.Kind.AeroClassic) {
                    assertEq(r.hops[i].pool.code, _clone(IViews(factory).implementation()), names[n]);
                } else if (kind == ImmutableSwapper.Kind.AeroSlipstream) {
                    assertEq(r.hops[i].pool.code, _clone(IViews(factory).poolImplementation()), names[n]);
                }
            }
        }
    }

    function test_treasury_isTheSafeOnBase() public {
        Treasury t = new Treasury();
        address treasury = d.TREASURY();
        assertEq(treasury, t.TREASURY());
        assertEq(treasury.codehash, SAFE_PROXY_CODEHASH);
        assertEq(IViews(treasury).getOwners(), t.owners());
        assertEq(IViews(treasury).getThreshold(), t.THRESHOLD());
        address singleton = address(uint160(uint256(vm.load(treasury, 0))));
        assertEq(singleton, block.chainid == 1 ? t.SINGLETON() : t.L2_SINGLETON());
    }

    function _check(string memory name) internal {
        _check(name, address(0));
    }

    // Swaps the route as the fixture holder, or as a fresh holder funded with its amount. A seeded route's pool gets the
    // fixture's seed, or `pool` when given, and the swap is only checked against the quote.
    function _check(string memory name, address pool) internal {
        (ImmutableSwapper.Route memory r, address holder, uint256 expected) = _fixture(name);
        if (pool != address(0)) r.hops[0].pool = pool;
        else if (expected == 0) r.hops[0].pool = _seed(name, r);
        if (holder == address(0)) {
            holder = makeAddr("holder");
            _fund(r.token, holder, r.amount);
        }
        ImmutableSwapper.Route[] memory routes = new ImmutableSwapper.Route[](1);
        routes[0] = r;
        ImmutableSwapper.Result memory quoted = _quote(holder, routes);
        (ImmutableSwapper.Result memory res, uint256 gasUsed) = _swapAs(holder, r);
        console.log(name, "gas:", gasUsed);
        assertEq(abi.encode(quoted), abi.encode(res), "quote matches swap");
        assertGt(res.amountOut, 0);
        if (expected != 0) assertEq(res.amountOut, expected, "the pools' own quote at the block");
    }

    function _quote(address holder, ImmutableSwapper.Route[] memory routes)
        internal
        virtual
        returns (ImmutableSwapper.Result memory)
    {
        vm.prank(holder);
        return _swapperFor(routes[0]).quote(routes)[0];
    }

    function _seed(string memory name, ImmutableSwapper.Route memory r) internal returns (address pool) {
        string memory k = string.concat(".routes.", name);
        uint256 seedIn = fx.readUintArray(string.concat(k, ".seedsIn"))[0];
        uint256 seedOut = fx.readUintArray(string.concat(k, ".seedsOut"))[0];
        require(seedIn != 0, "the test seeds this pool itself");
        (ImmutableSwapper.Kind kind, address factory) = _exchange(r.hops[0].exchange);
        address tokenOut = r.hops[0].tokenOut;
        pool = r.hops[0].pool;
        if (pool == address(0)) {
            pool = kind == ImmutableSwapper.Kind.AeroClassic
                ? IPoolSetup(factory).createPool(r.token, tokenOut)
                : IPoolSetup(factory).createPair(r.token, tokenOut);
        }
        _fund(r.token, pool, seedIn);
        _fund(tokenOut, pool, seedOut);
        IPoolSetup(pool).mint(address(this));
    }

    function _fund(address token, address to, uint256 amount) internal virtual {
        deal(token, to, IERC20(token).balanceOf(to) + amount);
    }

    function _swapperFor(ImmutableSwapper.Route memory r) internal view returns (ImmutableSwapper) {
        return swappers[r.hops[r.hops.length - 1].tokenOut];
    }

    function _swapAs(address holder, ImmutableSwapper.Route memory r)
        internal
        returns (ImmutableSwapper.Result memory res, uint256 gasUsed)
    {
        ImmutableSwapper.Route[] memory routes = new ImmutableSwapper.Route[](1);
        routes[0] = r;
        ImmutableSwapper swapper = _swapperFor(r);
        IERC20 output = IERC20(swapper.outputToken());
        uint256 holderBefore = output.balanceOf(holder);
        uint256 treasuryBefore = output.balanceOf(d.TREASURY());
        vm.startPrank(holder);
        // A low-level call, since some tokens, such as USDT on Ethereum, return nothing from approve.
        (bool approved,) = r.token.call(abi.encodeCall(IERC20.approve, (address(swapper), r.amount)));
        assertTrue(approved);
        gasUsed = gasleft();
        (ImmutableSwapper.Result[] memory results, uint256 paid, uint256 fee) =
            swapper.swap(routes, vm.getBlockTimestamp(), false);
        gasUsed -= gasleft();
        vm.stopPrank();
        res = results[0];
        assertEq(res.amountIn, r.amount);
        assertEq(fee, res.amountOut / 100, "exactly 1%");
        assertEq(paid, res.amountOut - fee);
        assertEq(output.balanceOf(holder) - holderBefore, paid);
        assertEq(output.balanceOf(d.TREASURY()) - treasuryBefore, fee);
        assertEq(output.balanceOf(address(swapper)), 0);
        assertEq(IERC20(r.token).balanceOf(address(swapper)), 0);
    }

    function _fixture(string memory name)
        internal
        view
        returns (ImmutableSwapper.Route memory r, address holder, uint256 quote)
    {
        string memory k = string.concat(".routes.", name);
        if (vm.keyExistsJson(fx, string.concat(k, ".holder"))) holder = fx.readAddress(string.concat(k, ".holder"));
        quote = fx.readUint(string.concat(k, ".quote"));
        r.token = fx.readAddress(string.concat(k, ".token"));
        r.amount = fx.readUint(string.concat(k, ".amount"));
        address[] memory factories = fx.readAddressArray(string.concat(k, ".factories"));
        address[] memory pools = fx.readAddressArray(string.concat(k, ".pools"));
        address[] memory tokensOut = fx.readAddressArray(string.concat(k, ".tokensOut"));
        uint256[] memory fees = fx.readUintArray(string.concat(k, ".fees"));
        int256[] memory spacings = fx.readIntArray(string.concat(k, ".tickSpacings"));
        r.hops = new ImmutableSwapper.Hop[](factories.length);
        for (uint256 i; i < factories.length; ++i) {
            r.hops[i] = ImmutableSwapper.Hop(
                _indexOf(factories[i]), pools[i], tokensOut[i], uint24(fees[i]), int24(spacings[i])
            );
        }
    }

    function _indexOf(address factory) internal view returns (uint8) {
        ImmutableSwapper.Exchange[] memory e = d.config(_chainId()).exchanges;
        for (uint256 i; i < e.length; ++i) {
            if (e[i].factory == factory) return uint8(i);
        }
        revert("not listed");
    }

    function _exchange(uint8 index) internal view returns (ImmutableSwapper.Kind, address) {
        ImmutableSwapper.Exchange memory e = d.config(_chainId()).exchanges[index];
        return (e.kind, e.factory);
    }

    function _isPinned(address target) internal pure returns (bool) {
        Pin[] memory p = _pins();
        for (uint256 i; i < p.length; ++i) {
            if (p[i].target == target) return true;
        }
        return false;
    }

    function _clone(address impl) internal pure returns (bytes memory) {
        return abi.encodePacked(hex"363d3d373d3d3d363d73", impl, hex"5af43d82803e903d91602b57fd5bf3");
    }
}
