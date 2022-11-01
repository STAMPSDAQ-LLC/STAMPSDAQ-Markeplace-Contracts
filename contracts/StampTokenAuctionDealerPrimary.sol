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
contract StampTokenAuctionDealer is Ownable, Destructible {

    event stampListed(uint256 stampId, uint256 price, uint256 initialRate, uint256 step, string startDateTime, string endDateTime, address seller);
    event offerCompleted(uint256 stampId, uint256 price, address buyer);
    event bidRecieved(uint256 stampId, address payer, uint256 amount);
    event Canceled(uint256 stampId);

    StampToken public _nftAddress;
    mapping(uint256 => uint256) _sellingList;
    mapping(uint256 => uint256) _lastBids;
    mapping(uint256 => address payable) _lastBidders;
    mapping(uint256 => uint256) _bidSteps;
    mapping(uint256 => uint256) _initialRates;
    mapping(uint256 => bool) _started;
    mapping(uint256 => string) _startDatetimes;
    mapping(uint256 => string) _endDatetimes;
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
    function addToListing(uint256 tokenId, uint256 price, uint256 initialRate, uint256 step, string memory startDateTime, string memory endDateTime) public onlyValidator {
        require(price > 0, "Provide correct price");
        require(StampToken(_nftAddress).ownerOf(tokenId) == msg.sender, "This is not your token");
        require(StampToken(_nftAddress).getApproved(tokenId) == address(this), "Token is not approved");
        _sellingList[tokenId] = price;
        _lastBids[tokenId] = 0;
        _started[tokenId] = false;
        _bidSteps[tokenId] = step;
        _lastBidders[tokenId] = payable(0);
        _startDatetimes[tokenId] = startDateTime;
        _endDatetimes[tokenId] = endDateTime;
        _initialRates[tokenId] = initialRate;
        _tokenSellers[tokenId] = payable(msg.sender);
        emit stampListed(tokenId, price, initialRate, step, startDateTime, endDateTime, msg.sender);
    }

    /**
    * @dev Complete offer and buy token
    */
    function complete(uint256 tokenId) public payable {
        require(msg.sender != address(0) && msg.sender != address(this), "Something nasty!");
        require(_sellingList[tokenId] != 0, "Offer has not found");
        require(_started[tokenId] == true, "Auction is inactive");
        require(msg.value >= _sellingList[tokenId], "Too low value provided");
        require(StampToken(_nftAddress).getApproved(tokenId) == address(this), "Token is not approved");
        StampToken(_nftAddress).safeTransferFrom(_tokenSellers[tokenId], msg.sender, tokenId);
        uint256 rewardPoolDeposit = 0;
        rewardPoolDeposit = (_sellingList[tokenId]) * 2/10;
        _tokenSellers[tokenId].transfer(_sellingList[tokenId]);
        RewardPool(_rewardPool).fill{value:rewardPoolDeposit}();
        _addressSTAMPSDAQ.transfer(address(this).balance);
        _sellingList[tokenId] = 0;
        _tokenSellers[tokenId] = payable(0);
        emit offerCompleted(tokenId, msg.value, msg.sender);
    }
    /**
    * @dev Complete offer and buy token
    */
    function completeFiat(uint256 tokenId, address payable payer) public payable onlyValidator {
        require(msg.sender != address(0) && msg.sender != address(this), "Something nasty!");
        require(_started[tokenId] == true, "Auction is inactive");
        require(payer != address(0) && payer != address(this), "Something nasty!");
        require(_sellingList[tokenId] != 0, "Offer has not found");
        require(msg.value >= _sellingList[tokenId], "Too low value provided");
        require(StampToken(_nftAddress).getApproved(tokenId) == address(this), "Token is not approved");
        StampToken(_nftAddress).safeTransferFrom(_tokenSellers[tokenId], payer, tokenId);
        uint256 rewardPoolDeposit = 0;
        rewardPoolDeposit = (_sellingList[tokenId]) * 2/10;
        _tokenSellers[tokenId].transfer(_sellingList[tokenId]);
        RewardPool(_rewardPool).fill{value:rewardPoolDeposit}();
        _addressSTAMPSDAQ.transfer(address(this).balance);
        _sellingList[tokenId] = 0;
        _tokenSellers[tokenId] = payable(0);
        emit offerCompleted(tokenId, msg.value, payer);
    }
    /**
    * @dev Complete offer and buy token
    */
    function makeBid(uint256 tokenId) public payable {
        require(msg.sender != address(0) && msg.sender != address(this), "Something nasty!");
        require(_sellingList[tokenId] != 0, "Offer has not found");
        require(_started[tokenId] == true, "Auction is inactive");
        require(msg.sender != _lastBidders[tokenId], "Your bid is last already");
        require(StampToken(_nftAddress).ownerOf(tokenId) == _tokenSellers[tokenId], "Token owner was changed");
        require(StampToken(_nftAddress).getApproved(tokenId) == address(this), "Token owner has not approved token");
        if(_lastBids[tokenId] == 0) {
          if(msg.value == _initialRates[tokenId]) {
            _lastBids[tokenId] = msg.value;
            _lastBidders[tokenId] = payable(msg.sender);
          } else {
            require((msg.value >= _initialRates[tokenId]) && (msg.value < _sellingList[tokenId]) && ((msg.value - _initialRates[tokenId]) % _bidSteps[tokenId] == 0), "Wrong bid provided");
            _lastBids[tokenId] = msg.value;
            _lastBidders[tokenId] = payable(msg.sender);
          }
        } else {
          require((msg.value > _lastBids[tokenId]) && (msg.value < _sellingList[tokenId]) && ((msg.value - _lastBids[tokenId]) % _bidSteps[tokenId] == 0), "Wrong bid provided");
          _lastBidders[tokenId].transfer(_lastBids[tokenId]);
          _lastBids[tokenId] = msg.value;
          _lastBidders[tokenId] = payable(msg.sender);
        }
        emit bidRecieved(tokenId, msg.sender, msg.value);
    }
    /**
    * @dev Complete offer and buy token
    */
    function makeBidFiat(uint256 tokenId, address payable payer) public payable onlyValidator {
        require(msg.sender != address(0) && msg.sender != address(this), "Something nasty!");
        require(payer != address(0) && payer != address(this), "Something nasty!");
        require(_sellingList[tokenId] != 0, "Offer has not found");
        require(_started[tokenId] == true, "Auction is inactive");
        require(payer != _lastBidders[tokenId], "Your bid is last already");
        require(StampToken(_nftAddress).ownerOf(tokenId) == _tokenSellers[tokenId], "Token owner was changed");
        require(StampToken(_nftAddress).getApproved(tokenId) == address(this), "Token owner has not approved token");
        if(_lastBids[tokenId] == 0) {
          if(msg.value == _initialRates[tokenId]) {
            _lastBids[tokenId] = msg.value;
            _lastBidders[tokenId] = payable(payer);
          } else {
            require((msg.value >= _initialRates[tokenId]) && (msg.value < _sellingList[tokenId]) && ((msg.value - _initialRates[tokenId]) % _bidSteps[tokenId] == 0), "Wrong bid provided");
            _lastBids[tokenId] = msg.value;
            _lastBidders[tokenId] = payable(payer);
          }
        } else {
          require((msg.value > _lastBids[tokenId]) && (msg.value < _sellingList[tokenId]) && ((msg.value - _lastBids[tokenId]) % _bidSteps[tokenId] == 0), "Wrong bid provided");
          _lastBidders[tokenId].transfer(_lastBids[tokenId]);
          _lastBids[tokenId] = msg.value;
          _lastBidders[tokenId] = payable(payer);
        }
        emit bidRecieved(tokenId, payer, msg.value);
    }
    /**
    * @dev Get price to complete contract (including comissions)
    */
    function start(uint256 tokenId) public onlyValidator {
      require(StampToken(_nftAddress).ownerOf(tokenId) == _tokenSellers[tokenId], "Token owner was changed");
      require(StampToken(_nftAddress).getApproved(tokenId) == address(this), "Token owner has not approved token");
      _started[tokenId] = true;
    }
    /**
    * @dev Get price to complete contract (including comissions)
    */
    function stop(uint256 tokenId) public onlyValidator {
      _started[tokenId] = false;
      _sellingList[tokenId] = 0;
      _lastBids[tokenId] = 0;
      _lastBidders[tokenId] = payable(0);
      _tokenSellers[tokenId] = payable(0);
      if(_lastBids[tokenId] == 0) {
        emit Canceled(tokenId);
      }
      else {
        if(StampToken(_nftAddress).getApproved(tokenId) == address(this)) {
          StampToken(_nftAddress).safeTransferFrom(_tokenSellers[tokenId], _lastBidders[tokenId], tokenId);
          uint256 rewardPoolDeposit = 0;
          rewardPoolDeposit = (_lastBids[tokenId] * 333/10000) * 2/10 ;
          RewardPool(_rewardPool).fill{value:rewardPoolDeposit}();
          _tokenSellers[tokenId].transfer(_lastBids[tokenId] - rewardPoolDeposit);
          _sellingList[tokenId] = 0;
          _tokenSellers[tokenId] = payable(0);
          emit offerCompleted(tokenId, _lastBids[tokenId], msg.sender);
        }
        else {
          _lastBidders[tokenId].transfer(_lastBids[tokenId]);
          emit Canceled(tokenId);
        }
      }
    }
     /**
    * @dev Get price to complete contract (including comissions)
    */
    function cancel(uint256 tokenId) public onlyValidator {
      require(StampToken(_nftAddress).ownerOf(tokenId) == msg.sender, "This is not your token");
      require(_lastBids[tokenId] == 0, "Auction have bids!");
      _started[tokenId] = false;
      _sellingList[tokenId] = 0;
      _lastBids[tokenId] = 0;
      _lastBidders[tokenId] = payable(0);
      _tokenSellers[tokenId] = payable(0);
      emit Canceled(tokenId);
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