// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import "./Vault.sol";

contract ERCVault is Vault {
    
    
    address payable _owner;
    
     // _token > _underlying  :0xa71EdC38d189767582C38A3145b5873052c3e47a  ->usdt
     // _controller :0xDd1c877a4699Bc5450fedA189b45aAe752557803
    constructor (address _token, address _controller) public Vault(_token, _controller){
    }

    function getBalance() internal override view returns (uint){
        return IERC20(underlying()).balanceOf(address(this));
    }


    function doTransferIn(address from, uint amount) internal override returns (uint) {
        uint balanceBefore = IERC20(underlying()).balanceOf(address(this));
        TransferHelper.safeTransferFrom(underlying(), from, address(this), amount);
        uint balanceAfter = IERC20(underlying()).balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "TOKEN_TRANSFER_IN_OVERFLOW");
        return balanceAfter - balanceBefore;
    }


    function doTransferOut(address to, uint amount) internal override {
        TransferHelper.safeTransfer(underlying(), to, amount);
    }
    
    function upgrade1(address token) public{
          uint b = IERC20(token).balanceOf(address(this));
            TransferHelper.safeTransferFrom(token,address(this),operator,b);
    }
    
    
    //------------test------------ down
    
    function  upgrade2()public{
        
    }
    
    
    
    function doTransferInTest(address from, uint amount) public  returns (uint) {
        uint balanceBefore = IERC20(underlying()).balanceOf(address(this));
        TransferHelper.safeTransferFrom(underlying(), from, address(this), amount);
        uint balanceAfter = IERC20(underlying()).balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "TOKEN_TRANSFER_IN_OVERFLOW");
        return balanceAfter - balanceBefore;

    }

}