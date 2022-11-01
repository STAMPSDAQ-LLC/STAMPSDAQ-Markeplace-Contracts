// contracts/StampTokenSale.sol
// STAMPSDAQ
// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
import {addressUtils} from "./Helpers.sol";
/**
 * @title PaymentValidator
 * @dev __todo
 */
contract ValidatorsSTAMPSDAQ {
    mapping (address => bool) public _validatorsList;
    uint16 public _validatorsCount;
    mapping (address => mapping (string => mapping (string => mapping(address => bool)))) public _validatorsVoting; // contract[method][params][voter]
    mapping (address => mapping (string => mapping (string => uint16))) public _validatorsVotes; // contract[method][params][votes]
    using addressUtils for address;
    /**
    * @dev Continues only if callee is contract creator
    */
    modifier validatorsOnly() {
        require(_validatorsList[msg.sender] == true);
        _;
    }

    function getLegitimacy(address contractAddr, string memory method, string memory params) public view returns(bool) {
        if(((_validatorsVotes[contractAddr][method][params] * (10**5))/_validatorsCount) > 66665) {
            return true;
        } else {
            return false;
        }
    }
    /**
    * @dev Contract Constructor
    */
    constructor(address validator2, address validator3) {
        require(validator2 != address(0) && validator2 != address(this), "Insane address given");
        require(validator3 != address(0) && validator3 != address(this) && validator3 != validator2, "Insane address given");
        require(msg.sender != address(0) && msg.sender != address(this), "Something nasty!");
        _validatorsList[msg.sender] = true;
        _validatorsList[validator2] = true;
        _validatorsList[validator3] = true;
        _validatorsCount = 3;
    }

    function voteFor(address contractAddr, string memory method, string memory params) validatorsOnly public{
        require(_validatorsVoting[contractAddr][method][params][msg.sender] == false, "You voted already");
        _validatorsVotes[contractAddr][method][params]++;
        _validatorsVoting[contractAddr][method][params][msg.sender] = true;
    }

    function addValidator(address validatorAddress) validatorsOnly public{
        require(getLegitimacy(address(this), "addValidator", validatorAddress.toString()), "Not enough validators voted for this");
        _validatorsList[validatorAddress] = true;
        _validatorsCount++;
    }
    /**
    * @dev Fallback features
    */
    receive() external payable {
        require(false, "This contract not operates with funds!");
    }

    fallback() external payable {
        require(false, "This contract not operates with funds!");
    }
}