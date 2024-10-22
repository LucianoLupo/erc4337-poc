// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {TheAccount} from "src/TheAccount.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract Deploy is Script {
    function run() public {
        deployAccount();
    }

    function deployAccount() public returns (HelperConfig, TheAccount) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.account);
        TheAccount account = new TheAccount(config.entryPoint);
        account.transferOwnership(config.account);
        vm.stopBroadcast();
        return (helperConfig, account);
    }
}