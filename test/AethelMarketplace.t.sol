// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AethelMarketplaceV1.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
contract MockUSDC {
    string public name = "Mock USDC";
    string public symbol = "USDC";
    uint8 public decimals = 6;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        _mint(msg.sender, 1_000_000 * 10**6);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "ERC20: transfer amount exceeds balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        require(balanceOf[sender] >= amount, "ERC20: transfer amount exceeds balance");
        require(allowance[sender][msg.sender] >= amount, "ERC20: transfer amount exceeds allowance");
        allowance[sender][msg.sender] -= amount;
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function _mint(address account, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }
}

contract AethelMarketplaceV2 is AethelMarketplaceV1 {
    uint256 public version;

    function initializeV2() external reinitializer(2) {
        version = 2;
    }

    function getVersion() external pure returns (uint256) {
        return 2;
    }
}

contract AethelMarketplaceTest is Test {
    AethelMarketplaceV1 public implementation;
    ERC1967Proxy public proxy;
    AethelMarketplaceV1 public marketplace;
    MockUSDC public usdc;

    address public owner;
    address public protocolTreasury;
    address public creator1;
    address public creator2;
    address public buyer1;
    address public buyer2;

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

    function setUp() public {
        owner = makeAddr("owner");
        protocolTreasury = makeAddr("protocolTreasury");
        creator1 = makeAddr("creator1");
        creator2 = makeAddr("creator2");
        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");

        // Deploy Mock USDC (6 Decimals)
        usdc = new MockUSDC();

        // Mint USDC to buyers
        usdc.mint(buyer1, 10_000 * 10**6);
        usdc.mint(buyer2, 10_000 * 10**6);

        // Deploy Marketplace V1 Implementation
        implementation = new AethelMarketplaceV1();

        // Encode initialization data
        bytes memory data = abi.encodeWithSelector(
            AethelMarketplaceV1.initialize.selector,
            address(usdc),
            protocolTreasury
        );

        // Deploy UUPS Proxy pointing to implementation
        vm.prank(owner);
        proxy = new ERC1967Proxy(address(implementation), data);

        // Wrap proxy in V1 interface
        marketplace = AethelMarketplaceV1(address(proxy));
    }

    // =========================================================================
    // 1. INITIALIZATION & UUPS COMPLIANCE TESTS
    // =========================================================================

    function testInitialization() public view {
        assertEq(marketplace.usdcToken(), address(usdc));
        assertEq(marketplace.protocolTreasury(), protocolTreasury);
        assertEq(marketplace.platformFeeBps(), 500);
        assertEq(marketplace.owner(), owner);
    }

    function testConstructorDisableInitializers() public {
        AethelMarketplaceV1 newImpl = new AethelMarketplaceV1();
        
        // Trying to call initialize on implementation contract should fail
        vm.expectRevert();
        newImpl.initialize(address(usdc), protocolTreasury);
    }

    // =========================================================================
    // 2. HAPPY PATHS: LISTING, PURCHASING, DELISTING, CONFIG
    // =========================================================================

    function testListMultipleAgents() public {
        vm.startPrank(creator1);
        
        vm.expectEmit(true, true, false, true);
        emit AgentListed("agent_1", 15 * 10**6, "meta1", creator1);
        marketplace.listAgent("agent_1", 15 * 10**6, "meta1");

        vm.expectEmit(true, true, false, true);
        emit AgentListed("agent_2", 30 * 10**6, "meta2", creator1);
        marketplace.listAgent("agent_2", 30 * 10**6, "meta2");
        
        vm.stopPrank();

        (string memory id1, address c1, uint256 p1, bool listed1,) = marketplace.marketRegistry("agent_1");
        assertEq(id1, "agent_1");
        assertEq(c1, creator1);
        assertEq(p1, 15 * 10**6);
        assertTrue(listed1);

        (string memory id2, address c2, uint256 p2, bool listed2,) = marketplace.marketRegistry("agent_2");
        assertEq(id2, "agent_2");
        assertEq(c2, creator1);
        assertEq(p2, 30 * 10**6);
        assertTrue(listed2);
    }

    function testPurchaseAgentSplitsAndLicense() public {
        // List an agent
        uint256 agentPrice = 100 * 10**6; // $100 USDC
        vm.prank(creator1);
        marketplace.listAgent("premium_agent", agentPrice, "premium_meta");

        // Buyer approves marketplace
        vm.startPrank(buyer1);
        usdc.approve(address(marketplace), agentPrice);

        // Purchase license
        vm.expectEmit(true, true, false, true);
        emit AgentPurchased(buyer1, "premium_agent", agentPrice);
        marketplace.purchaseAgent("premium_agent");
        vm.stopPrank();

        // Verify splits: 5% platform cut ($5 USDC), 95% creator cut ($95 USDC)
        uint256 expectedPlatformCut = (agentPrice * 500) / 10000; // 5 USDC
        uint256 expectedCreatorCut = agentPrice - expectedPlatformCut; // 95 USDC

        assertEq(usdc.balanceOf(protocolTreasury), expectedPlatformCut);
        assertEq(usdc.balanceOf(creator1), expectedCreatorCut);
        assertEq(usdc.balanceOf(buyer1), 10_000 * 10**6 - agentPrice);

        // Verify license recorded
        assertTrue(marketplace.userLicenses(buyer1, "premium_agent"));
    }

    function testDelistAgent() public {
        vm.prank(creator1);
        marketplace.listAgent("agent_to_delist", 10 * 10**6, "delist_meta");

        vm.prank(creator1);
        vm.expectEmit(true, false, false, true);
        emit AgentDelisted("agent_to_delist");
        marketplace.delistAgent("agent_to_delist");

        (,,, bool isListed,) = marketplace.marketRegistry("agent_to_delist");
        assertFalse(isListed);
    }

    function testSetPlatformFee() public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit FeeConfigUpdated(1000); // 10%
        marketplace.setPlatformFee(1000);

        assertEq(marketplace.platformFeeBps(), 1000);
    }

    // =========================================================================
    // 3. FAILURE MODES: ACCESS CONTROLS, BOUNDS, REDUNDANCIES
    // =========================================================================

    function testListAgentZeroPriceRevert() public {
        vm.prank(creator1);
        vm.expectRevert("Aethel: Price must exceed zero");
        marketplace.listAgent("agent_free", 0, "free_meta");
    }

    function testListAgentDuplicateIdRevert() public {
        vm.prank(creator1);
        marketplace.listAgent("unique_id", 10 * 10**6, "unique_meta");

        vm.prank(creator2);
        vm.expectRevert("Aethel: Agent ID already registered");
        marketplace.listAgent("unique_id", 20 * 10**6, "dup_meta");
    }

    function testPurchaseUnlistedRevert() public {
        // Not listed at all
        vm.startPrank(buyer1);
        usdc.approve(address(marketplace), 10 * 10**6);
        vm.expectRevert("Aethel: Agent is not active");
        marketplace.purchaseAgent("non_existent");
        vm.stopPrank();

        // Listed then delisted
        vm.prank(creator1);
        marketplace.listAgent("temp_agent", 10 * 10**6, "temp_meta");
        vm.prank(creator1);
        marketplace.delistAgent("temp_agent");

        vm.startPrank(buyer1);
        usdc.approve(address(marketplace), 10 * 10**6);
        vm.expectRevert("Aethel: Agent is not active");
        marketplace.purchaseAgent("temp_agent");
        vm.stopPrank();
    }

    function testPurchaseAlreadyLicensedRevert() public {
        vm.prank(creator1);
        marketplace.listAgent("agent_x", 10 * 10**6, "meta_x");

        vm.startPrank(buyer1);
        usdc.approve(address(marketplace), 20 * 10**6);
        
        marketplace.purchaseAgent("agent_x");
        
        vm.expectRevert("Aethel: License already claimed");
        marketplace.purchaseAgent("agent_x");
        vm.stopPrank();
    }

    function testPurchaseUSDCFailedRevert() public {
        vm.prank(creator1);
        marketplace.listAgent("expensive_agent", 50_000 * 10**6, "expensive_meta"); // More than buyer's balance

        vm.startPrank(buyer1);
        usdc.approve(address(marketplace), 50_000 * 10**6);
        vm.expectRevert(); // Standard ERC20 balance error
        marketplace.purchaseAgent("expensive_agent");
        vm.stopPrank();
    }

    // Creator delisting auth
    function testDelistNotCreatorRevert() public {
        vm.prank(creator1);
        marketplace.listAgent("creator_agent", 10 * 10**6, "creator_meta");

        vm.prank(creator2);
        vm.expectRevert("Aethel: Not your listing");
        marketplace.delistAgent("creator_agent");
    }

    function testSetPlatformFeeExceedsCapRevert() public {
        vm.prank(owner);
        vm.expectRevert("Aethel: Cap is 20%");
        marketplace.setPlatformFee(2001); // 20.01%
    }

    function testSetPlatformFeeNonOwnerRevert() public {
        vm.prank(creator1);
        vm.expectRevert(); // Inherited Ownable error
        marketplace.setPlatformFee(1000);
    }

    // =========================================================================
    // 4. UPGRADEABILITY VALIDATION TESTS
    // =========================================================================

    function testUpgradeImplementationPreservesState() public {
        // Setup initial state on V1
        vm.prank(creator1);
        marketplace.listAgent("agent_v1_legacy", 50 * 10**6, "legacy_meta");

        vm.startPrank(buyer1);
        usdc.approve(address(marketplace), 50 * 10**6);
        marketplace.purchaseAgent("agent_v1_legacy");
        vm.stopPrank();

        // Check state exists
        assertTrue(marketplace.userLicenses(buyer1, "agent_v1_legacy"));

        // Deploy V2 implementation
        AethelMarketplaceV2 implementationV2 = new AethelMarketplaceV2();

        // Perform upgrade by Owner
        vm.startPrank(owner);
        marketplace.upgradeToAndCall(
            address(implementationV2),
            abi.encodeWithSelector(AethelMarketplaceV2.initializeV2.selector)
        );
        vm.stopPrank();

        // Cast proxy address to V2 type
        AethelMarketplaceV2 marketplaceV2 = AethelMarketplaceV2(address(proxy));

        // Verify V2 specific function and state
        assertEq(marketplaceV2.getVersion(), 2);
        assertEq(marketplaceV2.version(), 2);

        // Verify historical state is preserved
        assertEq(marketplaceV2.usdcToken(), address(usdc));
        assertEq(marketplaceV2.protocolTreasury(), protocolTreasury);
        assertEq(marketplaceV2.platformFeeBps(), 500);

        (string memory id, address creator, uint256 price, bool listed,) = marketplaceV2.marketRegistry("agent_v1_legacy");
        assertEq(id, "agent_v1_legacy");
        assertEq(creator, creator1);
        assertEq(price, 50 * 10**6);
        assertTrue(listed);

        assertTrue(marketplaceV2.userLicenses(buyer1, "agent_v1_legacy"));
    }

    function testUpgradeNonOwnerRevert() public {
        AethelMarketplaceV2 implementationV2 = new AethelMarketplaceV2();

        vm.prank(creator1);
        vm.expectRevert(); // Inherited Ownable error
        marketplace.upgradeToAndCall(
            address(implementationV2),
            abi.encodeWithSelector(AethelMarketplaceV2.initializeV2.selector)
        );
    }
}
