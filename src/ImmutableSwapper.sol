// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {IAlgebraFactory} from "./interfaces/IAlgebraFactory.sol";
import {IAlgebraSwapCallback} from "./interfaces/IAlgebraSwapCallback.sol";
import {IClassicPool} from "./interfaces/IClassicPool.sol";
import {IConcentratedPool} from "./interfaces/IConcentratedPool.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IPairFactory} from "./interfaces/IPairFactory.sol";
import {IPoolFactory} from "./interfaces/IPoolFactory.sol";
import {IPoolManager} from "./interfaces/IPoolManager.sol";
import {IUniswapV2Factory} from "./interfaces/IUniswapV2Factory.sol";
import {IUniswapV3Factory} from "./interfaces/IUniswapV3Factory.sol";
import {IUniswapV3SwapCallback} from "./interfaces/IUniswapV3SwapCallback.sol";
import {IUnlockCallback} from "./interfaces/IUnlockCallback.sol";

contract ImmutableSwapper is IAlgebraSwapCallback, IUniswapV3SwapCallback, IUnlockCallback {
    enum Kind {
        HydrexAlgebra,
        HydrexClassic,
        AeroClassic,
        AeroSlipstream,
        UniswapV2,
        UniswapV3,
        UniswapV4
    }

    struct Exchange {
        Kind kind;
        address factory;
    }

    struct Hop {
        uint8 exchange;
        address pool;
        address tokenOut;
        uint24 fee;
        int24 tickSpacing;
    }

    struct Route {
        address token;
        uint256 amount;
        uint256 minPaid;
        Hop[] hops;
    }

    struct Result {
        bool done;
        uint256 amountIn;
        uint256 amountOut;
        bytes reason;
    }

    address public constant TREASURY = 0x450c72de8c0079B49AcedF294a13011bd09D125B;
    uint256 public constant FEE_BPS = 100;
    uint256 public constant MAX_HOPS = 3;
    uint256 private constant MAX_EXCHANGES = 12;
    uint160 private constant MIN_SQRT_RATIO = 4295128739;
    uint160 private constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    address public immutable outputToken;
    uint256 private immutable exchangeCount;
    // Each holds an exchange's kind above its factory's address; unused ones are zero.
    uint256 private immutable exchange0;
    uint256 private immutable exchange1;
    uint256 private immutable exchange2;
    uint256 private immutable exchange3;
    uint256 private immutable exchange4;
    uint256 private immutable exchange5;
    uint256 private immutable exchange6;
    uint256 private immutable exchange7;
    uint256 private immutable exchange8;
    uint256 private immutable exchange9;
    uint256 private immutable exchange10;
    uint256 private immutable exchange11;

    bool private transient locked;
    bool private transient quoting;
    address private transient expectedCaller;
    address private transient owedToken;
    uint256 private transient owedAmount;
    bool private transient owedIsToken0;

    event RouteSwapped(address indexed caller, uint256 index, address token, uint256 amountIn, uint256 amountOut);
    event RouteFailed(address indexed caller, uint256 index, address token, bytes reason);
    event Swapped(address indexed caller, uint256 paid, uint256 fee);

    error Expired();
    error BadHopCount(uint256 route);
    error BadPath(uint256 route, uint256 hop);
    error UnknownExchange(uint256 route, uint256 hop);
    error NotExchangePool(uint8 exchange, address pool);
    error NativeOutsideV4(uint256 route, uint256 hop);
    error NoOutput(uint256 route, uint256 hop);
    error PartialFill(address pool);
    error NotExpectedCaller(address caller);
    error TooLittle(uint256 route, uint256 paid, uint256 minPaid);
    error Quoted(uint256 amountOut);
    error TokenCallFailed(address token);
    error OnlySelf();
    error Reentrancy();
    error ZeroAddress();
    error BadExchangeCount();

    modifier nonReentrant() {
        if (locked) revert Reentrancy();
        locked = true;
        _;
        locked = false;
    }

    constructor(address outputToken_, Exchange[] memory exchanges_) {
        if (outputToken_ == address(0)) revert ZeroAddress();
        uint256 n = exchanges_.length;
        if (n == 0 || n > MAX_EXCHANGES) revert BadExchangeCount();
        uint256[MAX_EXCHANGES] memory packed;
        for (uint256 i; i < n; ++i) {
            address factory = exchanges_[i].factory;
            if (factory == address(0)) revert ZeroAddress();
            packed[i] = (uint256(exchanges_[i].kind) << 160) | uint160(factory);
        }
        outputToken = outputToken_;
        exchangeCount = n;
        exchange0 = packed[0];
        exchange1 = packed[1];
        exchange2 = packed[2];
        exchange3 = packed[3];
        exchange4 = packed[4];
        exchange5 = packed[5];
        exchange6 = packed[6];
        exchange7 = packed[7];
        exchange8 = packed[8];
        exchange9 = packed[9];
        exchange10 = packed[10];
        exchange11 = packed[11];
    }

    function swap(Route[] calldata routes, uint256 deadline, bool skipFailed)
        external
        nonReentrant
        returns (Result[] memory results, uint256 paid, uint256 fee)
    {
        if (block.timestamp > deadline) revert Expired();
        results = new Result[](routes.length);
        for (uint256 i; i < routes.length; ++i) {
            Result memory r = _try(i, routes[i]);
            results[i] = r;
            if (r.done) {
                uint256 routeFee = _fee(r.amountOut);
                fee += routeFee;
                paid += r.amountOut - routeFee;
                emit RouteSwapped(msg.sender, i, routes[i].token, r.amountIn, r.amountOut);
            } else if (skipFailed) {
                emit RouteFailed(msg.sender, i, routes[i].token, r.reason);
            } else {
                _bubble(r.reason);
            }
        }
        if (fee != 0) _transfer(outputToken, TREASURY, fee);
        if (paid != 0) _transfer(outputToken, msg.sender, paid);
        emit Swapped(msg.sender, paid, fee);
    }

    function quote(Route[] calldata routes) external nonReentrant returns (Result[] memory results) {
        quoting = true;
        results = new Result[](routes.length);
        for (uint256 i; i < routes.length; ++i) {
            results[i] = _try(i, routes[i]);
        }
        quoting = false;
    }

    function exchanges() external view returns (Exchange[] memory list) {
        list = new Exchange[](exchangeCount);
        for (uint256 i; i < list.length; ++i) {
            (list[i].kind, list[i].factory) = _exchange(i);
        }
    }

    function runRoute(address caller, uint256 index, Route calldata route)
        external
        returns (uint256 amountIn, uint256 amountOut)
    {
        if (msg.sender != address(this)) revert OnlySelf();
        _checkRoute(index, route);
        address token = route.token;
        amountIn = route.amount;
        if (amountIn == type(uint256).max) {
            amountIn = IERC20(token).balanceOf(caller);
            if (!quoting) {
                uint256 allowance = IERC20(token).allowance(caller, address(this));
                if (allowance < amountIn) amountIn = allowance;
            }
        }
        if (!quoting) {
            uint256 before = _balance(token);
            _call(token, abi.encodeCall(IERC20.transferFrom, (caller, address(this), amountIn)));
            amountIn = _balance(token) - before;
        }
        amountOut = _runHops(index, route.hops, token, amountIn);
        uint256 paid = amountOut - _fee(amountOut);
        if (paid < route.minPaid) revert TooLittle(index, paid, route.minPaid);
    }

    function algebraSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        _pay(amount0Delta, amount1Delta);
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        _pay(amount0Delta, amount1Delta);
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        _checkCaller();
        Hop[] memory hops = abi.decode(data, (Hop[]));
        IPoolManager manager = IPoolManager(msg.sender);
        (address tokenIn, uint256 amountIn) = (owedToken, owedAmount);
        (address token, uint256 amount) = (tokenIn, amountIn);
        for (uint256 i; i < hops.length; ++i) {
            address tokenOut = hops[i].tokenOut;
            bool zeroForOne = token < tokenOut;
            (address currency0, address currency1) = zeroForOne ? (token, tokenOut) : (tokenOut, token);
            int256 amountSpecified = -int256(amount);
            int256 delta = manager.swap(
                IPoolManager.PoolKey(currency0, currency1, hops[i].fee, hops[i].tickSpacing, address(0)),
                IPoolManager.SwapParams(zeroForOne, amountSpecified, _limit(zeroForOne)),
                ""
            );
            (int256 owed, int256 out) = _split(delta, zeroForOne);
            if (owed != amountSpecified) revert PartialFill(msg.sender);
            // Without hooks, an exact-input swap only ever pays the swapper, so out can't be negative.
            amount = uint256(out);
            token = tokenOut;
        }
        if (quoting) revert Quoted(amount);
        manager.sync(tokenIn);
        _transfer(tokenIn, msg.sender, amountIn);
        manager.settle();
        manager.take(token, address(this), amount);
        return "";
    }

    function _try(uint256 index, Route calldata route) private returns (Result memory r) {
        try this.runRoute(msg.sender, index, route) returns (uint256 amountIn, uint256 amountOut) {
            r = Result(true, amountIn, amountOut, "");
        } catch (bytes memory reason) {
            r.reason = reason;
        }
    }

    function _checkRoute(uint256 index, Route calldata route) private view {
        uint256 n = route.hops.length;
        if (n == 0 || n > MAX_HOPS) revert BadHopCount(index);
        address tokenIn = route.token;
        if (tokenIn == outputToken || tokenIn == address(0)) revert BadPath(index, 0);
        for (uint256 i; i < n; ++i) {
            Hop calldata hop = route.hops[i];
            if ((hop.tokenOut == outputToken) != (i == n - 1)) revert BadPath(index, i);
            (Kind kind, address factory) = _exchange(hop.exchange);
            if (factory == address(0)) revert UnknownExchange(index, i);
            if (hop.tokenOut == address(0) && (kind != Kind.UniswapV4 || route.hops[i + 1].exchange != hop.exchange)) {
                revert NativeOutsideV4(index, i);
            }
            if (!_isExchangePool(kind, factory, hop, tokenIn)) revert NotExchangePool(hop.exchange, hop.pool);
            tokenIn = hop.tokenOut;
        }
    }

    function _isExchangePool(Kind kind, address factory, Hop calldata hop, address tokenIn)
        private
        view
        returns (bool)
    {
        address pool = hop.pool;
        if (kind == Kind.UniswapV4) return pool == address(0);
        if (pool == address(0)) return false;
        if (kind == Kind.HydrexAlgebra) return IAlgebraFactory(factory).poolByPair(tokenIn, hop.tokenOut) == pool;
        if (kind == Kind.UniswapV2) return IUniswapV2Factory(factory).getPair(tokenIn, hop.tokenOut) == pool;
        if (kind == Kind.UniswapV3) return IUniswapV3Factory(factory).getPool(tokenIn, hop.tokenOut, hop.fee) == pool;
        bool listed =
            kind == Kind.HydrexClassic ? IPairFactory(factory).isPair(pool) : IPoolFactory(factory).isPool(pool);
        if (!listed) return false;
        (address token0, address token1) = tokenIn < hop.tokenOut ? (tokenIn, hop.tokenOut) : (hop.tokenOut, tokenIn);
        return IClassicPool(pool).token0() == token0 && IClassicPool(pool).token1() == token1;
    }

    function _runHops(uint256 index, Hop[] calldata hops, address token, uint256 amount) private returns (uint256) {
        uint256 i;
        while (i < hops.length) {
            (Kind kind, address factory) = _exchange(hops[i].exchange);
            uint256 next = i + 1;
            if (kind == Kind.UniswapV4) {
                while (next < hops.length && hops[next].exchange == hops[i].exchange) {
                    ++next;
                }
                if (hops[next - 1].tokenOut == token) revert BadPath(index, next - 1);
                amount = _swapV4(factory, hops[i:next], token, amount);
            } else if (_isConcentrated(kind)) {
                amount = _swapConcentrated(hops[i], token, amount);
            } else {
                amount = _swapClassic(kind, hops[i], token, amount);
            }
            if (amount == 0) revert NoOutput(index, next - 1);
            token = hops[next - 1].tokenOut;
            i = next;
        }
        return amount;
    }

    function _swapConcentrated(Hop calldata hop, address tokenIn, uint256 amount) private returns (uint256) {
        bool zeroForOne = tokenIn < hop.tokenOut;
        _expect(hop.pool, tokenIn, amount, zeroForOne);
        uint256 before = _balance(hop.tokenOut);
        (bool ok, bytes memory ret) = hop.pool
            .call(
                abi.encodeCall(
                    IConcentratedPool.swap, (address(this), zeroForOne, int256(amount), _limit(zeroForOne), "")
                )
            );
        expectedCaller = address(0);
        return _output(ok, ret, hop.tokenOut, before);
    }

    function _swapV4(address manager, Hop[] calldata hops, address tokenIn, uint256 amount) private returns (uint256) {
        address tokenOut = hops[hops.length - 1].tokenOut;
        _expect(manager, tokenIn, amount, false);
        uint256 before = _balance(tokenOut);
        (bool ok, bytes memory ret) = manager.call(abi.encodeCall(IPoolManager.unlock, (abi.encode(hops))));
        expectedCaller = address(0);
        return _output(ok, ret, tokenOut, before);
    }

    function _swapClassic(Kind kind, Hop calldata hop, address tokenIn, uint256 amount) private returns (uint256) {
        IClassicPool pool = IClassicPool(hop.pool);
        bool zeroForOne = tokenIn < hop.tokenOut;
        if (!quoting) {
            pool.sync();
            _transfer(tokenIn, address(pool), amount);
        }
        (uint256 reserveIn, uint256 reserveOut,) = pool.getReserves();
        if (!zeroForOne) (reserveIn, reserveOut) = (reserveOut, reserveIn);
        if (!quoting) amount = IERC20(tokenIn).balanceOf(address(pool)) - reserveIn;

        uint256 out;
        if (kind == Kind.UniswapV2) {
            out = amount * 997 * reserveOut / (reserveIn * 1000 + amount * 997);
        } else if (kind == Kind.AeroClassic) {
            out = pool.getAmountOutWithTotalFee(amount, tokenIn);
        } else {
            out = pool.getAmountOut(amount, tokenIn);
        }
        // Hydrex's stable pairs sometimes quote one wei more than their swap will accept.
        if (kind == Kind.HydrexClassic && out != 0) --out;
        if (quoting || out == 0) return out;

        (uint256 out0, uint256 out1) = zeroForOne ? (uint256(0), out) : (out, uint256(0));
        uint256 before = _balance(hop.tokenOut);
        pool.swap(out0, out1, address(this), "");
        return _balance(hop.tokenOut) - before;
    }

    function _expect(address caller, address token, uint256 amount, bool isToken0) private {
        expectedCaller = caller;
        owedToken = token;
        owedAmount = amount;
        owedIsToken0 = isToken0;
    }

    function _checkCaller() private {
        if (msg.sender != expectedCaller) revert NotExpectedCaller(msg.sender);
        expectedCaller = address(0);
    }

    function _pay(int256 amount0Delta, int256 amount1Delta) private {
        _checkCaller();
        (int256 owed, int256 out) = owedIsToken0 ? (amount0Delta, amount1Delta) : (amount1Delta, amount0Delta);
        if (owed != int256(owedAmount)) revert PartialFill(msg.sender);
        if (quoting) revert Quoted(out < 0 ? uint256(-out) : 0);
        _transfer(owedToken, msg.sender, owedAmount);
    }

    function _output(bool ok, bytes memory ret, address token, uint256 before) private view returns (uint256 amount) {
        if (!ok) {
            if (!quoting || ret.length != 36 || bytes4(ret) != Quoted.selector) _bubble(ret);
            assembly ("memory-safe") {
                amount := mload(add(ret, 36))
            }
        } else if (!quoting) {
            amount = _balance(token) - before;
        }
    }

    function _split(int256 delta, bool zeroForOne) private pure returns (int256 owed, int256 out) {
        int256 amount0 = delta >> 128;
        int256 amount1 = int128(delta);
        (owed, out) = zeroForOne ? (amount0, amount1) : (amount1, amount0);
    }

    function _exchange(uint256 i) private view returns (Kind, address) {
        uint256 e = _packed(i);
        return (Kind(e >> 160), address(uint160(e)));
    }

    function _packed(uint256 i) private view returns (uint256) {
        if (i == 0) return exchange0;
        if (i == 1) return exchange1;
        if (i == 2) return exchange2;
        if (i == 3) return exchange3;
        if (i == 4) return exchange4;
        if (i == 5) return exchange5;
        if (i == 6) return exchange6;
        if (i == 7) return exchange7;
        if (i == 8) return exchange8;
        if (i == 9) return exchange9;
        if (i == 10) return exchange10;
        if (i == 11) return exchange11;
        return 0;
    }

    function _isConcentrated(Kind kind) private pure returns (bool) {
        return kind == Kind.HydrexAlgebra || kind == Kind.AeroSlipstream || kind == Kind.UniswapV3;
    }

    function _limit(bool zeroForOne) private pure returns (uint160) {
        return zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1;
    }

    function _fee(uint256 amountOut) private pure returns (uint256) {
        return amountOut * FEE_BPS / 10_000;
    }

    function _balance(address token) private view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function _transfer(address token, address to, uint256 amount) private {
        _call(token, abi.encodeCall(IERC20.transfer, (to, amount)));
    }

    function _call(address token, bytes memory data) private {
        (bool ok, bytes memory ret) = token.call(data);
        if (!ok || (ret.length == 0 ? token.code.length == 0 : ret.length < 32 || abi.decode(ret, (uint256)) != 1)) {
            revert TokenCallFailed(token);
        }
    }

    function _bubble(bytes memory reason) private pure {
        assembly ("memory-safe") {
            revert(add(reason, 0x20), mload(reason))
        }
    }
}
