// contracts/StampTokenSale.sol
// STAMPSDAQ
// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./OwnableInterface.sol";
import {addressUtils} from "./Helpers.sol";
/**
 * @title Destructible
 * @dev Base contract that can be destroyed by owner. All funds in contract will be sent to the owner.
 */
abstract contract Destructible is Ownable {
  using addressUtils for address payable;
  constructor() payable {
  }
  /**
   * @dev Transfers the current balance to the owner and terminates the contract.
   */
  function destroy() onlyValidator public {
    require(_validator.getLegitimacy(address(this), "destroy", _owner.toString()), "Not enough validators voted for this");
    selfdestruct(_owner);
  }

  function destroyAndSend(address payable recipient) onlyValidator public {
    require(_validator.getLegitimacy(address(this), "destroy", recipient.toString()), "Not enough validators voted for this");
    selfdestruct(recipient);
  }
}