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

    // length of white list
    uint _count;

    // end time
    uint256 _endTime;

    string constant PATTERN_1 = "https://twitter.com/";
    string constant PATTERN_2 = "https://mobile.twitter.com/";

    // functions of linkList
    // set
    function _apply(string memory twitterLink_,string memory telegramID_) private{
        if(linkList.length == 0){
            indexMapping[address(0)] = linkList.length;
            linkList.push(link(address(0), "", "",0));
        }
        indexMapping[_msgSender()] = linkList.length;
        uint8 status = 1;
        if(checkTwitterUrl(twitterLink_)){
            status = 2;
        }
        linkList.push(link(_msgSender(), twitterLink_, telegramID_,status));
    }

    function checkTwitterUrl(string memory twitterLink_) private pure returns(bool){
       return  !(twitterLink_.toSlice().startsWith(PATTERN_1.toSlice()) || twitterLink_.toSlice().startsWith(PATTERN_2.toSlice()));
    }

    function applyWhiteList(string calldata twitterLink_,string calldata telegramID_) external{
        require(isApplying(), "require applying"); // time
        require(_applied() == 0, "require apply"); 
        _apply(twitterLink_,telegramID_);
    }

    // value :
    //      2:refuse
    //      3:pass
    function check(uint8 value, address userAddress) external onlyAdmin{
        linkList[indexMapping[userAddress]].status = value;
        if(value == 3){
            _countAdd();
        }
    }

    // get apply status
    function _applied() private view returns(uint result){
        if(linkList.length == 0 ){
            result = 0;
        }else if(isApplying()){
            result = linkList[indexMapping[_msgSender()]].status == 0 ? 0 : 1;
        }else{
            result = linkList[indexMapping[_msgSender()]].status;
        }
    }

    // result     0: not apply     1:audit       2:refused     3:pass
    function applied() external view returns(uint result){
        result = _applied();
    }

    // function of count
    // add
    function _countAdd() private{
        _count += 1;
    }

    // get
    function count() external view returns(uint256 result){
        result = _count;
    }

    // get
    function isExist(address addr) public view returns(bool result){
        result = linkList[indexMapping[addr]].status == 3;
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