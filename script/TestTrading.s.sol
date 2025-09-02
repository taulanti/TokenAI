// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {LLMBits} from "../src/LLMBits.sol";
import {TokenAI} from "../src/TokenAI.sol";

/**
 * @title TestTrading
 * @dev Script to test trading functionality between test accounts
 * 
 * Usage:
 * forge script script/TestTrading.s.sol:TestTrading --rpc-url $BNB_TESTNET_RPC_URL --broadcast
 */
contract TestTrading is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address llmBitsAddress = vm.envAddress("LLM_BITS_ADDRESS");
        address tokenAiAddress = vm.envAddress("TOKEN_AI_ADDRESS");
        address testAccount1 = vm.envAddress("TEST_ACCOUNT_1_ADDRESS");
        address testAccount2 = vm.envAddress("TEST_ACCOUNT_2_ADDRESS");
        
        LLMBits llmBits = LLMBits(llmBitsAddress);
        TokenAI tokenAI = TokenAI(tokenAiAddress);
        
        console.log("Testing trading functionality...");
        console.log("Test Account 1:", testAccount1);
        console.log("Test Account 2:", testAccount2);
        
        // Get token IDs (these should match the ones from MintTestTokens)
        uint256 gptAiCourseId = _computeTokenId("gpt-4", "ai-course-101", uint64(block.timestamp + 90 days));
        uint256 claudeMlCourseId = _computeTokenId("claude-3", "ml-course-201", uint64(block.timestamp + 60 days));
        uint256 gptWeb3CourseId = _computeTokenId("gpt-4", "web3-course-301", uint64(block.timestamp + 120 days));
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("\n=== BEFORE TRADE ===");
        _displayBalances(llmBits, tokenAI, testAccount1, testAccount2, gptAiCourseId, gptWeb3CourseId);
        
        // Test 1: Trade with native fees (TokenAI)
        console.log("\n=== TEST 1: TRADE WITH NATIVE FEES ===");
        console.log("Account 1 trades 100 GPT-4 AI Course tokens for 50 GPT-4 Web3 Course tokens from Account 2");
        console.log("Native fees: 10 tTAI from Account 1, 5 tTAI from Account 2");
        
        llmBits.tradeWithNativeFees(
            testAccount1, testAccount2,
            gptAiCourseId, 100,        // Account 1 gives 100 AI course tokens
            gptWeb3CourseId, 50,       // Account 2 gives 50 Web3 course tokens
            0,                         // No in-kind fee for Account 1
            10 * 10**18,              // 10 tTAI fee from Account 1
            5 * 10**18                // 5 tTAI fee from Account 2
        );
        
        console.log("\n=== AFTER TRADE 1 ===");
        _displayBalances(llmBits, tokenAI, testAccount1, testAccount2, gptAiCourseId, gptWeb3CourseId);
        
        // Test 2: Trade with in-kind fees (LLMBits tokens)
        console.log("\n=== TEST 2: TRADE WITH IN-KIND FEES ===");
        console.log("Account 2 trades 30 Web3 tokens for 50 AI Course tokens from Account 1");
        console.log("In-kind fees: 5 AI Course tokens from Account 1, 3 Web3 tokens from Account 2");
        
        llmBits.tradeWithLLMFees(
            testAccount2, testAccount1,
            gptWeb3CourseId, 30,       // Account 2 gives 30 Web3 tokens
            gptAiCourseId, 50,         // Account 1 gives 50 AI course tokens
            3,                         // 3 Web3 tokens as fee from Account 2
            5                          // 5 AI course tokens as fee from Account 1
        );
        
        console.log("\n=== AFTER TRADE 2 ===");
        _displayBalances(llmBits, tokenAI, testAccount1, testAccount2, gptAiCourseId, gptWeb3CourseId);
        
        vm.stopBroadcast();
        
        // Check treasury balances
        address treasury = llmBits.treasury();
        console.log("\n=== TREASURY EARNINGS ===");
        console.log("Treasury TokenAI Balance:", tokenAI.balanceOf(treasury) / 10**18, "tTAI");
        console.log("Treasury GPT-4 AI Course tokens:", llmBits.balanceOf(treasury, gptAiCourseId));
        console.log("Treasury GPT-4 Web3 Course tokens:", llmBits.balanceOf(treasury, gptWeb3CourseId));
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
        console.log("  - TokenAI:", tokenAI.balanceOf(account1) / 10**18, "tTAI");
        console.log("  - GPT-4 AI Course tokens:", llmBits.balanceOf(account1, tokenId1));
        console.log("  - GPT-4 Web3 Course tokens:", llmBits.balanceOf(account1, tokenId2));
        
        console.log("Account 2:");
        console.log("  - TokenAI:", tokenAI.balanceOf(account2) / 10**18, "tTAI");
        console.log("  - GPT-4 AI Course tokens:", llmBits.balanceOf(account2, tokenId1));
        console.log("  - GPT-4 Web3 Course tokens:", llmBits.balanceOf(account2, tokenId2));
    }
    
    function _computeTokenId(bytes16 model, bytes16 scope, uint64 expiration) internal view returns (uint256) {
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        return uint256(keccak256(abi.encode(
            keccak256("LLMBits.v1"),
            model,
            scope,
            expiration,
            deployer, // origin pool
            true,     // reclaimable
            true      // tradable
        )));
    }
}