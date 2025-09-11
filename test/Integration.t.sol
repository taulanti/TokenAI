// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {AAT, ITokenAI} from "../src/AAT.sol";
import {TokenAI} from "../src/TokenAI.sol";

contract IntegrationTest is Test {
    AAT public aat;
    TokenAI public tokenAI;
    
    address public owner;
    address public platformUser;
    address public student1;
    address public student2;
    address public instructor;
    address public treasury;
    
    string public constant BASE_URI = "https://platform.ai/metadata/";
    uint256 public constant PLATFORM_INITIAL_SUPPLY = 10000000 * 10**18; // 10M tokens
    
    // Course configurations
    bytes16 public constant COURSE_AI_101 = "ai-fundamentals";
    bytes16 public constant COURSE_ML_201 = "ml-advanced";
    bytes16 public constant MODEL_GPT4 = "gpt-4";
    bytes16 public constant MODEL_CLAUDE = "claude-3";
    
    function setUp() public {
        owner = makeAddr("owner");
        platformUser = makeAddr("platformUser");
        student1 = makeAddr("student1");
        student2 = makeAddr("student2");
        instructor = makeAddr("instructor");
        treasury = makeAddr("treasury");
        
        vm.startPrank(owner);
        
        // Deploy platform token with initial supply
        tokenAI = new TokenAI("AI Platform Token", "APT", PLATFORM_INITIAL_SUPPLY);
        
        // Deploy AAT with TokenAI integration
        aat = new AAT(BASE_URI, address(tokenAI));
        
        // Set treasury as fee recipient
        aat.setTreasury(treasury);
        
        // Set AAT as authorized minter for TokenAI
        tokenAI.setMinter(address(aat), true);
        
        // Distribute some platform tokens to users
        tokenAI.mint(student1, 1000 * 10**18);
        tokenAI.mint(student2, 1000 * 10**18);
        tokenAI.mint(instructor, 2000 * 10**18);
        
        vm.stopPrank();
    }
    
    /*─────────────────────── End-to-End Platform Scenarios ───────────────────────*/
    
    function testCompleteCoursePurchaseFlow() public {
        // Scenario: Student purchases AI course credits
        uint64 courseExpiration = uint64(block.timestamp + 90 days);
        uint256 creditAmount = 500; // 500 AI credits
        
        // 1. Platform mints course credits to student
        vm.prank(owner);
        uint256 courseTokenId = aat.mintToAddress(
            student1,
            instructor, // Instructor is the origin pool
            MODEL_GPT4,
            COURSE_AI_101,
            courseExpiration,
            true,  // reclaimable
            true,  // tradable
            creditAmount
        );
        
        // 2. Verify student received credits
        assertEq(aat.balanceOf(student1, courseTokenId), creditAmount);
        
        // 3. Student uses credits (simulated as transfer to platform for usage)
        uint256 usageAmount = 100;
        uint256 usageFeeNative = 5 * 10**18; // 5 APT fee
        uint256 usageFeeInKind = 10; // 10 credits fee
        
        vm.prank(student1);
        tokenAI.approve(address(aat), usageFeeNative);
        
        vm.prank(owner);
        aat.transfer(student1, platformUser, courseTokenId, usageAmount, usageFeeNative);
        
        // 4. Verify usage and fees
        assertEq(aat.balanceOf(student1, courseTokenId), creditAmount - usageAmount);
        assertEq(aat.balanceOf(platformUser, courseTokenId), usageAmount);
        assertEq(tokenAI.balanceOf(treasury), usageFeeNative);
    }
    
    function testStudentToStudentTrading() public {
        // Scenario: Students trade AI credits between different courses
        uint64 expiration = uint64(block.timestamp + 60 days);
        
        // 1. Platform mints different course credits to students
        vm.startPrank(owner);
        uint256 ai101TokenId = aat.mintToAddress(
            student1, instructor, MODEL_GPT4, COURSE_AI_101, expiration, true, true, 300
        );
        uint256 ml201TokenId = aat.mintToAddress(
            student2, instructor, MODEL_CLAUDE, COURSE_ML_201, expiration, true, true, 200
        );
        vm.stopPrank();
        
        // 2. Students trade credits
        uint256 tradeAmountA = 100;
        uint256 tradeAmountB = 80;
        uint256 tradeFeeA = 2 * 10**18;
        uint256 tradeFeeB = 2 * 10**18;
        
        // Students approve platform token for fees
        vm.prank(student1);
        tokenAI.approve(address(aat), tradeFeeA);
        vm.prank(student2);
        tokenAI.approve(address(aat), tradeFeeB);
        
        vm.prank(owner);
        aat.tradeWithNativeFees(
            student1, student2,
            ai101TokenId, tradeAmountA,
            ml201TokenId, tradeAmountB,
            0, // no match policy required
            tradeFeeA, tradeFeeB
        );
        
        // 3. Verify trade results
        assertEq(aat.balanceOf(student1, ai101TokenId), 300 - tradeAmountA);
        assertEq(aat.balanceOf(student1, ml201TokenId), tradeAmountB);
        assertEq(aat.balanceOf(student2, ai101TokenId), tradeAmountA);
        assertEq(aat.balanceOf(student2, ml201TokenId), 200 - tradeAmountB);
        
        // 4. Verify fees collected
        assertEq(tokenAI.balanceOf(treasury), tradeFeeA + tradeFeeB);
    }
    
    function testInstructorDistributionFlow() public {
        // Scenario: Instructor distributes credits to multiple students via batch transfer
        uint64 expiration = uint64(block.timestamp + 45 days);
        uint256 totalCredits = 1000;
        
        // 1. Platform mints credits to instructor
        vm.prank(owner);
        uint256 tokenId = aat.mintToAddress(
            instructor, instructor, MODEL_GPT4, COURSE_AI_101, expiration, true, true, totalCredits
        );
        
        // 2. Instructor distributes to students
        address[] memory students = new address[](2);
        students[0] = student1;
        students[1] = student2;
        
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 300;
        amounts[1] = 250;
        
        uint256[] memory feesNative = new uint256[](2);
        feesNative[0] = 1 * 10**18;
        feesNative[1] = 1 * 10**18;
        
        // Instructor approves platform tokens for fees
        vm.prank(instructor);
        tokenAI.approve(address(aat), 2 * 10**18);
        
        vm.prank(owner);
        aat.batchTransfer(instructor, students, tokenId, amounts, feesNative);
        
        // 3. Verify distribution
        assertEq(aat.balanceOf(student1, tokenId), amounts[0]);
        assertEq(aat.balanceOf(student2, tokenId), amounts[1]);
        assertEq(tokenAI.balanceOf(treasury), 2 * 10**18); // Total native fees
        
        // 4. Verify instructor's remaining balance
        uint256 expectedRemaining = totalCredits - amounts[0] - amounts[1]; // Minus distribution
        assertEq(aat.balanceOf(instructor, tokenId), expectedRemaining);
    }
    
    function testExpiredCreditsRenewal() public {
        // Scenario: Student's credits expire and need to be renewed
        uint64 shortExpiration = uint64(block.timestamp + 1 days);
        uint256 creditAmount = 400;
        
        // 1. Platform mints short-term credits
        vm.prank(owner);
        uint256 oldTokenId = aat.mintToAddress(
            student1, instructor, MODEL_GPT4, COURSE_AI_101, shortExpiration, true, true, creditAmount
        );
        
        // 2. Time passes and credits expire
        vm.warp(block.timestamp + 2 days);
        assertTrue(aat.isExpired(oldTokenId));
        
        // 3. Platform renews expired credits with new expiration
        uint64 newExpiration = uint64(block.timestamp + 30 days);
        vm.prank(owner);
        uint256 newTokenId = aat.burnAndRemintExpired(student1, oldTokenId, newExpiration);
        
        // 4. Verify renewal
        assertEq(aat.balanceOf(student1, oldTokenId), 0); // Old credits burned
        assertEq(aat.balanceOf(student1, newTokenId), creditAmount); // New credits minted
        assertFalse(aat.isExpired(newTokenId)); // New credits not expired
        
        AAT.TokenConfigs memory config = aat.getConfig(newTokenId);
        assertEq(config.expiration, newExpiration);
    }
    
    function testCrossCourseNativeTrading() public {
        // Scenario: Students trade credits from different courses using native fees
        uint64 expiration = uint64(block.timestamp + 60 days);
        
        // 1. Setup different course credits for students
        vm.startPrank(owner);
        uint256 ai101TokenId = aat.mintToAddress(
            student1, instructor, MODEL_GPT4, COURSE_AI_101, expiration, true, true, 500
        );
        uint256 ml201TokenId = aat.mintToAddress(
            student2, instructor, MODEL_CLAUDE, COURSE_ML_201, expiration, true, true, 400
        );
        vm.stopPrank();
        
        // 2. Execute native fee trade
        uint256 tradeAmountA = 200;
        uint256 tradeAmountB = 150;
        uint256 feeANative = 20 * 10**18; // 20 APT as fee from student1
        uint256 feeBNative = 15 * 10**18; // 15 APT as fee from student2
        
        // Students approve platform tokens for fees
        vm.prank(student1);
        tokenAI.approve(address(aat), feeANative);
        vm.prank(student2);
        tokenAI.approve(address(aat), feeBNative);
        
        vm.prank(owner);
        aat.tradeWithNativeFees(
            student1, student2,
            ai101TokenId, tradeAmountA,
            ml201TokenId, tradeAmountB,
            0, // no match policy
            feeANative, feeBNative
        );
        
        // 3. Verify complex balance state
        assertEq(aat.balanceOf(student1, ai101TokenId), 500 - tradeAmountA);
        assertEq(aat.balanceOf(student1, ml201TokenId), tradeAmountB);
        assertEq(aat.balanceOf(student2, ai101TokenId), tradeAmountA);
        assertEq(aat.balanceOf(student2, ml201TokenId), 400 - tradeAmountB);
        
        // 4. Verify treasury collected native fees
        assertEq(tokenAI.balanceOf(treasury), feeANative + feeBNative);
    }
    
    function testPlatformEmergencyControls() public {
        // Scenario: Platform needs to pause operations for emergency
        uint256 tokenId = _setupBasicCredits();
        
        // 1. Normal operations work
        vm.prank(owner);
        aat.transfer(student1, student2, tokenId, 50, 0);
        assertEq(aat.balanceOf(student2, tokenId), 50);
        
        // 2. Emergency pause
        vm.prank(owner);
        aat.pause();
        
        // 3. Operations are blocked
        vm.prank(owner);
        vm.expectRevert();
        aat.transfer(student1, student2, tokenId, 50, 0);
        
        vm.prank(owner);
        vm.expectRevert();
        aat.mintToAddress(student1, instructor, MODEL_GPT4, COURSE_AI_101, 
                             uint64(block.timestamp + 30 days), true, true, 100);
        
        // 4. Unpause and resume operations
        vm.prank(owner);
        aat.unpause();
        
        vm.prank(owner);
        aat.transfer(student1, student2, tokenId, 50, 0);
        assertEq(aat.balanceOf(student2, tokenId), 100);
    }
    
    function testMultiModelCreditManagement() public {
        // Scenario: Platform manages credits for different AI models
        uint64 expiration = uint64(block.timestamp + 60 days);
        
        // 1. Mint credits for different models
        vm.startPrank(owner);
        uint256 gpt4TokenId = aat.mintToAddress(
            student1, instructor, MODEL_GPT4, COURSE_AI_101, expiration, true, true, 300
        );
        uint256 claudeTokenId = aat.mintToAddress(
            student1, instructor, MODEL_CLAUDE, COURSE_AI_101, expiration, true, true, 200
        );
        vm.stopPrank();
        
        // 2. Verify different token IDs for different models
        assertTrue(gpt4TokenId != claudeTokenId);
        
        // 3. Student uses credits from both models
        vm.startPrank(owner);
        aat.transfer(student1, platformUser, gpt4TokenId, 100, 0);
        aat.transfer(student1, platformUser, claudeTokenId, 80, 0);
        vm.stopPrank();
        
        // 4. Verify separate tracking
        assertEq(aat.balanceOf(student1, gpt4TokenId), 300 - 100);
        assertEq(aat.balanceOf(student1, claudeTokenId), 200 - 80);
        assertEq(aat.balanceOf(platformUser, gpt4TokenId), 100);
        assertEq(aat.balanceOf(platformUser, claudeTokenId), 80);
    }
    
    function testPlatformRevenueCollection() public {
        // Scenario: Platform collects revenue through various fee mechanisms
        uint256 tokenId = _setupBasicCredits();
        
        uint256 initialTreasuryAPT = tokenAI.balanceOf(treasury);
        uint256 initialTreasuryCredits = aat.balanceOf(treasury, tokenId);
        
        // 1. Collect fees through transfers
        vm.prank(student1);
        tokenAI.approve(address(aat), 10 * 10**18);
        
        vm.prank(owner);
        aat.transfer(student1, student2, tokenId, 100, 5 * 10**18);
        
        // 2. Collect fees through batch operations
        address[] memory recipients = new address[](1);
        recipients[0] = student2;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 50;
        uint256[] memory feesNative = new uint256[](1);
        feesNative[0] = 3 * 10**18;
        
        vm.prank(student1);
        tokenAI.approve(address(aat), 3 * 10**18);
        
        vm.prank(owner);
        aat.batchTransfer(student1, recipients, tokenId, amounts, feesNative);
        
        // 3. Verify total revenue collection
        uint256 totalAPTFees = 8 * 10**18; // 5 + 3
        
        assertEq(tokenAI.balanceOf(treasury), initialTreasuryAPT + totalAPTFees);
    }
    
    /*─────────────────────── Helper Functions ───────────────────────*/
    
    function _setupBasicCredits() internal returns (uint256 tokenId) {
        vm.prank(owner);
        tokenId = aat.mintToAddress(
            student1,
            instructor,
            MODEL_GPT4,
            COURSE_AI_101,
            uint64(block.timestamp + 30 days),
            true,
            true,
            1000
        );
    }
    
    /*─────────────────────── Stress Tests ───────────────────────*/
    
    function testHighVolumeOperations() public {
        // Stress test with multiple operations
        uint256 tokenId = _setupBasicCredits();
        
        // Multiple sequential transfers
        for (uint i = 0; i < 10; i++) {
            vm.prank(owner);
            aat.transfer(student1, student2, tokenId, 5, 0);
            
            vm.prank(owner);
            aat.transfer(student2, student1, tokenId, 3, 0);
        }
        
        // Final balance check
        uint256 netTransferToStudent2 = (5 - 3) * 10; // 20 credits net
        assertEq(aat.balanceOf(student2, tokenId), netTransferToStudent2);
        assertEq(aat.balanceOf(student1, tokenId), 1000 - netTransferToStudent2);
    }
    
    function testComplexMultiUserScenario() public {
        // Complex scenario with multiple users and operations
        address[] memory users = new address[](5);
        for (uint i = 0; i < 5; i++) {
            users[i] = makeAddr(string(abi.encodePacked("user", vm.toString(i))));
            vm.prank(owner);
            tokenAI.mint(users[i], 100 * 10**18);
        }
        
        uint64 expiration = uint64(block.timestamp + 30 days);
        
        // Create different token types
        vm.startPrank(owner);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = aat.mintToAddress(users[0], instructor, MODEL_GPT4, "course-1", expiration, true, true, 500);
        tokenIds[1] = aat.mintToAddress(users[1], instructor, MODEL_CLAUDE, "course-2", expiration, true, true, 400);
        tokenIds[2] = aat.mintToAddress(users[2], instructor, MODEL_GPT4, "course-3", expiration, true, true, 600);
        vm.stopPrank();
        
        // Execute complex trading patterns
        for (uint i = 0; i < 3; i++) {
            uint256 userA = i;
            uint256 userB = (i + 1) % 3;
            uint256 tokenA = i;
            uint256 tokenB = (i + 1) % 3;
            
            vm.prank(users[userA]);
            tokenAI.approve(address(aat), 5 * 10**18);
            vm.prank(users[userB]);
            tokenAI.approve(address(aat), 5 * 10**18);
            
            vm.prank(owner);
            aat.tradeWithNativeFees(
                users[userA], users[userB],
                tokenIds[tokenA], 50,
                tokenIds[tokenB], 40,
                0, 2 * 10**18, 3 * 10**18
            );
        }
        
        // Verify final state is consistent
        for (uint i = 0; i < 3; i++) {
            assertTrue(aat.totalSupply(tokenIds[i]) > 0);
            assertTrue(tokenAI.balanceOf(treasury) > 0);
        }
    }
}