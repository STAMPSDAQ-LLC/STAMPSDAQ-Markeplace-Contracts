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
contract PackDropSale is Ownable, Destructible {

    event Completed(address indexed payer, uint256[] givenTokens, uint256 amount);

    StampToken public _nftAddress;
    uint256 public _basePrice;
    uint256 public _startTokenId;
    uint8 public _packSize;
    uint32 public _stampsAmount;
    uint256 public _actualPrice;
    uint256[] public _nftList;
    mapping (uint256 => bool) public _uniqueList;
    bool public _active;
    RewardPool public constant _rewardPool = RewardPool(payable(0x469C344d549aB1D7a3c384217e884d8Dc7Ce056C));
    ComissionManager public constant _comissionManager = ComissionManager(payable(0xd480738Aa28f202e31DE0F9A9Cf8AEBfE6Da5D29));
    address payable public constant _addressSTAMPSDAQ = payable(0x23E81B8ac10C3f122353b514E3477f613cc10CA4);

    /**
    * @dev Contract Constructor
    * @param nftAddress address for STAMPSDAQ NFT contract address
    */
    constructor(address nftAddress, uint256 startTokenId, uint256 basePrice, uint8 packSize, uint32 stampsAmount) {
        require(nftAddress != address(0) && nftAddress != address(this), "Insane address given");
        _nftAddress = StampToken(nftAddress);
        _packSize = packSize;
        _startTokenId = startTokenId;
        _basePrice = basePrice;
        _actualPrice = basePrice;
        _stampsAmount = stampsAmount;
        _active = false;
    }
    /**
    * @dev Contract Constructor
    */
    function fillList(uint amount) public onlyValidator {
      require(_nftList.length < _stampsAmount, "Package list already filled!");
      require(_nftList.length + amount <= _stampsAmount, "Too big value provided");
      require(!_active, "Sale already active!");
      for(uint i = 0; i < amount; i ++) {
        _nftList.push(_startTokenId + _nftList.length);
      }
    }
     /**
    * @dev Contract Constructor
    */
    function random() private view returns (uint) {
        // sha3 and now have been deprecated
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, _nftList.length)));
        // convert hash to integer
        // players is an array of entrants    
    }
    /**
    * @dev Contract Constructor
    */
    function getRandomStamp() private returns (uint256) {
        uint256 selectedStamp = 0;
        if(_nftList.length == 1) {
          selectedStamp = _nftList[0];
          _nftList.pop();
        } else if (_nftList.length > 1) {
          uint256 index = random() % _nftList.length - 1;
          selectedStamp = _nftList[index];
          _nftList[index] = _nftList[_nftList.length -1];
          _nftList.pop();
        }
        return selectedStamp;
    }
     /**
    * @dev Contract Constructor
    */
    function fillUiniqueList(uint256[] memory ids) public onlyValidator {
      require(_nftList.length == _stampsAmount, "Package list not filled");
      require(!_active, "Sale already active!");
      for(uint i = 0; i < ids.length; i ++) {
        _uniqueList[ids[i]] = true;
      }
      _active = true;
    }

    // /**
    // * @dev Complete offer and buy token
    // */
    function complete() public payable {
        require(msg.sender != address(0) && msg.sender != address(this), "Something nasty!");
        require(_active, "Offer inactive");
        require(msg.value >= _actualPrice, "Too low value provided");
        uint256[] memory givenStamps = new uint256[](_packSize);
        for(uint i = 0; i < _packSize; i++) {
          givenStamps[i] = getRandomStamp();
          require(StampToken(_nftAddress).ownerOf(givenStamps[i]) == address(this), "Token owner was changed");
          StampToken(_nftAddress).safeTransferFrom(address(this), msg.sender, givenStamps[i]);
          if(_uniqueList[givenStamps[i]]) {
            _actualPrice = _actualPrice - 1000000000000000000;
          }
        }
        uint256 rewardPoolDeposit = _actualPrice * 2/10;
        RewardPool(_rewardPool).fill{value:rewardPoolDeposit}();
        _addressSTAMPSDAQ.transfer(address(this).balance);
        emit Completed(msg.sender, givenStamps, msg.value);
    } 
    // /**
    // * @dev Complete offer and buy token
    // */
    function completeFiat(address payable payer) public onlyValidator {
        require(payer != address(0) && payer != address(this), "Something nasty!");
        require(_active, "Offer inactive");
        uint256[] memory givenStamps = new uint256[](_packSize);
        for(uint i = 0; i < _packSize; i++) {
          givenStamps[i] = getRandomStamp();
          require(StampToken(_nftAddress).ownerOf(givenStamps[i]) == address(this), "Token owner was changed");
          StampToken(_nftAddress).safeTransferFrom(address(this), payer, givenStamps[i]);
          if(_uniqueList[givenStamps[i]]) {
            _actualPrice = _actualPrice - 1000000000000000000;
          }
        }
        emit Completed(payer, givenStamps, _actualPrice);
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