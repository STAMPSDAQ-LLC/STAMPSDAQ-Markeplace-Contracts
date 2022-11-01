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
contract StampTokenBuyDealer is Ownable, Destructible {

    event buyOfferPlaced(uint256 profileId, uint256 price, uint8 step, uint256 id, address buyer);
    event sellOfferPlaced(uint256 tokenId, uint256 price, uint8 step, address seller);
    event buyCancelled(uint256 profileId, address buyer);
    event sellCancelled(uint256 stampId, address seller);
    event sellCompleted(uint256 stampId, uint256 price, address seller);
    event buyCompleted(uint256 profileId, uint256 stampId, uint256 price, address buyer);

    StampToken public _nftAddress;
    mapping(uint256 => address) _sellingList;
    mapping(uint256 => address) _buyersList;
    mapping(uint256 => uint256) _buyingList;
    mapping(address => mapping ( uint256 => uint256)) _buyingPriceList;
    mapping(address => mapping ( uint256 => uint8)) _buyingStepList;
    mapping(uint256 => uint256) _priceList;
    mapping(uint256 => uint8) _stepList;
    uint256 _buyingCounter;
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
        _buyingCounter = 10000000000000000000023;
    }

    function createSellOffer(uint256 tokenId, uint256 price, uint8 step) public {
        require(price > 0, "Provide correct price");
        require(StampToken(_nftAddress).getApproved(tokenId) == address(this), "Token is not approved");
        _sellingList[tokenId] = msg.sender;
        _priceList[tokenId] = price;
        _stepList[tokenId] = step;
        emit sellOfferPlaced(tokenId, price, step, msg.sender);
    }

     function createBuyOffer(uint256 profileId, uint256 price, uint8 step) public payable {
        require(price > 0, "Provide correct price");
        require(msg.value >= price + (price * step)/100, "Please, send maximum deal value");
        _buyingPriceList[msg.sender][profileId] = price;
        _buyingStepList[msg.sender][profileId] = step;
        _buyersList[_buyingCounter] = msg.sender;
        _buyingList[_buyingCounter] = profileId;
        _buyingCounter++;
        emit buyOfferPlaced(profileId, price, step, _buyingCounter - 1, msg.sender);
    }
    /**
    * @dev Complete offer and buy token
    */
    function getFlexPrice(uint256 price, uint8 step, uint256 value) private pure returns(uint256) {
        uint256 minTradePrice = price - ((price * step)/100);
        uint256 maxTradePrice = price + ((price * step)/100);
        if (value < minTradePrice) {
            return 0;
        }
        if (value > maxTradePrice) {
            return maxTradePrice;
        } else {
            return minTradePrice + ((value - minTradePrice) / 2);
        }
    }

    function complete(uint256 dealId) public payable {
        require(_sellingList[dealId] != address(0), "No such offer");
        require(StampToken(_nftAddress).getApproved(dealId) == address(this), "Token is not approved");
        uint256 toPay = getFlexPrice(_priceList[dealId], _stepList[dealId], msg.value);
        require(toPay > 0, "Wrong value for deal");
        StampToken(_nftAddress).safeTransferFrom(_sellingList[dealId], msg.sender, dealId);
        payable(_sellingList[dealId]).transfer(toPay);
        payable(msg.sender).transfer(msg.value - toPay);
        emit sellCompleted(dealId, toPay, _sellingList[dealId]);
        _sellingList[dealId] = address(0);
    }

    function complete(uint256 dealId, uint256 stamp, uint256 maxPrice) public payable {
        require(_buyersList[dealId] != address(0), "No such offer");
        require(StampToken(_nftAddress).getApproved(stamp) == address(this), "Token is not approved");
        uint256 toPay = getFlexPrice(_buyingPriceList[_buyersList[dealId]][_buyingList[dealId]], _buyingStepList[_buyersList[dealId]][_buyingList[dealId]], maxPrice);
        require(toPay > 0, "Wrong value for deal");
        StampToken(_nftAddress).safeTransferFrom(msg.sender, _buyersList[dealId], stamp);
        payable(msg.sender).transfer(toPay);
        payable(_buyersList[dealId]).transfer((_buyingPriceList[_buyersList[dealId]][_buyingList[dealId]] + ((_buyingPriceList[_buyersList[dealId]][_buyingList[dealId]]*_buyingStepList[_buyersList[dealId]][_buyingList[dealId]])/100)) - toPay);
         emit buyCompleted(_buyingList[dealId], stamp,  toPay, _sellingList[dealId]);
        _buyersList[dealId] = address(0);
    }
    /**
    * @dev Get price to complete contract (including comissions)
    */
    function cancelSell(uint256 stampId) public {
      require(_sellingList[stampId] == msg.sender, "Not your deal");
      _sellingList[stampId] = address(0);
      emit sellCancelled(stampId, msg.sender);
    }
     function cancelBuy(uint256 dealId) public {
      require(_buyersList[dealId] == msg.sender, "Not your deal");
      payable(msg.sender).transfer(_buyingPriceList[_buyersList[dealId]][_buyingList[dealId]]);
      _buyersList[dealId] = address(0);
      emit buyCancelled(_buyingList[_buyingCounter], msg.sender);
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