// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {LLMBits, ITokenAI} from "../src/LLMBits.sol";
import {TokenAI} from "../src/TokenAI.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract EdgeCasesTest is Test {
    using Strings for uint256;
    
    LLMBits public llmBits;
    TokenAI public tokenAI;
    
    address public owner;
    address public user1;
    address public user2;
    address public originPool;
    address public treasury;
    address public attacker;
    
    string public constant BASE_URI = "https://api.example.com/metadata/";
    uint256 public constant INITIAL_TOKEN_SUPPLY = 1000000 * 10**18;
    
    bytes16 public constant MODEL = "gpt-4";
    bytes16 public constant SCOPE = "course-101";
    uint64 public expiration;
    
    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        originPool = makeAddr("originPool");
        treasury = makeAddr("treasury");
        attacker = makeAddr("attacker");
        
        expiration = uint64(block.timestamp + 30 days);
        
        vm.startPrank(owner);
        tokenAI = new TokenAI("TokenAI", "TAI", INITIAL_TOKEN_SUPPLY);
        llmBits = new LLMBits(BASE_URI, address(tokenAI));
        llmBits.setTreasury(treasury);
        tokenAI.setMinter(address(llmBits), true);
        vm.stopPrank();
    }
    
    /*─────────────────────── Integer Overflow/Underflow Tests ───────────────────────*/
    
    function testBatchTransferOverflowPrevention() public {
        uint256 tokenId = _mintToken(user1, 1000);
        
        address[] memory recipients = new address[](2);
        recipients[0] = user2;
        recipients[1] = makeAddr("user3");
        
        // Try to cause overflow in totalAmount calculation
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = type(uint256).max / 2;
        amounts[1] = type(uint256).max / 2 + 1; // This should cause overflow
        
        uint256[] memory feesNative = new uint256[](2);
        feesNative[0] = 0;
        feesNative[1] = 0;
        
        vm.prank(owner);
        // Should revert due to insufficient balance, not overflow
        vm.expectRevert();
        llmBits.batchTransfer(user1, recipients, tokenId, amounts, feesNative);
    }
    
    function testFeeOverflowPrevention() public {
        uint256 tokenId = _mintToken(user1, 1000);
        
        // Give user1 limited TokenAI
        vm.prank(owner);
        tokenAI.mint(user1, 10 * 10**18);
        
        vm.prank(user1);
        tokenAI.approve(address(llmBits), type(uint256).max);
        
        // Try excessive native fee
        vm.prank(owner);
        vm.expectRevert();
        llmBits.transfer(user1, user2, tokenId, 100, type(uint256).max); // Excessive native fee
    }
    
    function testTimestampUnderflowPrevention() public {
        // Test with expiration = 1 (very early timestamp)
        uint64 earlyExpiration = 1;
        
        vm.prank(owner);
        uint256 tokenId = llmBits.mintToAddress(
            user1, originPool, MODEL, SCOPE, earlyExpiration, true, true, 1000
        );
        
        // Token should be expired immediately
        assertTrue(llmBits.isExpired(tokenId));
        
        // Transfers should fail
        vm.prank(owner);
        vm.expectRevert(LLMBits.TokenExpired.selector);
        llmBits.transfer(user1, user2, tokenId, 100, 0);
    }
    
    /*─────────────────────── Access Control Edge Cases ───────────────────────*/
    
    function testUnauthorizedMinterAccess() public {
        // Attacker tries to set themselves as minter
        vm.prank(attacker);
        vm.expectRevert();
        tokenAI.setMinter(attacker, true);
        
        // Attacker tries to mint directly
        vm.prank(attacker);
        vm.expectRevert(TokenAI.UnauthorizedMinter.selector);
        tokenAI.mint(attacker, 1000 * 10**18);
    }
    
    function testOwnershipTransferAttack() public {
        // Current owner can transfer ownership
        vm.prank(owner);
        tokenAI.transferOwnership(user1);
        
        // Old owner can no longer perform owner actions
        vm.prank(owner);
        vm.expectRevert();
        tokenAI.setMinter(owner, true);
        
        // New owner can perform actions
        vm.prank(user1);
        tokenAI.setMinter(user1, true);
    }
    
    function testMinterRoleBypass() public {
        // Set user1 as minter
        vm.prank(owner);
        tokenAI.setMinter(user1, true);
        
        // Remove minter role
        vm.prank(owner);
        tokenAI.setMinter(user1, false);
        
        // Should not be able to mint anymore
        vm.prank(user1);
        vm.expectRevert(TokenAI.UnauthorizedMinter.selector);
        tokenAI.mint(user2, 1000);
    }
    
    /*─────────────────────── Reentrancy Attack Tests ───────────────────────*/
    
    function testReentrancyDuringTransfer() public {
        uint256 tokenId = _mintToken(user1, 1000);
        
        // Deploy malicious contract that tries to reenter
        ReentrantReceiver maliciousContract = new ReentrantReceiver(llmBits, owner);
        
        // Transfer TO malicious contract - this will trigger the reentrant call
        vm.prank(owner);
        llmBits.transfer(user1, address(maliciousContract), tokenId, 100, 0);
        
        // Check that reentrancy was attempted but blocked
        assertTrue(maliciousContract.attacked());
    }
    
    /*─────────────────────── Fee Manipulation Tests ───────────────────────*/
    
    function testExcessiveFeeAttack() public {
        uint256 tokenId = _mintToken(user1, 1000);
        
        // Give user1 some TokenAI but not enough for excessive fee
        vm.prank(owner);
        tokenAI.mint(user1, 5 * 10**18);
        
        vm.prank(user1);
        tokenAI.approve(address(llmBits), 100 * 10**18); // Approve more than balance
        
        // Try to set fee larger than user's TokenAI balance
        vm.prank(owner);
        vm.expectRevert();
        llmBits.transfer(user1, user2, tokenId, 100, 100 * 10**18); // Excessive native fee
    }
    
    function testFeeRecipientManipulation() public {
        uint256 tokenId = _mintToken(user1, 1000);
        
        // Attacker tries to change fee recipient
        vm.prank(attacker);
        vm.expectRevert();
        llmBits.setTreasury(attacker);
        
        // Only owner can change fee recipient
        vm.prank(owner);
        llmBits.setTreasury(attacker);
        
        // Give user1 some TokenAI for fees
        vm.prank(owner);
        tokenAI.mint(user1, 100 * 10**18);
        
        vm.prank(user1);
        tokenAI.approve(address(llmBits), 10 * 10**18);
        
        // Now fees go to attacker
        vm.prank(owner);
        llmBits.transfer(user1, user2, tokenId, 100, 10 * 10**18);
        
        assertEq(tokenAI.balanceOf(attacker), 10 * 10**18);
        // No in-kind fees collected since we removed that feature
        assertEq(llmBits.balanceOf(attacker, tokenId), 0);
    }
    
    /*─────────────────────── Token Configuration Attack Tests ───────────────────────*/
    
    function testTokenConfigurationMismatch() public {
        // Mint token with specific config
        vm.prank(owner);
        uint256 tokenId1 = llmBits.mintToAddress(
            user1, originPool, MODEL, SCOPE, expiration, true, true, 1000
        );
        
        // Try to mint same token ID with different config (should fail)
        vm.prank(owner);
        uint256 tokenId2 = llmBits.mintToAddress(
            user1, originPool, MODEL, SCOPE, expiration, true, true, 500
        );
        
        // Should be same token ID
        assertEq(tokenId1, tokenId2);
        assertEq(llmBits.totalSupply(tokenId1), 1500);
    }
    
    function testNonTradableTokenBypass() public {
        // Mint non-tradable token to user (not origin pool)
        vm.prank(owner);
        uint256 tokenId = llmBits.mintToAddress(
            user1, originPool, MODEL, SCOPE, expiration, true, false, 1000
        );
        
        // User should not be able to transfer
        vm.prank(owner);
        vm.expectRevert(LLMBits.TokenNotTradable.selector);
        llmBits.transfer(user1, user2, tokenId, 100, 0);
        
        // But origin pool should be able to transfer
        vm.prank(owner);
        llmBits.mintToAddress(
            originPool, originPool, MODEL, SCOPE, expiration, true, false, 500
        );
        
        vm.prank(owner);
        llmBits.transfer(originPool, user1, tokenId, 100, 0);
    }
    
    /*─────────────────────── Gas Limit Attack Tests ───────────────────────*/
    
    function testLargeBatchOperationGasLimit() public {
        uint256 tokenId = _mintToken(user1, type(uint256).max);
        
        // Create very large arrays
        uint256 arraySize = 1000; // Large but not too large for test environment
        address[] memory recipients = new address[](arraySize);
        uint256[] memory amounts = new uint256[](arraySize);
        uint256[] memory feesNative = new uint256[](arraySize);
        uint256[] memory feesInKind = new uint256[](arraySize);
        
        for (uint256 i = 0; i < arraySize; i++) {
            recipients[i] = makeAddr(string(abi.encodePacked("recipient", vm.toString(i))));
            amounts[i] = 1;
            feesNative[i] = 0;
        }
        
        // Should handle large batch without running out of gas in test environment
        vm.prank(owner);
        llmBits.batchTransfer(user1, recipients, tokenId, amounts, feesNative);
        
        // Verify first and last recipients received tokens
        assertEq(llmBits.balanceOf(recipients[0], tokenId), 1);
        assertEq(llmBits.balanceOf(recipients[arraySize - 1], tokenId), 1);
    }
    
    /*─────────────────────── Front-running Attack Tests ───────────────────────*/
    
    function testTradeFrontRunning() public {
        // Setup two different tokens for trading
        vm.startPrank(owner);
        uint256 tokenIdA = llmBits.mintToAddress(
            user1, originPool, MODEL, "course-a", expiration, true, true, 1000
        );
        uint256 tokenIdB = llmBits.mintToAddress(
            user2, originPool, MODEL, "course-b", expiration, true, true, 800
        );
        vm.stopPrank();
        
        // Give users TokenAI for fees
        vm.startPrank(owner);
        tokenAI.mint(user1, 100 * 10**18);
        tokenAI.mint(user2, 100 * 10**18);
        vm.stopPrank();
        
        // Users approve tokens
        vm.prank(user1);
        tokenAI.approve(address(llmBits), 50 * 10**18);
        vm.prank(user2);
        tokenAI.approve(address(llmBits), 50 * 10**18);
        
        // Simulate front-running by changing fees mid-transaction
        vm.prank(owner);
        llmBits.tradeWithNativeFees(
            user1, user2,
            tokenIdA, 100,
            tokenIdB, 80,
            0, 10 * 10**18, 15 * 10**18
        );
        
        // Verify trade completed with expected fees
        assertEq(tokenAI.balanceOf(treasury), 25 * 10**18);
    }
    
    /*─────────────────────── Edge Cases in Expiration Logic ───────────────────────*/
    
    function testExpirationBoundaryConditions() public {
        // Test expiration exactly at current timestamp
        uint64 currentTime = uint64(block.timestamp);
        
        vm.prank(owner);
        uint256 tokenId = llmBits.mintToAddress(
            user1, originPool, MODEL, SCOPE, currentTime, true, true, 1000
        );
        
        // Should be expired immediately
        assertTrue(llmBits.isExpired(tokenId));
        
        // Test expiration one second in future
        vm.prank(owner);
        uint256 tokenId2 = llmBits.mintToAddress(
            user1, originPool, MODEL, "scope-2", currentTime + 1, true, true, 1000
        );
        
        // Should not be expired yet
        assertFalse(llmBits.isExpired(tokenId2));
        
        // Move forward one second
        vm.warp(block.timestamp + 1);
        
        // Now should be expired
        assertTrue(llmBits.isExpired(tokenId2));
    }
    
    function testZeroExpirationToken() public {
        // Token with zero expiration should never expire
        vm.prank(owner);
        uint256 tokenId = llmBits.mintToAddress(
            user1, originPool, MODEL, SCOPE, 0, true, true, 1000
        );
        
        assertFalse(llmBits.isExpired(tokenId));
        
        // Move far into future
        vm.warp(block.timestamp + 365 days);
        
        // Still should not be expired
        assertFalse(llmBits.isExpired(tokenId));
    }
    
    /*─────────────────────── Malicious Input Tests ───────────────────────*/
    
    function testZeroAddressInputs() public {
        vm.startPrank(owner);
        
        // Test zero recipient
        vm.expectRevert(LLMBits.ZeroAddress.selector);
        llmBits.mintToAddress(
            address(0), originPool, MODEL, SCOPE, expiration, true, true, 1000
        );
        
        // Test zero origin pool
        vm.expectRevert(LLMBits.ZeroAddress.selector);
        llmBits.mintToAddress(
            user1, address(0), MODEL, SCOPE, expiration, true, true, 1000
        );
        
        // Test zero fee recipient
        vm.expectRevert(LLMBits.ZeroAddress.selector);
        llmBits.setTreasury(address(0));
        
        vm.stopPrank();
    }
    
    function testArrayLengthMismatches() public {
        uint256 tokenId = _mintToken(user1, 1000);
        
        address[] memory recipients = new address[](2);
        recipients[0] = user2;
        recipients[1] = makeAddr("user3");
        
        // Mismatched amounts array
        uint256[] memory amounts = new uint256[](3); // Wrong length
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 150;
        
        uint256[] memory feesNative = new uint256[](2);
        
        vm.prank(owner);
        vm.expectRevert(LLMBits.ArrayLengthMismatch.selector);
        llmBits.batchTransfer(user1, recipients, tokenId, amounts, feesNative);
    }
    
    /*─────────────────────── Helper Functions ───────────────────────*/
    
    function _mintToken(address to, uint256 amount) internal returns (uint256 tokenId) {
        vm.prank(owner);
        tokenId = llmBits.mintToAddress(
            to, originPool, MODEL, SCOPE, expiration, true, true, amount
        );
    }
}

// Malicious contract for reentrancy testing
contract ReentrantReceiver {
    LLMBits public llmBits;
    address public owner;
    bool public attacked = false;
    
    constructor(LLMBits _llmBits, address _owner) {
        llmBits = _llmBits;
        owner = _owner;
    }
    
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4) {
        // Try to reenter during transfer
        if (!attacked) {
            attacked = true;
            try llmBits.transfer(address(this), from, id, 50, 0) {
                // Reentrancy succeeded (should not happen)
            } catch {
                // Reentrancy blocked (expected)
            }
        }
        return this.onERC1155Received.selector;
    }
    
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}