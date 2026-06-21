// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/AethelMarketplaceV1.sol";

contract DeployMarketplace is Script {
    function run() public {
        // Falls back to Anvil's default key #0 for dry-run simulations (no --broadcast).
        // For live deployment, set PRIVATE_KEY=0x<your_key> in .env
        uint256 deployerPrivateKey = vm.envOr(
            "PRIVATE_KEY",
            uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
        );

        address testnetUsdc = vm.envOr("USDC_ADDRESS", address(0x3600000000000000000000000000000000000000));
        address treasury = vm.envOr("TREASURY_ADDRESS", address(0x2));

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy implementation (constructor calls _disableInitializers())
        AethelMarketplaceV1 implementation = new AethelMarketplaceV1();

        // 2. Encode the initializer call
        bytes memory initData = abi.encodeWithSelector(
            AethelMarketplaceV1.initialize.selector,
            testnetUsdc,
            treasury
        );

        // 3. Deploy ERC1967 UUPS proxy pointing to implementation
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        console.log(unicode"Aethel Labs Marketplace Implementation:", address(implementation));
        console.log(unicode"Aethel Labs Marketplace Proxy Deployed at:", address(proxy));

        vm.stopBroadcast();
    }
}