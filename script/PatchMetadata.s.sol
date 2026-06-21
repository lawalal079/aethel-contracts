// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AethelMarketplaceV1.sol";

/**
 * @notice Backfills metadataUri for the 6 agents that were listed before the
 *         V1 upgrade (when listAgent only accepted 2 args). Calls the new
 *         setAgentMetadata() function which was added in the second upgrade.
 *
 * Usage:
 *   make patch-metadata-dry    (simulate only)
 *   make patch-metadata-live   (broadcast to ARC Testnet)
 */
contract PatchMetadata is Script {
    address constant PROXY = 0x86552B0e39CF2b4861cd0d34254F0fd98d23E852;

    function run() public {
        uint256 deployerPrivateKey = vm.envOr(
            "PRIVATE_KEY",
            uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
        );

        AethelMarketplaceV1 market = AethelMarketplaceV1(PROXY);

        vm.startBroadcast(deployerPrivateKey);

        market.setAgentMetadata(
            "agent_data_analysis",
            '{"title":"Data Analysis Agent","description":"Processes large datasets, creates visualizations, and generates executive summaries in real-time.","icon":"ChartLine"}'
        );
        console.log("Patched: agent_data_analysis");

        market.setAgentMetadata(
            "agent_content_writing",
            '{"title":"Content Writing","description":"SEO-optimized articles, whitepapers, and technical documentation with zero hallucination.","icon":"FileText"}'
        );
        console.log("Patched: agent_content_writing");

        market.setAgentMetadata(
            "agent_python_coding",
            '{"title":"Python Coding","description":"Automates script generation, debugging, and API integrations with enterprise-grade standards.","icon":"Code"}'
        );
        console.log("Patched: agent_python_coding");

        market.setAgentMetadata(
            "agent_lang_translation",
            '{"title":"Language Translation","description":"High-fidelity translation across 40+ languages with deep cultural context awareness.","icon":"Translate"}'
        );
        console.log("Patched: agent_lang_translation");

        market.setAgentMetadata(
            "agent_image_gen",
            '{"title":"Image Generation","description":"Photorealistic corporate assets and marketing visuals generated on demand.","icon":"Image"}'
        );
        console.log("Patched: agent_image_gen");

        market.setAgentMetadata(
            "agent_ai_moderation",
            '{"title":"AI Moderation","description":"Scalable community protection and content filtering with real-time enforcement.","icon":"ShieldCheck"}'
        );
        console.log("Patched: agent_ai_moderation");

        vm.stopBroadcast();
    }
}
