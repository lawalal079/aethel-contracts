# ==============================================================================
#  Æthel Labs — Marketplace Deployment Makefile
#  Target Network: ARC Testnet (Circle Layer-1, Chain ID: 5042002)
# ==============================================================================
-include .env

# Ensure Foundry binaries are on PATH (installed at ~/.foundry/bin in WSL)
export PATH := $(HOME)/.foundry/bin:$(PATH)

.PHONY: all build test clean coverage snapshot format \
        deploy-dry-run deploy-arc-testnet list-agents list-agents-live \
        upgrade-arc-testnet patch-metadata-dry patch-metadata-live verify help

# ------------------------------------------------------------------------------
# ARC Testnet Config
# ------------------------------------------------------------------------------
ARC_RPC_URL       ?= https://rpc.testnet.arc.network
ARC_CHAIN_ID      ?= 5042002
ARC_EXPLORER_URL  ?= https://testnet.arcscan.app

# Deploy script entrypoint
DEPLOY_SCRIPT     := script/Deploy.s.sol:DeployMarketplace

# ------------------------------------------------------------------------------
# Core targets
# ------------------------------------------------------------------------------
all: clean build test

build:
	@forge build

test:
	@forge test -vv

test-verbose:
	@forge test -vvvv

coverage:
	@forge coverage

snapshot:
	@forge snapshot

format:
	@forge fmt

clean:
	@forge clean

# ------------------------------------------------------------------------------
# Deployment — ARC Testnet
# ------------------------------------------------------------------------------

## Dry-run: simulate the full deployment locally — no broadcast, no gas spent
## Works without a PRIVATE_KEY in .env (uses Anvil default sender for simulation)
deploy-dry-run:
	@echo "==> Simulating deployment on ARC Testnet (no broadcast)..."
	@forge script $(DEPLOY_SCRIPT) \
		--rpc-url $(ARC_RPC_URL) \
		--chain-id $(ARC_CHAIN_ID) \
		--sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
		-vvvv

## Live deploy: broadcast transactions to ARC Testnet
deploy-arc-testnet:
	@echo "==> Deploying Aethel Marketplace to ARC Testnet (Chain ID: $(ARC_CHAIN_ID))..."
	@forge script $(DEPLOY_SCRIPT) \
		--rpc-url $(ARC_RPC_URL) \
		--chain-id $(ARC_CHAIN_ID) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--legacy \
		-vvvv

upgrade-arc-testnet:
	@echo "==> Upgrading Aethel Marketplace on ARC Testnet (Chain ID: $(ARC_CHAIN_ID))..."
	@forge script script/Upgrade.s.sol:UpgradeMarketplace \
		--rpc-url $(ARC_RPC_URL) \
		--chain-id $(ARC_CHAIN_ID) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--legacy \
		-vvvv


## Seed marketplace: list all 6 agents (dry-run, no broadcast)
list-agents:
	@echo "==> Simulating agent listings (no broadcast)..."
	@forge script script/ListAgents.s.sol:ListAgents \
		--rpc-url $(ARC_RPC_URL) \
		--chain-id $(ARC_CHAIN_ID) \
		-vvvv

## Seed marketplace: list all 6 agents (live broadcast)
list-agents-live:
	@echo "==> Listing agents on ARC Testnet (live broadcast)..."
	@forge script script/ListAgents.s.sol:ListAgents \
		--rpc-url $(ARC_RPC_URL) \
		--chain-id $(ARC_CHAIN_ID) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--legacy \
		-vvvv

## Backfill metadataUri for pre-upgrade listings (dry-run)
patch-metadata-dry:
	@echo "==> Simulating metadata patch (no broadcast)..."
	@forge script script/PatchMetadata.s.sol:PatchMetadata \
		--rpc-url $(ARC_RPC_URL) \
		--chain-id $(ARC_CHAIN_ID) \
		-vvvv

## Backfill metadataUri for pre-upgrade listings (live broadcast)
patch-metadata-live:
	@echo "==> Patching agent metadata on ARC Testnet (live broadcast)..."
	@forge script script/PatchMetadata.s.sol:PatchMetadata \
		--rpc-url $(ARC_RPC_URL) \
		--chain-id $(ARC_CHAIN_ID) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--legacy \
		-vvvv

## Verify contract source on ARC block explorer after deployment
## Usage: make verify CONTRACT=<proxy_or_impl_address>
verify:
	@echo "==> Verifying contract $(CONTRACT) on ARC Testnet explorer..."
	@forge verify-contract $(CONTRACT) \
		src/AethelMarketplaceV1.sol:AethelMarketplaceV1 \
		--rpc-url $(ARC_RPC_URL) \
		--chain-id $(ARC_CHAIN_ID) \
		--verifier blockscout \
		--verifier-url $(ARC_EXPLORER_URL)/api

# ------------------------------------------------------------------------------
# Help
# ------------------------------------------------------------------------------
help:
	@echo ""
	@echo "  Aethel Labs Marketplace — Available Commands"
	@echo "  ============================================="
	@echo "  make build              — Compile contracts"
	@echo "  make test               — Run test suite (verbose)"
	@echo "  make coverage           — Generate coverage report"
	@echo "  make clean              — Remove build artifacts"
	@echo "  make format             — Format Solidity files"
	@echo "  make deploy-dry-run     — Simulate deployment (no tx broadcast)"
	@echo "  make deploy-arc-testnet — Deploy to ARC Testnet (live broadcast)"
	@echo "  make upgrade-arc-testnet — Upgrade UUPS proxy to new implementation"
	@echo "  make patch-metadata-live — Backfill metadataUri on existing listings"
	@echo "  make verify CONTRACT=<addr> — Verify source on ARC explorer"
	@echo ""
	@echo "  Required .env vars:"
	@echo "    PRIVATE_KEY    — Deployer private key WITH 0x prefix (e.g. 0xabc123...)"
	@echo "    USDC_ADDRESS   — (optional) Testnet USDC token address"
	@echo "    TREASURY_ADDRESS — (optional) Protocol treasury address"
	@echo ""
