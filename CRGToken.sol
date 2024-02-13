1111pragma solidity ^0.5.16;

import "./CargioSafeMath.sol";
import "./Ownable.sol";
import "./IBEP20.sol";

contract CRGToken is Context, IBEP20, Ownable {
    using CargioSafeMath for uint256;

    event NewDaoAddress(address oldDaoAddress, address newDaoAddress);
    event NewBurnRate(uint256 oldBurnRate, uint256 newBurnRate);
    event NewDaoRate(uint256 oldDaoRate, uint256 newDaoRate);
    event AddReceiver(address indexed account);
    event RemoveReceiver(address indexed account);


    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;
    uint8 private _decimals;
    string private _symbol;
    string private _name;

    uint256 private constant maxRate = 5000;
    uint256 private constant rateDecimal = 10000;
    uint256 public burnRate;
    address public daoAddress;
    mapping(address => bool) public recipientlist;

    constructor() public {
        _name = "Cargio Token";
        _symbol = "CRG";
        _decimals = 18;
        burnRate = 0;
        daoRate = 0;
        daoAddress = address(0);
        _totalSupply = 12_000_000 * (10 ** uint256(_decimals));
        _balances[msg.sender] = _totalSupply;

        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function getOwner() external view returns (address) {
        return owner();
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "decreased allowance below zero"));
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "transfer from the zero address");
        require(recipient != address(0), "transfer to the zero address");

        if(recipientlist[recipient]){
            _balances[sender] = _balances[sender].sub(amount, "transfer amount exceeds balance");
            _balances[recipient] = _balances[recipient].add(amount);
            emit Transfer(sender, recipient, amount);
        } else {
            (uint256 reciAmount, uint256 burnAmount, uint256 daoFee) = _calculateValues(amount);
            _balances[sender] = _balances[sender].sub(amount, "transfer amount exceeds balance");
            _balances[recipient] = _balances[recipient].add(reciAmount);
            emit Transfer(sender, recipient, reciAmount);
            if(burnAmount > 0){
                _totalSupply = _totalSupply.sub(burnAmount);
                emit Transfer(sender, address(0), burnAmount);
            }
            if(daoFee > 0){
                _balances[daoAddress] = _balances[daoAddress].add(daoFee);
                emit Transfer(sender, daoAddress, daoFee);
            }
        }
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "burn from the zero address");

        _balances[account] = _balances[account].sub(amount, "burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "approve from the zero address");
        require(spender != address(0), "approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, _msgSender(), _allowances[account][_msgSender()].sub(amount, "burn amount exceeds allowance"));
    }

    function changeBurnRate(uint256 newBurnRate) external onlyOwner {
        require(newBurnRate <= maxRate, "Burn Rate overflow");
        require(newBurnRate >= 0, "Burn Rate can't be negative");

        uint256 oldBurnRate = burnRate;
        burnRate = newBurnRate;
        emit NewBurnRate(oldBurnRate, newBurnRate);
    }

    function changeDaoRate(uint256 newDaoRate) external onlyOwner {
        require(newDaoRate <= maxRate, "Dao Rate overflow");
        require(newDaoRate >= 0, "Dao Rate can't be negative");

        uint256 oldDaoRate = daoRate;
        daoRate = newDaoRate;
        emit NewDaoRate(oldDaoRate, newDaoRate);
    }

    function changeDaoAddress(address newDaoAddress) external onlyOwner {
        require(newDaoAddress != address(0), "Address can't be zero");

        address oldDaoAddress = daoAddress;
        daoAddress = newDaoAddress;
        emit NewDaoAddress(oldDaoAddress, newDaoAddress);
    }

    function _calculateBurnAmount(uint256 amount) private view returns (uint256) {
        if(burnRate <= 0){
            return 0;
        }
        return amount.mul(burnRate).div(rateDecimal);
    }

    function _calculateDaoFee(uint256 amount) private view returns (uint256) {
        if(daoRate <= 0 || daoAddress==address(0)){
            return 0;
        }
        return amount.mul(daoRate).div(rateDecimal);
    }

    function _calculateValues(uint256 amount) private view returns (uint256, uint256, uint256){
        uint256 burnValue = _calculateBurnAmount(amount);
        uint256 daoValue = _calculateDaoFee(amount);
        uint256 recValue = amount.sub(burnValue).sub(daoValue);
        return (recValue, burnValue, daoValue);
    }

    function addlist(address account) external onlyOwner {
        recipientlist[account] = true;
        emit AddReceiver(account);
    }

    function removeWhitelist(address account) external onlyOwner {
        delete recipientWhitelist[account];
        emit RemoveReceiver(account);
    }
}
