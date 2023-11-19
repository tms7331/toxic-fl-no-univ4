// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {GasSnapshot} from "forge-gas-snapshot/GasSnapshot.sol";
import {IHooks} from "@uniswap/v4-core/contracts/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/contracts/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/contracts/libraries/TickMath.sol";
import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/contracts/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/contracts/types/PoolId.sol";
import {Deployers} from "@uniswap/v4-core/contracts/../test/utils/Deployers.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/contracts/types/Currency.sol";
import {FeeLibrary} from "@uniswap/v4-core/contracts/libraries/FeeLibrary.sol";
import {BalanceDelta} from "@uniswap/v4-core/contracts/types/BalanceDelta.sol";
import {HookTest} from "./utils/HookTest.sol";
import {SuaveGatedFeeHook} from "../src/SuaveGatedFeeHook.sol";
import {HookMiner} from "./utils/HookMiner.sol";

contract SuaveGatedFeeHookTest is HookTest, Deployers, GasSnapshot {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    SuaveGatedFeeHook suaveHook;
    PoolKey poolKey;
    PoolId poolId;

    function setUp() public {
        // creates the pool manager, test tokens, and other utility routers
        HookTest.initHookTestEnv();

        // Deploy the hook to an address with the correct flags
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            type(SuaveGatedFeeHook).creationCode,
            abi.encode(address(manager))
        );
        suaveHook = new SuaveGatedFeeHook{salt: salt}(
            IPoolManager(address(manager))
        );
        require(
            address(suaveHook) == hookAddress,
            "SuaveGatedFeeHookTest: hook address mismatch"
        );

        // Create the pool
        poolKey = PoolKey(
            Currency.wrap(address(token0)),
            Currency.wrap(address(token1)),
            3000 | FeeLibrary.DYNAMIC_FEE_FLAG,
            60,
            IHooks(suaveHook)
        );
        poolId = poolKey.toId();
        console2.log("Pre Pool initialized");
        manager.initialize(poolKey, SQRT_RATIO_1_1, ZERO_BYTES);
        console2.log("Pool initialized");

        // Provide liquidity to the pool
        modifyPositionRouter.modifyPosition(
            poolKey,
            IPoolManager.ModifyPositionParams(-60, 60, 10 ether),
            ZERO_BYTES
        );
        modifyPositionRouter.modifyPosition(
            poolKey,
            IPoolManager.ModifyPositionParams(-120, 120, 10 ether),
            ZERO_BYTES
        );
        modifyPositionRouter.modifyPosition(
            poolKey,
            IPoolManager.ModifyPositionParams(
                TickMath.minUsableTick(60),
                TickMath.maxUsableTick(60),
                10 ether
            ),
            ZERO_BYTES
        );
    }

    function testSuaveGatedFeeHookDynamicFee() public {
        // Make sure hooks are dynamically set
        int256 amount = 1000;
        bool zeroForOne = true;
        // Default user - swap should execute, they should pay 1% fee!
        console2.log("Making first swap");
        BalanceDelta delta = swap(poolKey, amount, zeroForOne, ZERO_BYTES);
        int128 a0 = delta.amount0();
        int128 a1 = delta.amount1();
        // Delta is changes in the pool, so we swapped 1k for 989, price is 1 so 1%
        //console2.log(a0);
        //console2.log(a1);
        assertEq(a0, 1000);
        assertEq(a1, -989);

        // now we'll set the user to have a reduced fee - just set it to 0?  Then we should see that reflected in swap
        //suaveHook.setUserFee(address(this), 1);
        suaveHook.setUserFee(address(swapRouter), 0);

        //zeroForOne = false;
        // Default user - swap should execute, they should pay 1% fee!
        delta = swap(poolKey, amount, zeroForOne, ZERO_BYTES);
        // console2.log("Did two swaps...");
        a0 = delta.amount0();
        a1 = delta.amount1();

        // price has slightly moved, this is essentially 0 fees...
        assertEq(a0, 1000);
        assertEq(a1, -999);

        // console2.log(a0);
        // console2.log(a1);
        //// ------------------- //
        //assertEq(suaveHook.beforeSwapCount(poolId), 1);
        //assertEq(suaveHook.afterSwapCount(poolId), 1);
    }
}
