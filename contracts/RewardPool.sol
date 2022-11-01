// contracts/StampTokenSale.sol
// STAMPSDAQ
// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./DestructibleInterface.sol";
import {stringUtils} from "./Helpers.sol";

/**
 * @title RewardPool
 * RewardPool - contract for accepting ang managing contest funds
 */
contract RewardPool is Ownable, Destructible {

    event Sent(address indexed payee, string payoutType, uint256 amount, uint256 balance);
    event Received(address indexed payer, uint256 amount, uint256 balance);
    uint256 public _collectorPool;
    uint256 public _traderPool;
    uint256 public _nftPool;
    uint256 public _triviaPool;
    uint256 public constant _payoutTresholdTotalNeeded = 100000000000000000000000;
    string public constant _payoutTypeCollector = "collector";
    string public constant _payoutTypeTrader = "trader";
    string public constant _payoutTypeNFT = "nft";
    string public constant _payoutTypeTrivia = "trivia";
    bool public _filled;
    using stringUtils for string;
    /**
    * @dev Contract Constructor
    */
    constructor() {
        _collectorPool = 0;
        _traderPool = 0;
        _nftPool = 0;
        _triviaPool = 0;
        _filled = false;
    }

    /**
    * @dev function to recieve and distrivute revard pool balance
    */
    function fill() external payable {
        require(msg.value >= 0, "You need send founds");
        require(msg.sender != address(0) && msg.sender != address(this), "Something nasty!");
        uint256 base25Percent = msg.value/4;
        _collectorPool = _collectorPool + base25Percent;
        _traderPool = _traderPool + base25Percent;
        _nftPool = _nftPool + base25Percent;
        _triviaPool = msg.value - (base25Percent * 3);
        if(address(this).balance >= _payoutTresholdTotalNeeded) {
            _filled = true;
        }
        emit Received(msg.sender, msg.value, address(this).balance);
    }

    /**
    * @dev function for sending rewards
    */
    function payReward(address payable payee, string memory payoutType, uint256 amount) external onlyValidator {
        require(payee != address(0) && payee != address(this), "Insane addresses given");
        require(_filled, "Pool is not ready to pay");
        if(payoutType.compare(_payoutTypeCollector)) {
            require(_collectorPool >= amount, "Not enough funds!");
            _collectorPool = _collectorPool - amount;
            payee.transfer(amount);
            emit Sent(payee, _payoutTypeCollector, amount, address(this).balance);

        } else if (payoutType.compare( _payoutTypeTrader)) {
            require(_traderPool >= amount, "Not enough funds!");
            _traderPool = _traderPool - amount;
            payee.transfer(amount);
            emit Sent(payee, _payoutTypeTrader, amount, address(this).balance);
        } else if (payoutType.compare( _payoutTypeNFT)) {
            require(_nftPool >= amount, "Not enough funds!");
            _nftPool = _nftPool - amount;
            payee.transfer(amount);
            emit Sent(payee, _payoutTypeNFT, amount, address(this).balance);
        } else {
            require(_triviaPool >= amount, "Not enough funds!");
            _triviaPool = _triviaPool - amount;
            payee.transfer(amount);
            emit Sent(payee, _payoutTypeTrivia, amount, address(this).balance);
        }
    }
    /**
    * @dev Fallback features
    */
    receive() external payable {
        require(false, "Use fill method");
    }

    fallback() external payable {
        require(false, "Use fill method");
    }
}