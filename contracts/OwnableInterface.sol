// contracts/StampTokenSale.sol
// STAMPSDAQ
// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
import "./ValidatorsSTAMPSDAQ.sol";
/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
abstract contract Ownable {
  address payable public _owner;
  ValidatorsSTAMPSDAQ public constant _validator = ValidatorsSTAMPSDAQ(payable(0xEBf10249710358997B7f239BCc711dD96721B6C5));
  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() {
    _owner = payable(msg.sender);
  }
  /**
  * @dev Continues only if callee is contract creator
  */
  modifier onlyOwner() {
    require(msg.sender == _owner);
    _;
  }
  modifier onlyValidator() {
    require(_validator._validatorsList(msg.sender), "You not in validators list");
    _;
  }
}