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
contract FlatPriceSale is Ownable, Destructible {

    event Sent(address indexed payee, uint256 amount, uint256 balance);
    event Completed(address indexed payer, uint tokenId, uint256 amount);

    StampToken public _nftAddress;
    uint256 public _price;
    uint256 public _startTokenId;
    uint256 public _endTokenId;
    uint256 public _tokenPointer;
    bool public _active;
    RewardPool public constant _rewardPool = RewardPool(payable(0x0A14f23754c6dFd10b2a91318c5082AD23AedC51));
    ComissionManager public constant _comissionManager = ComissionManager(payable(0x8fB73526ebC0754afca47476Ff0bfD30BA523A27));
    address payable public constant _addressSTAMPSDAQ = payable(0x23E81B8ac10C3f122353b514E3477f613cc10CA4);

    /**
    * @dev Contract Constructor
    * @param nftAddress address for STAMPSDAQ NFT contract address
    * @param price initial sales price
    */
    constructor(address nftAddress, uint256 price, uint256 startTokenId, uint256 endTokenId) {
        require(nftAddress != address(0) && nftAddress != address(this), "Insane address given");
        require(price > 0, "Provide correct price");
        _nftAddress = StampToken(nftAddress);
        _startTokenId = startTokenId;
        _tokenPointer = startTokenId;
        _endTokenId = endTokenId;
        _price = price;
        _active = true;
    }

    /**
    * @dev Complete offer and buy token
    */
    function complete() public payable {
        require(msg.sender != address(0) && msg.sender != address(this), "Something nasty!");
        require(_active != false, "Offer is not active");
        require(msg.value >= _price, "Too low value provided");
        require(StampToken(_nftAddress).getApproved(_tokenPointer) == address(this), "Token was not approved");
        StampToken(_nftAddress).safeTransferFrom(_addressSTAMPSDAQ, msg.sender, _tokenPointer);
        uint256 rewardPoolDeposit = 0;
        rewardPoolDeposit = msg.value * 2/10;
        RewardPool(_rewardPool).fill{value:rewardPoolDeposit}();
        _addressSTAMPSDAQ.transfer(msg.value - rewardPoolDeposit);
        if(_tokenPointer == _endTokenId) {
          _active = false;
        }
        _tokenPointer++;
        emit Completed(msg.sender, _tokenPointer-1, msg.value);
    }

    /**
    * @dev Complete offer and buy token
    */
    function completeFiat(address payable payer) public onlyValidator {
        require(msg.sender != address(0) && msg.sender != address(this), "Something nasty!");
        require(_active != false, "Offer is not active");
        require(StampToken(_nftAddress).getApproved(_tokenPointer) == address(this), "Token was not approved");
        StampToken(_nftAddress).safeTransferFrom(_addressSTAMPSDAQ, payer, _tokenPointer);
        if(_tokenPointer == _endTokenId) {
          _active = false;
        }
        _tokenPointer++;
        emit Completed(payer, _tokenPointer-1, _price);
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