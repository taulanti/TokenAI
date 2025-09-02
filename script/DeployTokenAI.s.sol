// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {TokenAI} from "../src/TokenAI.sol";

/**
 * @title DeployTokenAI
 * @dev Script to deploy only TokenAI contract first
 * 
 * Usage:
 * forge script script/DeployTokenAI.s.sol:DeployTokenAI --rpc-url $BNB_RPC_URL --broadcast --verify
 */
contract DeployTokenAI is Script {
    
    // Platform configuration
    string public constant TOKEN_NAME = "AI Platform Token";
    string public constant TOKEN_SYMBOL = "APT";
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying TokenAI to BNB Smart Chain...");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy TokenAI with 0 initial supply
        console.log("Deploying TokenAI...");
        TokenAI tokenAI = new TokenAI(TOKEN_NAME, TOKEN_SYMBOL, 0);
        console.log("TokenAI deployed at:", address(tokenAI));
        
        vm.stopBroadcast();
        
        // Log deployment summary
        console.log("\n=== TOKENAI DEPLOYMENT SUMMARY ===");
        console.log("Network: BNB Smart Chain");
        console.log("TokenAI Address:", address(tokenAI));
        console.log("Name:", TOKEN_NAME);
        console.log("Symbol:", TOKEN_SYMBOL);
        console.log("Initial Supply: 0");
        console.log("Owner:", deployer);
        
        // Add this address to your .env file as TREASURY_ADDRESS
        console.log("\n=== NEXT STEPS ===");
        console.log("1. Add this to your .env file:");
        console.log(string(abi.encodePacked("TREASURY_ADDRESS=", vm.toString(address(tokenAI)))));
        console.log("2. Deploy LLMBits using DeployLLMBits script");
        
        // Verification command
        console.log("\n=== VERIFICATION COMMAND ===");
        console.log(string(abi.encodePacked(
            "forge verify-contract ",
            vm.toString(address(tokenAI)),
            " src/TokenAI.sol:TokenAI --chain-id 56 --constructor-args ",
            vm.toString(abi.encode(TOKEN_NAME, TOKEN_SYMBOL, uint256(0)))
        )));
    }
}

/**
 * @title DeployTokenAITestnet
 * @dev Script to deploy TokenAI to testnet
 */
contract DeployTokenAITestnet is Script {
    
    string public constant TOKEN_NAME = "AI Platform Token Testnet";
    string public constant TOKEN_SYMBOL = "tAPT";
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying TokenAI to BNB Smart Chain Testnet...");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        TokenAI tokenAI = new TokenAI(TOKEN_NAME, TOKEN_SYMBOL, 0);
        console.log("TokenAI deployed at:", address(tokenAI));
        
        vm.stopBroadcast();
        
        console.log("\n=== TESTNET DEPLOYMENT SUMMARY ===");
        console.log("Network: BNB Smart Chain Testnet");
        console.log("TokenAI Address:", address(tokenAI));
        console.log("Add to .env: TREASURY_ADDRESS=", address(tokenAI));
    }
}