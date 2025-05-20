// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/VirtualsSniper.sol";

contract DeployVirtualsSniper is Script {
    function run() external {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address routerAddress = vm.envAddress("UNISWAP_ROUTER");
        address wethAddress = vm.envAddress("WETH_ADDRESS");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the contract
        VirtualsSniper sniper = new VirtualsSniper(
            routerAddress,
            wethAddress
        );

        vm.stopBroadcast();

        // Log important information
        console.log("VirtualsSniper deployed at:", address(sniper));
        console.log("Owner:", sniper.owner());
        console.log("Router:", address(sniper.router()));
        console.log("WETH:", sniper.WETH());
    }
}