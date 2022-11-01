// contracts/StampTokenSale.sol
// STAMPSDAQ
// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./DestructibleInterface.sol";
import "./StampToken.sol";
import "./RewardPool.sol";
import "./ComissionManager.sol";


/**
 * @title StampTokenSale
 * StampTokenSale - a sales contract for saling STAMPSDAQ non-fungible tokens
 */
contract StampTokenDealer is Ownable, Destructible {

    event stampListed(uint256 stampId, uint256 price, address seller);
    event offerCompleted(uint256 stampId, uint256 price, address buyer);
    event Canceled(uint256 stampId);

    StampToken public _nftAddress;
    mapping(uint256 => uint256) _sellingList;
    mapping(uint256 => address payable) _tokenSellers;
    RewardPool public constant _rewardPool = RewardPool(payable(0x469C344d549aB1D7a3c384217e884d8Dc7Ce056C));
    ComissionManager public constant _comissionManager = ComissionManager(payable(0xd480738Aa28f202e31DE0F9A9Cf8AEBfE6Da5D29));
    address payable public constant _addressSTAMPSDAQ = payable(0x23E81B8ac10C3f122353b514E3477f613cc10CA4);

    /**
    * @dev Contract Constructor
    * @param nftAddress address for STAMPSDAQ NFT contract address
    */
    constructor(address nftAddress) {
        require(nftAddress != address(0) && nftAddress != address(this), "Insane address given");
        _nftAddress = StampToken(nftAddress);
    }
    function addToListing(uint256 tokenId, uint256 price) public {
        require(price > 0, "Provide correct price");
        require(StampToken(_nftAddress).ownerOf(tokenId) == msg.sender, "This is not your token");
        require(StampToken(_nftAddress).getApproved(tokenId) == address(this), "Token is not approved");
        _sellingList[tokenId] = price;
        _tokenSellers[tokenId] = payable(msg.sender);
        emit stampListed(tokenId, price, msg.sender);
    }

    /**
    * @dev Complete offer and buy token
    */
    function complete(uint256 tokenId) public payable {
        require(msg.sender != address(0) && msg.sender != address(this), "Something nasty!");
        require(_sellingList[tokenId] != 0, "Offer has not found");
        uint256 endPrice = 0;
        endPrice = ComissionManager(_comissionManager).getComissionedPrice(msg.sender, _sellingList[tokenId]);
        require(msg.value >= endPrice, "Too low value provided");
        require(StampToken(_nftAddress).getApproved(tokenId) == address(this), "Token is not approved");
        StampToken(_nftAddress).safeTransferFrom(_tokenSellers[tokenId], msg.sender, tokenId);
        uint256 rewardPoolDeposit = 0;
        rewardPoolDeposit = (endPrice - _sellingList[tokenId]) * 2/10;
        _tokenSellers[tokenId].transfer(_sellingList[tokenId]);
        RewardPool(_rewardPool).fill{value:rewardPoolDeposit}();
        _addressSTAMPSDAQ.transfer(address(this).balance);
        _sellingList[tokenId] = 0;
        _tokenSellers[tokenId] = payable(0);
        emit offerCompleted(tokenId, msg.value,  msg.sender);
    }
     /**
    * @dev Complete offer and buy token
    */
    function completeFiat(uint256 tokenId, address payable payer) public payable onlyValidator {
        require(payer != address(0) && payer != address(this), "Something nasty!");
        require(_sellingList[tokenId] != 0, "Offer has not found");
        uint256 endPrice = 0;
        endPrice = ComissionManager(_comissionManager).getComissionedPrice(payer, _sellingList[tokenId]);
        require(msg.value >= endPrice, "Too low value provided");
        require(StampToken(_nftAddress).getApproved(tokenId) == address(this), "Token is not approved");
        StampToken(_nftAddress).safeTransferFrom(_tokenSellers[tokenId], payer, tokenId);
        uint256 rewardPoolDeposit = 0;
        rewardPoolDeposit = (endPrice - _sellingList[tokenId]) * 2/10;
        _tokenSellers[tokenId].transfer(_sellingList[tokenId]);
        RewardPool(_rewardPool).fill{value:rewardPoolDeposit}();
        _addressSTAMPSDAQ.transfer(address(this).balance);
        _sellingList[tokenId] = 0;
        _tokenSellers[tokenId] = payable(0);
        emit offerCompleted(tokenId, msg.value,  payer);
    }
     /**
    * @dev Get price to complete contract (including comissions)
    */
    function cancel(uint256 tokenId) public {
      require(StampToken(_nftAddress).ownerOf(tokenId) == msg.sender, "This is not your token");
      require(_sellingList[tokenId] != 0, "Offer has not found");
      _sellingList[tokenId] = 0;
      _tokenSellers[tokenId] = payable(0);
      emit Canceled(tokenId);
    }
    /**
    * @dev Get price to complete contract (including comissions)
    */
    function getPayablePrice(address payable payer, uint256 tokenId)
        public
        view
        returns (uint256) {
      return ComissionManager(_comissionManager).getComissionedPrice(payer, _sellingList[tokenId]);
    }
    /**
    * @dev Fallback features
    */
    receive() external payable {
        require(false, "Use complete method");
    }

    fallback() external payable {
        require(false, "Use complete method");
    }
}