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
    // Each names a factory, or Uniswap v4's PoolManager, fixed at deployment.
    enum Exchange {
        HydrexAlgebra,
        HydrexClassic,
        AeroVolatile,
        AeroStable,
        AeroSlipstream,
        AerodromeClassic,
        AerodromeSlipstream,
        AerodromeSlipstream2,
        AerodromeSlipstream3,
        UniswapV2,
        UniswapV3,
        UniswapV4
    }

    // One swap, from the previous hop's token, or the route's.
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

    struct Result {
        bool done;
        uint256 amountIn;
        uint256 amountOut; // before the fee
        bytes reason; // why the route failed, if it did
    }

    address public constant TREASURY = 0x450c72de8c0079B49AcedF294a13011bd09D125B;
    uint256 public constant FEE_BPS = 100;
    uint256 public constant MAX_HOPS = 3;
    uint256 private constant EXCHANGES = 12;
    uint160 private constant MIN_SQRT_RATIO = 4295128739;
    uint160 private constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    // What every route ends in, and what the caller and the treasury are paid in.
    address public immutable outputToken;
    address private immutable hydrexAlgebra;
    address private immutable hydrexClassic;
    address private immutable aeroVolatile;
    address private immutable aeroStable;
    address private immutable aeroSlipstream;
    address private immutable aerodromeClassic;
    address private immutable aerodromeSlipstream;
    address private immutable aerodromeSlipstream2;
    address private immutable aerodromeSlipstream3;
    address private immutable uniswapV2;
    address private immutable uniswapV3;
    address private immutable uniswapV4;

    bool private transient locked;
    bool private transient quoting;
    // The pool, or Uniswap v4's manager, that may call back during the current hop, and what it is owed.
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
    error NotExchangePool(Exchange exchange, address pool);
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

    modifier nonReentrant() {
        if (locked) revert Reentrancy();
        locked = true;
        _;
        locked = false;
    }

    // exchanges_ is in the order of Exchange.
    constructor(address outputToken_, address[EXCHANGES] memory exchanges_) {
        if (outputToken_ == address(0)) revert ZeroAddress();
        for (uint256 i; i < EXCHANGES; ++i) {
            if (exchanges_[i] == address(0)) revert ZeroAddress();
        }
        outputToken = outputToken_;
        hydrexAlgebra = exchanges_[0];
        hydrexClassic = exchanges_[1];
        aeroVolatile = exchanges_[2];
        aeroStable = exchanges_[3];
        aeroSlipstream = exchanges_[4];
        aerodromeClassic = exchanges_[5];
        aerodromeSlipstream = exchanges_[6];
        aerodromeSlipstream2 = exchanges_[7];
        aerodromeSlipstream3 = exchanges_[8];
        uniswapV2 = exchanges_[9];
        uniswapV3 = exchanges_[10];
        uniswapV4 = exchanges_[11];
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

    // Called with eth_call: what swap would return now. It moves nothing, and needs no allowance: an amount of
    // type(uint256).max quotes the caller's whole balance. The lock matters: a swap nested in a quote would pull nothing,
    // yet pay out.
    function quote(Route[] calldata routes) external nonReentrant returns (Result[] memory results) {
        quoting = true;
        results = new Result[](routes.length);
        for (uint256 i; i < routes.length; ++i) {
            results[i] = _try(i, routes[i]);
        }
        quoting = false;
    }

    // Each Exchange's factory, or manager, in the enum's order.
    function exchanges() external view returns (address[] memory list) {
        list = new address[](EXCHANGES);
        for (uint256 i; i < EXCHANGES; ++i) {
            list[i] = _factory(Exchange(i));
        }
    }

    // Runs one route in a call of its own, so that a route that fails undoes everything it did.
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
            // forge-lint: disable-next-line(unsafe-typecast)
            int256 amountSpecified = -int256(amount);
            int256 delta = manager.swap(
                IPoolManager.PoolKey(currency0, currency1, hops[i].fee, hops[i].tickSpacing, address(0)),
                IPoolManager.SwapParams(zeroForOne, amountSpecified, _limit(zeroForOne)),
                ""
            );
            (int256 owed, int256 out) = _split(delta, zeroForOne);
            if (owed != amountSpecified) revert PartialFill(msg.sender);
            // Never negative: an exact input swap through a pool without hooks only owes the swapper.
            // forge-lint: disable-next-line(unsafe-typecast)
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
            // A hop out to native ETH is not the last, which ends in the output token, so hops[i + 1] exists.
            if (
                hop.tokenOut == address(0)
                    && (hop.exchange != Exchange.UniswapV4 || route.hops[i + 1].exchange != Exchange.UniswapV4)
            ) revert NativeOutsideV4(index, i);
            if (!_isExchangePool(hop, tokenIn)) revert NotExchangePool(hop.exchange, hop.pool);
            tokenIn = hop.tokenOut;
        }
    }

    function _isExchangePool(Hop calldata hop, address tokenIn) private view returns (bool) {
        Exchange e = hop.exchange;
        address pool = hop.pool;
        if (e == Exchange.UniswapV4) return pool == address(0);
        // Factories answer zero for a pair they don't know.
        if (pool == address(0)) return false;
        address factory = _factory(e);
        if (e == Exchange.HydrexAlgebra) return IAlgebraFactory(factory).poolByPair(tokenIn, hop.tokenOut) == pool;
        if (e == Exchange.UniswapV2) return IUniswapV2Factory(factory).getPair(tokenIn, hop.tokenOut) == pool;
        if (e == Exchange.UniswapV3) return IUniswapV3Factory(factory).getPool(tokenIn, hop.tokenOut, hop.fee) == pool;
        bool listed =
            e == Exchange.HydrexClassic ? IPairFactory(factory).isPair(pool) : IPoolFactory(factory).isPool(pool);
        if (!listed) return false;
        (address token0, address token1) = tokenIn < hop.tokenOut ? (tokenIn, hop.tokenOut) : (hop.tokenOut, tokenIn);
        // Classic and Slipstream pools both expose their sorted tokens.
        return IClassicPool(pool).token0() == token0 && IClassicPool(pool).token1() == token1;
    }

    function _runHops(uint256 index, Hop[] calldata hops, address token, uint256 amount) private returns (uint256) {
        uint256 i;
        while (i < hops.length) {
            Exchange e = hops[i].exchange;
            uint256 next = i + 1;
            if (e == Exchange.UniswapV4) {
                while (next < hops.length && hops[next].exchange == Exchange.UniswapV4) {
                    ++next;
                }
                // The run pays its first token inside unlock, so its output can be counted only if it's another token.
                if (hops[next - 1].tokenOut == token) revert BadPath(index, next - 1);
                amount = _swapV4(hops[i:next], token, amount);
            } else if (_isConcentrated(e)) {
                amount = _swapConcentrated(hops[i], token, amount);
            } else {
                amount = _swapClassic(hops[i], token, amount);
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
                    IConcentratedPool.swap,
                    // forge-lint: disable-next-line(unsafe-typecast)
                    (address(this), zeroForOne, int256(amount), _limit(zeroForOne), "")
                )
            );
        expectedCaller = address(0);
        return _output(ok, ret, hop.tokenOut, before);
    }

    function _swapV4(Hop[] calldata hops, address tokenIn, uint256 amount) private returns (uint256) {
        address tokenOut = hops[hops.length - 1].tokenOut;
        _expect(uniswapV4, tokenIn, amount, false);
        uint256 before = _balance(tokenOut);
        (bool ok, bytes memory ret) = uniswapV4.call(abi.encodeCall(IPoolManager.unlock, (abi.encode(hops))));
        expectedCaller = address(0);
        return _output(ok, ret, tokenOut, before);
    }

    function _swapClassic(Hop calldata hop, address tokenIn, uint256 amount) private returns (uint256) {
        Exchange e = hop.exchange;
        IClassicPool pool = IClassicPool(hop.pool);
        bool zeroForOne = tokenIn < hop.tokenOut;
        if (!quoting) {
            // Synced first, the pool counts only this hop's input as input, which is all its price assumes.
            pool.sync();
            _transfer(tokenIn, address(pool), amount);
        }
        (uint256 reserveIn, uint256 reserveOut,) = pool.getReserves();
        if (!zeroForOne) (reserveIn, reserveOut) = (reserveOut, reserveIn);
        // What the pool received: a token that charges a fee on transfers sends it less.
        if (!quoting) amount = IERC20(tokenIn).balanceOf(address(pool)) - reserveIn;

        uint256 out;
        if (e == Exchange.UniswapV2) {
            out = amount * 997 * reserveOut / (reserveIn * 1000 + amount * 997);
        } else if (e == Exchange.AeroVolatile || e == Exchange.AeroStable) {
            // Aero's fee depends on the caller and on the transaction's priority fee, so the swapper asks itself.
            out = pool.getAmountOutWithTotalFee(amount, tokenIn);
        } else {
            out = pool.getAmountOut(amount, tokenIn);
        }
        // Hydrex's pairs run Solidly's first stable curve, which can quote one wei more than the pair then accepts.
        if (e == Exchange.HydrexClassic && out != 0) --out;
        if (quoting || out == 0) return out;

        (uint256 out0, uint256 out1) = zeroForOne ? (uint256(0), out) : (out, uint256(0));
        uint256 before = _balance(hop.tokenOut);
        pool.swap(out0, out1, address(this), "");
        return _balance(hop.tokenOut) - before;
    }

    // Records who may call back during this hop, and what it is owed.
    function _expect(address caller, address token, uint256 amount, bool isToken0) private {
        expectedCaller = caller;
        owedToken = token;
        owedAmount = amount;
        owedIsToken0 = isToken0;
    }

    function _checkCaller() private {
        if (msg.sender != expectedCaller) revert NotExpectedCaller(msg.sender);
        // forge-lint: disable-next-line(missing-events-access-control)
        expectedCaller = address(0);
    }

    function _pay(int256 amount0Delta, int256 amount1Delta) private {
        _checkCaller();
        (int256 owed, int256 out) = owedIsToken0 ? (amount0Delta, amount1Delta) : (amount1Delta, amount0Delta);
        // Exactly the hop's amount, of the hop's token: no partial fill, and nothing more.
        // forge-lint: disable-next-line(unsafe-typecast)
        if (owed != int256(owedAmount)) revert PartialFill(msg.sender);
        // forge-lint: disable-next-line(unsafe-typecast)
        if (quoting) revert Quoted(out < 0 ? uint256(-out) : 0);
        _transfer(owedToken, msg.sender, owedAmount);
    }

    // What a hop returned: the difference in the swapper's balance, or the amount carried by Quoted while quoting.
    function _output(bool ok, bytes memory ret, address token, uint256 before) private view returns (uint256 amount) {
        if (!ok) {
            // forge-lint: disable-next-line(unsafe-typecast)
            if (!quoting || ret.length != 36 || bytes4(ret) != Quoted.selector) _bubble(ret);
            assembly ("memory-safe") {
                amount := mload(add(ret, 36))
            }
        } else if (!quoting) {
            amount = _balance(token) - before;
        }
    }

    // A BalanceDelta holds amount0 in its upper 128 bits and amount1 in its lower 128.
    function _split(int256 delta, bool zeroForOne) private pure returns (int256 owed, int256 out) {
        int256 amount0 = delta >> 128;
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 amount1 = int128(delta);
        (owed, out) = zeroForOne ? (amount0, amount1) : (amount1, amount0);
    }

    function _factory(Exchange e) private view returns (address) {
        if (e == Exchange.HydrexAlgebra) return hydrexAlgebra;
        if (e == Exchange.HydrexClassic) return hydrexClassic;
        if (e == Exchange.AeroVolatile) return aeroVolatile;
        if (e == Exchange.AeroStable) return aeroStable;
        if (e == Exchange.AeroSlipstream) return aeroSlipstream;
        if (e == Exchange.AerodromeClassic) return aerodromeClassic;
        if (e == Exchange.AerodromeSlipstream) return aerodromeSlipstream;
        if (e == Exchange.AerodromeSlipstream2) return aerodromeSlipstream2;
        if (e == Exchange.AerodromeSlipstream3) return aerodromeSlipstream3;
        if (e == Exchange.UniswapV2) return uniswapV2;
        if (e == Exchange.UniswapV3) return uniswapV3;
        return uniswapV4;
    }

    function _isConcentrated(Exchange e) private pure returns (bool) {
        return e == Exchange.HydrexAlgebra || e == Exchange.AeroSlipstream || e == Exchange.AerodromeSlipstream
            || e == Exchange.AerodromeSlipstream2 || e == Exchange.AerodromeSlipstream3 || e == Exchange.UniswapV3;
    }

    // No price limit.
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
        // Nothing, from a contract, or a word of 1: anything else is a failure.
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
