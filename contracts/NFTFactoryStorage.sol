// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title NFTFactoryStorage Contract 
 * @author TOKAMAK OPAL TEAM
 * @notice This contract manages storage variables related to the NFT used by the NFTFactory
 * It is used for the creation of NFT, transfer of NFT or even specific customized interactions implemented.
**/
contract NFTFactoryStorage {
    
    //---------------------------------------------------------------------------------------
    //--------------------------------------STRUCT-------------------------------------------
    //---------------------------------------------------------------------------------------
    
    struct Nft {
        // add any additionnal features here
        uint256 tokenId;  
        uint256 value; // 27 decimals
        string tokenURI; // IPFS address of the metadata file 
    }

    //---------------------------------------------------------------------------------------
    //-------------------------------------STORAGE-------------------------------------------
    //---------------------------------------------------------------------------------------

    Nft[] public Nfts;

    mapping(uint256 => address) public NFTIndexToOwner;
    mapping(address => uint256) public ownershipTokenCount;

    bool public paused;

    // contract addresses
    address internal wston;
    address internal treasury;

    //---------------------------------------------------------------------------------------
    //-------------------------------------EVENTS--------------------------------------------
    //---------------------------------------------------------------------------------------

    // Premining events
    event Created(
        uint256 indexed tokenId, 
        uint256 value,
        address owner,
        string tokenURI 
    );
    event TransferNFT(address from, address to, uint256 tokenId);

    // melt even
    event NFTMelted(uint256 tokenId, address owner);

    // Pause Events
    event Paused(address account);
    event Unpaused(address account);

    //---------------------------------------------------------------------------------------
    //-------------------------------------ERRORS--------------------------------------------
    //---------------------------------------------------------------------------------------

    // Mining errors
    error MismatchedArrayLengths();
    error AddressZero();
    error NotNFTOwner();

    // Transfer error
    error SameSenderAndRecipient();
    error TransferFailed();

    // access errors
    error UnauthorizedCaller(address caller);
    error ContractPaused();
    error ContractNotPaused();
    error URIQueryForNonexistentToken(uint256 tokenId);
}