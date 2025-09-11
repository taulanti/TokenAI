// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/*───────────────────────────────────────────────────────────────────────────*\
│  AAT (AI Access Token)                                                   │
│                                                                           │
│  ERC-1155 with per-class configuration, custodial transfer/trade, and     │
│  native TokenAI fee support.                                              │
│                                                                           │
│  • All transfer/trade entrypoints are owner-only (custodian flow).        │
│  • Transfers allowed if token is tradable OR sender == originPool.        │
│  • Expired tokens are non-transferable; use burn-and-remint.              │
│  • tokenId = keccak256(abi.encode(DOMAIN, config...)) (deterministic).    │
\*───────────────────────────────────────────────────────────────────────────*/

interface ITokenAI {
    function burnFrom(address from, uint256 amount) external;
    function mint(address to, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract AAT is ERC1155, ERC1155Supply, Ownable, ReentrancyGuard, Pausable {
    using Strings for uint256;

    /*─────────────────────────── Constants ───────────────────────────*/

    // Bump this if you ever change the token id encoding scheme/fields.
    bytes32 private constant _ID_DOMAIN = keccak256("AAT.v1");

    /*─────────────────────────── Storage ────────────────────────────*/

    ITokenAI public tokenAi; // Optional native fee token (mint/burn controlled by you)
    address public treasury; // Destination for all fees (native + in-kind)
    string private baseUri;

    struct TokenConfigs {
        bytes16 model; // LLM family-model-version  (≤16 bytes)
        bytes16 scope; // Course / project code     (≤16 bytes)
        uint64 expiration; // UNIX timestamp (0 = no expiration)
        address originPool; // Controller that can override tradable rules
        bool reclaimable; // Reserved for future reclaim logic
        bool tradable; // If true, non-originPool holders can transfer
    }

    // tokenId => immutable configuration
    mapping(uint256 => TokenConfigs) public tokenConfigs;

    // Bitmask flags for match policies
    uint8 private constant MATCH_MODEL = 1 << 0;
    uint8 private constant MATCH_SCOPE = 1 << 1;
    uint8 private constant MATCH_EXPIRATION = 1 << 2;
    uint8 private constant MATCH_RECLAIMABLE = 1 << 3;
    uint8 private constant MATCH_TRADABLE = 1 << 4;
    uint8 private constant MATCH_ORIGINPOOL = 1 << 5;

    /*──────────────────────────── Errors ───────────────────────────*/

    error ZeroAddress();
    error UnknownTokenId(uint256 id);
    error ConfigMismatch();
    error TokenAlreadyExists();
    error TokenNotTradable();
    error TokenNotExpired();
    error InsufficientBalance(
        address from,
        uint256 tokenId,
        uint256 required,
        uint256 available
    );
    error TokenExpired();
    error InvalidExpiration();
    error ArrayLengthMismatch();
    error NoTokensToReclaim();
    error PolicyMismatch(uint8 field);
    error ApprovalsDisabled();
    error ExcessiveFee();
    error MaxSupplyExceeded();

    /*──────────────────────────── Events ───────────────────────────*/

    event TokenMinted(
        address indexed to,
        uint256 indexed tokenId,
        uint256 amount,
        bytes16 model,
        bytes16 scope,
        uint64 expiration,
        address originPool,
        bool reclaimable,
        bool tradable
    );

    event BaseUriUpdated(string newBaseUri);
    event FeeTokenSet(address token);
    event TreasurySet(address treasury);

    event FeeAppliedNative(
        address indexed partyA,
        address indexed partyB,
        uint256 feeANative,
        uint256 feeBNative,
        address indexed treasury
    );


    /*──────────────────────── Constructor ─────────────────────────*/

    constructor(
        string memory _baseUri,
        address _tokenAi
    ) ERC1155("") Ownable(msg.sender) {
        baseUri = _baseUri;
        treasury = owner();
        if (_tokenAi != address(0)) {
            tokenAi = ITokenAI(_tokenAi);
            emit FeeTokenSet(_tokenAi);
        }
    }

    /*─────────────────────── Admin Controls ───────────────────────*/

    function pause() external onlyOwner {
        _pause();
    }
    function unpause() external onlyOwner {
        _unpause();
    }

    function setBaseUri(string memory _newBaseUri) external onlyOwner {
        baseUri = _newBaseUri;
        emit BaseUriUpdated(_newBaseUri);
    }

    function setFeeToken(address tokenAiAddress) external onlyOwner {
        if (tokenAiAddress == address(0)) revert ZeroAddress();
        tokenAi = ITokenAI(tokenAiAddress);
        emit FeeTokenSet(tokenAiAddress);
    }

    function setTreasury(address _treasury) external onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        treasury = _treasury;
        emit TreasurySet(_treasury);
    }

    /*───────────────────────── Metadata ───────────────────────────*/

    function uri(uint256 tokenId) public view override returns (string memory) {
        return
            string(abi.encodePacked(baseUri, tokenId.toHexString(32), ".json"));
    }

    /*──────────────────── TokenId derivation ──────────────────────*/

    function computeTokenId(
        address originPool,
        bytes16 model,
        bytes16 scope,
        uint64 expiration,
        bool reclaimable,
        bool tradable
    ) public pure returns (uint256 tokenId) {
        // Use abi.encode and a domain salt to keep determinism across future schema changes
        return
            uint256(
                keccak256(
                    abi.encode(
                        _ID_DOMAIN,
                        originPool,
                        model,
                        scope,
                        expiration,
                        reclaimable,
                        tradable
                    )
                )
            );
    }

    /*─────────────────────────── Views ────────────────────────────*/

    function isExpired(uint256 id) public view returns (bool) {
        TokenConfigs memory cfg = tokenConfigs[id];
        if (cfg.originPool == address(0)) return false; // unknown -> false
        return (cfg.expiration != 0 && block.timestamp >= cfg.expiration);
    }

    function getConfig(
        uint256 tokenId
    ) external view returns (TokenConfigs memory config) {
        config = tokenConfigs[tokenId];
        if (config.originPool == address(0)) revert UnknownTokenId(tokenId);
    }

    /*────────────────────────── Minting ───────────────────────────*/

    function _mintTo(
        address recipient,
        address originPool,
        bytes16 model,
        bytes16 scope,
        uint64 expiration,
        bool reclaimable,
        bool tradable,
        uint256 amount
    ) internal returns (uint256 tokenId) {
        if (recipient == address(0) || originPool == address(0))
            revert ZeroAddress();

        tokenId = computeTokenId(
            originPool,
            model,
            scope,
            expiration,
            reclaimable,
            tradable
        );
        TokenConfigs memory cfg = tokenConfigs[tokenId];

        if (cfg.originPool == address(0)) {
            tokenConfigs[tokenId] = TokenConfigs({
                model: model,
                scope: scope,
                expiration: expiration,
                originPool: originPool,
                reclaimable: reclaimable,
                tradable: tradable
            });
        } else {
            // Redundant in practice since tokenId encodes all fields, but keep as a guard for integrity.
            if (
                cfg.model != model ||
                cfg.scope != scope ||
                cfg.expiration != expiration ||
                cfg.originPool != originPool ||
                cfg.reclaimable != reclaimable ||
                cfg.tradable != tradable
            ) revert ConfigMismatch();
        }

        _mint(recipient, tokenId, amount, "");
        emit TokenMinted(
            recipient,
            tokenId,
            amount,
            model,
            scope,
            expiration,
            originPool,
            reclaimable,
            tradable
        );
    }

    function mintToAddress(
        address recipient,
        address originPool,
        bytes16 model,
        bytes16 scope,
        uint64 expiration,
        bool reclaimable,
        bool tradable,
        uint256 amount
    ) external onlyOwner whenNotPaused nonReentrant returns (uint256 tokenId) {
        if (amount == 0) revert InsufficientBalance(address(0), 0, 1, 0);
        tokenId = _mintTo(
            recipient,
            originPool,
            model,
            scope,
            expiration,
            reclaimable,
            tradable,
            amount
        );
    }

    /*───────────────────────── Transfers ──────────────────────────*/

    function _validateTransferRules(address from, uint256 id) private view {
        TokenConfigs memory cfg = tokenConfigs[id];
        if (cfg.originPool == address(0)) revert UnknownTokenId(id);
        if (cfg.expiration != 0 && block.timestamp >= cfg.expiration)
            revert TokenExpired();

        bool allowed = cfg.tradable || (from == cfg.originPool);
        if (!allowed) revert TokenNotTradable();
    }

    function _singleTransfer(
        address from,
        address to,
        uint256 id,
        uint256 amt
    ) private {
        if (to == address(0)) revert ZeroAddress();
        uint256 bal = balanceOf(from, id);
        if (bal < amt) revert InsufficientBalance(from, id, amt, bal);
        _safeTransferFrom(from, to, id, amt, "");
    }

    function transfer(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        uint256 feeNative
    ) external onlyOwner whenNotPaused nonReentrant {
        _validateTransferRules(from, id);

        uint256 bal = balanceOf(from, id);
        if (bal < amount) revert InsufficientBalance(from, id, amount, bal);

        // Native fee (TokenAI)
        if (feeNative > 0) {
            if (address(tokenAi) == address(0)) revert ZeroAddress();
            if (tokenAi.balanceOf(from) < feeNative)
                revert InsufficientBalance(
                    from,
                    0,
                    feeNative,
                    tokenAi.balanceOf(from)
                );
            tokenAi.burnFrom(from, feeNative);
            tokenAi.mint(treasury, feeNative);
            emit FeeAppliedNative(from, address(0), feeNative, 0, treasury);
        }

        _singleTransfer(from, to, id, amount);
    }

    

    

    function batchTransfer(
        address from,
        address[] calldata recipients,
        uint256 id,
        uint256[] calldata amounts,
        uint256[] calldata feesNative
    ) external onlyOwner whenNotPaused nonReentrant {
        uint256 len = recipients.length;
        if (
            len == 0 ||
            amounts.length != len ||
            feesNative.length != len
        ) revert ArrayLengthMismatch();

        _validateTransferRules(from, id);

        uint256 totalAmount;
        uint256 totalFeeNative;

        for (uint256 i; i < len; ) {
            if (recipients[i] == address(0)) revert ZeroAddress();
            totalAmount += amounts[i];
            totalFeeNative += feesNative[i];
            unchecked {
                ++i;
            }
        }

        uint256 bal = balanceOf(from, id);
        if (bal < totalAmount) revert InsufficientBalance(from, id, totalAmount, bal);

        // Handle native fees in batch
        if (totalFeeNative > 0) {
            if (address(tokenAi) == address(0)) revert ZeroAddress();
            if (tokenAi.balanceOf(from) < totalFeeNative)
                revert InsufficientBalance(
                    from,
                    0,
                    totalFeeNative,
                    tokenAi.balanceOf(from)
                );
            tokenAi.burnFrom(from, totalFeeNative);
            tokenAi.mint(treasury, totalFeeNative);
        }

        // Perform actual transfers
        for (uint256 i; i < len; ) {
            _safeTransferFrom(from, recipients[i], id, amounts[i], "");
            unchecked {
                ++i;
            }
        }

        // Emit consolidated events
        if (totalFeeNative > 0) {
            emit FeeAppliedNative(
                from,
                address(0),
                totalFeeNative,
                0,
                treasury
            );
        }
    }

    /*────────────────────────── Trading ───────────────────────────*/

    function _validateMatchMask(
        TokenConfigs memory A,
        TokenConfigs memory B,
        uint8 policyMask
    ) internal pure {
        if (policyMask == 0) return;
        uint8 diff;
        if (A.model != B.model) diff |= MATCH_MODEL;
        if (A.scope != B.scope) diff |= MATCH_SCOPE;
        if (A.expiration != B.expiration) diff |= MATCH_EXPIRATION;
        if (A.reclaimable != B.reclaimable) diff |= MATCH_RECLAIMABLE;
        if (A.tradable != B.tradable) diff |= MATCH_TRADABLE;
        if (A.originPool != B.originPool) diff |= MATCH_ORIGINPOOL;

        uint8 violation = diff & policyMask;
        if (violation != 0) revert PolicyMismatch(violation);
    }

    function tradeWithNativeFees(
        address partyA,
        address partyB,
        uint256 idA,
        uint256 amountA,
        uint256 idB,
        uint256 amountB,
        uint8 matchMask,
        uint256 feeANative,
        uint256 feeBNative
    ) external onlyOwner whenNotPaused nonReentrant {
        if (partyA == address(0) || partyB == address(0)) revert ZeroAddress();

        _validateTrade(partyA, idA, amountA, partyB, idB, amountB, matchMask);

        _processNativeFees(partyA, feeANative, partyB, feeBNative);

        _singleTransfer(partyA, partyB, idA, amountA);
        _singleTransfer(partyB, partyA, idB, amountB);
    }

    function _validateTrade(
        address partyA,
        uint256 idA,
        uint256 amountA,
        address partyB,
        uint256 idB,
        uint256 amountB,
        uint8 matchMask
    ) internal view {
        _validateTransferRules(partyA, idA);
        TokenConfigs memory cfgA = tokenConfigs[idA];
        uint256 balA = balanceOf(partyA, idA);
        if (balA < amountA) revert InsufficientBalance(partyA, idA, amountA, balA);

        _validateTransferRules(partyB, idB);
        TokenConfigs memory cfgB = tokenConfigs[idB];
        uint256 balB = balanceOf(partyB, idB);
        if (balB < amountB) revert InsufficientBalance(partyB, idB, amountB, balB);

        _validateMatchMask(cfgA, cfgB, matchMask);
    }

    function _processNativeFees(
        address partyA,
        uint256 feeANative,
        address partyB,
        uint256 feeBNative
    ) internal {
        if (feeANative > 0) {
            if (address(tokenAi) == address(0)) revert ZeroAddress();
            if (tokenAi.balanceOf(partyA) < feeANative)
                revert InsufficientBalance(partyA, 0, feeANative, tokenAi.balanceOf(partyA));
            tokenAi.burnFrom(partyA, feeANative);
        }
        if (feeBNative > 0) {
            if (address(tokenAi) == address(0)) revert ZeroAddress();
            if (tokenAi.balanceOf(partyB) < feeBNative)
                revert InsufficientBalance(partyB, 0, feeBNative, tokenAi.balanceOf(partyB));
            tokenAi.burnFrom(partyB, feeBNative);
        }

        if (feeANative + feeBNative > 0) {
            tokenAi.mint(treasury, feeANative + feeBNative);
            emit FeeAppliedNative(partyA, partyB, feeANative, feeBNative, treasury);
        }
    }


    /*──────────────────────── Burn & Remint ───────────────────────*/

    function burnAndRemintExpired(
        address holder,
        uint256 oldId,
        uint64 newExpiration
    ) external onlyOwner whenNotPaused nonReentrant returns (uint256 newId) {
        if (holder == address(0)) revert ZeroAddress();
        if (newExpiration <= uint64(block.timestamp))
            revert InvalidExpiration();

        TokenConfigs memory oldCfg = tokenConfigs[oldId];
        if (oldCfg.originPool == address(0)) revert UnknownTokenId(oldId);
        if (oldCfg.expiration == 0 || block.timestamp < oldCfg.expiration)
            revert TokenNotExpired();

        uint256 bal = balanceOf(holder, oldId);
        if (bal == 0) revert NoTokensToReclaim();

        newId = computeTokenId(
            oldCfg.originPool,
            oldCfg.model,
            oldCfg.scope,
            newExpiration,
            oldCfg.reclaimable,
            oldCfg.tradable
        );

        tokenConfigs[newId] = TokenConfigs({
            model: oldCfg.model,
            scope: oldCfg.scope,
            expiration: newExpiration,
            originPool: oldCfg.originPool,
            reclaimable: oldCfg.reclaimable,
            tradable: oldCfg.tradable
        });

        _burn(holder, oldId, bal);
        _mint(holder, newId, bal, "");

        emit TokenMinted(
            holder,
            newId,
            bal,
            oldCfg.model,
            oldCfg.scope,
            newExpiration,
            oldCfg.originPool,
            oldCfg.reclaimable,
            oldCfg.tradable
        );
    }

    /*────────────── Lock down standard 1155 approvals ─────────────*/

    function setApprovalForAll(
        address /*operator*/,
        bool /*approved*/
    ) public pure override {
        revert ApprovalsDisabled();
    }

    function isApprovedForAll(
        address /*account*/,
        address /*operator*/
    ) public pure override returns (bool) {
        return false;
    }

    /*────────────── Owner-only transfer entrypoints ───────────────*/

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override onlyOwner whenNotPaused {
        _validateTransferRules(from, id);

        super.safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override onlyOwner whenNotPaused {
        if (to == address(0)) revert ZeroAddress();

        for (uint256 i; i < ids.length; ) {
            _validateTransferRules(from, ids[i]);
            unchecked {
                ++i;
            }
        }
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /*────────────────────── Internal Overrides ────────────────────*/

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Supply) {
        super._update(from, to, ids, values);
    }

    function supportsInterface(
        bytes4 id
    ) public view virtual override(ERC1155) returns (bool) {
        return super.supportsInterface(id);
    }
}