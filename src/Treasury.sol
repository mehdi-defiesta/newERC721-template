// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { INFTFactory } from "./interfaces/INFTFactory.sol"; 
import { NFTFactoryStorage } from "./NFTFactoryStorage.sol";
import { AuthControl } from "./common/AuthControl.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { TreasuryStorage } from "./TreasuryStorage.sol"; 
import "./proxy/ProxyStorage.sol";

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


interface IMarketPlace {
    function putNFTListForSale(uint256[] memory tokenIds, uint256[] memory prices) external;
    function putNFTForSale(uint256 _tokenId, uint256 _price) external;
    function buyNFT(uint256 _tokenId, bool _paymentMethod) external;
    function removeNFTForSale(uint256 _tokenId) external;
}

interface IWstonSwapPool {
    function swapTONforWSTON(uint256 tonAmount) external;
}

/**
 * @title Treasury Contract for Token ManaNFTent
 * @author TOKAMAK OPAL TEAM
 * @notice This contract manages the storage and transfer of NFT tokens and WSTON tokens within the ecosystem.
 * It facilitates interactions with the NFTFactory, Marketplace, Random Pack, and Airdrop contracts.
 * The contract includes functionalities for creating premined NFTs, handling token transfers, and managing sales on the marketplace.
 * @dev The contract integrates with external interfaces for NFT creation, marketplace operations, and token swaps.
 * It includes security features such as pausing operations and role-based access control.
 */
contract Treasury is ProxyStorage, IERC721Receiver, ReentrancyGuard, AuthControl, TreasuryStorage {
    using SafeERC20 for IERC20;

    modifier whenNotPaused() {
      require(!paused, "Pausable: paused");
      _;
    }


    modifier whenPaused() {
        require(paused, "Pausable: not paused");
        _;
    }

    modifier onlyWstonSwapPoolOrOwner() {
        require(msg.sender == wstonSwapPool ||
        isOwner(), "caller is not the Swapper");
        _;
    }

    function pause() public onlyOwner whenNotPaused {
        paused = true;
    }

    function unpause() public onlyOwner whenPaused {
        paused = false;
    }

    //---------------------------------------------------------------------------------------
    //--------------------------------INITIALIZE FUNCTIONS-----------------------------------
    //---------------------------------------------------------------------------------------

    /**
     * @notice Initializes the Treasury contract with the given parameters.
     * @param _wston Address of the WSTON token.
     * @param _ton Address of the TON token.
     * @param _nftFactory Address of the NFT factory contract.
     */
    function initialize(address _wston, address _ton, address _nftFactory) external {
        require(!initialized, "already initialized");   
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        nftFactory = _nftFactory;
        wston = _wston;
        ton = _ton;
        initialized = true;
    }

     /**
     * @notice Sets the address of the NFT factory.
     * @param _nftFactory New address of the NFT factory contract.
     */
    function setNftFactory(address _nftFactory) external onlyOwnerOrAdmin {
        _checkNonAddress(nftFactory);
        nftFactory = _nftFactory;
    }

    /**
     * @notice Sets the address of the WSTON swap pool.
     * @param _wstonSwapPool New address of the WSTON swap pool.
     */
    function setWstonSwapPool(address _wstonSwapPool) external onlyOwnerOrAdmin {
        _checkNonAddress(_wstonSwapPool);
        wstonSwapPool = _wstonSwapPool;
    }

    /**
     * @notice updates the wston token address
     * @param _wston New wston token address
     */
    function setWston(address _wston) external onlyOwner {
        wston = _wston;
    }

    /**
     * @notice updates the ton token address
     * @param _ton New ton token address
     */
    function setTon(address _ton) external onlyOwner {
        ton = _ton;
    }

    /**
     * @notice Approves the WSTON swap pool to spend TON tokens.
     */
    function tonApproveWstonSwapPool(uint256 _amount) external onlyWstonSwapPoolOrOwner returns(bool) {
        _checkNonAddress(ton);
        IERC20(ton).approve(wstonSwapPool, _amount);
        return true;
    }

    /**
     * @notice Approves a specific operator to manage a NFT token.
     * @param operator Address of the operator.
     * @param _tokenId ID of the token to approve.
     */
    function approveNFT(address operator, uint256 _tokenId) external onlyOwnerOrAdmin {
        INFTFactory(nftFactory).approve(operator, _tokenId);
    }

    //---------------------------------------------------------------------------------------
    //--------------------------------EXTERNAL FUNCTIONS-------------------------------------
    //---------------------------------------------------------------------------------------

    /**
     * @notice Transfers WSTON tokens to a specified address.
     * @param _to Address to transfer WSTON tokens to.
     * @param _amount Amount of WSTON tokens to transfer.
     * @dev only the NFTFactory, MarketPlace, RandomPack, Airdrop or the Owner are authorized to transfer the funds
     * @return bool Returns true if the transfer is successful.
     */
    function transferWSTON(address _to, uint256 _amount) external onlyOwner nonReentrant returns(bool) {
        // check _to diffrent from address(0)
        _checkNonAddress(_to);

        // check the balance of the treasury
        uint256 contractWSTONBalance = getWSTONBalance();
        if(contractWSTONBalance < _amount) {
            revert UnsuffiscientWstonBalance();
        }

        // transfer to the recipient
        IERC20(wston).safeTransfer(_to, _amount);
        return true;
    }

    /**
     * @notice Transfers TON tokens to a specified address.
     * @param _to Address to transfer TON tokens to.
     * @param _amount Amount of TON tokens to transfer.
     * @dev only the owner or the admins are authorized to call the function
     * @return bool Returns true if the transfer is successful.
     */
    function transferTON(address _to, uint256 _amount) external onlyOwnerOrAdmin returns(bool) {
        // check _to diffrent from address(0)
        _checkNonAddress(_to);

        // check the balance of the treasury 
        uint256 contractTONBalance = getTONBalance();
        if(contractTONBalance < _amount) {
            revert UnsuffiscientTonBalance();
        }

        // transfer to the recipient
        IERC20(ton).safeTransfer(_to, _amount);
        return true;
    }

    /**
     * @notice Creates a premined NFT with specified attributes.
     * @param _value value of WSTON associated with the NFT.
     * @dev the contract must hold enough WSTON to cover the entire supply of NFTs across all owners
     * @return uint256 Returns the ID of the created NFT.
     */
    function createPreminedNFT( 
        uint256 _value,
        string memory _tokenURI
    ) external onlyOwner returns (uint256) {
        // safety check for WSTON solvency
        if(getWSTONBalance() < INFTFactory(nftFactory).getNFTsSupplyTotalValue() + _value) {
            revert NotEnoughWstonAvailableInTreasury();
        }

        // we create the NFT from the NFTFactory
        return INFTFactory(nftFactory).createNFT(
            _value,
            _tokenURI
        );
    }

    /**
     * @notice Creates a pool of premined NFTs with specified attributes.
     * @param _values Array of WSTON values associated with each NFT to be created.
     * @dev the contract must hold enough WSTON to cover the entire supply of NFTs across all owners
     * @return uint256[] Returns an array of IDs for the created NFTs.
     */
    function createPreminedNFTPool(
        uint256[] memory _values,
        string[] memory _tokenURIs
    ) public onlyOwner returns (uint256[] memory) {

        //calculate the value of the pool of NFTs to be created
        uint256 sumOfNewPoolValues;
        for (uint256 i = 0; i < _values.length; ++i) {
            sumOfNewPoolValues += _values[i];
        }

        // add the value calculated to the total supply value and check that the treasury balance holds enough WSTON
        if(getWSTONBalance() < INFTFactory(nftFactory).getNFTsSupplyTotalValue() + sumOfNewPoolValues) {
            revert NotEnoughWstonAvailableInTreasury();
        }

        // we create the pool from the NFTFactory
        return INFTFactory(nftFactory).createNFTPool(
            _values,
            _tokenURIs
        );
    }

    /**
     * @notice Transfers a NFT from the treasury to a specified address.
     * @param _to Address to transfer the NFT to.
     * @param _tokenId ID of the NFT token to transfer.
     * @dev only the NFTFactory, MarketPlace, RandomPack, Airdrop or the Owner are able to transfer NFTs from the treasury
     * @return bool Returns true if the transfer is successful.
     */
    function transferTreasuryNFTto(address _to, uint256 _tokenId) external onlyOwner returns(bool) {
        INFTFactory(nftFactory).transferFrom(address(this), _to, _tokenId);
        return true;
    }

    /**
     * @notice Handles the receipt of an ERC721 token.
     * @return bytes4 Returns the selector of the onERC721Received function.
     */
    function onERC721Received(
        address /*operator*/,
        address /*from*/,
        uint256 /*tokenId*/,
        bytes calldata /*data*/
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    //---------------------------------------------------------------------------------------
    //--------------------------------INTERNAL FUNCTIONS-------------------------------------
    //---------------------------------------------------------------------------------------

    /**
     * @notice Checks if the provided address is a non-zero address.
     * @param account Address to check.
     */
    function _checkNonAddress(address account) internal pure {
        if(account == address(0))   revert InvalidAddress();
    }

    //---------------------------------------------------------------------------------------
    //------------------------STORAGE GETTER / VIEW FUNCTIONS--------------------------------
    //---------------------------------------------------------------------------------------

    // Function to check the balance of TON token within the contract
    function getTONBalance() public view returns (uint256) {
        return IERC20(ton).balanceOf(address(this));
    }

    // Function to check the balance of WSTON token within the contract
    function getWSTONBalance() public view returns (uint256) {
        return IERC20(wston).balanceOf(address(this));
    }

    function getNFTFactoryAddress() external view returns (address) {return nftFactory;}
    function getTonAddress() external view returns(address) {return ton;}
    function getWstonAddress() external view returns(address) {return wston;}
    function getSwapPoolAddress() external view returns(address) {return wstonSwapPool;}

}