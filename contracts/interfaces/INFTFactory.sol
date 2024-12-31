
// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { NFTFactoryStorage } from "../NFTFactoryStorage.sol";

interface INFTFactory {
    struct Nft {
        // add any additionnal features here
        uint256 tokenId;  
        uint256 value; // 27 decimals
        string tokenURI; // IPFS address of the metadata file 
    }

    function createNFT( 
        uint256 _value,
        address _owner,
        string memory _tokenURI
    ) external  returns (uint256);

    function createNFTPool(
        uint256[] memory _values,
        address[] memory _owners,
        string[] memory _tokenURIs
    ) external returns (uint256[] memory);

    function transferFrom(address from, address to, uint256 tokenId) external;

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) external;

    function setTokenURI(uint256 tokenId, string memory _tokenURI) external;

    function ownerOf(uint256 tokenId) external view returns(address);

    function getNFTsSupplyTotalValue() external view returns(uint256 totalValue);

    function getApproved(uint256 tokenId) external view returns (address);

    function approve(address to, uint256 tokenId) external;

    function setApprovalForAll(address operator, bool approved) external;

    function isApprovedForAll(address owner, address operator) external view returns (bool);

    function getNFT(uint256 tokenId) external view returns (Nft memory);

}