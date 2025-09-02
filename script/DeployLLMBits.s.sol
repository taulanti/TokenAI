// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {TokenAI} from "../src/TokenAI.sol";
import {LLMBits} from "../src/LLMBits.sol";

/**
 * @title DeployLLMBits
 * @dev Script to deploy LLMBits after TokenAI is deployed
 * 
 * Prerequisites: 
 * 1. TokenAI must be deployed first
 * 2. TREASURY_ADDRESS must be set in .env to TokenAI address
 * 
 * Usage:
 * forge script script/DeployLLMBits.s.sol:DeployLLMBits --rpc-url $BNB_RPC_URL --broadcast --verify
 */
contract DeployLLMBits is Script {
    
    string public constant BASE_URI = "https://api.tokenai.com/metadata/";
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address treasuryAddress = vm.envAddress("TREASURY_ADDRESS");
        
        console.log("Deploying LLMBits to BNB Smart Chain...");
        console.log("Deployer address:", deployer);
        console.log("Treasury (TokenAI) address:", treasuryAddress);
        console.log("Deployer balance:", deployer.balance);
        
        // Verify TokenAI exists at treasury address
        TokenAI tokenAI = TokenAI(treasuryAddress);
        require(
            keccak256(abi.encodePacked(tokenAI.symbol())) == keccak256(abi.encodePacked("TAI")),
            "Invalid TokenAI address - symbol mismatch"
        );
        console.log("TokenAI verified at:", treasuryAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy LLMBits
        console.log("Deploying LLMBits...");
        LLMBits llmBits = new LLMBits(BASE_URI, treasuryAddress);
        console.log("LLMBits deployed at:", address(llmBits));
        
        // Set LLMBits as authorized minter for TokenAI
        console.log("Setting LLMBits as authorized minter...");
        tokenAI.setMinter(address(llmBits), true);
        
        // Set treasury to TokenAI address
        console.log("Setting treasury...");
        llmBits.setTreasury(treasuryAddress);
        
        vm.stopBroadcast();
        
        // Log deployment summary
        console.log("\n=== LLMBITS DEPLOYMENT SUMMARY ===");
        console.log("Network: BNB Smart Chain");
        console.log("LLMBits Address:", address(llmBits));
        console.log("TokenAI Address:", treasuryAddress);
        console.log("Base URI:", BASE_URI);
        console.log("Treasury:", treasuryAddress);
        console.log("LLMBits authorized to mint TokenAI: true");
        
        // Verification command
        console.log("\n=== VERIFICATION COMMAND ===");
        console.log(string(abi.encodePacked(
            "forge verify-contract ",
            vm.toString(address(llmBits)),
            " src/LLMBits.sol:LLMBits --chain-id 56 --constructor-args ",
            vm.toString(abi.encode(BASE_URI, treasuryAddress))
        )));
        
        // Update .env suggestion
        console.log("\n=== UPDATE .ENV FILE ===");
        console.log("Add these addresses to your .env file:");
        console.log(string(abi.encodePacked("TOKEN_AI_ADDRESS=", vm.toString(treasuryAddress))));
        console.log(string(abi.encodePacked("LLM_BITS_ADDRESS=", vm.toString(address(llmBits)))));
    }
}

/**
 * @title DeployLLMBitsTestnet
 * @dev Script to deploy LLMBits to testnet
 */
contract DeployLLMBitsTestnet is Script {
    
    string public constant BASE_URI = "https://testnet-api.tokenai.com/metadata/";
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address treasuryAddress = vm.envAddress("TREASURY_ADDRESS");
        
        console.log("Deploying LLMBits to BNB Smart Chain Testnet...");
        
        vm.startBroadcast(deployerPrivateKey);
        
        TokenAI tokenAI = TokenAI(treasuryAddress);
        LLMBits llmBits = new LLMBits(BASE_URI, treasuryAddress);
        
        // Configure permissions
        tokenAI.setMinter(address(llmBits), true);
        llmBits.setTreasury(treasuryAddress);
        
        // Create test tokens for demonstration
        console.log("Creating test tokens...");
        llmBits.mintToAddress(
            vm.addr(deployerPrivateKey),
            vm.addr(deployerPrivateKey),
            "gpt-4",
            "ai-fundamentals", 
            uint64(block.timestamp + 90 days),
            true, true, 1000
        );
        
        vm.stopBroadcast();
        
        console.log("\n=== TESTNET DEPLOYMENT SUMMARY ===");
        console.log("LLMBits Address:", address(llmBits));
        console.log("TokenAI Address:", treasuryAddress);
        console.log("Test tokens created");
    }
}