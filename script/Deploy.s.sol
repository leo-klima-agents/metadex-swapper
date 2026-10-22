// SPDX-License-Identifier: MIT
pragma solidity 0.8.37;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ImmutableSwapper} from "../src/ImmutableSwapper.sol";

contract Deploy is Script {
    struct Output {
        string symbol;
        address token;
    }

    struct Config {
        string name;
        Output[] outputs;
        ImmutableSwapper.Exchange[] exchanges;
    }

    uint256 public constant ETHEREUM = 1;
    uint256 public constant BASE = 8453;
    uint256 public constant OPTIMISM = 10;
    uint256 public constant ARBITRUM = 42161;
    uint256 public constant ARC = 5042;

    address public constant TREASURY = 0x450c72de8c0079B49AcedF294a13011bd09D125B;

    // Aero's classic factories have the same addresses on every chain.
    address public constant AERO_VOLATILE = 0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2;
    address public constant AERO_STABLE = 0x78589E876edcEbdce72ee3436ab3c9AD3a7cEF2D;

    string public constant SALT_PREIMAGE = "metadex.cafe/ImmutableSwapper/v2";
    bytes32 public constant SALT = keccak256(bytes(SALT_PREIMAGE));

    function chains() public pure returns (uint256[] memory list) {
        list = new uint256[](5);
        (list[0], list[1], list[2], list[3], list[4]) = (ETHEREUM, BASE, OPTIMISM, ARBITRUM, ARC);
    }

    function config(uint256 chainId) public pure returns (Config memory) {
        if (chainId == ETHEREUM) return _ethereum();
        if (chainId == BASE) return _base();
        if (chainId == OPTIMISM) return _optimism();
        if (chainId == ARBITRUM) return _arbitrum();
        if (chainId == ARC) return _arc();
        revert("unsupported chain");
    }

    function kindName(ImmutableSwapper.Kind kind) public pure returns (string memory) {
        if (kind == ImmutableSwapper.Kind.AeroClassic) return "AeroClassic";
        if (kind == ImmutableSwapper.Kind.AeroSlipstream) return "AeroSlipstream";
        if (kind == ImmutableSwapper.Kind.UniswapV2) return "UniswapV2";
        if (kind == ImmutableSwapper.Kind.UniswapV3) return "UniswapV3";
        if (kind == ImmutableSwapper.Kind.UniswapV4) return "UniswapV4";
        if (kind == ImmutableSwapper.Kind.HydrexClassic) return "HydrexClassic";
        if (kind == ImmutableSwapper.Kind.HydrexAlgebra) return "HydrexAlgebra";
        revert("unnamed kind");
    }

    function constructorArgs(uint256 chainId, address outputToken) public pure returns (bytes memory) {
        return abi.encode(outputToken, config(chainId).exchanges);
    }

    function initCode(uint256 chainId, address outputToken) public pure returns (bytes memory) {
        return bytes.concat(type(ImmutableSwapper).creationCode, constructorArgs(chainId, outputToken));
    }

    function predict(uint256 chainId, address outputToken) public pure returns (address) {
        return vm.computeCreate2Address(SALT, keccak256(initCode(chainId, outputToken)), CREATE2_FACTORY);
    }

    function run() external returns (address[] memory deployed) {
        uint256 chainId = block.chainid;
        Config memory c = config(chainId);
        require(CREATE2_FACTORY.code.length != 0, "CREATE2 deployer not present");
        require(TREASURY.code.length != 0, "treasury not deployed on this chain");
        for (uint256 i; i < c.exchanges.length; ++i) {
            require(c.exchanges[i].factory.code.length != 0, "exchange has no code");
        }
        string memory recorded = vm.readFile("verification/bytecode-hashes.json");
        deployed = new address[](c.outputs.length);
        for (uint256 i; i < c.outputs.length; ++i) {
            Output memory o = c.outputs[i];
            require(o.token.code.length != 0, "output token has no code");
            deployed[i] = predict(chainId, o.token);
            console.log(o.symbol, deployed[i]);
            string memory key = string.concat(".chains.", c.name, ".deployments.", o.symbol, ".address");
            require(
                deployed[i] == vm.parseJsonAddress(recorded, key),
                "build differs from verification/bytecode-hashes.json"
            );
        }
        for (uint256 i; i < c.outputs.length; ++i) {
            if (deployed[i].code.length != 0) {
                console.log(c.outputs[i].symbol, "already deployed");
                continue;
            }
            vm.broadcast();
            (bool ok,) = CREATE2_FACTORY.call(bytes.concat(SALT, initCode(chainId, c.outputs[i].token)));
            require(ok && deployed[i].code.length != 0, "CREATE2 deploy failed");
            console.log(c.outputs[i].symbol, "deployed");
        }
    }

    function _ethereum() private pure returns (Config memory c) {
        c.name = "ethereum";
        c.outputs = new Output[](5);
        c.outputs[0] = Output("WETH", 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        c.outputs[1] = Output("USDC", 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        c.outputs[2] = Output("EURC", 0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c);
        c.outputs[3] = Output("cirBTC", 0x72DFB2E44f59C5AD2bAFE84314E5b99a7cd5075E);
        c.outputs[4] = Output("cbBTC", 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf);
        c.exchanges = _aeroAndUniswap(
            0xF4Fd2E6c5B60c5b365cd1B96DD6245E6D60414c2,
            0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f,
            0x1F98431c8aD98523631AE4a59f267346ea31F984,
            0x000000000004444c5dc75cB358380D2e3dE08A90
        );
    }

    function _base() private pure returns (Config memory c) {
        c.name = "base";
        c.outputs = new Output[](6);
        c.outputs[0] = Output("WETH", 0x4200000000000000000000000000000000000006);
        c.outputs[1] = Output("USDC", 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
        c.outputs[2] = Output("EURC", 0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42);
        c.outputs[3] = Output("cbBTC", 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf);
        c.outputs[4] = Output("AERO", 0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee);
        c.outputs[5] = Output("HYDX", 0x00000e7efa313F4E11Bfff432471eD9423AC6B30);
        c.exchanges = new ImmutableSwapper.Exchange[](8);
        c.exchanges[0] = _exchange(ImmutableSwapper.Kind.AeroClassic, AERO_VOLATILE);
        c.exchanges[1] = _exchange(ImmutableSwapper.Kind.AeroClassic, AERO_STABLE);
        c.exchanges[2] = _exchange(ImmutableSwapper.Kind.AeroSlipstream, 0x9CB220581b91b0C83223012FE69688b92aD07a76);
        c.exchanges[3] = _exchange(ImmutableSwapper.Kind.UniswapV2, 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6);
        c.exchanges[4] = _exchange(ImmutableSwapper.Kind.UniswapV3, 0x33128a8fC17869897dcE68Ed026d694621f6FDfD);
        c.exchanges[5] = _exchange(ImmutableSwapper.Kind.UniswapV4, 0x498581fF718922c3f8e6A244956aF099B2652b2b);
        c.exchanges[6] = _exchange(ImmutableSwapper.Kind.HydrexClassic, 0xC47F17c4fd96F50eFD2A2448ceDe5C185c084bf0);
        c.exchanges[7] = _exchange(ImmutableSwapper.Kind.HydrexAlgebra, 0x36077D39cdC65E1e3FB65810430E5b2c4D5fA29E);
    }

    function _optimism() private pure returns (Config memory c) {
        c.name = "optimism";
        c.outputs = new Output[](2);
        c.outputs[0] = Output("WETH", 0x4200000000000000000000000000000000000006);
        c.outputs[1] = Output("USDC", 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85);
        c.exchanges = _aeroAndUniswap(
            0xfeaB42D90055db3a0616249f76B6002D72266778,
            0x0c3c1c532F1e39EdF36BE9Fe0bE1410313E074Bf,
            0x1F98431c8aD98523631AE4a59f267346ea31F984,
            0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3
        );
    }

    function _arbitrum() private pure returns (Config memory c) {
        c.name = "arbitrum";
        c.outputs = new Output[](3);
        c.outputs[0] = Output("WETH", 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        c.outputs[1] = Output("USDC", 0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
        c.outputs[2] = Output("cbBTC", 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf);
        c.exchanges = _aeroAndUniswap(
            0x88a60ee77392577c355C0acb2A8d476D5a4EC03a,
            0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9,
            0x1F98431c8aD98523631AE4a59f267346ea31F984,
            0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32
        );
    }

    function _arc() private pure returns (Config memory c) {
        c.name = "arc";
        c.outputs = new Output[](3);
        c.outputs[0] = Output("USDC", 0x3600000000000000000000000000000000000000);
        c.outputs[1] = Output("EURC", 0xbEf5f6d51CB62b58e6A8f77868681825C6fe21c1);
        c.outputs[2] = Output("cirBTC", 0x171A4217b86A807A64eB94757Db6849fb4bDbAA0);
        c.exchanges = _aeroAndUniswap(
            0x7F83235643181E440433400a027618Cd50879751,
            0x89e5DB8B5aA49aA85AC63f691524311AEB649eba,
            0xf0db7b58379503491d857dB50AC9ece64c653918,
            0x8366a39CC670B4001A1121B8F6A443A643e40951
        );
    }

    function _aeroAndUniswap(address slipstream, address v2, address v3, address v4)
        private
        pure
        returns (ImmutableSwapper.Exchange[] memory e)
    {
        e = new ImmutableSwapper.Exchange[](6);
        e[0] = _exchange(ImmutableSwapper.Kind.AeroClassic, AERO_VOLATILE);
        e[1] = _exchange(ImmutableSwapper.Kind.AeroClassic, AERO_STABLE);
        e[2] = _exchange(ImmutableSwapper.Kind.AeroSlipstream, slipstream);
        e[3] = _exchange(ImmutableSwapper.Kind.UniswapV2, v2);
        e[4] = _exchange(ImmutableSwapper.Kind.UniswapV3, v3);
        e[5] = _exchange(ImmutableSwapper.Kind.UniswapV4, v4);
    }

    function _exchange(ImmutableSwapper.Kind kind, address factory)
        private
        pure
        returns (ImmutableSwapper.Exchange memory)
    {
        return ImmutableSwapper.Exchange(kind, factory);
    }
}
