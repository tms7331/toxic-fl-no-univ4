// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BaseHook} from "v4-periphery/BaseHook.sol";

import {Hooks} from "@uniswap/v4-core/contracts/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/contracts/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/contracts/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/contracts/types/BalanceDelta.sol";
import {AxiomV2Client} from "./AxiomV2Client.sol";

contract SuaveGatedFeeHook is BaseHook, AxiomV2Client {
    using PoolIdLibrary for PoolKey;

    mapping(PoolId => uint256 count) public beforeSwapCount;

    // We will store the results of our axiom queries here, but these maps will actually be queried from suave!
    mapping(address => bool) public isSolver;
    mapping(address => uint256) public swapTotals;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    // Not initializing this in constructor, so we'll have to do a function call to set it
    // AxiomV2Client(_axiomV2QueryAddress)

    function getHooksCalls() public pure override returns (Hooks.Calls memory) {
        return
            Hooks.Calls({
                beforeInitialize: false,
                afterInitialize: false,
                beforeModifyPosition: false,
                afterModifyPosition: false,
                beforeSwap: true,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false
            });
    }

    function _axiomV2Callback(
        uint64 sourceChainId,
        address callerAddr,
        bytes32 querySchema,
        uint256 queryId,
        bytes32[] calldata axiomResults,
        bytes calldata callbackExtraData
    ) internal virtual override {
        // TODO - manage these maps!
        //mapping(address => bool) public isSolver;
        //mapping(address => uint256) public swapTotals;
    }

    function _validateAxiomV2Call(
        uint64 sourceChainId,
        address callerAddr,
        bytes32 querySchema
    ) internal virtual override {
        // Hardcode expected chain to 5 for goerli for now?
        uint64 callbackSourceChainId = 5;
        require(
            sourceChainId == callbackSourceChainId,
            "AxiomV2: caller sourceChainId mismatch"
        );
        // TODO - let's add/track this...
        // require(
        //     querySchema == axiomCallbackQuerySchema,
        //     "AxiomV2: query schema mismatch"
        // );
    }

    function setUserFee() public {}

    function beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
        return BaseHook.beforeSwap.selector;
    }
}
