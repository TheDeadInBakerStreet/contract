// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface IHTX{

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function issueTransfer(address recipient, uint256 amount) external returns (bool);

    function updateUserBalance(bool _flag, uint256 _rate ,uint256 _developerRate,uint256 _daoRate,uint256 _lpRate) external  returns(uint256, uint256);
}