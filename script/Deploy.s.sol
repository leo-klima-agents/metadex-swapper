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

    uint256 public constant BASE = 8453;
    address public constant TREASURY = 0x450c72de8c0079B49AcedF294a13011bd09D125B;

    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant EURC = 0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42;
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address public constant AERO = 0x3f5bF3EdAc59d650D8fDf9657a71F2f904A3a4Ee;
    address public constant HYDX = 0x00000e7efa313F4E11Bfff432471eD9423AC6B30;

    address public constant HYDREX_ALGEBRA = 0x36077D39cdC65E1e3FB65810430E5b2c4D5fA29E;
    address public constant HYDREX_CLASSIC = 0xC47F17c4fd96F50eFD2A2448ceDe5C185c084bf0;
    address public constant AERO_VOLATILE = 0x8E6a9FCd1d638CC760Ffba397605Fe3355dE76D2;
    address public constant AERO_STABLE = 0x78589E876edcEbdce72ee3436ab3c9AD3a7cEF2D;
    address public constant AERO_SLIPSTREAM = 0x9CB220581b91b0C83223012FE69688b92aD07a76;
    address public constant UNISWAP_V2 = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;
    address public constant UNISWAP_V3 = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;
    address public constant UNISWAP_V4 = 0x498581fF718922c3f8e6A244956aF099B2652b2b;

    string public constant SALT_PREIMAGE = "metadex.cafe/ImmutableSwapper/v2";
    bytes32 public constant SALT = keccak256(bytes(SALT_PREIMAGE));

    function chains() public pure returns (uint256[] memory list) {
        list = new uint256[](1);
        list[0] = BASE;
    }

    function chainName(uint256 chainId) public pure returns (string memory) {
        if (chainId == BASE) return "base";
        revert("unsupported chain");
    }

    function outputs(uint256 chainId) public pure returns (Output[] memory o) {
        if (chainId == BASE) {
            o = new Output[](6);
            o[0] = Output("USDC", USDC);
            o[1] = Output("EURC", EURC);
            o[2] = Output("WETH", WETH);
            o[3] = Output("cbBTC", CBBTC);
            o[4] = Output("AERO", AERO);
            o[5] = Output("HYDX", HYDX);
            return o;
        }
        revert("unsupported chain");
    }

    function exchanges(uint256 chainId) public pure returns (ImmutableSwapper.Exchange[] memory e) {
        if (chainId == BASE) {
            e = new ImmutableSwapper.Exchange[](8);
            e[0] = ImmutableSwapper.Exchange(ImmutableSwapper.Kind.HydrexAlgebra, HYDREX_ALGEBRA);
            e[1] = ImmutableSwapper.Exchange(ImmutableSwapper.Kind.HydrexClassic, HYDREX_CLASSIC);
            e[2] = ImmutableSwapper.Exchange(ImmutableSwapper.Kind.AeroClassic, AERO_VOLATILE);
            e[3] = ImmutableSwapper.Exchange(ImmutableSwapper.Kind.AeroClassic, AERO_STABLE);
            e[4] = ImmutableSwapper.Exchange(ImmutableSwapper.Kind.AeroSlipstream, AERO_SLIPSTREAM);
            e[5] = ImmutableSwapper.Exchange(ImmutableSwapper.Kind.UniswapV2, UNISWAP_V2);
            e[6] = ImmutableSwapper.Exchange(ImmutableSwapper.Kind.UniswapV3, UNISWAP_V3);
            e[7] = ImmutableSwapper.Exchange(ImmutableSwapper.Kind.UniswapV4, UNISWAP_V4);
            return e;
        }
        revert("unsupported chain");
    }

    function kindName(ImmutableSwapper.Kind kind) public pure returns (string memory) {
        string[7] memory names =
            ["HydrexAlgebra", "HydrexClassic", "AeroClassic", "AeroSlipstream", "UniswapV2", "UniswapV3", "UniswapV4"];
        return names[uint256(kind)];
    }

    function constructorArgs(uint256 chainId, address outputToken) public pure returns (bytes memory) {
        return abi.encode(outputToken, exchanges(chainId));
    }

    function initCode(uint256 chainId, address outputToken) public pure returns (bytes memory) {
        return bytes.concat(type(ImmutableSwapper).creationCode, constructorArgs(chainId, outputToken));
    }

    function predict(uint256 chainId, address outputToken) public pure returns (address) {
        return vm.computeCreate2Address(SALT, keccak256(initCode(chainId, outputToken)), CREATE2_FACTORY);
    }

    function run() external returns (address[] memory deployed) {
        uint256 chainId = block.chainid;
        string memory name = chainName(chainId);
        require(CREATE2_FACTORY.code.length != 0, "CREATE2 deployer not present");
        require(TREASURY.code.length != 0, "treasury not deployed on this chain");
        ImmutableSwapper.Exchange[] memory e = exchanges(chainId);
        for (uint256 i; i < e.length; ++i) {
            require(e[i].factory.code.length != 0, "exchange has no code");
        }
        string memory recorded = vm.readFile("verification/bytecode-hashes.json");
        Output[] memory o = outputs(chainId);
        deployed = new address[](o.length);
        for (uint256 i; i < o.length; ++i) {
            require(o[i].token.code.length != 0, "output token has no code");
            deployed[i] = predict(chainId, o[i].token);
            console.log(o[i].symbol, deployed[i]);
            string memory key = string.concat(".chains.", name, ".deployments.", o[i].symbol, ".address");
            require(
                deployed[i] == vm.parseJsonAddress(recorded, key),
                "build differs from verification/bytecode-hashes.json"
            );
        }
        for (uint256 i; i < o.length; ++i) {
            if (deployed[i].code.length != 0) {
                console.log(o[i].symbol, "already deployed");
                continue;
            }
            vm.broadcast();
            (bool ok,) = CREATE2_FACTORY.call(bytes.concat(SALT, initCode(chainId, o[i].token)));
            require(ok && deployed[i].code.length != 0, "CREATE2 deploy failed");
            console.log(o[i].symbol, "deployed");
        }
    }
}
