// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AethelMarketplaceV1.sol";

/**
 * @notice Lists all 6 Æthel agents on-chain via the deployer key.
 *         Run once after deployment to seed the marketplace registry.
 *
 * Usage:
 *   make list-agents          (dry-run, no broadcast)
 *   make list-agents-live     (live broadcast to ARC testnet)
 */
contract ListAgents is Script {
    // ── Proxy address (already deployed) ─────────────────────────────────────
    address constant PROXY = 0x86552B0e39CF2b4861cd0d34254F0fd98d23E852;

    function run() public {
        uint256 deployerPrivateKey = vm.envOr(
            "PRIVATE_KEY",
            uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
        );

        AethelMarketplaceV1 market = AethelMarketplaceV1(PROXY);

        // ── Helper: only list if not already registered ───────────────────────
        vm.startBroadcast(deployerPrivateKey);

        _listIfNew(market, "agent_data_analysis",    3_000_000, '{"title":"Data Analysis Agent","description":"Processes large datasets, creates visualizations, and generates summaries in real-time.","icon":"ChartLine"}');
        _listIfNew(market, "agent_content_writing",  4_500_000, '{"title":"Content Writing","description":"SEO-optimized articles, whitepapers, and technical documentation with zero hallucination.","icon":"FileText"}');
        _listIfNew(market, "agent_python_coding",    6_000_000, '{"title":"Python Coding","description":"Automates script generation, debugging, and API integrations with enterprise standards.","icon":"Code"}');
        _listIfNew(market, "agent_lang_translation", 2_000_000, '{"title":"Language Translation","description":"High-fidelity translation across 40+ languages with deep cultural context awareness.","icon":"Translate"}');
        _listIfNew(market, "agent_image_gen",        5_000_000, '{"title":"Image Generation","description":"Photorealistic corporate assets and marketing visuals generated on demand.","icon":"Image"}');
        _listIfNew(market, "agent_ai_moderation",    2_500_000, '{"title":"AI Moderation","description":"Scalable community protection and content filtering with real-time enforcement.","icon":"ShieldCheck"}');

        vm.stopBroadcast();
    }

    function _listIfNew(AethelMarketplaceV1 market, string memory agentId, uint256 priceUsdc6, string memory metadataUri) internal {
        (,address creator,,,) = market.marketRegistry(agentId);
        if (creator == address(0)) {
            market.listAgent(agentId, priceUsdc6, metadataUri);
            console.log("Listed:", agentId, "at price:", priceUsdc6);
        } else {
            console.log("Already listed:", agentId);
        }
    }
}
