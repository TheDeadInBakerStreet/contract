// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import './lib/SafeMath.sol';
import './interface/IHTX.sol';
import './interface/IERC20.sol';
import "./interface/ICrowdfunding.sol";
import "./DAO.sol";
import "./Common.sol";

contract DAOConstant is Common{
    using SafeMath for uint256;

    event Deposit(uint256 indexed _index, address indexed _addr, uint256 amount, uint256 timestamp);
    event WithdrawApply(address indexed _addr, uint256 timestamp);
    event Withdraw(address indexed _addr, uint256 amount,uint256 timestamp);
    event Reward(address indexed _addr, uint256 amount, uint256 timestamp);
    event SwitchDAOPool(string poolName, bool status, uint256 timestamp);
    event Price(uint256 price,uint256 timestamp);
    event R_waveRecord(uint256 R,uint256 timestamp);

    // index of DAO which isRunning == true;
    uint256[] indexes;
    
    // Fluctuation constant
    uint256 _C_rate;
    
    // The price of the first acquisition
    uint256 _initPrice;
    
    // price of HTX
    uint256 _lastPrice;
    
    // wave motion
    uint256 _R_wave;

    // DAO pool
    struct DAOInfo{
        uint256 index;
        string poolName;
        uint256 period;
        bool isRunning;
        // The total amount deposit per pool
        uint256 total;
        // The total number of effective pledges per pool
        uint256 totalEffective;
        // The total number of locked HTX per pool
        uint256 totalLocked;
        // The total number of reward per pool
        uint256 totalReward;
    }
    DAOInfo[] _DAOInfos;
    
    struct DAOUser{
        // for query
        mapping(address => uint256) indexMapping;
        // for iterate
        mapping(uint256 => user) userMapping;
        uint256 userCount;
    }
    struct user{
        address userAddr;
        uint256 effective;
        uint256 reward;
        uint256 locked;
        uint256 lockedStartTime;
    }
    DAOUser[] _DAOUsers;

    // amount of DAO pool
    uint256 _totalDAO;

    // wave motion base
    uint256 constant BASE_R_WAVE = 5;

    // promissory decimals
    uint256 constant DECIMALS1 = 16;
    uint256 constant DECIMALS2 = 18;

    // rate for developer
    uint256 constant DEV_RATE = 5;

    // rate for DAO
    uint256 constant DAO_RATE = 3;

    // rate for LP contract
    uint256 constant LP_RATE = 2;

    // ratio
    struct ratio{
        uint256 ratioX;
        bool flag;
    }
    ratio[] _ratios;

    // address of developer
    address developerAddress;

    // HTX contract address
    IHTX _HTXContract;

    // HTX ERC20 interface
    IERC20 _HTXContractERC20;

    // Crowdfunding contract
    ICrowdfunding _ICrowdfunding;

    // @dev functions of _totalDAO
    function _addTotalDAO(uint256 value) internal {
        _totalDAO = _totalDAO.add(value);
    }

    function _subTotalDAO(uint256 value) internal {
        _totalDAO = _totalDAO.sub(value);
    }

    //      get
    function __totalDAO() internal view returns(uint256 result){
        return _totalDAO;
    }

    function totalDAO() external view returns(uint256 result){
        return __totalDAO();
    }

    // @dev functions of _C_rate
    //      set
    function _setC_rate(uint256 value) internal{
        _C_rate = value;
    }

    function initialize(uint256 c_rate_, address HTXContractAddress_, address crowdfundingContractAddress_) external onlyAdmin() {
        _setC_rate(c_rate_);
        _setHTXContract(HTXContractAddress_);
        _setICrowdfunding(crowdfundingContractAddress_);
    }

    //      get
    function __C_rate() internal view returns(uint256){
        return _C_rate;
    }

    function C_rate() external view returns(uint256){
        return __C_rate();
    }

    // @dev functions of _lastPrice / _initPrice
    //      set
    function _setLastPrice(uint256 nowPrice) internal {
        _lastPrice = nowPrice;
    }

    function _setInitPrice(uint256 value) internal {
        _initPrice = value;
    }

    //      get
    function __lastPrice() internal view returns(uint256){
        return _lastPrice;
    }

    function __initPrice() internal view returns(uint256){
        return _initPrice;
    }

    function price() external view returns(uint256 initPrice, uint256 currentPrice){
        return(__initPrice(), __lastPrice());
    }

    // @dev functions of ratios
    //      set
    function _setRatios() internal {
        _ratios.push(ratio(10,false));
        _ratios.push(ratio(20,false));
        _ratios.push(ratio(80,false));
    }

    //      get
    function __ratios() internal view returns(ratio[] memory){
        return _ratios;
    }

    function ratios() external view returns(ratio[] memory){
        return __ratios();
    }


    // @dev functions of _R_wave
    //      set
    function _setR_wave(uint256 value) internal{
        _R_wave = value;
    }

    //      get
    function __R_wave() internal view returns(uint256){
        return _R_wave;
    }

    // @dev functions of _DAOUsers and _DAOInfos
    //      create
    function createDAOPool(string calldata _poolName, uint256 _period) external onlyAdmin() returns(bool){
        return _createDAOPool(_poolName, _period);
    }

    function _createDAOPool(string memory _poolName, uint256 _period) internal returns(bool){
        require(poolNotExist(_poolName),"Already Exist");
        DAOInfo memory DAOInfo_ = DAOInfo({
        index : _DAOInfos.length,
        poolName : _poolName,
        period : _period,
        isRunning : false,
        total : 0,
        totalEffective : 0,
        totalLocked : 0,
        totalReward : 0
        });
        DAOUser memory DAOUser_ = DAOUser({
        userCount : 0
        });
        _DAOInfos.push(DAOInfo_);
        _DAOUsers.push(DAOUser_);
        _updateDAOUser(_DAOUsers.length - 1, address(0), 0, 0, 0, 0);
        return true;
    }

    function poolNotExist(string memory _poolName) private view returns(bool){
        if(_DAOInfos.length == 0){
            return true;
        }
        for(uint i = 0; i < _DAOInfos.length; i++) {
            if(equals(_DAOInfos[i].poolName, _poolName)){
                return false;
            }
        }
        return true;
    }

    function equals(string memory a, string memory b) private pure returns(bool){
        if(bytes(a).length != bytes(b).length){
            return false;
        } else {
            return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
        }
    }

    //      set
    // This function to deposit
    function _deposit(uint256 _index, uint _amount) internal returns(bool){
        address _addr = _msgSender();
        require(_DAOInfos[_index].isRunning,"Open soon");
        // update _totalDAO
        _addTotalDAO(_amount);
        // update DAOUser
        uint index = _DAOUsers[_index].indexMapping[_addr];
        if(index == 0){
            _updateDAOUser(_index, _addr, _amount, 0, 0, 0);
        } else {
            uint256 userIndex = _DAOUsers[_index].indexMapping[_addr];
            _DAOUsers[_index].userMapping[userIndex].effective = _DAOUsers[_index].userMapping[userIndex].effective.add(_amount);
        }
        // update DAOInfo
        _DAOInfos[_index].total = _DAOInfos[_index].total.add(_amount);
        _DAOInfos[_index].totalEffective = _DAOInfos[_index].totalEffective.add(_amount);
        emit Deposit(_index, _msgSender(), _amount, block.timestamp);
        return true;
    }

    function _updateDAOUser(uint256 _index, address _addr, uint256 _effective, uint256 _reward, uint256 _locked, uint256 _lockedStartTime) internal {
        _DAOUsers[_index].indexMapping[_addr] = _DAOUsers[_index].userCount;
        _DAOUsers[_index].userMapping[_DAOUsers[_index].userCount] = user(_addr, _effective, _reward, _locked, _lockedStartTime);
        _DAOUsers[_index].userCount += 1;
    }

    function _DAOUserLength() private view returns(uint256){
        return _DAOUsers.length - 1;
    }

    // This function applies to withdraw
    function _withdrawApply(uint256 _index) internal returns(bool){
        uint userIndex = _DAOUsers[_index].indexMapping[_msgSender()];
        require(userIndex != 0, "No deposit");
        uint256 effective = _DAOUsers[_index].userMapping[userIndex].effective;
        uint256 locked = _DAOUsers[_index].userMapping[userIndex].locked;
        // update DAOInfo
        _DAOInfos[_index].totalEffective = _DAOInfos[_index].totalEffective.sub(effective);
        _DAOInfos[_index].totalLocked = _DAOInfos[_index].totalLocked.add(effective);
        // update DAOUser
        _DAOUsers[_index].userMapping[userIndex].locked = locked.add(effective);
        _DAOUsers[_index].userMapping[userIndex].effective = 0;
        _DAOUsers[_index].userMapping[userIndex].lockedStartTime = block.timestamp;
        emit WithdrawApply(_msgSender(), block.timestamp);
        return true;
    }
    // This function to withdraw
    function _canWithdraw(uint256 _index) internal view returns(bool){
        uint userIndex = _DAOUsers[_index].indexMapping[_msgSender()];
        uint lockedStartTime = _DAOUsers[_index].userMapping[userIndex].lockedStartTime;
        uint poolLocked = _DAOInfos[_index].period;
        return lockedStartTime != 0 && lockedStartTime + poolLocked <= block.timestamp;
    }

    function canWithdraw(uint256 _poolIndex) external view returns(bool){
        return _canWithdraw(_poolIndex);
    }

    function _withdraw(uint256 _index) internal returns (uint256){
        uint userIndex = _DAOUsers[_index].indexMapping[_msgSender()];
        uint256 locked =  _DAOUsers[_index].userMapping[userIndex].locked ;
        // update DAOUser
        _DAOUsers[_index].userMapping[userIndex].locked = 0;
        _DAOUsers[_index].userMapping[userIndex].lockedStartTime = 0;
        // update DAOInfo
        _DAOInfos[_index].total = _DAOInfos[_index].total.sub(locked);
        _DAOInfos[_index].totalLocked = _DAOInfos[_index].totalLocked.sub(locked);
        _subTotalDAO(locked);
        emit Withdraw(_msgSender(), locked, block.timestamp);
        return locked;
    }

    // function to open or close DAOPool
    function _switchDAOPool(uint256 _index) internal returns(bool){
        _DAOInfos[_index].isRunning = !_DAOInfos[_index].isRunning;
        emit SwitchDAOPool(_DAOInfos[_index].poolName, _DAOInfos[_index].isRunning, block.timestamp);
        return true;
    }

    //      get
    // This function to get reward
    function _getReward(uint256 _index) internal returns (uint256){
        uint userIndex = _DAOUsers[_index].indexMapping[_msgSender()];
        uint256 reward = _DAOUsers[_index].userMapping[userIndex].reward;
        _DAOUsers[_index].userMapping[userIndex].reward = 0;
        emit Reward(_msgSender(), reward, block.timestamp);
        return reward;
    }

    function getReward(uint256 _index) external returns (uint256){
        return _getReward(_index);
    }

    function __DAOInfos() internal view returns(DAOInfo[] memory){
        return _DAOInfos;
    }

    function DAOInfos() external view returns(DAOInfo[] memory){
        return __DAOInfos();
    }

    function __DAOInfo(uint256 _poolIndex) internal view returns(DAOInfo memory){
        return _DAOInfos[_poolIndex];
    }

    function DAOInfoDetails(uint256 _poolIndex) external view returns(DAOInfo memory){
        return __DAOInfo(_poolIndex);
    }

    function __userInfo(uint256 _poolIndex) internal view returns (user memory){
        uint256 userIndex = _DAOUsers[_poolIndex].indexMapping[_msgSender()];
        return _DAOUsers[_poolIndex].userMapping[userIndex];
    }

    function userInfo(uint256 _poolIndex) external view returns(user memory){
        return __userInfo(_poolIndex);
    }

    function countDown(uint256 _poolIndex) external view returns(uint256){
        uint256 lockedStartTime = __userInfo(_poolIndex).lockedStartTime;
        uint256 period = __DAOInfo(_poolIndex).period;
        return lockedStartTime != 0 ? lockedStartTime.add(period).sub(block.timestamp) : 0;
    }



    // @dev function of _HTXContract
    //		set
    function _setHTXContract(address contractAddr) internal returns(bool){
        _HTXContract = IHTX(contractAddr);
        _setHTXContractERC20(contractAddr);
        return true;
    }

    // function setHTXContract(address contractAddr) external onlyAdmin() returns(bool){
    //     return _setHTXContract(contractAddr);
    // }

    //		get
    function __HTXContract() internal view returns(IHTX){
        return _HTXContract;
    }


    // @dev function of _HTXContractERC20
    //		set
    function _setHTXContractERC20(address contractAddr) internal returns(bool){
        _HTXContractERC20 = IERC20(contractAddr);
        return true;
    }

    //      get
    function __HTXContractERC20() internal view returns(IERC20){
        return _HTXContractERC20;
    }

    // @dev function of _ICrowdfunding
    //		set
    function _setICrowdfunding(address contractAddr) internal returns(bool){
        _ICrowdfunding = ICrowdfunding(contractAddr);
        return true;
    }

    // function setICrowdfunding(address contractAddr) external onlyAdmin() returns(bool){
    //     return _setICrowdfunding(contractAddr);
    // }

    //		get
    function __ICrowdfunding() internal view returns(ICrowdfunding){
        return _ICrowdfunding;
    }

    // computational formula of R_wave
    function calculateR(uint256 nowPrice) internal returns(bool, uint256){
        bool flag = nowPrice <= __lastPrice();
        uint256 R = (flag ? __lastPrice().sub(nowPrice).mul(10 ** DECIMALS2).div(nowPrice.add(__lastPrice())) : nowPrice.sub(__lastPrice()).mul(10 ** DECIMALS2).div(nowPrice.add(__lastPrice())));
        _setR_wave(R);
        _setLastPrice(nowPrice);
        emit R_waveRecord(R,block.timestamp);
        emit Price(nowPrice,block.timestamp);
        return (flag, R);
    }

    // R_wave greater than 5%
    function isGreater(uint256 R_wave_) internal pure returns(bool){
        return R_wave_ > (BASE_R_WAVE * (10 ** DECIMALS1));
    }

    /**
    * Iterate the user array,
    * calculate the award for each person
    * and distribute the HTX quantity
    */
    function iteration(uint256 toDAO,uint256 toDAOAward, uint256 mint) internal{
        uint256 totalDeposit;
        uint256 totalEffective;
        for(uint i = 0; i < _DAOInfos.length; i++) {
            if(_DAOInfos[i].isRunning){
                indexes.push(_DAOInfos[i].index);
                totalDeposit = totalDeposit.add(_DAOInfos[i].total);
                totalEffective = totalEffective.add(_DAOInfos[i].totalEffective);
            }
        }
        iterationToDeposit(totalDeposit, toDAOAward);
        iterationToDistribute(totalEffective, toDAO, mint);
    }

    function iterationToDeposit(uint256 totalDeposit, uint256 toDAOAward) private {
        if(indexes.length == 0 || totalDeposit == 0){
            return;
        }
        // iterate DAOPools
        for(uint i = 0; i < indexes.length; i++) {
            uint256 poolIndex_ = indexes[i];
            uint256 userCount = _DAOUsers[poolIndex_].userCount;
            uint256 totalPerDAODeposit = _DAOInfos[poolIndex_].total;
            uint256 perPoolTotalAward = totalPerDAODeposit.mul(10 ** DECIMALS2).mul(toDAOAward).div(totalDeposit);
            __DAOInfos()[poolIndex_].totalReward = __DAOInfos()[poolIndex_].totalReward.add(perPoolTotalAward);
            // iterate users of this DAOPool which index is i
            for(uint j = 0; j < userCount; j++) {
                uint256 total = _DAOUsers[poolIndex_].userMapping[j].effective.add(_DAOUsers[poolIndex_].userMapping[j].locked);
                uint256 reward__ = total.mul(perPoolTotalAward).div(totalPerDAODeposit).div(10 ** DECIMALS2);
                _DAOUsers[poolIndex_].userMapping[j].reward = _DAOUsers[poolIndex_].userMapping[j].reward.add(reward__);
            }
        }
    }

    function iterationToDistribute(uint256 amount,uint256 toDAO, uint256 mint) internal {
        if(indexes.length == 0){
            return;
        }
        uint256 perAmount = toDAO.div(indexes.length);
        // iterate DAOPools
        for(uint i = 0; i < indexes.length; i++) {
            uint256 poolIndex_ = indexes[i];
            uint256 userCount = _DAOUsers[poolIndex_].userCount;
            uint256 totalEffective = _DAOInfos[poolIndex_].totalEffective;
            if(totalEffective == 0){
                continue;
            }
            // iterate users of this DAOPool which index is i
            uint256 incentive = _DAOInfos[poolIndex_].totalEffective.mul(10 ** DECIMALS2).mul(mint).div(10 ** DECIMALS2).div(amount);
            uint256 perPoolTotalAward = perAmount.add(incentive);
            __DAOInfos()[poolIndex_].totalReward = __DAOInfos()[poolIndex_].totalReward.add(perPoolTotalAward);
            for(uint j = 0; j < userCount; j++) {
                uint256 effective = _DAOUsers[poolIndex_].userMapping[j].effective;
                uint256 reward_ = effective.mul(10 ** DECIMALS2).mul(perPoolTotalAward).div(totalEffective).div(10 ** DECIMALS2);
                _DAOUsers[poolIndex_].userMapping[j].reward = _DAOUsers[poolIndex_].userMapping[j].reward.add(reward_);
            }
        }
        delete(indexes);
    }

    function oracle(uint256 price_) internal returns(bool){
        for(uint i = 0; i < __ratios().length; i++) {
            if(!__ratios()[i].flag && __ratios()[i].ratioX.mul(__initPrice()) <= price_){
                _ratios[i].flag = true;
                return true;
            }
        }
        return false;
    }
}


contract DAO is DAOConstant {
    /*
	 * @dev constructor of Contract DAO
	 */
    constructor(uint256 initPrice) public {
        _setPublisher();
        // Set up the contract publisher
        _setRatios();
        _setR_wave(0);
        _setInitPrice(initPrice);
        _setLastPrice(initPrice);
    }

    // @dev function deposit
    function deposit(uint256 _poolIndex, uint256 amount) external returns(bool){
        require(_DAOInfos[_poolIndex].isRunning,"Not yet");
        uint256 userIndex = _DAOUsers[_poolIndex].indexMapping[_msgSender()];
        uint256 locked = _DAOUsers[_poolIndex].userMapping[userIndex].locked;
        require(locked == 0, "Locking");
        // Transfer HTX from user address to this contract address
        __HTXContractERC20().transferFrom(msg.sender,address(this),amount);
        return _deposit(_poolIndex, amount);
    }

    // @dev functions of withdraw
    // apply to withdraw
    function withdrawApply(uint256 _poolIndex) external returns(bool){
        return _withdrawApply(_poolIndex);
    }
    // withdraw
    function withdraw(uint256 _poolIndex) external returns(bool){
        require(_canWithdraw(_poolIndex),"Not yet");
        __HTXContractERC20().transfer(_msgSender(),_withdraw(_poolIndex));
        return true;
    }

    // @dev function to get reward
    function reward(uint256 _poolIndex) external returns(bool){
        return __HTXContractERC20().transfer(_msgSender(),_getReward(_poolIndex));
    }

    // @dev function of open or close DAOPool
    function switchDAOPool(uint256 _poolIndex) external onlyAdmin() returns(bool){
        return _switchDAOPool(_poolIndex);
    }

    // @dev function of priceOracle (Java calls)
    function priceOracle(uint256 nowPrice) external onlyAdmin() returns(bool){
        bool flag;
        uint256 _R;
        // The return R is multiplied by the sixteenth power
        (flag, _R) = calculateR(nowPrice);
        if(!isGreater(_R)){
            return false;
        }
        /**
         * Increase user balance
         * parameter1 : increase(false) or decrease(true
         * parameter2 : R_wave
         * parameter3 : the rate of development
         * parameter4 : the rate of DAOPool
         * @return :  how much should DAOPool go up
         */
        /**
         * toDAO : from 3%
         * toDAOUser : from 92% of DAO`user
         */
        uint256 toDAO;
        uint256 toDAOAward;
        (toDAO, toDAOAward)= __HTXContract().updateUserBalance(flag, _R, DEV_RATE.mul(10 ** DECIMALS1), DAO_RATE.mul(10 ** DECIMALS1), LP_RATE.mul(10 ** DECIMALS1));
        uint256 mint = 0;
        if(!flag){
            if(oracle(nowPrice)){
                // Distribute the reward
                mint = __ICrowdfunding().coinCount();
                __HTXContract().issueTransfer(address(this),mint);
            }
            iteration(toDAO,toDAOAward,mint);
        }
        return true;
    }
}