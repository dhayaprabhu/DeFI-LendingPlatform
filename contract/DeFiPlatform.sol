// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DeFiPlatform is ERC1155, Ownable {
    uint256 public constant STABLECOIN = 1;
    uint256 public constant YIELD_BEARING_ASSET = 2;
    uint256 public constant GOVERNANCE_TOKEN = 3;
    address addowner;
    event TokensMinted(address indexed account, uint256 tokenId, uint256 amount);

    constructor() ERC1155("https://api.example.com/token/{id}.json") Ownable(addowner) {
        // Mint initial supply for each financial instrument
        _mint(msg.sender, STABLECOIN, 1000, "");
        _mint(msg.sender, YIELD_BEARING_ASSET, 500, "");
        _mint(msg.sender, GOVERNANCE_TOKEN, 200, "");
    }

    // Mint new tokens
    function mint(address account, uint256 tokenId, uint256 amount) external onlyOwner {
        _mint(account, tokenId, amount, "");
        emit TokensMinted(account, tokenId, amount);
    }

    // Trade tokens
    function trade(address from, address to, uint256 tokenId, uint256 amount) external {
        require(msg.sender == from || isApprovedForAll(from, msg.sender), "Unauthorized");
        safeTransferFrom(from, to, tokenId, amount, "");
    }

    // Custom function to check the balance of a specific financial instrument
    function _balanceOf(address account, uint256 tokenId) external view returns (uint256) {
        return balanceOf(account, tokenId);
    }
}
