// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AethelMarketplaceV1.sol";

contract UpgradeMarketplace is Script {
    address constant PROXY = 0x86552B0e39CF2b4861cd0d34254F0fd98d23E852;

    function run() public {
        uint256 deployerPrivateKey = vm.envOr(
            "PRIVATE_KEY",
            uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
        );

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy new implementation contract
        AethelMarketplaceV1 newImplementation = new AethelMarketplaceV1();
        console.log("New Implementation Deployed at:", address(newImplementation));

        // 2. Upgrade the proxy pointing to the new implementation
        AethelMarketplaceV1 proxy = AethelMarketplaceV1(PROXY);
        proxy.upgradeToAndCall(address(newImplementation), "");
        console.log("Proxy successfully upgraded to new implementation!");

        vm.stopBroadcast();
    }
}
