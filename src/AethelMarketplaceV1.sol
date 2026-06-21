// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IERC20 {
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
}

/**
 * @title Æthel Labs: Open Upgradeable Agent Marketplace (V1)
 * @notice UUPS-compliant marketplace allowing multi-vendor listings and custom splits
 */
contract AethelMarketplaceV1 is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    address public protocolTreasury;
    address public usdcToken;
    uint256 public platformFeeBps; // e.g., 500 = 5% platform fee cut

    struct AgentListing {
        string agentId;
        address creator;
        uint256 price; // Configured in 6 decimals for stable USDC tracking
        bool isListed;
        string metadataUri;
    }

    // Market item directory: agentId => Listing details
    mapping(string => AgentListing) public marketRegistry;

    // Access ledger to verify ownership: userAddress => agentId => activeLicense
    mapping(address => mapping(string => bool)) public userLicenses;

    event AgentListed(
        string indexed agentId,
        uint256 price,
        string metadataUri,
        address indexed developer
    );
    event AgentDelisted(string indexed agentId);
    event AgentPurchased(
        address indexed buyer,
        string indexed agentId,
        uint256 totalPaid
    );
    event FeeConfigUpdated(uint256 newFee);
    event TreasuryUpdated(
        address indexed oldTreasury,
        address indexed newTreasury
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // Essential Security Rule: Prevents direct interaction with the logic impl
        _disableInitializers();
    }

    /**
     * @notice Replaces the standard constructor for deployment proxy frameworks
     */
    function initialize(
        address _usdcToken,
        address _protocolTreasury
    ) public initializer {
        // Initializing inherited OpenZeppelin modules safely
        __Ownable_init(msg.sender);

        usdcToken = _usdcToken;
        protocolTreasury = _protocolTreasury;
        platformFeeBps = 500; // Defaults to a 5% cut for the platform
    }

    /**
     * @dev Mandatory internal authorization hook required by UUPS standard to restrict code upgrades
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {
        // Ensures only your master deployer/owner keys can point the proxy to a V2 implementation
    }

    /**
     * @notice Allows any developer to list an autonomous agent into the Æthel ecosystem
     * @param _agentId The unique string identifier for the system mapping
     * @param _price The price defined in 6-decimals (e.g., 6000000 for a $6.00 agent)
     * @param _metadataUri The metadata URI containing JSON strings for UI rendering
     */
    function listAgent(string calldata _agentId, uint256 _price, string calldata _metadataUri) external {
        require(_price > 0, "Aethel: Price must exceed zero");
        require(
            marketRegistry[_agentId].creator == address(0),
            "Aethel: Agent ID already registered"
        );

        marketRegistry[_agentId] = AgentListing({
            agentId: _agentId,
            creator: msg.sender,
            price: _price,
            isListed: true,
            metadataUri: _metadataUri
        });

        emit AgentListed(_agentId, _price, _metadataUri, msg.sender);
    }

    /**
     * @notice Allows a user to buy an agent license. Dynamically routes splits to creator and protocol treasury.
     * @param _agentId The specific tool or software stack identifier being deployed
     */
    function purchaseAgent(string calldata _agentId) external {
        AgentListing memory item = marketRegistry[_agentId];

        require(item.isListed, "Aethel: Agent is not active");
        require(
            !userLicenses[msg.sender][_agentId],
            "Aethel: License already claimed"
        );

        // Calculate fee breakdowns utilizing Basis Points (BPS)
        uint256 platformCut = (item.price * platformFeeBps) / 10000;
        uint256 creatorCut = item.price - platformCut;

        // Pull payment securely into the marketplace core from the user's Privy/Circle session
        require(
            IERC20(usdcToken).transferFrom(
                msg.sender,
                address(this),
                item.price
            ),
            "Aethel: USDC transfer failed"
        );

        // Disburse the respective value splits directly on-chain
        if (platformCut > 0) {
            IERC20(usdcToken).transfer(protocolTreasury, platformCut);
        }
        IERC20(usdcToken).transfer(item.creator, creatorCut);

        // Record permission boundaries natively
        userLicenses[msg.sender][_agentId] = true;

        emit AgentPurchased(msg.sender, _agentId, item.price);
    }

    /**
     * @notice Allows creators to temporarily or permanently remove their listings from the store front
     */
    function delistAgent(string calldata _agentId) external {
        require(
            marketRegistry[_agentId].creator == msg.sender,
            "Aethel: Not your listing"
        );
        marketRegistry[_agentId].isListed = false;
        emit AgentDelisted(_agentId);
    }

    /**
     * @notice Protocol level management tool to tune cut configurations
     */
    function setPlatformFee(uint256 _newFeeBps) external onlyOwner {
        require(_newFeeBps <= 2000, "Aethel: Cap is 20%"); // Guardrail to protect market trust
        platformFeeBps = _newFeeBps;
        emit FeeConfigUpdated(_newFeeBps);
    }

    /**
     * @notice Allows the protocol owner to route the platform fees to a new secure treasury destination
     * @param _newTreasury The address of the new corporate or multi-sig vault account
     */
    function updateTreasury(address _newTreasury) external onlyOwner {
        require(_newTreasury != address(0), "Aethel: Invalid treasury address");
        address oldTreasury = protocolTreasury;
        protocolTreasury = _newTreasury;

        emit TreasuryUpdated(oldTreasury, _newTreasury);
    }

    /**
     * @notice Allows the original listing creator or the protocol owner to update
     *         the metadataUri for an existing agent registration.
     *         Useful for backfilling metadata on agents listed before the V1 upgrade.
     * @param _agentId   The unique string identifier of the agent to update
     * @param _metadataUri The new JSON metadata string (title, description, icon)
     */
    function setAgentMetadata(string calldata _agentId, string calldata _metadataUri) external {
        address creator = marketRegistry[_agentId].creator;
        require(creator != address(0), "Aethel: Agent not registered");
        require(
            msg.sender == creator || msg.sender == owner(),
            "Aethel: Not authorized"
        );
        marketRegistry[_agentId].metadataUri = _metadataUri;
    }
}
