// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {LLMBits} from "../src/LLMBits.sol";
import {TokenAI} from "../src/TokenAI.sol";

/**
 * @title TestTransfers
 * @dev Script to test transfer functionality including batch transfers
 * 
 * Usage:
 * forge script script/TestTransfers.s.sol:TestTransfers --rpc-url $BNB_TESTNET_RPC_URL --broadcast
 */
contract TestTransfers is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address llmBitsAddress = vm.envAddress("LLM_BITS_ADDRESS");
        address tokenAiAddress = vm.envAddress("TOKEN_AI_ADDRESS");
        address testAccount1 = vm.envAddress("TEST_ACCOUNT_1_ADDRESS");
        address testAccount2 = vm.envAddress("TEST_ACCOUNT_2_ADDRESS");
        
        LLMBits llmBits = LLMBits(llmBitsAddress);
        TokenAI tokenAI = TokenAI(tokenAiAddress);
        
        console.log("Testing transfer functionality...");
        
        // Get token IDs
        uint256 gptAiCourseId = _computeTokenId("gpt-4", "ai-course-101", uint64(block.timestamp + 90 days));
        uint256 claudeMlCourseId = _computeTokenId("claude-3", "ml-course-201", uint64(block.timestamp + 60 days));
        uint256 nonTradableId = _computeTokenId("gpt-3.5", "private-session", uint64(block.timestamp + 30 days), false);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("\n=== BEFORE TRANSFERS ===");
        _displayBalances(llmBits, tokenAI, testAccount1, testAccount2, gptAiCourseId, claudeMlCourseId);
        
        // Test 1: Simple transfer with native fee
        console.log("\n=== TEST 1: SIMPLE TRANSFER WITH NATIVE FEE ===");
        console.log("Transfer 50 GPT-4 AI Course tokens from Account 1 to Account 2");
        console.log("Fee: 5 tAPT");
        
        llmBits.transfer(
            testAccount1,
            testAccount2,
            gptAiCourseId,
            50,              // amount
            5 * 10**18,      // 5 tAPT native fee
            0                // no in-kind fee
        );
        
        console.log("\n=== AFTER TRANSFER 1 ===");
        _displayBalances(llmBits, tokenAI, testAccount1, testAccount2, gptAiCourseId, claudeMlCourseId);
        
        // Test 2: Transfer with in-kind fee
        console.log("\n=== TEST 2: TRANSFER WITH IN-KIND FEE ===");
        console.log("Transfer 25 Claude ML tokens from Account 1 to Account 2");
        console.log("Fee: 2 Claude ML tokens");
        
        llmBits.transfer(
            testAccount1,
            testAccount2,
            claudeMlCourseId,
            25,              // amount
            0,               // no native fee
            2                // 2 tokens in-kind fee
        );
        
        console.log("\n=== AFTER TRANSFER 2 ===");
        _displayBalances(llmBits, tokenAI, testAccount1, testAccount2, gptAiCourseId, claudeMlCourseId);
        
        // Test 3: Batch transfer
        console.log("\n=== TEST 3: BATCH TRANSFER ===");
        console.log("Batch transfer from Account 1 to multiple recipients");
        
        address[] memory recipients = new address[](2);
        recipients[0] = testAccount2;
        recipients[1] = deployer;
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 20; // 20 to Account 2
        amounts[1] = 10; // 10 to deployer
        
        uint256[] memory feesNative = new uint256[](2);
        feesNative[0] = 2 * 10**18; // 2 tAPT fee for Account 2 transfer
        feesNative[1] = 1 * 10**18; // 1 tAPT fee for deployer transfer
        
        uint256[] memory feesInKind = new uint256[](2);
        feesInKind[0] = 0;
        feesInKind[1] = 0;
        
        llmBits.batchTransfer(
            testAccount1,
            recipients,
            gptAiCourseId,
            amounts,
            feesNative,
            feesInKind
        );
        
        console.log("\n=== AFTER BATCH TRANSFER ===");
        _displayBalances(llmBits, tokenAI, testAccount1, testAccount2, gptAiCourseId, claudeMlCourseId);
        console.log("Deployer GPT-4 AI Course balance:", llmBits.balanceOf(deployer, gptAiCourseId));
        
        // Test 4: Try to transfer non-tradable token (should fail from non-origin pool)
        console.log("\n=== TEST 4: NON-TRADABLE TOKEN TRANSFER (SHOULD FAIL) ===");
        console.log("Attempting to transfer non-tradable token from Account 2 (should fail)");
        
        try llmBits.transfer(
            testAccount2,
            testAccount1,
            nonTradableId,
            10,
            0,
            0
        ) {
            console.log("ERROR: Non-tradable transfer succeeded (should have failed)");
        } catch {
            console.log("SUCCESS: Non-tradable transfer correctly failed");
        }
        
        // Test 5: Origin pool can transfer non-tradable tokens
        console.log("\n=== TEST 5: ORIGIN POOL TRANSFER OF NON-TRADABLE ===");
        console.log("Origin pool transfers non-tradable tokens (should succeed)");
        
        // First, transfer some non-tradable tokens to origin pool
        uint256 instructorPoolId = _computeTokenId("claude-3", "instructor-pool", uint64(block.timestamp + 180 days), false);
        
        llmBits.transfer(
            deployer,        // from origin pool
            testAccount1,    // to Account 1
            instructorPoolId,
            50,              // amount
            0,               // no native fee
            0                // no in-kind fee
        );
        
        console.log("Transferred 50 instructor pool tokens to Account 1");
        console.log("Account 1 instructor pool balance:", llmBits.balanceOf(testAccount1, instructorPoolId));
        
        vm.stopBroadcast();
        
        // Final summary
        console.log("\n=== FINAL TREASURY SUMMARY ===");
        address treasury = llmBits.treasury();
        console.log("Treasury TokenAI Balance:", tokenAI.balanceOf(treasury) / 10**18, "tAPT");
        console.log("Treasury GPT-4 AI Course tokens:", llmBits.balanceOf(treasury, gptAiCourseId));
        console.log("Treasury Claude ML tokens:", llmBits.balanceOf(treasury, claudeMlCourseId));
    }
    
    function _displayBalances(
        LLMBits llmBits,
        TokenAI tokenAI,
        address account1,
        address account2,
        uint256 tokenId1,
        uint256 tokenId2
    ) internal view {
        console.log("Account 1:");
        console.log("  - TokenAI:", tokenAI.balanceOf(account1) / 10**18, "tAPT");
        console.log("  - GPT-4 AI Course tokens:", llmBits.balanceOf(account1, tokenId1));
        console.log("  - Claude ML Course tokens:", llmBits.balanceOf(account1, tokenId2));
        
        console.log("Account 2:");
        console.log("  - TokenAI:", tokenAI.balanceOf(account2) / 10**18, "tAPT");
        console.log("  - GPT-4 AI Course tokens:", llmBits.balanceOf(account2, tokenId1));
        console.log("  - Claude ML Course tokens:", llmBits.balanceOf(account2, tokenId2));
    }
    
    function _computeTokenId(bytes16 model, bytes16 scope, uint64 expiration) internal view returns (uint256) {
        return _computeTokenId(model, scope, expiration, true);
    }
    
    function _computeTokenId(bytes16 model, bytes16 scope, uint64 expiration, bool tradable) internal view returns (uint256) {
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        return uint256(keccak256(abi.encode(
            keccak256("LLMBits.v1"),
            model,
            scope,
            expiration,
            deployer, // origin pool
            true,     // reclaimable
            tradable  // tradable
        )));
    }
}