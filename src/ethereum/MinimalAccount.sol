// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
// Learn more about how AA smart contracts should look like: https://eips.ethereum.org/EIPS/eip-4337

contract MinimalAccount is IAccount, Ownable {
    // ================================================================
    // │                        CUSTOM ERRORS                         │
    // ================================================================
    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner();
    error MinimalAccount__CallFailed(bytes);

    // ================================================================
    // │                       STATE VARIABLES                        │
    // ================================================================

    IEntryPoint private immutable i_entryPoint;

    // ================================================================
    // │                         MODIFIERS                            │
    // ================================================================
    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__NotFromEntryPoint();
        }
        _;
    }

    modifier requireFromEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MinimalAccount__NotFromEntryPointOrOwner();
        }
        _;
    }

    // ================================================================
    // │                        CONSTRUCTOR                           │
    // ================================================================
    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    // ================================================================
    // │                      EXTERNAL FUNCTIONS                      │
    // ================================================================
    function execute(address dest, uint256 value, bytes calldata functionData) external {
        (bool success, bytes memory result) = dest.call{value: value}(functionData);

        if (!success) {
            revert MinimalAccount__CallFailed(result);
        }
    }

    receive() external payable {}

    // A signature is valid if its the minimal account contract owner (we can get creative and add more logic but for this example we'll keep it simple)
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        requireFromEntryPoint
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);
        // _validateNonce()
        _payPrefund(missingAccountFunds);
    }

    // ================================================================
    // │                      INTERNAL FUNCTIONS                      │
    // ================================================================
    // EIP-191 version of the signed hash
    // Here essentially we could add any logic as long as we return SIG_VALIDATION_SUCCESS or SIG_VALIDATION_FAILED for a valid or invalid signature respectively
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256)
    {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);

        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }

        return SIG_VALIDATION_SUCCESS;
    }

    // Paying back the entry point contract that initially paid the gas to submit our transaction
    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            (success);
        }
    }

    // ================================================================
    // │                           GETTERS                            │
    // ================================================================
    function getEntryPoint() external view returns (address) {
        return address(i_entryPoint);
    }
}
