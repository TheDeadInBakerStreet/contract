// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.6.0;

import './lib/SafeMath.sol';
import './lib/Address.sol';
import './interface/IERC20.sol';
import "./interface/IHTX.sol";
import "./interface/ILpDeposit.sol";
import "./Common.sol";


contract Initializable is Common{
  /**
   * @dev Indicates that the contract has been initialized.
   */
  bool private initialized;

  /**
   * @dev Indicates that theTransfer contract is in the process of being initialized.
   */
  bool private initializing;

  /**
   * @dev Modifier to use in the initializer function of a contract.
   */
  modifier initializer() {
    require(initializing || isConstructor() || !initialized, "Contract instance has already been initialized");

      //initializing
    bool isTopLevelCall = !initializing;
    if (isTopLevelCall) {
      initializing = true;
      initialized = true;
    }

    _;

    if (isTopLevelCall) {
      initializing = false;
    }
  }

  /// @dev Returns true if and only if the function is running in the constructor
  function isConstructor() private view returns (bool) {
    // extcodesize checks the size of the code stored in an address, and
    // address returns the current address. Since the code is still not
    // deployed when running a constructor, any checks on its code size will
    // yield zero, making it an effective way to detect if a contract is
    // under construction or not.
    address self = address(this);
    uint256 cs;
    assembly { cs := extcodesize(self) }
    return cs == 0;
  }

  // Reserved storage space to allow for layout changes in the future.
  uint256[50] private ______gap;
}

contract ContextUpgradeSafe is Initializable {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    function __Context_init() internal initializer {
        _setPublisher();
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {

    }

    address _daoAddress;
    address _crowdfundingAddress;
    address _lpAddress;
    ILpDeposit _lpDeposit;
    
    //@dev function of  daoAddress
    function _setDAOAddress(address __daoAddress) internal returns(bool){
        _daoAddress = __daoAddress;
        return true;
    }

    // function setDAOAddress(address __daoAddress) external onlyAdmin returns(bool){
    //     return _setDAOAddress(__daoAddress);
    // }

    function daoAddress() internal view returns(address){
        return _daoAddress;
    }

    //@dev function of  crowdfundingAddress
    function _setCrowdfundingAddress(address __crowdfundingAddress) internal returns(bool){
        _crowdfundingAddress = __crowdfundingAddress;
        return true;
    }

    // function setCrowdfundingAddress(address __crowdfundingAddress) external onlyAdmin returns(bool){
    //     return _setCrowdfundingAddress(__crowdfundingAddress);
    // }

    function crowdfundingAddress() internal view returns(address){
        return _crowdfundingAddress;
    }

    //@dev function of  lpAddress
    function _setLPAddress(address __lpAddress) internal returns(bool){
        _lpDeposit = ILpDeposit(__lpAddress);
        _lpAddress = __lpAddress;
        return true;
    }

    // function setLPAddress(address __lpAddress) external onlyAdmin returns(bool){
    //     return _setLPAddress(__lpAddress);
    // }

    function lpAddress() internal view returns(address){
        return _lpAddress;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }

    uint256[50] private __gap;
}

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20MinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20UpgradeSafe is ContextUpgradeSafe , IERC20{
    using SafeMath for uint256;
    using Address for address;
    event IssueTransfer(address _from,address _to,uint256 amount,uint256 timeStamp);

//    mapping (address => uint256) private _balances;

    mapping(address => uint) _userIndexMapping;
    struct userInfoStruct{
        address userAddr;
        uint256 userBalance;
    }

    userInfoStruct[] userInfos;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    
    address _developerAddress;
    
    //@dev function of  developAddress
    function _setDeveloperAddress(address __developerAddress) internal returns(bool){
        _developerAddress = __developerAddress;
        // 12138
        _userIndexMapping[__developerAddress] = userInfos.length;
        userInfos.push(userInfoStruct(_developerAddress,0));
        
        return true;
    }

    // function setDeveloperAddress(address __developerAddress) external onlyAdmin returns(bool){
    //     return  _setDeveloperAddress(__developerAddress);
    // }

    function developerAddress() external view returns(address){
        return _developerAddress;
    }

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */

    function __ERC20_init(string memory name, string memory symbol) internal initializer {
        __Context_init();
        __ERC20_init_unchained(name, symbol);
    }

    function __ERC20_init_unchained(string memory name, string memory symbol) internal initializer {
        _name = name;
        _symbol = symbol;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual  override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        if(_userIndexMapping[account] == 0){
            return 0;
        }
        return  userInfos[_userIndexMapping[account]].userBalance;
    }


    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(amount));
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note a
     * the beginning of {ERC20};
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        if(recipient == crowdfundingAddress()){
            _approve(sender, recipient,_allowances[sender][recipient].sub(amount, "ERC20: transfer amount exceeds allowance"));
        } else {
            _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        }
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        // Determine if the recipient already exists
        if(queryAddressIndex(recipient) == 0){
            // if not ,create a userInfoStruct and push it into userInfos array
            userInfoStruct memory _recipient = userInfoStruct(recipient,0);
            userInfos.push(_recipient);
            // Use the array length as the index
            _userIndexMapping[recipient] = userInfosLength() - 1;
        }

        userInfos[queryAddressIndex(sender)].userBalance = userInfos[queryAddressIndex(sender)].userBalance.sub(amount, "ERC20: transfer amount exceeds balance");
        userInfos[queryAddressIndex(recipient)].userBalance = userInfos[queryAddressIndex(recipient)].userBalance.add(amount);
        emit Transfer(sender, recipient, amount);
    }

    // query index of address
    function queryAddressIndex(address _address) internal  view  returns(uint256){
        return _userIndexMapping[_address];
    }

    function userInfosLength() internal  view returns(uint){
        return userInfos.length;
    }

    function getUserInfo(address _address) external view returns(userInfoStruct memory){
        uint256 index = queryAddressIndex(_address);
        if(index == 0){
            return userInfoStruct(_msgSender(), 0);
        }
        return userInfos[index];
    }

    function addTotalSupply(uint256 _amount) internal  returns(bool){
        _totalSupply = _totalSupply.add(_amount);
        return true;
    }

    function reduceTotalSupply(uint256 _amount) internal  returns(bool){
        require(_totalSupply > _amount ,"totalSupply is not enough");
        _totalSupply = _totalSupply.sub(_amount);
        return true;
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);

        if(userInfosLength() == 0){
            userInfoStruct memory zeroAccount = userInfoStruct(address(0),amount);
            userInfoStruct memory _account = userInfoStruct(account,amount);
            userInfos.push(zeroAccount);
            _userIndexMapping[address(0)] = 0;
            userInfos.push(_account);
            _userIndexMapping[account] = userInfosLength()-1 ;
        }else{
            userInfos[queryAddressIndex(account)].userBalance =  userInfos[queryAddressIndex(account)].userBalance.add(amount);
        }

//        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);
        userInfos[queryAddressIndex(account)].userBalance = userInfos[queryAddressIndex(account)].userBalance.sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }

    uint256[44] private __gap;
}

contract HTXRate is ERC20UpgradeSafe{
    // total increment
    uint256  _totalIncrementAmount;
    uint256  _totalDeveloperAmount;
    uint256  _totalDAOAmount;
    uint256  _totalDAOAward;
    uint256  _totalLpAward;
    uint256  PERCENT;

    modifier onlyContractAddress() {
        require(_msgSender() == daoAddress() || _msgSender() == crowdfundingAddress(), "require Contract Address");
        _;
    }

    // Modify the user balance according to the proportion of increase or decrease
    function updateUserBalance(bool _flag, uint256 _rate ,uint256 _developerRate,uint256 _daoRate,uint256 _lpRate) external virtual onlyContractAddress returns(uint256, uint256){
        if(_flag){ // if the price goes down
            priceDown(_rate);
            setTotalDAOAmount(0);
            setTotalDAOAward(0);
        }else{//if the price goes up
            priceUp(_rate ,_developerRate,_daoRate,_lpRate);
        }
        return (_totalDAOAmount, _totalDAOAward);
    }

    //@dev price down
    function priceDown(uint256 _rate) internal{
        uint256 tempTotalAmount = 0;
        for(uint i = 1; i < userInfos.length;i++){
            // excluding  an DAO address and LP address
            if(queryDAOAddressIndex() == i || queryLPAddressIndex() == i){
                continue;
            }
            tempTotalAmount = tempTotalAmount.add(userInfos[i].userBalance);
            uint256 __rate = PERCENT.sub(_rate);
            // reduce user Balance
            userInfos[i].userBalance = userInfos[i].userBalance.mul(__rate).div(10 ** uint256(decimals()));
        }
        reduceTotalSupply((tempTotalAmount.mul(_rate)).div(10 ** uint256(decimals())));
    }

    // @dev price up
    function priceUp(uint256 _rate ,uint256 _developerRate,uint256 _daoRate,uint256 _lpRate) internal  {
        // total increment
        setTotalIncrementAmount(_rate);
        // update develop balance
        setTotalDeveloperAmount(_developerRate);
        // update DAO
        setTotalDAOAmount(_daoRate);
        // update LPAward
        setTotalLPAward(_lpRate);

        //90%
        uint256 tempAmount = _totalIncrementAmount.sub(_totalDeveloperAmount).sub(_totalDAOAmount).sub(_totalLpAward);

        for(uint i = 1; i < userInfos.length; i++){
            // excluding an LP address
            if(queryLPAddressIndex() == i){
                continue;
            }
            //record DAO award
            if(queryDAOAddressIndex() == i){
                setTotalDAOAward(userInfos[i].userBalance.mul(tempAmount).div(totalSupply()));
            }
            // add  user Balance
            userInfos[i].userBalance = userInfos[i].userBalance.add(userInfos[i].userBalance.mul(tempAmount).div(totalSupply()));
        }
        userInfos[queryDAOAddressIndex()].userBalance = userInfos[queryDAOAddressIndex()].userBalance.add(_totalDAOAmount);
        userInfos[queryDeveloperAddressIndex()].userBalance = userInfos[queryDeveloperAddressIndex()].userBalance.add(_totalDeveloperAmount);
        addTotalSupply(_totalIncrementAmount);

        //lp reward
        if(queryAddressIndex(_lpAddress) == 0){
            transfer(_lpAddress,0);
        }

        userInfos[queryLPAddressIndex()].userBalance = userInfos[queryLPAddressIndex()].userBalance.add(_totalLpAward);

        _lpDeposit.reward(_totalLpAward);
    }

    // @dev issuse
    function issueTransfer(address recipient, uint256 amount) external virtual onlyContractAddress returns (bool) {
        _mint(address(this),amount );
        _transfer(address(this), recipient, amount);
        emit IssueTransfer(address(this),recipient,amount ,block.timestamp);
        return true;
    }

    // function of  totalIncrementAmount
    function setTotalIncrementAmount(uint256 _rate ) internal  returns(bool){
        _totalIncrementAmount = (totalSupply().mul(_rate)).div(10 ** uint256(decimals()));
        return true;
    }

    function __totalIncrementAmount() internal view returns(uint256){
        return _totalIncrementAmount;
    }

    function totalIncrementAmount() external view returns(uint256){
        return __totalIncrementAmount();
    }

    // function of totalDAoAmount
    function setTotalDAOAmount(uint256 _daoRate) internal{
        _totalDAOAmount = (_totalIncrementAmount.mul(_daoRate)).div(10 ** uint256(decimals()));
    }

    // function of totalDAOAward
    function setTotalDAOAward(uint256 totalDAOAward_) internal{
        _totalDAOAward = totalDAOAward_;
    }

    // function of totalLpAward
    function setTotalLPAward(uint256 _lpRate) internal{
        _totalLpAward = (_totalIncrementAmount.mul(_lpRate)).div(10 ** uint256(decimals()));
    }


    // function of totalDevelopAmount
    function setTotalDeveloperAmount(uint256 _developerRate) internal returns(bool){
        _totalDeveloperAmount =( _totalIncrementAmount.mul(_developerRate)).div(10 ** uint256(decimals()));
        return true;
    }
    
    function setPercent() internal {
        PERCENT  =  10 ** uint256(decimals());
    }

    // query index of DAO address
    function queryDAOAddressIndex() internal  view returns(uint256){
        return _userIndexMapping[_daoAddress];
    }

    // query index of develop address
    function queryDeveloperAddressIndex() internal view  returns(uint256){
        return _userIndexMapping[_developerAddress];
    }

    // query index of Lp address
    function queryLPAddressIndex() internal  view returns(uint256){
        return _userIndexMapping[_lpAddress];
    }
    
    // init
    function initialize(address crowdfundingAddress_, address daoAddress_, address lpAddress_, address devAddress_) external onlyAdmin{
        _setCrowdfundingAddress(crowdfundingAddress_);
        _setDAOAddress(daoAddress_);
        _setLPAddress(lpAddress_);
        _setDeveloperAddress(devAddress_);
    }
}


contract HTX is HTXRate{
	constructor(string memory _name,string memory _symbol,uint256 initCrowdfunding) public initializer {
        __ERC20_init(_name, _symbol);
		_mint(address(this), initCrowdfunding * 10 ** uint256(decimals()));
		setPercent();
	}
}
