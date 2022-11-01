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
contract StampTokenOfferDealer is Ownable, Destructible {

    event offerPlaced(address sender, address recipient, uint256[] myStamps, uint256[] yourStamps, uint256 moneyDiff, bool payeer);
    event offerCompleted(address offerer, address offered);
    event offerCancelled(address offerer, address offered);

    StampToken public _nftAddress;
    mapping(address => mapping(address => bool)) _offerersList;
    mapping(address => mapping(address => uint256[])) _offeredList;
    mapping(address => mapping(address => uint256[])) _offeringList;
    mapping(address => mapping(address => uint256)) _diffList;
    mapping(address => mapping(address => bool)) _payeerList;
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

    function makeOffer(address payable recipient, uint256[] memory myStamps, uint256[] memory yourStamps, uint256 moneyDiff, bool payeer) public payable{
        require(recipient != address(0) && recipient != address(this), "Something nasty!");
        require(_offerersList[msg.sender][recipient] != true, "You have active offer!");
        if(moneyDiff > 0 && payeer) {
            require(msg.value >= moneyDiff, "Too low value provided");
        }
        for(uint i = 0; i < myStamps.length; i++) {
            require(StampToken(_nftAddress).getApproved(myStamps[i]) == address(this), "Token is not approved");
        }
        _offerersList[msg.sender][recipient] = true;
        _offeredList[msg.sender][recipient] = myStamps;
        _offeringList[msg.sender][recipient] = yourStamps;
        _diffList[msg.sender][recipient] = moneyDiff;
        _payeerList[msg.sender][recipient] = payeer;
        emit offerPlaced(msg.sender, recipient, myStamps, yourStamps, moneyDiff, payeer);
    }

    /**
    * @dev Complete offer and buy token
    */
    function complete(address payable offerer) public payable{
        require(offerer != address(0) && offerer != address(this), "Something nasty!");
        require(_offerersList[offerer][msg.sender] == true, "There is no offer like this");
        if(_diffList[offerer][msg.sender] > 0 && !_payeerList[offerer][msg.sender]) {
            require(msg.value >= _diffList[offerer][msg.sender], "Too low value provided");
        }
        for(uint i = 0; i < _offeringList[offerer][msg.sender].length; i++) {
            require(StampToken(_nftAddress).getApproved(_offeringList[offerer][msg.sender][i]) == address(this), "Token is not approved");
        }
        for(uint i = 0; i < _offeringList[offerer][msg.sender].length; i++) {
            StampToken(_nftAddress).safeTransferFrom(msg.sender, offerer, _offeringList[offerer][msg.sender][i]);
        }
        for(uint i = 0; i < _offeredList[offerer][msg.sender].length; i++) {
            StampToken(_nftAddress).safeTransferFrom(offerer, msg.sender, _offeredList[offerer][msg.sender][i]);
        }
        if(_diffList[offerer][msg.sender] > 0 && !_payeerList[offerer][msg.sender]) {
            offerer.transfer(_diffList[offerer][msg.sender]);
        }
        if(_diffList[offerer][msg.sender] > 0 && _payeerList[offerer][msg.sender]) {
            payable(msg.sender).transfer(_diffList[offerer][msg.sender]);
        }
        _offerersList[offerer][msg.sender] = false;
        emit offerCompleted(offerer, msg.sender);
    }

    /**
    * @dev Complete offer and buy token
    */
    function reject(address payable offerer) public{
        require(offerer != address(0) && offerer != address(this), "Something nasty!");
        require(_offerersList[offerer][msg.sender] == true, "There is no offer like this");
        _offerersList[offerer][msg.sender] = false;
        if(_diffList[offerer][msg.sender] > 0 && _payeerList[offerer][msg.sender]) {
            offerer.transfer(_diffList[offerer][msg.sender]);
        }
        emit offerCancelled(offerer, msg.sender);
    }
    /**
    * @dev Complete offer and buy token
    */
    function cancel(address payable recipient) public {
        require(recipient != address(0) && recipient != address(this), "Something nasty!");
        require(_offerersList[msg.sender][recipient] == true, "There is no offer like this");
        _offerersList[msg.sender][recipient] = false;
        if(_diffList[msg.sender][recipient] > 0 && _payeerList[msg.sender][recipient]) {
            payable(msg.sender).transfer(_diffList[msg.sender][recipient]);
        }
        emit offerCancelled( msg.sender, recipient);
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