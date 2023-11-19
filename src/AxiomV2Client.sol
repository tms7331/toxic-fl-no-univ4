// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//import "./interfaces/IAxiomV2Client.sol";
import {IAxiomV2Client} from "./interfaces/IAxiomV2Client.sol";

abstract contract AxiomV2Client {
    // Hardcoding address on goerli
    // Reference: https://docs.axiom.xyz/transparency-and-security/contract-addresses
    address public immutable axiomV2QueryAddress =
        0xBd5307B0Bf573E3F2864Af960167b24Aa346952b;

    event AxiomV2Call(
        uint64 indexed sourceChainId,
        address callerAddr,
        bytes32 indexed querySchema,
        uint256 indexed queryId
    );

    // Want to deploy this contract before the axiom query, so let's just set it externally...
    //constructor(address _axiomV2QueryAddress) {
    //    axiomV2QueryAddress = _axiomV2QueryAddress;
    //}

    function axiomV2Callback(
        uint64 sourceChainId,
        address callerAddr,
        bytes32 querySchema,
        uint256 queryId,
        bytes32[] calldata axiomResults,
        bytes calldata callbackExtraData
    ) external {
        require(
            msg.sender == axiomV2QueryAddress,
            "AxiomV2Client: caller must be axiomV2QueryAddress"
        );
        //emit AxiomV2Call(sourceChainId, callerAddr, querySchema, queryId);

        _validateAxiomV2Call(sourceChainId, callerAddr, querySchema);
        _axiomV2Callback(
            sourceChainId,
            callerAddr,
            querySchema,
            queryId,
            axiomResults,
            callbackExtraData
        );
    }

    function _validateAxiomV2Call(
        uint64 sourceChainId,
        address callerAddr,
        bytes32 querySchema
    ) internal virtual;

    function _axiomV2Callback(
        uint64 sourceChainId,
        address callerAddr,
        bytes32 querySchema,
        uint256 queryId,
        bytes32[] calldata axiomResults,
        bytes calldata callbackExtraData
    ) internal virtual;
}
