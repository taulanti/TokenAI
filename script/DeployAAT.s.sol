// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {TokenAI} from "../src/TokenAI.sol";
import {AAT} from "../src/AAT.sol";

/**
 * @title DeployAAT
 * @dev Script to deploy AAT after TokenAI is deployed
 * 
 * Prerequisites: 
 * 1. TokenAI must be deployed first
 * 2. TREASURY_ADDRESS must be set in .env to TokenAI address
 * 
 * Usage:
 * forge script script/DeployAAT.s.sol:DeployAAT --rpc-url $BNB_RPC_URL --broadcast --verify
 */
contract DeployAAT is Script {
    
    string public constant BASE_URI = "https://api.tokenai.com/metadata/";
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address treasuryAddress = vm.envAddress("TREASURY_ADDRESS");
        
        console.log("Deploying AAT to BNB Smart Chain...");
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
        
        // Deploy AAT
        console.log("Deploying AAT...");
        AAT aat = new AAT(BASE_URI, treasuryAddress);
        console.log("AAT deployed at:", address(aat));
        
        // Set AAT as authorized minter for TokenAI
        console.log("Setting AAT as authorized minter...");
        tokenAI.setMinter(address(aat), true);
        
        // Set treasury to TokenAI address
        console.log("Setting treasury...");
        aat.setTreasury(treasuryAddress);
        
        vm.stopBroadcast();
        
        // Log deployment summary
        console.log("\n=== AAT DEPLOYMENT SUMMARY ===");
        console.log("Network: BNB Smart Chain");
        console.log("AAT Address:", address(aat));
        console.log("TokenAI Address:", treasuryAddress);
        console.log("Base URI:", BASE_URI);
        console.log("Treasury:", treasuryAddress);
        console.log("AAT authorized to mint TokenAI: true");
        
        // Verification command
        console.log("\n=== VERIFICATION COMMAND ===");
        console.log(string(abi.encodePacked(
            "forge verify-contract ",
            vm.toString(address(aat)),
            " src/AAT.sol:AAT --chain-id 56 --constructor-args ",
            vm.toString(abi.encode(BASE_URI, treasuryAddress))
        )));
        
        // Update .env suggestion
        console.log("\n=== UPDATE .ENV FILE ===");
        console.log("Add these addresses to your .env file:");
        console.log(string(abi.encodePacked("TOKEN_AI_ADDRESS=", vm.toString(treasuryAddress))));
        console.log(string(abi.encodePacked("AAT_ADDRESS=", vm.toString(address(aat)))));
    }
}

/**
 * @title DeployAATTestnet
 * @dev Script to deploy AAT to testnet
 */
contract DeployAATTestnet is Script {
    
    string public constant BASE_URI = "https://testnet-api.tokenai.com/metadata/";
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address treasuryAddress = vm.envAddress("TREASURY_ADDRESS");
        
        console.log("Deploying AAT to BNB Smart Chain Testnet...");
        
        vm.startBroadcast(deployerPrivateKey);
        
        TokenAI tokenAI = TokenAI(treasuryAddress);
        AAT aat = new AAT(BASE_URI, treasuryAddress);
        
        // Configure permissions
        tokenAI.setMinter(address(aat), true);
        aat.setTreasury(treasuryAddress);
        
        // Create test tokens for demonstration
        console.log("Creating test tokens...");
        aat.mintToAddress(
            vm.addr(deployerPrivateKey),
            vm.addr(deployerPrivateKey),
            "gpt-4",
            "ai-fundamentals", 
            uint64(block.timestamp + 90 days),
            true, true, 1000
        );
        
        vm.stopBroadcast();
        
        console.log("\n=== TESTNET DEPLOYMENT SUMMARY ===");
        console.log("AAT Address:", address(aat));
        console.log("TokenAI Address:", treasuryAddress);
        console.log("Test tokens created");
    }
}