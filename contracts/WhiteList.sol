// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.6.0;

import "./Common.sol";
import "./interface/IWhiteList.sol";
import "./lib/Strings.sol";

contract WhiteList is Common{
    using Strings for *;

    // twitter link list
    struct link{
        address userAddress;
        string twitterLink;
        string telegramID;
        // 0: not apply     1:audit       2:refused     3:pass
        uint8 status;
    }
    mapping(address => uint256) indexMapping;
    link[] linkList;

    // mapping of white lists
    mapping(address => uint8) _whiteList;

    // length of white list
    uint _count;

    // end time
    uint256 _endTime;

    string constant PARTTERN = "http://twitter.com/";

    // functions of linkList
    // set
    function _apply(string memory twitterLink_,string memory telegramID_) private{
        indexMapping[_msgSender()] = linkList.length;
        linkList.push(link(_msgSender(), twitterLink_, telegramID_,1));
    }

    function checkTwitterUrl(string memory twitterLink_) private pure returns(bool){
       return  twitterLink_.toSlice().startsWith(PARTTERN.toSlice());
    }

    function applyWhiteList(string calldata twitterLink_,string calldata telegramID_) external{
        require(checkTwitterUrl(twitterLink_),"require twitter link");
        require(isApplying(), "require applying");
        require(_applied(), "require apply");
        _apply(twitterLink_,telegramID_);
    }

    // value :
    //      0:refuse
    //      1:pass
    function check(uint256 value, address userAddress) external onlyAdmin{
        linkList[indexMapping[userAddress]].status = 2;
        if(value == 0){
            return;
        }
        _setWhiteList(userAddress);
    }

    // get apply status
    function _applied() private view returns(bool result){
        if(linkList.length == 0 ){
            result = true;
        }else{
            result = linkList[indexMapping[_msgSender()]].status == 0;
        }
    }

    function applied() external view returns(bool result){
        result = _applied();
    }

    // functions of whiteList
    // set
    function _setWhiteList(address addr) private{
        require(!isExist(addr), "require exist!");
        _whiteList[addr] = 1;
        _countAdd();
    }

    function _countAdd() private{
        _count += 1;
    }

    // get
    function isExist(address addr) public view returns(bool result){
        result = __whiteList(addr) == 1;
    }

    function __whiteList(address addr) private view returns(uint8 value){
        value = _whiteList[addr];
    }

    function whiteList() external view returns(uint8 value){
        value = _whiteList[_msgSender()];
    }

    function linkLists() external view returns(link[] memory){
        return linkList;
    }

    // functions of endTime
    // set
    function setEndTime(uint256 day) external onlyAdmin{
        _endTime = block.timestamp + (day * 60 * 60 * 24);
    }

    // get
    function isApplying() public view returns(bool result){
        result = _endTime >= block.timestamp;
    }

    constructor() public{
        _setPublisher();
    }
}