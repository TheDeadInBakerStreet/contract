pragma solidity ^0.6.0;

import './interface/IERC20.sol';
import './interface/IHTX.sol';
import './interface/IPancakeFactory.sol';
import './interface/IPancakeRouter.sol';
import './interface/ILpDeposit.sol';
import './lib/SafeMath.sol';
import "./lib/Address.sol";
import "./lib/TransferHelper.sol";
import "./Common.sol";
import "./interface/IWhiteList.sol";

contract CrowdfundingConstant is Common{
	using SafeMath for uint256;

	event Crowdfunding(address indexed user, uint256 amount, uint256 timestamp);
	event Claim(address indexed user, uint256 HTXAmount, uint256 USDTAmount, uint256 timestamp);
	event Completed(uint256 timestamp);

	// @dev initial circulation
	uint256 _initialCirculation;
	uint256 _userInitial;
	uint256 _whitelistInitial;

	// @dev the start time of crowdfunding;
	uint256 _startTime;

	// @dev a convenient query mapping
	mapping(address => uint) _indexMapping;

	// @dev the struct of user information
	struct userInfoStruct{
		// user's address
		address userAddress;
		// actual amount paid
		uint256 paidAmount;
		// amount winning
		uint256 winning;
		// remaining quantity
		uint256 remain;
		// HTX of per User
		uint256 HTXOfUser;
	}
	userInfoStruct[] _userInfos;

	// the current total amount of crowdfunding
	uint256 _currentTotalFunding;

	// total amount of crowdfunding currently effective
	uint256 _currentEffective;

	//the total amount of whitelist crowdfunding
	uint256 _whitelistTotalFunding;

	//the effective amount of the whitelist crowdfunding
	uint256 _whitelistEffective;


	// the count of HTX
	uint256 _coinCount;

	// the end time of crowdfunding
	uint256 _endTime;

	// maximum crowdfunding per address
	uint256 _maximum;

	// the crowdfunding switch
	uint256 _canCrowdfunding = 0;


	uint constant HALF = 2;
	uint constant DECIMALS = 16;
	uint min = 10 ** DECIMALS;
	uint256 constant NOT_START = 0;
	uint256 constant GOING = 1;
	uint256 constant COMPLETED = 2;
	uint256 constant DOUBLE = 2;


	// HTX contract address
	IHTX _HTXContract;
	address _HTX;
	
	// LpDeposit contract Address
	ILpDeposit _LpContract;

	// ERC20 of HTX contract address
	IERC20 _HTXContractERC20;

	// ERC20 of USDT contract address
	IERC20 _USDTContract;
	address _USDT;

	// PancakeSwap
	IPancakeFactory _pancakeFactory;
	IPancakeRouter _pancakeRouter;

	// interface of white list
	IWhiteList _whiteList;

	// Pair address
	address _pair;
	address constant PANCAKE_ROUTER_ADDRESS = 0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F;
	address constant PANCAKE_FACTORY_ADDRESS = 0xBCfCcbde45cE874adCB698cC183deBcF17952812;

	// @dev functions of _initialCiculation
	//		set
	function _setInitialCirculation(uint256 userInitial_, uint256 whitelistInitial_) internal{
		_userInitial = userInitial_ * (10 ** uint256(__HTXContractERC20().decimals()));
		_whitelistInitial = whitelistInitial_ * (10 ** uint256(__HTXContractERC20().decimals()));
		_initialCirculation = _userInitial.add(_whitelistInitial);
	}

	//		get
	function __initialCirculation() internal virtual view returns(uint256 result) {
		result = _initialCirculation;
	}

	// @dev functions of _startTime
	//		set
	function _setStartTime(uint256 __startTime) internal{
		_startTime = __startTime;
	}

	//		get
	function __startTime() internal view returns(uint256 result) {
		result = _startTime;
	}

	// @dev function of _indexMapping
	//		set
	function _setIndexMapping(address addr, uint index) internal{
		_indexMapping[addr] = index;
	}

	//		get
	function indexMapping(address _address) private view returns(uint index_){
		index_ = _indexMapping[_address];
	}

	// @dev functions of userInfos
	//		set
	function _setUserInfos(address _address, uint256 _paidAmount) internal{
		// The first user of crowdfunding
		if(userInfosLength() == 0){
			_userInfos.push(userInfoStruct(address(0), 0, 0, 0, 0));
			_indexMapping[address(0)] = userInfosLength() - 1;
			// Index starts at 1
			_userInfos.push(userInfoStruct(_address, _paidAmount, 0, 0, 0));
			_indexMapping[_address] = userInfosLength() - 1;
		} else
		// First time to participate in the crowdfunding users
			if(indexMapping(_address) == 0){

				//whitelist users
				if(__whiteList().isExist(_address)){
					uint256 htxAmount =  _paidAmount > __maximum() ? __maximum() : _paidAmount;
					uint256 remain = _paidAmount > __maximum() ? _paidAmount.sub(__maximum()) : 0;
					userInfoStruct memory user = userInfoStruct(_address, _paidAmount, 0, remain, htxAmount);
					_userInfos.push(user);
				}else{ // general users
					userInfoStruct memory user = userInfoStruct(_address, _paidAmount, 0, 0, 0);
					_userInfos.push(user);
				}

				_indexMapping[_address] = userInfosLength() - 1;
			} else {
				// Users who have already participated in crowdfunding
				userInfoStruct memory user = __userInfos();
				//whitelist users
				if(__whiteList().isExist(_address)){
					uint256 htxAmount =  _paidAmount.add(user.paidAmount) > __maximum() ? __maximum() : _paidAmount.add(user.paidAmount);
					uint256 remain = _paidAmount.add(user.paidAmount) > __maximum() ? _paidAmount.add(user.paidAmount).sub(__maximum()) : 0;
					user.paidAmount = user.paidAmount.add(_paidAmount);
					user.HTXOfUser = htxAmount;
					user.remain = remain;
					_userInfos[indexMapping(_address)] = user;
				}else{// general users
					user.paidAmount = user.paidAmount.add(_paidAmount);
					_userInfos[indexMapping(_address)] = user;
				}
			}
	}

	//		get
	function __userInfos() internal view returns(userInfoStruct memory usr){
		uint256 index = indexMapping(_msgSender());
		usr = index == 0 ? userInfoStruct(_msgSender(), 0, 0, 0, 0) : _userInfos[index];
	}

	//		get expect number of winning
	function getExpect(userInfoStruct memory _userInfo) internal view returns(uint256 expect_){
		if(__whiteList().isExist(_userInfo.userAddress)){
			expect_ = _userInfo.HTXOfUser;
			return expect_;
		}

	    uint256 effectiveOfUser = _userInfo.paidAmount > __maximum() ? __maximum() : _userInfo.paidAmount;
	    uint256 totalEffective_ = __currentEffective().sub(__whitelistEffective()) > __userInitial() ? __userInitial() : __currentEffective().sub(__whitelistEffective());
		expect_ = totalEffective_ == 0 ? 0 : effectiveOfUser.mul(totalEffective_).div(__currentEffective().sub(__whitelistEffective()));
	}
	
	function userInfos() external view returns(uint256 _paidAmount, uint256 _winning, uint256 _remain,uint256 _HTXOfUser,uint256 _expect){
		userInfoStruct memory user = __userInfos();
		return (user.paidAmount, user.winning, user.remain, user.HTXOfUser,__canCrowdfunding() == GOING ? getExpect(user) : 0);
	}

	function userInfosLength() internal view returns(uint length_){
		length_ = _userInfos.length;
	}

	// @dev functions of _maximum
	//		set
	function _setMaximum(uint256 __maximum) internal{
		_maximum = __maximum.mul(10 ** uint256(__HTXContractERC20().decimals()));
	}

// 	function setMaximum(uint256 __maximum) external onlyAdmin(){
// 		_setMaximum(__maximum);
// 	}

	//		get
	function __maximum() internal view returns(uint256 maximum_){
		maximum_ = _maximum;
	}
	
	function maximum() external view returns(uint256 maximum_){
		maximum_ = __maximum();
	}

	// @dev functions of _whitelistTotalFunding
	//		set
	function _setWhitelistTotalFunding(uint256 value) internal{
		_whitelistTotalFunding = _whitelistTotalFunding.add(value);
	}

	//		get
	function __whitelistTotalFunding() internal view returns(uint256 whitelistTotalFunding){
		whitelistTotalFunding = _whitelistTotalFunding;
	}

	// @dev functions of _whitelistEffective
	//		set
	function _setWhitelistEffective(uint256 value) internal{
		_whitelistEffective = _whitelistEffective.add(value);
	}

	//		get
	function __whitelistEffective() internal view returns(uint256 whitelistEffective){
		whitelistEffective = _whitelistEffective;
	}

	// @dev functions of _currentTotalFunding
	//		set
	function _setCurrentTotalFunding(uint256 value) internal{
		_currentTotalFunding = _currentTotalFunding.add(value);
	}

	//		get
	function __currentTotalFunding() internal view returns(uint256 currentTotalFunding_){
		currentTotalFunding_ = _currentTotalFunding;
	}

	// @dev functions of _currentEffective
	//		set
	function _setCurrentEffective(uint256 value) internal{
		_currentEffective = _currentEffective.add(value);
	}

	//		get
	function __currentEffective() internal view returns(uint256 currentEffective_){
		currentEffective_ = _currentEffective;
	}

	// @dev functions of _coinCount
	//		set
	function _setCoinCount(uint256 value) internal{
		_coinCount = value * DOUBLE;
	}

	//		get
	function __coinCount() internal virtual view returns(uint256){
		return _coinCount;
	}

	function coinCount() external  view returns(uint256){
	    return __coinCount();
	}

	// @dev functions of _endTime.
	//		set
	function _setEndTime(uint __period) internal{
		_endTime = _startTime + __period;
	}

	//		get
	function __endTime() internal view returns(uint256){
		return _endTime;
	}


	// @dev function of _HTXContract
	//		set
	function _setHTXContract(address contractAddr) internal{
		_HTXContract = IHTX(contractAddr);
		_HTX = contractAddr;
	}

	function initialize(address HTXcontractAddr, address LPContractAddr, uint256 userInitial_,uint256 whitelistInitial_,  uint256 maximum_) external onlyAdmin(){
		_setHTXContractERC20(HTXcontractAddr);
		_setHTXContract(HTXcontractAddr);
		_setLPContract(LPContractAddr);
		_setInitialCirculation(userInitial_,whitelistInitial_);
		_setMaximum(maximum_);
	}

	//		get
	function __HTXContract() internal view returns(IHTX){
		return _HTXContract;
	}
	
	// @dev function of _LPContract
	//		set
	function _setLPContract(address lpContractAddr) internal{
		_LpContract = ILpDeposit(lpContractAddr);
	}

// 	function setLPContract(address lpContractAddr) external onlyAdmin(){
// 		_setLPContract(lpContractAddr);
// 	}

	// @dev function of _USDTContract
	//		set
	function _setUSDTContract() internal{
		_USDT = 0xa71EdC38d189767582C38A3145b5873052c3e47a;
		_USDTContract = IERC20(_USDT);
	}

	//		get
	function __USDTContract() internal view returns(IERC20){
		return _USDTContract;
	}

	// @dev functions of pancakeSwap
	//		set
	function _setPancakeSwap() internal{
		_pancakeFactory = IPancakeFactory(PANCAKE_FACTORY_ADDRESS);
		_pancakeRouter = IPancakeRouter(PANCAKE_ROUTER_ADDRESS);
	}

	//		get
	function __pancakeFactory() internal view returns(IPancakeFactory){
		return _pancakeFactory;
	}

	// @dev functions of white list
	//		set
	function _setWhiteList(address whiteList) internal{
		_whiteList = IWhiteList(whiteList);
	}

	//		get
	function __whiteList() internal view returns(IWhiteList){
		return _whiteList;
	}

	// @dev function of _HTXContractERC20
	//		set
	function _setHTXContractERC20(address contractAddr) internal{
		_HTXContractERC20 = IERC20(contractAddr);
	}

	//		get
	function __HTXContractERC20() internal view returns(IERC20){
		return _HTXContractERC20;
	}

	// @dev function of _canCrowdfunding
	//		set
	function _setCanCrowdfunding(uint256 _status, uint256 _period) internal{
		// Set a start date for crowdfunding
		_setStartTime(block.timestamp);
		// Set an end date for crowdfunding
		_setEndTime(_period);
		_canCrowdfunding = _status;
	}

	function openOrCloseCrowdfunding(uint256 _status, uint256 _period) external onlyAdmin{
		_setCanCrowdfunding(_status, _period);
	}

	//		get
	function __canCrowdfunding() internal view returns(uint256){
		return _canCrowdfunding;
	}

	function canCrowdfunding() external view returns(uint256 result){
		return __canCrowdfunding();
	}

	// functions of _pair
	//		set
	function _setPair(address pair_) internal {
		_pair = pair_;
	}

	//		get
	function __pair() internal view returns(address){
		return _pair;
	}

	function pair() external view returns(address){
		return __pair();
	}

	//		get
	function __whitelistInitial() internal view returns(uint256 whitelistInitial_){
		whitelistInitial_ = _whitelistInitial;
	}

	//		get
	function __userInitial() internal view returns(uint256 userInitial_){
		userInitial_ = _userInitial;
	}
}


contract Crowdfunding is CrowdfundingConstant{
	/*
	 * @dev constructor of Contract crowdfunding
	 */
	constructor(address whiteListContract) public {
	    _setPublisher();
		// Set up the contract USDTContract
		_setUSDTContract();
		// Set up the contract pancakeSwap
		_setPancakeSwap();
		// Set up the contract WhiteListContract
		_setWhiteList(whiteListContract);
	}

	/**
	 * @dev parameter for crowdfunding show
	 */
	function crowdfundingShow() external view returns(uint256 countDown, uint256 expect, uint256 total, uint256 totalEffective){
	    uint256 _countDown = __canCrowdfunding() == 1 && __endTime() > block.timestamp ? (__endTime() - block.timestamp) : 0;
		return(_countDown, __initialCirculation(), __currentTotalFunding(), __currentEffective());
	}

	/**
	 * @dev this function is used to determine if the crowdfunding is due
	 */
	function _isDue() private view returns(bool){
		return block.timestamp <= __endTime();
	}

	/**
	 * @dev function of crowdfunding
	 */
	function crowdfunding(uint256 value) external returns(bool result){
		require(__canCrowdfunding() == GOING, "Not yet");

		//if whitelist
		if(__whiteList().isExist(_msgSender())){
			// update whitelist params
			_setWhitelistTotalFunding(value);
			_setWhitelistEffective(value > __maximum() ? __maximum(): value);

		}

		// Transfer from user address to contract address
		__USDTContract().transferFrom(_msgSender(),address(this),value);
		// update parameter _initialCirculation
		_setCurrentTotalFunding(value);
		// update parameter _setCurrentAvailable
		_setCurrentEffective(value > __maximum() ? __maximum() : value);

		// update parameter _indexMapping and _userInfos
		_setUserInfos(_msgSender(),value);

		if(!_isDue()){
			// End the crowdfunding
			_setCanCrowdfunding(COMPLETED,0);
			/**
			 * If the actual amount of crowdfunding is more than 20,000,
			 * the total HTX coin counts will be calculated as 20,000;
			 * otherwise, it will be calculated as the actual amount of crowdfunding
			 */
			uint256 usdtEffective = __currentEffective() > __initialCirculation() ? __initialCirculation() : __currentEffective();
			_setCoinCount(usdtEffective);
			// The HTX amount of crowdfunding distribution
			uint256 amount = __coinCount().div(HALF);
			// Transfer HTX from HTX __USDTContract
			__HTXContract().issueTransfer(address(this),__coinCount());
			// Iterate through the user array
			iteration(amount);
			// Create Pancake pair
			TransferHelper.safeApprove(_USDT, PANCAKE_ROUTER_ADDRESS, usdtEffective);
			TransferHelper.safeApprove(_HTX, PANCAKE_ROUTER_ADDRESS, amount);
 			_setPair(__pancakeFactory().createPair(_USDT,_HTX));
 			_pancakeRouter.addLiquidity(_USDT, _HTX, usdtEffective, amount, min, min, __owner(), block.timestamp);
 			//set pair address  of  lp contract
 			_LpContract.setPairAddress(__pair());
 			
            emit Completed(block.timestamp);
		}
		emit Crowdfunding(_msgSender(), value, block.timestamp);
		return true;
	}

	/**
	 * @dev function of claim
	 */
	function claim() external returns(bool result){
		require(__canCrowdfunding() == COMPLETED,"Not yet");
		__HTXContractERC20().transfer(_msgSender(), __userInfos().HTXOfUser);
		__USDTContract().transfer(_msgSender(), __userInfos().remain);
		_userInfos[_indexMapping[_msgSender()]].paidAmount = 0;
		_userInfos[_indexMapping[_msgSender()]].remain = 0;
		_userInfos[_indexMapping[_msgSender()]].HTXOfUser = 0;
		emit Claim(_msgSender(), __userInfos().HTXOfUser, __userInfos().remain, block.timestamp);
		return true;
	}

	/**
     * Iterate the user array,
     * calculate the median scalar for each person
     * and distribute the HTX quantity
     */
	function iteration(uint256 amount) private{
		for(uint256 i = 1; i < userInfosLength(); i++) {

			userInfoStruct memory user = _userInfos[i];

			if(__whiteList().isExist(user.userAddress)){
				continue;
			}

			uint256 paidAmount = user.paidAmount > __maximum() ? __maximum() : user.paidAmount;

			uint256 totalEffective = __currentEffective().sub(__whitelistEffective()) > __userInitial() ? __userInitial() : __currentEffective().sub(__whitelistEffective());
			user.winning = paidAmount.mul(totalEffective).div(__currentEffective().sub(__whitelistEffective()));
			user.remain = user.paidAmount.sub(user.winning);
			user.HTXOfUser = user.winning.mul(amount).div(totalEffective);
			_userInfos[i] = user;
		}
	}
}