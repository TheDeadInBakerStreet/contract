pragma solidity ^0.6.0;

import "./interface/IPancakePair.sol";

contract PriceFromPancakeSwap{
    address owner;
    mapping(address => IPancakePair) pancakePairMapping;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner(){
        require(owner == msg.sender,"require owner");
        _;
    }

    function setPancakePair(address addr) external onlyOwner{
        pancakePairMapping[addr]  = IPancakePair(addr);
    }

    function getReserves(address addr) external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast){
        return pancakePairMapping[addr].getReserves();
    }

    function balanceOf(address addr,address _owner) external view returns (uint){
        return pancakePairMapping[addr].balanceOf(_owner);
    }
}