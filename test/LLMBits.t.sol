// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {LLMBits, ITokenAI} from "../src/LLMBits.sol";
import {TokenAI} from "../src/TokenAI.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract LLMBitsTest is Test {
    using Strings for uint256;
    LLMBits public llmBits;
    TokenAI public tokenAI;
    
    address public owner;
    address public user1;
    address public user2;
    address public originPool;
    address public treasury;
    
    string public constant BASE_URI = "https://api.example.com/metadata/";
    uint256 public constant INITIAL_TOKEN_SUPPLY = 1000000 * 10**18;
    
    // Test token configuration
    bytes16 public constant MODEL = "gpt-4";
    bytes16 public constant SCOPE = "course-101";
    uint64 public expiration;
    bool public constant RECLAIMABLE = true;
    bool public constant TRADABLE = true;
    
    event TokenMinted(
        address indexed to,
        uint256 indexed tokenId,
        uint256 amount,
        bytes16 model,
        bytes16 scope,
        uint64 expiration,
        address originPool,
        bool reclaimable,
        bool tradable
    );
    
    event FeeAppliedNative(
        address indexed partyA,
        address indexed partyB,
        uint256 feeANative,
        uint256 feeBNative,
        address indexed treasury
    );
    
    
    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        originPool = makeAddr("originPool");
        treasury = makeAddr("treasury");
        
        expiration = uint64(block.timestamp + 30 days);
        
        vm.startPrank(owner);
        
        // Deploy TokenAI first
        tokenAI = new TokenAI("TokenAI", "TAI", INITIAL_TOKEN_SUPPLY);
        
        // Deploy LLMBits with TokenAI address
        llmBits = new LLMBits(BASE_URI, address(tokenAI));
        
        // Set fee recipient
        llmBits.setTreasury(treasury);
        
        // Set LLMBits as authorized minter for TokenAI
        tokenAI.setMinter(address(llmBits), true);
        
        vm.stopPrank();
    }
    
    /*─────────────────────── Deployment Tests ───────────────────────*/
    
    function testDeployment() public view {
        assertEq(address(llmBits.tokenAi()), address(tokenAI));
        assertEq(llmBits.treasury(), treasury);
        assertEq(llmBits.owner(), owner);
        assertFalse(llmBits.paused());
    }
    
    function testDeploymentWithoutTokenAI() public {
        vm.prank(owner);
        LLMBits newContract = new LLMBits(BASE_URI, address(0));
        
        assertEq(address(newContract.tokenAi()), address(0));
    }
    
    /*─────────────────────── Admin Controls Tests ───────────────────────*/
    
    function testPause() public {
        vm.prank(owner);
        llmBits.pause();
        
        assertTrue(llmBits.paused());
    }
    
    function testUnpause() public {
        vm.startPrank(owner);
        llmBits.pause();
        llmBits.unpause();
        vm.stopPrank();
        
        assertFalse(llmBits.paused());
    }
    
    function testSetBaseUri() public {
        string memory newUri = "https://newapi.example.com/";
        
        vm.prank(owner);
        llmBits.setBaseUri(newUri);
        
        uint256 tokenId = llmBits.computeTokenId(originPool, MODEL, SCOPE, expiration, RECLAIMABLE, TRADABLE);
        string memory expectedUri = string(abi.encodePacked(newUri, tokenId.toHexString(32), ".json"));
        assertEq(llmBits.uri(tokenId), expectedUri);
    }
    
    function testSetFeeToken() public {
        TokenAI newToken = new TokenAI("NewToken", "NEW", 0);
        
        vm.prank(owner);
        llmBits.setFeeToken(address(newToken));
        
        assertEq(address(llmBits.tokenAi()), address(newToken));
    }
    
    function testSetTreasury() public {
        address newRecipient = makeAddr("newRecipient");
        
        vm.prank(owner);
        llmBits.setTreasury(newRecipient);
        
        assertEq(llmBits.treasury(), newRecipient);
    }
    
    function testOnlyOwnerFunctions() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        llmBits.pause();
        
        vm.expectRevert();
        llmBits.setBaseUri("test");
        
        vm.expectRevert();
        llmBits.setFeeToken(address(tokenAI));
        
        vm.expectRevert();
        llmBits.setTreasury(user2);
        
        vm.stopPrank();
    }
    
    /*─────────────────────── Token ID Computation Tests ───────────────────────*/
    
    function testComputeTokenId() public view {
        uint256 tokenId1 = llmBits.computeTokenId(originPool, MODEL, SCOPE, expiration, RECLAIMABLE, TRADABLE);
        uint256 tokenId2 = llmBits.computeTokenId(originPool, MODEL, SCOPE, expiration, RECLAIMABLE, TRADABLE);
        
        // Same parameters should produce same ID
        assertEq(tokenId1, tokenId2);
        
        // Different parameters should produce different ID
        uint256 tokenId3 = llmBits.computeTokenId(originPool, "gpt-3", SCOPE, expiration, RECLAIMABLE, TRADABLE);
        assertTrue(tokenId1 != tokenId3);
    }
    
    function testTokenIdDeterminism() public view {
        uint256 tokenId = llmBits.computeTokenId(originPool, MODEL, SCOPE, expiration, RECLAIMABLE, TRADABLE);
        
        // Should be deterministic across calls
        for (uint i = 0; i < 5; i++) {
            uint256 newId = llmBits.computeTokenId(originPool, MODEL, SCOPE, expiration, RECLAIMABLE, TRADABLE);
            assertEq(tokenId, newId);
        }
    }
    
    /*─────────────────────── Minting Tests ───────────────────────*/
    
    function testMintToAddress() public {
        uint256 amount = 1000;
        uint256 expectedTokenId = llmBits.computeTokenId(originPool, MODEL, SCOPE, expiration, RECLAIMABLE, TRADABLE);
        
        vm.expectEmit(true, true, false, true);
        emit TokenMinted(user1, expectedTokenId, amount, MODEL, SCOPE, expiration, originPool, RECLAIMABLE, TRADABLE);
        
        vm.prank(owner);
        uint256 tokenId = llmBits.mintToAddress(user1, originPool, MODEL, SCOPE, expiration, RECLAIMABLE, TRADABLE, amount);
        
        assertEq(llmBits.balanceOf(user1, tokenId), amount);
        assertEq(llmBits.totalSupply(tokenId), amount);
        
        // Check token config
        LLMBits.TokenConfigs memory config = llmBits.getConfig(tokenId);
        assertEq(config.model, MODEL);
        assertEq(config.scope, SCOPE);
        assertEq(config.expiration, expiration);
        assertEq(config.originPool, originPool);
        assertEq(config.reclaimable, RECLAIMABLE);
        assertEq(config.tradable, TRADABLE);
    }
    
    function testMintSameTokenMultipleTimes() public {
        uint256 amount1 = 500;
        uint256 amount2 = 300;
        
        vm.startPrank(owner);
        uint256 tokenId1 = llmBits.mintToAddress(user1, originPool, MODEL, SCOPE, expiration, RECLAIMABLE, TRADABLE, amount1);
        uint256 tokenId2 = llmBits.mintToAddress(user2, originPool, MODEL, SCOPE, expiration, RECLAIMABLE, TRADABLE, amount2);
        vm.stopPrank();
        
        // Should be same token ID
        assertEq(tokenId1, tokenId2);
        
        // Total supply should be sum
        assertEq(llmBits.totalSupply(tokenId1), amount1 + amount2);
        assertEq(llmBits.balanceOf(user1, tokenId1), amount1);
        assertEq(llmBits.balanceOf(user2, tokenId1), amount2);
    }
    
    function testMintZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert();
        llmBits.mintToAddress(user1, originPool, MODEL, SCOPE, expiration, RECLAIMABLE, TRADABLE, 0);
    }
    
    function testMintToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(LLMBits.ZeroAddress.selector);
        llmBits.mintToAddress(address(0), originPool, MODEL, SCOPE, expiration, RECLAIMABLE, TRADABLE, 1000);
    }
    
    function testMintZeroOriginPool() public {
        vm.prank(owner);
        vm.expectRevert(LLMBits.ZeroAddress.selector);
        llmBits.mintToAddress(user1, address(0), MODEL, SCOPE, expiration, RECLAIMABLE, TRADABLE, 1000);
    }
    
    /*─────────────────────── Transfer Tests ───────────────────────*/
    
    function testTransfer() public {
        uint256 tokenId = _mintTokenToUser(user1, 1000);
        uint256 transferAmount = 300;
        uint256 feeNative = 10 * 10**18;
        
        // Give user1 some TokenAI for fees
        vm.prank(owner);
        tokenAI.mint(user1, feeNative);
        
        // User1 approves LLMBits to burn TokenAI
        vm.prank(user1);
        tokenAI.approve(address(llmBits), feeNative);
        
        vm.prank(owner);
        llmBits.transfer(user1, user2, tokenId, transferAmount, feeNative);
        
        assertEq(llmBits.balanceOf(user1, tokenId), 1000 - transferAmount);
        assertEq(llmBits.balanceOf(user2, tokenId), transferAmount);
        assertEq(tokenAI.balanceOf(treasury), feeNative);
    }
    
    function testTransferNonTradableFromOriginPool() public {
        uint256 tokenId = _mintTokenToUser(originPool, 1000, false); // Non-tradable
        
        vm.prank(owner);
        llmBits.transfer(originPool, user1, tokenId, 300, 0);
        
        assertEq(llmBits.balanceOf(user1, tokenId), 300);
    }
    
    function testTransferNonTradableFromNonOriginPool() public {
        uint256 tokenId = _mintTokenToUser(user1, 1000, false); // Non-tradable
        
        vm.prank(owner);
        vm.expectRevert(LLMBits.TokenNotTradable.selector);
        llmBits.transfer(user1, user2, tokenId, 300, 0);
    }
    
    function testTransferExpiredToken() public {
        uint64 pastExpiration = uint64(block.timestamp + 1 days);
        uint256 tokenId = _mintTokenWithExpiration(user1, 1000, pastExpiration);
        
        // Move time forward to make token expired
        vm.warp(block.timestamp + 2 days);
        
        vm.prank(owner);
        vm.expectRevert(LLMBits.TokenExpired.selector);
        llmBits.transfer(user1, user2, tokenId, 300, 0);
    }
    
    function testTransferInsufficientBalance() public {
        uint256 tokenId = _mintTokenToUser(user1, 1000);
        
        vm.prank(owner);
        vm.expectRevert();
        llmBits.transfer(user1, user2, tokenId, 1500, 0); // More than balance
    }
    
    /*─────────────────────── Batch Transfer Tests ───────────────────────*/
    
    function testBatchTransfer() public {
        uint256 tokenId = _mintTokenToUser(user1, 2000);
        
        address[] memory recipients = new address[](3);
        recipients[0] = user2;
        recipients[1] = makeAddr("user3");
        recipients[2] = makeAddr("user4");
        
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 300;
        amounts[1] = 200;
        amounts[2] = 100;
        
        uint256[] memory feesNative = new uint256[](3);
        feesNative[0] = 5 * 10**18;
        feesNative[1] = 3 * 10**18;
        feesNative[2] = 2 * 10**18;
        
        // Give user1 TokenAI for fees
        uint256 totalNativeFees = 10 * 10**18;
        vm.prank(owner);
        tokenAI.mint(user1, totalNativeFees);
        
        vm.prank(user1);
        tokenAI.approve(address(llmBits), totalNativeFees);
        
        vm.prank(owner);
        llmBits.batchTransfer(user1, recipients, tokenId, amounts, feesNative);
        
        // Check balances
        assertEq(llmBits.balanceOf(recipients[0], tokenId), amounts[0]);
        assertEq(llmBits.balanceOf(recipients[1], tokenId), amounts[1]);
        assertEq(llmBits.balanceOf(recipients[2], tokenId), amounts[2]);
        
        // Check fees collected
        assertEq(tokenAI.balanceOf(treasury), totalNativeFees);
        
        // Check remaining balance
        uint256 totalTransferred = 600; // 300 + 200 + 100
        assertEq(llmBits.balanceOf(user1, tokenId), 2000 - totalTransferred);
    }
    
    function testBatchTransferArrayLengthMismatch() public {
        uint256 tokenId = _mintTokenToUser(user1, 1000);
        
        address[] memory recipients = new address[](2);
        recipients[0] = user2;
        recipients[1] = makeAddr("user3");
        
        uint256[] memory amounts = new uint256[](3); // Wrong length
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 150;
        
        uint256[] memory feesNative = new uint256[](2);
        
        vm.prank(owner);
        vm.expectRevert(LLMBits.ArrayLengthMismatch.selector);
        llmBits.batchTransfer(user1, recipients, tokenId, amounts, feesNative);
    }
    
    /*─────────────────────── Trading Tests ───────────────────────*/
    
    function testTradeWithNativeFees() public {
        // Create different token types for trading
        vm.startPrank(owner);
        uint256 tokenIdA = llmBits.mintToAddress(user1, originPool, MODEL, "course-a", expiration, RECLAIMABLE, TRADABLE, 1000);
        uint256 tokenIdB = llmBits.mintToAddress(user2, originPool, MODEL, "course-b", expiration, RECLAIMABLE, TRADABLE, 800);
        vm.stopPrank();
        
        uint256 amountA = 300;
        uint256 amountB = 200;
        uint256 feeANative = 5 * 10**18;
        uint256 feeBNative = 3 * 10**18;
        
        // Give users TokenAI for fees
        vm.startPrank(owner);
        tokenAI.mint(user1, feeANative);
        tokenAI.mint(user2, feeBNative);
        vm.stopPrank();
        
        // Users approve LLMBits to burn their TokenAI
        vm.prank(user1);
        tokenAI.approve(address(llmBits), feeANative);
        vm.prank(user2);
        tokenAI.approve(address(llmBits), feeBNative);
        
        vm.prank(owner);
        llmBits.tradeWithNativeFees(user1, user2, tokenIdA, amountA, tokenIdB, amountB, 0, feeANative, feeBNative);
        
        // Check token swaps
        assertEq(llmBits.balanceOf(user1, tokenIdA), 1000 - amountA);
        assertEq(llmBits.balanceOf(user1, tokenIdB), amountB);
        assertEq(llmBits.balanceOf(user2, tokenIdA), amountA);
        assertEq(llmBits.balanceOf(user2, tokenIdB), 800 - amountB);
        
        // Check fees collected
        assertEq(tokenAI.balanceOf(treasury), feeANative + feeBNative);
    }
    
    
    /*─────────────────────── Burn and Remint Tests ───────────────────────*/
    
    function testBurnAndRemintExpired() public {
        uint64 pastExpiration = uint64(block.timestamp + 1 days);
        uint256 oldTokenId = _mintTokenWithExpiration(user1, 1000, pastExpiration);
        
        // Move time forward to make token expired
        vm.warp(block.timestamp + 2 days);
        
        uint64 newExpiration = uint64(block.timestamp + 30 days);
        
        vm.prank(owner);
        uint256 newTokenId = llmBits.burnAndRemintExpired(user1, oldTokenId, newExpiration);
        
        // Old token should be burned
        assertEq(llmBits.balanceOf(user1, oldTokenId), 0);
        assertEq(llmBits.totalSupply(oldTokenId), 0);
        
        // New token should be minted
        assertEq(llmBits.balanceOf(user1, newTokenId), 1000);
        assertEq(llmBits.totalSupply(newTokenId), 1000);
        
        // Check new token config
        LLMBits.TokenConfigs memory config = llmBits.getConfig(newTokenId);
        assertEq(config.expiration, newExpiration);
    }
    
    function testBurnAndRemintNotExpired() public {
        uint256 tokenId = _mintTokenToUser(user1, 1000); // Not expired
        uint64 newExpiration = uint64(block.timestamp + 60 days);
        
        vm.prank(owner);
        vm.expectRevert(LLMBits.TokenNotExpired.selector);
        llmBits.burnAndRemintExpired(user1, tokenId, newExpiration);
    }
    
    function testBurnAndRemintInvalidExpiration() public {
        uint64 pastExpiration = uint64(block.timestamp + 1 days);
        uint256 tokenId = _mintTokenWithExpiration(user1, 1000, pastExpiration);
        
        // Move time forward to make token expired
        vm.warp(block.timestamp + 2 days);
        
        uint64 invalidExpiration = uint64(block.timestamp - 1 hours); // Past time
        
        vm.prank(owner);
        vm.expectRevert(LLMBits.InvalidExpiration.selector);
        llmBits.burnAndRemintExpired(user1, tokenId, invalidExpiration);
    }
    
    /*─────────────────────── Helper Functions ───────────────────────*/
    
    function _mintTokenToUser(address user, uint256 amount) internal returns (uint256 tokenId) {
        return _mintTokenToUser(user, amount, TRADABLE);
    }
    
    function _mintTokenToUser(address user, uint256 amount, bool tradable) internal returns (uint256 tokenId) {
        vm.prank(owner);
        tokenId = llmBits.mintToAddress(user, originPool, MODEL, SCOPE, expiration, RECLAIMABLE, tradable, amount);
    }
    
    function _mintTokenWithExpiration(address user, uint256 amount, uint64 exp) internal returns (uint256 tokenId) {
        vm.prank(owner);
        tokenId = llmBits.mintToAddress(user, originPool, MODEL, SCOPE, exp, RECLAIMABLE, TRADABLE, amount);
    }
    
    /*─────────────────────── View Function Tests ───────────────────────*/
    
    function testIsExpired() public {
        uint64 shortExpiration = uint64(block.timestamp + 1 days);
        uint64 futureExpiration = uint64(block.timestamp + 30 days);
        
        uint256 shortTokenId = _mintTokenWithExpiration(user1, 1000, shortExpiration);
        uint256 validTokenId = _mintTokenWithExpiration(user1, 1000, futureExpiration);
        uint256 noExpirationTokenId = _mintTokenWithExpiration(user1, 1000, 0);
        
        // Initially not expired
        assertFalse(llmBits.isExpired(shortTokenId));
        assertFalse(llmBits.isExpired(validTokenId));
        assertFalse(llmBits.isExpired(noExpirationTokenId));
        
        // Move time forward to expire short token
        vm.warp(block.timestamp + 2 days);
        
        assertTrue(llmBits.isExpired(shortTokenId));
        assertFalse(llmBits.isExpired(validTokenId));
        assertFalse(llmBits.isExpired(noExpirationTokenId));
    }
    
    function testGetConfig() public {
        uint256 tokenId = _mintTokenToUser(user1, 1000);
        
        LLMBits.TokenConfigs memory config = llmBits.getConfig(tokenId);
        assertEq(config.model, MODEL);
        assertEq(config.scope, SCOPE);
        assertEq(config.expiration, expiration);
        assertEq(config.originPool, originPool);
        assertEq(config.reclaimable, RECLAIMABLE);
        assertEq(config.tradable, TRADABLE);
    }
    
    function testGetConfigUnknownToken() public {
        uint256 unknownTokenId = 12345;
        
        vm.expectRevert(abi.encodeWithSelector(LLMBits.UnknownTokenId.selector, unknownTokenId));
        llmBits.getConfig(unknownTokenId);
    }
    
    function testURI() public {
        uint256 tokenId = _mintTokenToUser(user1, 1000);
        
        string memory expectedUri = string(abi.encodePacked(BASE_URI, tokenId.toHexString(32), ".json"));
        assertEq(llmBits.uri(tokenId), expectedUri);
    }
    
    /*─────────────────────── Approval Disabled Tests ───────────────────────*/
    
    function testApprovalsDisabled() public {
        vm.prank(user1);
        vm.expectRevert(LLMBits.ApprovalsDisabled.selector);
        llmBits.setApprovalForAll(user2, true);
        
        assertFalse(llmBits.isApprovedForAll(user1, user2));
    }
}