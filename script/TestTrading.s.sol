// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script, console} from "forge-std/Script.sol";
import {AAT} from "../src/AAT.sol";
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
        address aatAddress = vm.envAddress("AAT_ADDRESS");
        address tokenAiAddress = vm.envAddress("TOKEN_AI_ADDRESS");
        address testAccount1 = vm.envAddress("TEST_ACCOUNT_1_ADDRESS");
        address testAccount2 = vm.envAddress("TEST_ACCOUNT_2_ADDRESS");

        AAT aat = AAT(aatAddress);
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
        _displayBalances(aat, tokenAI, testAccount1, testAccount2, gptAiCourseId, gptWeb3CourseId);

        // Test 1: Trade with native fees (TokenAI)
        console.log("\n=== TEST 1: TRADE WITH NATIVE FEES ===");
        console.log("Account 1 trades 100 GPT-4 AI Course tokens for 50 GPT-4 Web3 Course tokens from Account 2");
        console.log("Native fees: 10 tTAI from Account 1, 5 tTAI from Account 2");

        aat.tradeWithNativeFees(
            testAccount1,
            testAccount2,
            gptAiCourseId,
            100, // Account 1 gives 100 AI course tokens
            gptWeb3CourseId,
            50, // Account 2 gives 50 Web3 course tokens
            0, // No in-kind fee for Account 1
            10 * 10 ** 18, // 10 tTAI fee from Account 1
            5 * 10 ** 18 // 5 tTAI fee from Account 2
        );

        console.log("\n=== AFTER TRADE 1 ===");
        _displayBalances(aat, tokenAI, testAccount1, testAccount2, gptAiCourseId, gptWeb3CourseId);

        // Test 2: Second trade with native fees only
        console.log("\n=== TEST 2: SECOND TRADE WITH NATIVE FEES ===");
        console.log("Account 2 trades 30 Web3 tokens for 50 AI Course tokens from Account 1");
        console.log("Native fees: 3 tTAI from Account 2, 5 tTAI from Account 1");

        aat.tradeWithNativeFees(
            testAccount2,
            testAccount1,
            gptWeb3CourseId,
            30, // Account 2 gives 30 Web3 tokens
            gptAiCourseId,
            50, // Account 1 gives 50 AI course tokens
            0, // No match mask
            3 * 10 ** 18, // 3 tTAI fee from Account 2
            5 * 10 ** 18 // 5 tTAI fee from Account 1
        );

        console.log("\n=== AFTER TRADE 2 ===");
        _displayBalances(aat, tokenAI, testAccount1, testAccount2, gptAiCourseId, gptWeb3CourseId);

        vm.stopBroadcast();

        // Check treasury balances
        address treasury = aat.treasury();
        console.log("\n=== TREASURY EARNINGS ===");
        console.log("Treasury TokenAI Balance:", tokenAI.balanceOf(treasury) / 10 ** 18, "tTAI");
    }

    function _displayBalances(
        AAT aat,
        TokenAI tokenAI,
        address account1,
        address account2,
        uint256 tokenId1,
        uint256 tokenId2
    ) internal view {
        console.log("Account 1:");
        console.log("  - TokenAI:", tokenAI.balanceOf(account1) / 10 ** 18, "tTAI");
        console.log("  - GPT-4 AI Course tokens:", aat.balanceOf(account1, tokenId1));
        console.log("  - GPT-4 Web3 Course tokens:", aat.balanceOf(account1, tokenId2));

        console.log("Account 2:");
        console.log("  - TokenAI:", tokenAI.balanceOf(account2) / 10 ** 18, "tTAI");
        console.log("  - GPT-4 AI Course tokens:", aat.balanceOf(account2, tokenId1));
        console.log("  - GPT-4 Web3 Course tokens:", aat.balanceOf(account2, tokenId2));
    }

    function _computeTokenId(bytes16 model, bytes16 scope, uint64 expiration) internal view returns (uint256) {
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        return uint256(
            keccak256(
                abi.encode(
                    keccak256("AAT.v1"),
                    model,
                    scope,
                    expiration,
                    deployer, // origin pool
                    true, // reclaimable
                    true // tradable
                )
            )
        );
    }
}
