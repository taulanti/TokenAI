// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {TokenAI} from "../src/TokenAI.sol";

contract TokenAITest is Test {
    TokenAI public tokenAI;

    address public owner;
    address public user1;
    address public user2;
    address public treasury;

    uint256 public constant INITIAL_SUPPLY = 1000000 * 10 ** 18; // 1M tokens

    event Minted(address indexed to, uint256 amount);
    event BurnedFrom(address indexed from, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        treasury = makeAddr("treasury");

        vm.startPrank(owner);
        tokenAI = new TokenAI("TokenAI", "TAI", INITIAL_SUPPLY);
        vm.stopPrank();
    }

    /*─────────────────────── Deployment Tests ───────────────────────*/

    function testDeployment() public view {
        assertEq(tokenAI.name(), "TokenAI");
        assertEq(tokenAI.symbol(), "TAI");
        assertEq(tokenAI.decimals(), 18);
        assertEq(tokenAI.totalSupply(), INITIAL_SUPPLY);
        assertEq(tokenAI.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(tokenAI.owner(), owner);
    }

    function testDeploymentWithoutInitialSupply() public {
        vm.prank(owner);
        TokenAI token = new TokenAI("Test", "TEST", 0);

        assertEq(token.totalSupply(), 0);
        assertEq(token.balanceOf(owner), 0);
    }

    /*─────────────────────── Minting Tests ───────────────────────*/

    function testMint() public {
        uint256 mintAmount = 1000 * 10 ** 18;

        vm.expectEmit(true, false, false, true);
        emit Minted(user1, mintAmount);

        vm.prank(owner);
        tokenAI.mint(user1, mintAmount);

        assertEq(tokenAI.balanceOf(user1), mintAmount);
        assertEq(tokenAI.totalSupply(), INITIAL_SUPPLY + mintAmount);
    }

    function testMintMultipleUsers() public {
        uint256 amount1 = 500 * 10 ** 18;
        uint256 amount2 = 300 * 10 ** 18;

        vm.startPrank(owner);
        tokenAI.mint(user1, amount1);
        tokenAI.mint(user2, amount2);
        vm.stopPrank();

        assertEq(tokenAI.balanceOf(user1), amount1);
        assertEq(tokenAI.balanceOf(user2), amount2);
        assertEq(tokenAI.totalSupply(), INITIAL_SUPPLY + amount1 + amount2);
    }

    function testMintOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        tokenAI.mint(user2, 1000);
    }

    function testMintZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(TokenAI.ZeroAddress.selector);
        tokenAI.mint(address(0), 1000);
    }

    function testMintZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(TokenAI.ZeroAmount.selector);
        tokenAI.mint(user1, 0);
    }

    function testMintWhenPaused() public {
        vm.startPrank(owner);
        tokenAI.pause();

        vm.expectRevert();
        tokenAI.mint(user1, 1000);
        vm.stopPrank();
    }

    /*─────────────────────── Burning Tests ───────────────────────*/

    function testBurnFrom() public {
        uint256 burnAmount = 1000 * 10 ** 18;

        // Give user1 some tokens
        vm.prank(owner);
        tokenAI.mint(user1, burnAmount * 2);

        // User1 approves owner to burn tokens
        vm.prank(user1);
        tokenAI.approve(owner, burnAmount);

        uint256 initialSupply = tokenAI.totalSupply();

        vm.expectEmit(true, false, false, true);
        emit BurnedFrom(user1, burnAmount);

        vm.prank(owner);
        tokenAI.burnFrom(user1, burnAmount);

        assertEq(tokenAI.balanceOf(user1), burnAmount);
        assertEq(tokenAI.totalSupply(), initialSupply - burnAmount);
    }

    function testBurnFromZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(TokenAI.ZeroAddress.selector);
        tokenAI.burnFrom(address(0), 1000);
    }

    function testBurnFromZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(TokenAI.ZeroAmount.selector);
        tokenAI.burnFrom(user1, 0);
    }

    function testBurnFromInsufficientAllowance() public {
        vm.prank(owner);
        tokenAI.mint(user1, 1000);

        vm.prank(owner);
        vm.expectRevert();
        tokenAI.burnFrom(user1, 500); // No allowance set
    }

    function testBurnFromWhenPaused() public {
        vm.prank(owner);
        tokenAI.mint(user1, 1000);

        vm.prank(user1);
        tokenAI.approve(owner, 500);

        vm.prank(owner);
        tokenAI.pause();

        vm.prank(owner);
        vm.expectRevert();
        tokenAI.burnFrom(user1, 500);
    }

    /*─────────────────────── Transfer Tests ───────────────────────*/

    function testTransfer() public {
        uint256 transferAmount = 1000 * 10 ** 18;

        vm.prank(owner);
        bool success = tokenAI.transfer(user1, transferAmount);

        assertTrue(success);
        assertEq(tokenAI.balanceOf(user1), transferAmount);
        assertEq(tokenAI.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
    }

    function testTransferFrom() public {
        uint256 transferAmount = 1000 * 10 ** 18;

        // Owner approves user1 to transfer tokens
        vm.prank(owner);
        tokenAI.approve(user1, transferAmount);

        vm.prank(user1);
        bool success = tokenAI.transferFrom(owner, user2, transferAmount);

        assertTrue(success);
        assertEq(tokenAI.balanceOf(user2), transferAmount);
        assertEq(tokenAI.balanceOf(owner), INITIAL_SUPPLY - transferAmount);
    }

    function testTransferWhenPaused() public {
        vm.prank(owner);
        tokenAI.pause();

        vm.prank(owner);
        vm.expectRevert();
        tokenAI.transfer(user1, 1000);
    }

    function testTransferFromWhenPaused() public {
        vm.prank(owner);
        tokenAI.approve(user1, 1000);

        vm.prank(owner);
        tokenAI.pause();

        vm.prank(user1);
        vm.expectRevert();
        tokenAI.transferFrom(owner, user2, 1000);
    }

    /*─────────────────────── Pause Tests ───────────────────────*/

    function testPause() public {
        vm.prank(owner);
        tokenAI.pause();

        assertTrue(tokenAI.paused());
    }

    function testUnpause() public {
        vm.startPrank(owner);
        tokenAI.pause();
        tokenAI.unpause();
        vm.stopPrank();

        assertFalse(tokenAI.paused());
    }

    function testPauseOnlyOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        tokenAI.pause();
    }

    function testUnpauseOnlyOwner() public {
        vm.prank(owner);
        tokenAI.pause();

        vm.prank(user1);
        vm.expectRevert();
        tokenAI.unpause();
    }

    /*─────────────────────── Access Control Tests ───────────────────────*/

    function testOwnership() public view {
        assertEq(tokenAI.owner(), owner);
    }

    function testOnlyOwnerFunctions() public {
        // Test that non-owners cannot call owner functions
        vm.startPrank(user1);

        vm.expectRevert();
        tokenAI.mint(user2, 1000);

        vm.expectRevert();
        tokenAI.pause();

        vm.expectRevert();
        tokenAI.unpause();

        vm.stopPrank();
    }

    /*─────────────────────── Integration Tests ───────────────────────*/

    function testMintAndBurnCycle() public {
        uint256 amount = 1000 * 10 ** 18;

        // Mint tokens
        vm.prank(owner);
        tokenAI.mint(user1, amount);

        uint256 totalAfterMint = tokenAI.totalSupply();

        // User approves and burns half
        vm.prank(user1);
        tokenAI.approve(owner, amount / 2);

        vm.prank(owner);
        tokenAI.burnFrom(user1, amount / 2);

        assertEq(tokenAI.balanceOf(user1), amount / 2);
        assertEq(tokenAI.totalSupply(), totalAfterMint - (amount / 2));
    }

    function testComplexTokenFlow() public {
        uint256 mintAmount = 2000 * 10 ** 18;
        uint256 transferAmount = 500 * 10 ** 18;
        uint256 burnAmount = 300 * 10 ** 18;

        // Owner mints to user1
        vm.prank(owner);
        tokenAI.mint(user1, mintAmount);

        // User1 transfers to user2
        vm.prank(user1);
        tokenAI.transfer(user2, transferAmount);

        // User2 approves owner to burn some tokens
        vm.prank(user2);
        tokenAI.approve(owner, burnAmount);

        vm.prank(owner);
        tokenAI.burnFrom(user2, burnAmount);

        // Final state checks
        assertEq(tokenAI.balanceOf(user1), mintAmount - transferAmount);
        assertEq(tokenAI.balanceOf(user2), transferAmount - burnAmount);
        assertEq(tokenAI.totalSupply(), INITIAL_SUPPLY + mintAmount - burnAmount);
    }

    /*─────────────────────── Fuzz Tests ───────────────────────*/

    function testFuzzMint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0);
        vm.assume(amount < type(uint256).max / 2); // Prevent overflow

        uint256 initialSupply = tokenAI.totalSupply();

        vm.prank(owner);
        tokenAI.mint(to, amount);

        assertEq(tokenAI.balanceOf(to), amount);
        assertEq(tokenAI.totalSupply(), initialSupply + amount);
    }

    function testFuzzTransfer(uint256 amount) public {
        vm.assume(amount > 0 && amount <= INITIAL_SUPPLY);

        vm.prank(owner);
        tokenAI.transfer(user1, amount);

        assertEq(tokenAI.balanceOf(user1), amount);
        assertEq(tokenAI.balanceOf(owner), INITIAL_SUPPLY - amount);
    }
}
