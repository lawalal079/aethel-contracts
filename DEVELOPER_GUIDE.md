# Developer Guide: Listing Agents on Æthel Labs Marketplace

The Æthel Labs Agent Marketplace is a fully decentralized, on-chain registry allowing multi-vendor autonomous agent listings. The marketplace UI renders listings dynamically by query-filtering the smart contract's state and transaction logs, meaning **there is no central database**.

Once you list your agent on-chain, it automatically propagates to the frontend UI for all users.

---

## 1. Network & Contract Reference

| Parameter | Value |
|---|---|
| **Target Network** | ARC Testnet (Circle L1) |
| **Chain ID** | `5042002` |
| **RPC Endpoint** | `https://rpc.testnet.arc.network` |
| **Block Explorer** | [testnet.arcscan.app](https://testnet.arcscan.app) |
| **Marketplace Proxy Address** | `0x86552B0e39CF2b4861cd0d34254F0fd98d23E852` |
| **USDC Token Address** | `0x3600000000000000000000000000000000000000` |

Both the proxy and implementation logic contract are fully verified on the explorer.

---

## 2. The Listing Interface

To register your agent, call the `listAgent` function on the marketplace contract:

```solidity
function listAgent(
    string calldata _agentId,
    uint256 _price,
    string calldata _metadataUri
) external;
```

### Parameters

1. **`_agentId`** (`string`): A unique alphanumeric identifier for your agent (e.g. `agent_data_analysis` or `my_translator_v1`). Must not be already registered.
2. **`_price`** (`uint256`): The price that users pay in USDC to license your agent, denominated in **6 decimals** (e.g. `$5.00` = `5000000`).
3. **`_metadataUri`** (`string`): A JSON string containing metadata for rendering in the UI. 
   
   ```json
   {
     "title": "Data Analyst Pro",
     "description": "Performs automatic database indexing and SQL optimizations.",
     "icon": "ChartLine"
   }
   ```

   * **Supported UI Icons:** `ChartLine`, `FileText`, `Code`, `Translate`, `Image`, `ShieldCheck` (falls back to a default gear icon if left empty or mismatching).
   * **Sanitization Policy:** To protect users, the frontend automatically strips HTML tags, filters out inline event handlers (XSS prevention), overrides `javascript:` URIs, and caps string inputs at `512` characters.

---

## 3. How to Submit a Listing

### Option A: Using the Block Explorer (No Code)
Since the contracts are verified, you can list directly using a browser wallet (e.g., Metamask):
1. Navigate to [Arcscan - Write Contract Tab](https://testnet.arcscan.app/address/0x86552B0e39CF2b4861cd0d34254F0fd98d23E852?tab=write_contract).
2. Connect your wallet to the block explorer.
3. Locate the `listAgent` function.
4. Input your `_agentId`, `_price` (in 6 decimals), and `_metadataUri` JSON string.
5. Click **Write** and approve the transaction.

---

### Option B: Using Foundry (CLI)
If you are developing inside the marketplace repository:
1. Open the seed script: [`ListAgents.s.sol`](file:///c:/Users/lawal/Documents/ARC/just-do-it/aethel-marketplace/script/ListAgents.s.sol#L30-L36)
2. Add your agent configuration under the broadcast block:
   ```solidity
   _listIfNew(market, "my_custom_agent", 5_000_000, '{"title":"My Custom Agent","description":"Details...","icon":"Code"}');
   ```
3. Run the deployment simulator to dry-run verification:
   ```bash
   make list-agents
   ```
4. Broadcast live to ARC Testnet:
   ```bash
   make list-agents-live
   ```

---

### Option C: Using a Node.js Script (Viem / Ethers)
You can call the listing contract dynamically inside your backend or deployment pipeline:

```typescript
import { createWalletClient, http, parseUnits, parseAbi } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';

const abi = parseAbi([
  'function listAgent(string calldata _agentId, uint256 _price, string calldata _metadataUri) external'
]);

const account = privateKeyToAccount('0xYOUR_PRIVATE_KEY');

const client = createWalletClient({
  account,
  transport: http('https://rpc.testnet.arc.network')
});

async function listAgent() {
  const hash = await client.writeContract({
    address: '0x86552B0e39CF2b4861cd0d34254F0fd98d23E852',
    abi,
    functionName: 'listAgent',
    args: [
      'agent_custom_translator',
      parseUnits('4.50', 6), // $4.50 USDC
      JSON.stringify({
        title: 'High Fidelity Translator',
        description: 'Translates documents across 40+ languages.',
        icon: 'Translate'
      })
    ]
  });
  console.log(`Listing transaction submitted: ${hash}`);
}
```

---

## 4. Revenue Sharing & Management

* **Fee Splits:** When a user licenses your agent, the contract splits the payment automatically:
  * **95%** goes directly to your developer address (the account that called `listAgent`).
  * **5%** goes to the platform's treasury.
* **Delisting:** If you wish to suspend listings, call `delistAgent(string calldata _agentId)` from your developer address.
* **Metadata Updates:** You can update description, title, or icon assets by calling `setAgentMetadata(string calldata _agentId, string calldata _metadataUri)`. Only the original developer or contract owner can update metadata.
