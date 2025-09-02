// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {LLMBits} from "../src/LLMBits.sol";
import {TokenAI} from "../src/TokenAI.sol";

/**
 * @title MintTestTokens
 * @dev Script to mint test tokens for testing trading/transfer functionality
 * 
 * Usage:
 * forge script script/MintTestTokens.s.sol:MintTestTokens --rpc-url $BNB_TESTNET_RPC_URL --broadcast
 */
contract MintTestTokens is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address llmBitsAddress = vm.envAddress("LLM_BITS_ADDRESS");
        address tokenAiAddress = vm.envAddress("TOKEN_AI_ADDRESS");
        address testAccount1 = vm.envAddress("TEST_ACCOUNT_1_ADDRESS");
        address testAccount2 = vm.envAddress("TEST_ACCOUNT_2_ADDRESS");
        
        console.log("Minting test tokens...");
        console.log("LLMBits:", llmBitsAddress);
        console.log("TokenAI:", tokenAiAddress);
        console.log("Test Account 1:", testAccount1);
        console.log("Test Account 2:", testAccount2);
        
        LLMBits llmBits = LLMBits(llmBitsAddress);
        TokenAI tokenAI = TokenAI(tokenAiAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Mint some TokenAI to test accounts for fees
        console.log("\n=== MINTING TOKENAI FOR FEES ===");
        tokenAI.mint(testAccount1, 1000 * 10**18); // 1000 APT
        tokenAI.mint(testAccount2, 1000 * 10**18); // 1000 APT
        console.log("Minted 1000 tAPT to each test account");
        
        // Mint different types of LLMBits tokens
        console.log("\n=== MINTING LLMBITS TOKENS ===");
        
        // 1. GPT-4 tokens for AI course (tradable, reclaimable)
        uint256 tokenId1 = llmBits.mintToAddress(
            testAccount1,
            deployer, // origin pool
            "gpt-4",
            "ai-course-101",
            uint64(block.timestamp + 90 days),
            true, // reclaimable
            true, // tradable
            500   // amount
        );
        console.log("Minted 500 GPT-4 AI Course tokens to Account 1, Token ID:", tokenId1);
        
        // 2. Claude tokens for ML course (tradable, reclaimable)
        uint256 tokenId2 = llmBits.mintToAddress(
            testAccount1,
            deployer,
            "claude-3",
            "ml-course-201",
            uint64(block.timestamp + 60 days),
            true,
            true,
            300
        );
        console.log("Minted 300 Claude ML Course tokens to Account 1, Token ID:", tokenId2);
        
        // 3. GPT-4 tokens for different course to Account 2
        uint256 tokenId3 = llmBits.mintToAddress(
            testAccount2,
            deployer,
            "gpt-4",
            "web3-course-301",
            uint64(block.timestamp + 120 days),
            true,
            true,
            400
        );
        console.log("Minted 400 GPT-4 Web3 Course tokens to Account 2, Token ID:", tokenId3);
        
        // 4. Non-tradable tokens for testing restrictions
        uint256 tokenId4 = llmBits.mintToAddress(
            testAccount2,
            deployer,
            "gpt-3.5",
            "private-session",
            uint64(block.timestamp + 30 days),
            true,
            false, // NOT tradable
            200
        );
        console.log("Minted 200 Non-tradable GPT-3.5 tokens to Account 2, Token ID:", tokenId4);
        
        // 5. Some tokens to origin pool for testing transfers
        llmBits.mintToAddress(
            deployer, // to origin pool
            deployer, // origin pool
            "claude-3",
            "instructor-pool",
            uint64(block.timestamp + 180 days),
            true,
            false, // non-tradable but origin pool can transfer
            1000
        );
        console.log("Minted 1000 Instructor Pool tokens to Origin Pool");
        
        vm.stopBroadcast();
        
        // Display summary
        console.log("\n=== MINTING SUMMARY ===");
        console.log("Test Account 1 Holdings:");
        console.log("- TokenAI Balance:", tokenAI.balanceOf(testAccount1) / 10**18, "tAPT");
        console.log("- GPT-4 AI Course (ID", tokenId1, "):", llmBits.balanceOf(testAccount1, tokenId1));
        console.log("- Claude ML Course (ID", tokenId2, "):", llmBits.balanceOf(testAccount1, tokenId2));
        
        console.log("\nTest Account 2 Holdings:");
        console.log("- TokenAI Balance:", tokenAI.balanceOf(testAccount2) / 10**18, "tAPT");
        console.log("- GPT-4 Web3 Course (ID", tokenId3, "):", llmBits.balanceOf(testAccount2, tokenId3));
        console.log("- GPT-3.5 Non-tradable (ID", tokenId4, "):", llmBits.balanceOf(testAccount2, tokenId4));
        
        console.log("\nOrigin Pool Holdings:");
        console.log("- Instructor Pool tokens:", llmBits.balanceOf(deployer, _computeTokenId("claude-3", "instructor-pool")));
        
        console.log("\n=== TESTING READY ===");
        console.log("You can now test:");
        console.log("1. Transfers between accounts");
        console.log("2. Trading different token types");
        console.log("3. Fee collection mechanics");
        console.log("4. Non-tradable token restrictions");
    }
    
    // Helper function to compute token ID for verification
    function _computeTokenId(bytes16 model, bytes16 scope) internal view returns (uint256) {
        return uint256(keccak256(abi.encode(
            keccak256("LLMBits.v1"), // domain
            model,
            scope,
            uint64(block.timestamp + 180 days), // expiration
            vm.addr(vm.envUint("PRIVATE_KEY")), // deployer as origin pool
            true, // reclaimable
            false // tradable
        )));
    }
}