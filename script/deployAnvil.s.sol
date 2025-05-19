// scripts/DeployAnvil.s.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/VirtualsSniper.sol";

contract DeployAnvil is Script {
    function run() external {
        // Use the first Anvil account as deployer
        uint256 deployerPrivateKey = vm.envUint("ANVIL_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Anvil-specific addresses (use the ones from your anvil output)
        address routerAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // Mock Uniswap
        address wethAddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // Mock WETH
        
        console.log("Deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);
        console.log("Router:", routerAddress);
        console.log("WETH:", wethAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        VirtualsSniper sniper = new VirtualsSniper(routerAddress, wethAddress);
        vm.stopBroadcast();
        
        console.log("VirtualSniper deployed at:", address(sniper));
    }
}