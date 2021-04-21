pragma solidity ^0.6.0;

interface IWhiteList{
    function isExist(address addr) external view returns(bool result);
}