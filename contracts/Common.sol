pragma solidity ^0.6.0;

contract Common {
    address _publisher;
    address _owner;
    address _admin;

    modifier onlyPublisher() {
        require(_msgSender() == __publisher() , "require publisher");
        _;
    }

    modifier onlyOwner() {
        require(_msgSender() == __owner(), "require owner");
        _;
    }

    modifier onlyAdmin() {
        require(_msgSender() == __admin() || _msgSender() == __owner(), "require admin");
        _;
    }

    // functions of publisher
    //		set
    function _setPublisher() internal{
        _publisher = _msgSender();
    }

    //		get
    function __publisher() internal view returns(address){
        return _publisher;
    }

    // functions of owner
    //		set
    function _setOwner(address __owner) internal onlyPublisher(){
        _owner = __owner;
    }

    function setOwner(address __owner) external onlyPublisher(){
        _setOwner(__owner);
    }

    //		get
    function __owner() internal view returns(address){
        return _owner;
    }

    function owner() external view returns(address){
        return __owner();
    }

    // functions of admin
    //		set
    function _setAdmin(address __admin) internal onlyOwner() {
        _admin = __admin;
    }

    function setAdmin(address __admin) external onlyOwner() {
        _setAdmin(__admin);
    }

    //		get
    function __admin() internal view returns(address){
        return _admin;
    }

    function admin() external view returns(address){
        return __admin();
    }

    function _msgSender() internal view returns(address){
        return msg.sender;
    }
}