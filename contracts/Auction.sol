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
contract Auction is Ownable, Destructible {

    event Sent(address indexed payee, uint256 amount, uint256 balance);
    event BidRecieved(address indexed payer, uint256 amount);
    event Completed(address indexed payer, uint tokenId, uint256 amount);
    event Canceled(uint tokenId);

    StampToken public _nftAddress;
    uint256 public _tokenId;
    address payable public _tokenOwner;
    bool public _completed;
    bool public _active;
    bool public _sideSales;
    uint256 public _initialRate;
    uint256 public _step;
    uint256 public _price;
    string public _startDateTime;
    string public _endDateTime;
    uint256 public _lastBid;
    address payable public _lastBidder;

    RewardPool public constant _rewardPool = RewardPool(payable(0x469C344d549aB1D7a3c384217e884d8Dc7Ce056C));
    ComissionManager public constant _comissionManager = ComissionManager(payable(0xd480738Aa28f202e31DE0F9A9Cf8AEBfE6Da5D29));
    address payable public constant _addressSTAMPSDAQ = payable(0x23E81B8ac10C3f122353b514E3477f613cc10CA4);

    /**
    * @dev Contract Constructor
    * @param nftAddress address for STAMPSDAQ NFT contract address
    * @param tokenId for sale
    * @param price initial sales price
    */
    constructor(address nftAddress, uint256 tokenId, uint256 price, uint256 initialRate, uint256 step, string memory startDateTime, string memory endDateTime) {
        require(nftAddress != address(0) && nftAddress != address(this), "Insane address given");
        require(StampToken(nftAddress).ownerOf(tokenId) == msg.sender, "This is not your token");
        require(price > 0, "Provide correct price");
        require(initialRate > 0 && initialRate < price, "Provide correct initial rate");
        require(step > 0 && step < price, "Provide correct bid step");
        _sideSales = (msg.sender != _addressSTAMPSDAQ);
        _tokenOwner = payable(msg.sender);
        _nftAddress = StampToken(nftAddress);
        _tokenId = tokenId;
        _price = price;
        _initialRate = initialRate;
        _step = step;
        _startDateTime = startDateTime;
        _endDateTime = endDateTime;
        _completed = false;
        _active = false;
        _lastBid = 0;
        _lastBidder = payable(0);
    }

    /**
    * @dev Complete offer and buy token
    */
    function complete() public payable {
        require(msg.sender != address(0) && msg.sender != address(this), "Something nasty!");
        require(_completed == false, "Offer alrady completed");
        require(_active == true, "Auction is inactive");
        uint256 endPrice = 0;
        if(_sideSales != true) {
          endPrice = _price;
        } else {
          endPrice = ComissionManager(_comissionManager).getComissionedPrice(msg.sender, _price);
        }
        require(msg.value >= endPrice, "Too low value provided");
        require(StampToken(_nftAddress).ownerOf(_tokenId) == _tokenOwner, "Token owner was changed");
        require(StampToken(_nftAddress).getApproved(_tokenId) == address(this), "Token owner has not approved token");
        if(_lastBid != 0) {
          _lastBidder.transfer(_lastBid);
        }
        _lastBid = msg.value;
        _lastBidder = payable(msg.sender);
        StampToken(_nftAddress).safeTransferFrom(_tokenOwner, msg.sender, _tokenId);
        uint256 rewardPoolDeposit = 0;
        if(_sideSales != true) {
          rewardPoolDeposit = endPrice * 2/10;
          RewardPool(_rewardPool).fill{value:rewardPoolDeposit}();
          _tokenOwner.transfer(address(this).balance);
        } else {
          rewardPoolDeposit = (endPrice - _price) * 2/10;
          _tokenOwner.transfer(_price);
          RewardPool(_rewardPool).fill{value:rewardPoolDeposit}();
          _addressSTAMPSDAQ.transfer(address(this).balance);
        }
        _completed = true;
        _active = false;
        emit Completed(msg.sender, _tokenId, msg.value);
    }
    /**
    * @dev Complete offer and buy token
    */
    function makeBid() public payable {
        require(msg.sender != address(0) && msg.sender != address(this), "Something nasty!");
        require(_completed == false, "Offer alrady completed");
        require(_active == true, "Auction is inactive");
        require(msg.sender != _lastBidder, "Your bit is last already");
        require(StampToken(_nftAddress).ownerOf(_tokenId) == _tokenOwner, "Token owner was changed");
        require(StampToken(_nftAddress).getApproved(_tokenId) == address(this), "Token owner has not approved token");
        if(_lastBid == 0) {
          if(msg.value == _initialRate) {
            _lastBid = msg.value;
            _lastBidder = payable(msg.sender);
          } else {
            require((msg.value >= _initialRate) && (msg.value < _price) && ((msg.value - _initialRate) % _step == 0), "Wrong bid provided");
            _lastBid = msg.value;
            _lastBidder = payable(msg.sender);
          }
        } else {
          require((msg.value > _lastBid) && (msg.value < _price) && ((msg.value - _lastBid) % _step == 0), "Wrong bid provided");
          _lastBidder.transfer(_lastBid);
          _lastBid = msg.value;
          _lastBidder = payable(msg.sender);
        }
        emit BidRecieved(msg.sender, msg.value);
    }
    /**
    * @dev Get price to complete contract (including comissions)
    */
    function start() public onlyValidator {
      require(StampToken(_nftAddress).ownerOf(_tokenId) == _tokenOwner, "Token owner was changed");
      require(StampToken(_nftAddress).getApproved(_tokenId) == address(this), "Token owner has not approved token");
      _active = true;
    }
    /**
    * @dev Get price to complete contract (including comissions)
    */
    function stop() public onlyValidator {
      _active = false;
      if(StampToken(_nftAddress).getApproved(_tokenId) == address(this)) {
        StampToken(_nftAddress).safeTransferFrom(_tokenOwner, _lastBidder, _tokenId);
        uint256 rewardPoolDeposit = 0;
        rewardPoolDeposit = _lastBid * 2/10;
        RewardPool(_rewardPool).fill{value:rewardPoolDeposit}();
        _tokenOwner.transfer(address(this).balance);
        _completed = true;
      }
    }
    /**
    * @dev Get price to complete contract (including comissions)
    */
    function cancel() public onlyOwner {
      require(_lastBid == 0, "Auction has bids");
      _active = false;
      selfdestruct(_owner);
    }
    /**
    * @dev Get price to complete contract (including comissions)
    */
    function getPayablePrice(address payable payer)
        public
        view
        returns (uint256) {
      return ComissionManager(_comissionManager).getComissionedPrice(payer, _price);
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