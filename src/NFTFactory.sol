// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {NFTFactoryStorage} from "./NFTFactoryStorage.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./proxy/ProxyStorage.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface ITreasury {
    function transferWSTON(address _to, uint256 _amount) external returns (bool);
    function transferTreasuryNFTto(address _to, uint256 _tokenId) external returns (bool);
}

/**
 * @title NFTFactory
 * @author TOKAMAK OPAL TEAM
 * @dev The NFTFactory contract is responsible for managing the lifecycle of NFT tokens within the system.
 * This includes the creation, transfer, and brun of NFTs. The contract provides functionalities
 * for both administrative and user interactions, ensuring a comprehensive manaNFTent of NFT tokens.
 *
 * Administrative Functions
 * - Premine NFTs: Allows administrators to create and allocate NFTs directly to the treasury contract.
 *   The purpose is to initialize the system with a predefined set of NFTs that can be distributed or sold later.
 *
 * User Functions
 * - Burn NFTs: Users can convert their NFTs back into their underlying value.
 *   This process involves burning the NFT token and transferring its value to the user.
 *
 * Security and Access Control
 * - The contract implements access control mechanisms to ensure that only authorized users can perform certain actions.
 *   For example, only the contract owner or designated administrators can premine NFTs.
 * - The contract also includes mechanisms to pause and unpause operations, providing an additional layer of security
 *   in case of emergencies or required maintenance.
 *
 * Integration
 * - The NFTFactory contract integrates with other components of the system, such as the treasury and marketplace contracts,
 *   to facilitate seamless interactions and transactions involving NFTs.
 */

contract NFTFactory is ProxyStorage,
    Initializable,
    ERC721URIStorageUpgradeable,
    NFTFactoryStorage,
    OwnableUpgradeable,
    ReentrancyGuard {

    /**
     * @notice Modifier to ensure the contract is not paused.
     */

    modifier whenNotPaused() {
        if (paused) {
            revert ContractPaused();
        }
        _;
    }

    /**
     * @notice Modifier to ensure the contract is paused.
     */
    modifier whenPaused() {
        if (!paused) {
            revert ContractNotPaused();
        }
        _;
    }

    /**
     * @notice Modifier to ensure the caller is the treasury contract
     */
    modifier onlyTreasury() {
        if (msg.sender != treasury) {
            revert UnauthorizedCaller(msg.sender);
        }
        _;
    }

    //---------------------------------------------------------------------------------------
    //--------------------------INITIALIZATION FUNCTIONS-------------------------------------
    //---------------------------------------------------------------------------------------

    /**
     * @notice Initializes the contract with the given parameters.
     * @param _tokenName name of the NFT to be created.
     * @param _symbol symbol of the NFT to be created.
     * @param _owner Address of the contract owner.
     * @param _wston Address of the WSTON token.
     * @param _ton Address of the TON token.
     * @param _treasury Address of the treasury contract.
     */
    function initialize(
        string memory _tokenName, 
        string memory _symbol, 
        address _owner, 
        address _wston, 
        address _ton, 
        address _treasury
    ) external initializer {
        __ERC721_init(_tokenName, _symbol);
        __Ownable_init(_owner);
        wston = _wston;
        ton = _ton;
        treasury = _treasury;
    }

    /**
     * @notice Sets the treasury address.
     * @param _treasury The new treasury address.
     */
    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    /**
     * @notice updates the wston token address
     * @param _wston New wston token address.
     */
    function setWston(address _wston) external onlyOwner {
        wston = _wston;
    }

    /**
     * @notice updates the Ton token address
     * @param _ton New wston token address.
     */
    function setTon(address _ton) external onlyOwner {
        ton = _ton;
    }

    //---------------------------------------------------------------------------------------
    //--------------------------EXTERNAL FUNCTIONS-------------------------------------------
    //---------------------------------------------------------------------------------------

    /**
     * @notice Melts an NFT, converting it back to its value.
     * @param _tokenId ID of the token to melt.
     * @dev The caller receives the WSTON amount associated with the NFT.
     * @dev The ERC721 token is burned.
     * @dev The caller must be the token owner.
     */
    function meltNFT(uint256 _tokenId) external whenNotPaused {
        // Check if the caller's address is zero
        if (msg.sender == address(0)) {
            revert AddressZero();
        }
        // Ensure the caller is the owner of the NFT
        if (NFTIndexToOwner[_tokenId] != msg.sender) {
            revert NotNFTOwner();
        }
        // Get the value of the NFT
        uint256 amount = Nfts[_tokenId].value;
        // Burn the NFT and update ownership counts
        delete Nfts[_tokenId];
        ownershipTokenCount[msg.sender]--;
        delete NFTIndexToOwner[_tokenId];
        // Burn the ERC721 token
        _burn(_tokenId);
        // Transfer the WSTON amount to the caller
        if (!ITreasury(treasury).transferWSTON(msg.sender, amount)) {
            revert TransferFailed();
        }
        // Emit an event indicating the NFT has been melted
        emit NFTMelted(_tokenId, msg.sender);
    }

    /**
     * @notice Creates an NFT based on its attributes passed in the parameters and assigns their ownership to the owner.
     * @param _value WSTON value of the new NFT to be created.
     * @param _owner owner of the new NFT.
     * @param _tokenURI TokenURI of the NFT.
     * @return The IDs of the newly created NFT.
     */
    function createNFT(uint256 _value, address _owner, string memory _tokenURI)
        public
        onlyTreasury
        whenNotPaused
        returns (uint256)
    {

        // Create the new NFT and get its ID
        Nft memory newNft = Nft({
            tokenId: 0,
            value: _value,
            tokenURI: _tokenURI
        });

        Nfts.push(newNft);
        uint256 newNftId = Nfts.length - 1;
        Nfts[newNftId].tokenId = newNftId;

        // update ownership variables
        NFTIndexToOwner[newNftId] = _owner;
        ownershipTokenCount[_owner]++;

        // Mint the NFT and set its token URI
        _safeMint(_owner, newNftId);
        _setTokenURI(newNftId, _tokenURI);

        // Emit an event for the creation of the new NFT
        emit Created(newNftId, _value, _owner, _tokenURI);
        return newNftId;
    }

    /**
     * @notice Creates a pool of NFTs based on their attributes passed in the parameters and assigns their ownership to the owners.
     * @param _values value of each NFT to be minted
     * @param _owners owners of the NFTs to be minted.
     * @param _tokenURIs TokenURIs of each NFT
     * @return The IDs of the newly created NFTs.
     */
    function createNFTPool(
        uint256[] memory _values,
        address[] memory _owners,
        string[] memory _tokenURIs
    ) public onlyTreasury whenNotPaused returns (uint256[] memory) {
        require(_values.length == _owners.length && 
        _values.length == _tokenURIs.length, "Wrong parameters length");

        // Cache the length of the _rarities array for gas optimization
        uint256 length = _values.length;

        // Initialize an array to store the IDs of the newly created NFTs
        uint256[] memory newNftIds = new uint256[](_values.length);

        // Loop through each set of attributes and create a NFTs
        for (uint256 i = 0; i < length; ++i) {
            // Create an NFT with the specified attributes and store its ID
            newNftIds[i] = createNFT(_values[i], _owners[i], _tokenURIs[i]);
        }

        // Return the array of new NFT IDs
        return newNftIds;
    }

        /**
     * @notice Transfers an NFT token from one address to another.
     * @dev Overrides the ERC721 transferFrom function. The transfer is only allowed when the contract is not paused.
     *      The sender and recipient must be different.
     * @param from The address to transfer the token from.
     * @param to The address to transfer the token to.
     * @param tokenId The ID of the token to transfer.
     */
    function transferFrom(address from, address to, uint256 tokenId)
        public
        override(ERC721Upgradeable, IERC721)
        whenNotPaused
    {
        // Check if the sender and recipient addresses are the same
        if (to == from) {
            revert SameSenderAndRecipient(); // Revert if they are the same
        }

        // Perform the NFT transfer logic
        _transferNFT(from, to, tokenId);

        // Call the parent contract's transferFrom function to handle the ERC721 transfer
        super.transferFrom(from, to, tokenId);

        // Emit an event to log the transfer of the NFT
        emit TransferNFT(from, to, tokenId);
    }

    /**
     * @notice Safely transfers a NFT token from one address to another.
     * @dev Overrides the ERC721 safeTransferFrom function. The transfer is only allowed when the contract is not paused.
     *      Checks if the recipient is a contract and if it can handle ERC721 tokens.
     * @param from The address to transfer the token from.
     * @param to The address to transfer the token to.
     * @param tokenId The ID of the token to transfer.
     * @param data Additional data with no specified format, sent in call to `to`.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        override(ERC721Upgradeable, IERC721)
        whenNotPaused
    {
        // Check if the sender and recipient addresses are the same
        if (to == from) {
            revert SameSenderAndRecipient(); // Revert if they are the same
        }

        // Perform the NFT transfer logic
        _transferNFT(from, to, tokenId);

        // Call the parent contract's transferFrom function to handle the ERC721 transfer
        super.transferFrom(from, to, tokenId);

        // Check if the recipient is a contract and if it can handle ERC721 tokens
        _checkOnERC721(from, to, tokenId, data);

        // Emit an event to log the transfer of the NFT
        emit TransferNFT(from, to, tokenId);
    }

    /**
     * @notice Sets the token URI for a specific NFT token.
     * @param tokenId The ID of the token to set the URI for.
     * @param _tokenURI The URI to set for the token.
     */
    function setTokenURI(uint256 tokenId, string memory _tokenURI) external {
        _setTokenURI(tokenId, _tokenURI);
    }

    //---------------------------------------------------------------------------------------
    //--------------------------PRIVATE/INERNAL FUNCTIONS------------------------------------
    //---------------------------------------------------------------------------------------

    /**
     * @notice Transfers a NFT from one address to another.
     * @param _from The address to transfer the NFT from.
     * @param _to The address to transfer the NFT to.
     * @param _tokenId The ID of the NFT to transfer.
     */
    function _transferNFT(address _from, address _to, uint256 _tokenId) private {
        // Increment the ownership count for the recipient
        ownershipTokenCount[_to]++;
        // Update the owner of the NFT
        NFTIndexToOwner[_tokenId] = _to;
        // Decrement the ownership count for the sender
        ownershipTokenCount[_from]--;
    }

    /**
     * @notice Sets the token URI for an NFT.
     * @dev Overrides the internal function to ensure only the owner can set the URI.
     * @param tokenId The ID of the NFT.
     * @param _tokenURI The URI to set for the NFT.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal override {
        // Ensure the sender is the owner of the NFT
        if (msg.sender != ownerOf(tokenId)) {
            revert NotNFTOwner();
        }
        // Call the parent function to set the token URI
        super._setTokenURI(tokenId, _tokenURI);
    }

    /**
     * @notice Checks if the recipient address can handle ERC721 tokens.
     * @dev Calls the onERC721Received function on the recipient if it is a contract.
     * @param from The address sending the token.
     * @param to The address receiving the token.
     * @param tokenId The ID of the token being transferred.
     * @param data Additional data with no specified format.
     */
    function _checkOnERC721(address from, address to, uint256 tokenId, bytes memory data) private {
        // Check if the recipient is a contract
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                // Ensure the recipient contract returns the correct value
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    revert ERC721InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                // Handle the case where the recipient contract does not implement the interface correctly
                if (reason.length == 0) {
                    revert ERC721InvalidReceiver(to);
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    //---------------------------------------------------------------------------------------
    //-----------------------------VIEW FUNCTIONS--------------------------------------------
    //---------------------------------------------------------------------------------------

    /**
     * @notice Retrieves the details of a specific NFT by its token ID.
     * @param tokenId The ID of the NFT to retrieve.
     * @return The NFT struct containing details of the specified NFT.
     */
    function getNft(uint256 tokenId) public view returns (Nft memory) {
        // Iterate through the list of NFTs to find the one with the specified token ID
        for (uint256 i = 0; i < Nfts.length; ++i) {
            if (Nfts[i].tokenId == tokenId) {
                return Nfts[i];
            }
        }
        // Revert if the NFT with the specified token ID does not exist
        revert("Nft with the specified tokenId does not exist");
    }

    /**
     * @notice Retrieves the total supply of NFT tokens.
     * @return The total number of NFT tokens in existence.
     */
    function totalSupply() public view returns (uint256) {
        // Return the total number of NFTs, excluding the zero index
        return Nfts.length - 1;
    }

    /**
     * @notice Calculates the total value of all NFTs in supply.
     * @return totalValue The cumulative value of all NFTs.
     */
    function getNFTsSupplyTotalValue() external view returns (uint256 totalValue) {
        uint256 nftslength = Nfts.length;

        // Sum the values of all NFTs to get the total supply value
        for (uint256 i = 0; i < nftslength; ++i) {
            totalValue += Nfts[i].value;
        }
    }

    //---------------------------------------------------------------------------------------
    //-------------------------------STORAGE GETTERS-----------------------------------------
    //---------------------------------------------------------------------------------------

    function getTreasuryAddress() external view returns (address) {
        return treasury;
    }

    function getTonAddress() external view returns (address) {
        return ton;
    }

    function getWstonAddress() external view returns (address) {
        return wston;
    }
}