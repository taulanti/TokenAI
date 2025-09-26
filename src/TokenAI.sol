// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/*───────────────────────────────────────────────────────────────────────────*\
│  TokenAI                                                                  │
│                                                                           │
│  Native ERC20 token for the AI platform fee system.                      │
│                                                                           │
│  • Owner-controlled minting for fee collection                           │
│  • Burnable for deflationary fee mechanics                               │
│  • Pausable for emergency controls                                       │
│  • Integrates with LLMBits for native fee payments                       │
\*───────────────────────────────────────────────────────────────────────────*/

contract TokenAI is ERC20, ERC20Burnable, Ownable, Pausable {
    /*──────────────────────────── Errors ───────────────────────────*/

    error ZeroAddress();
    error ZeroAmount();
    error UnauthorizedMinter();

    /*──────────────────────────── Events ───────────────────────────*/

    event Minted(address indexed to, uint256 amount);
    event BurnedFrom(address indexed from, uint256 amount);
    event MinterSet(address indexed minter, bool enabled);

    /*─────────────────────────── Storage ────────────────────────────*/

    mapping(address => bool) public minters;

    /*─────────────────────────── Modifiers ────────────────────────────*/

    modifier onlyMinter() {
        if (!minters[msg.sender] && msg.sender != owner()) {
            revert UnauthorizedMinter();
        }
        _;
    }

    /*──────────────────────── Constructor ─────────────────────────*/

    constructor(string memory name, string memory symbol, uint256 initialSupply)
        ERC20(name, symbol)
        Ownable(msg.sender)
    {
        if (initialSupply > 0) {
            _mint(msg.sender, initialSupply);
        }
    }

    /*─────────────────────── Admin Controls ───────────────────────*/

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setMinter(address minter, bool enabled) external onlyOwner {
        if (minter == address(0)) revert ZeroAddress();
        minters[minter] = enabled;
        emit MinterSet(minter, enabled);
    }

    /*──────────────────────── Minting & Burning ────────────────────*/

    function mint(address to, uint256 amount) external onlyMinter whenNotPaused {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        _mint(to, amount);
        emit Minted(to, amount);
    }

    function burnFrom(address from, uint256 amount) public override whenNotPaused {
        if (from == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        // Use the inherited ERC20Burnable functionality
        super.burnFrom(from, amount);
        emit BurnedFrom(from, amount);
    }

    /*─────────────────────── Transfer Overrides ───────────────────*/

    function transfer(address to, uint256 amount) public override whenNotPaused returns (bool) {
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override whenNotPaused returns (bool) {
        return super.transferFrom(from, to, amount);
    }
}
