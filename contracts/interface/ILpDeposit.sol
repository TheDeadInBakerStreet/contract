// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface ILpDeposit{
    function reward(uint256 amount) external;
     function setPairAddress(address _addr) external;
}