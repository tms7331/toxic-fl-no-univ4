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

    // These will be set by suave function calls!
    address private _swapperAddress;
    uint24 private _swapperReducedFee;
    uint256 private _lastBlockNumber;

    // axiom querySchema for our 'isSolver' check
    bytes32 querySchema0;
    // axiom querySchema for our swap volume check
    bytes32 querySchema1;

    event AxiomV2Callback(
        uint64 indexed sourceChainId,
        address callerAddr,
        bytes32 indexed querySchema,
        uint256 indexed queryId
    );

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

    function setAxiomV2QuerySchema0(bytes32 _querySchema) public {
        querySchema0 = _querySchema;
    }

    function setAxiomV2QuerySchema1(bytes32 _querySchema) public {
        querySchema1 = _querySchema;
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
        address userAddress = address(uint160(uint256(axiomResults[0])));

        // query0 will be the cowswap solver one
        if (querySchema == querySchema0) {
            // No other params passsed/needed - if proof was passed in the address must be a solver
            isSolver[userAddress] = true;
        }
        // query1 will be user's total trading volume
        else if (querySchema == querySchema1) {
            uint256 swapVolume = uint256(axiomResults[1]);
            // we want to overwrite here -
            swapTotals[userAddress] = swapVolume;
        }

        emit AxiomV2Callback(sourceChainId, callerAddr, querySchema, queryId);
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
        // Would be nice to have validation of schema,
        // but not sure how to get values before deployment
        //require(
        //    querySchema == querySchema0 || querySchema == querySchema1,
        //    "AxiomV2: query schema mismatch"
        //);
    }

    // TODO - need to gate access to this function so it can ONLY be called by a suave transaction
    function setUserFee(
        address swapperAddress,
        uint24 swapperReducedFee
    ) public {
        _swapperAddress = swapperAddress;
        _swapperReducedFee = swapperReducedFee;
    }

    // This gets our dynamic fee
    function getFee(
        address sender,
        PoolKey calldata key
    ) external view returns (uint24) {
        // If user matches the user who has had their fees set, return the adjusted rate
        if (sender == _swapperAddress) {
            return _swapperReducedFee;
        }
        // 1% feees are the default
        return 10000;
    }

    function beforeSwap(
        address swapper,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
        // Make sure only the specified user gets the fee reduction
        //_swapperAddress

        // Enforce top of the block auction
        if (block.number > _lastBlockNumber) {
            // TODO - how exactly can we confirm this caller won the suave auction?
            // Idea for very ugly mechanism to enforce this would be to have hashes, sync up
            // some kind of lists in both contracts so 'calldata' has to be a secret word that will
            // produce an expected hash, but this is very ugly and would require a lot of storage

            _lastBlockNumber = block.number;
        }

        return BaseHook.beforeSwap.selector;
    }
}
