pragma solidity ^0.8.24;

import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

contract AATest is Test {
    MinimalAccount public account;

    function setUp() public {
        account = new MinimalAccount();
    }

    function test_consoleLog() public pure {
        console2.log("Hello, World!");
    }
}
