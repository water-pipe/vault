// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import "openzeppelin/contracts/math/Math.sol";
import "openzeppelin/contracts/math/SafeMath.sol";

import "../interfaces/mdex/IMDexRouter.sol";
import "../interfaces/yearn/IVault.sol";
import "../interfaces/yearn/IStrategy.sol";
import "../interfaces/IMasterChef.sol";
import "../interfaces/mdex/IMdexPair.sol";
import "./AbstractLPStrategy.sol";

contract MdexBoardroomLPStrategy is AbstractLPStrategy {
    using SafeMath for uint;

    address public rewardPool;
    uint public poolID;





    // _poolID >  0
     //mdx
    //_vault vault_address 0x8352eee26b01f23043fbf386f7da80b9c2cee954 > 0x0e8fc3197985046Bd95d3Bd018Fe704D661f9d9B
    //_controller 0xcB04e174e6A1416bb6aF59549cf6ecea0B034830 > 0xDd1c877a4699Bc5450fedA189b45aAe752557803
    // _want > _underlying 0x615E6285c5944540fd8bd921c9c8c56739Fd1E13

    //_rewardPool > airdrop  0x9197d717a4F45B672aCacaB4CC0C6e09222f8695 > 0x25034d246d79Df1070d66136c23cb5713F65dED2
   
    // _pswapRouter 0xED7d5F38C79115ca12fe6C0041abb22F0A06C300
    //_rewardToken > 0x5545153CCFcA01fbd7Dd11C0b23ba694D9509A6F
    constructor(
        address _vault,
        address _controller,
        address _underlying,
        address _rewardPool,
        uint256 _poolID,
        address _rewardToken,
        address _swapRouter
    ) AbstractLPStrategy(_vault, _controller, _underlying, _rewardToken, _swapRouter) public {
        address _lpt;
        rewardPool = _rewardPool;
        rewardToken = _rewardToken;
        (_lpt,,,) = IMasterChef(rewardPool).poolInfo(_poolID);
        require(_lpt == underlying(), "Pool Info does not match underlying");

        poolID = _poolID;
    }

    function balanceOfPool() public view returns (uint256 bal) {
        (bal,) = IMasterChef(rewardPool).userInfo(poolId(), address(this));
    }

    function exitRewardPool() internal {
        uint256 bal = balanceOfPool();
        if (bal != 0) {
            IMasterChef(rewardPool).withdraw(poolId(), bal);
        }
    }

    function enterRewardPool() internal {
        uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));
        TransferHelper.safeApprove(underlying(), rewardPool, 0);
        TransferHelper.safeApprove(underlying(), rewardPool, entireBalance);
        IMasterChef(rewardPool).deposit(poolId(), entireBalance);
    }

    function emergencyWithdraw(uint _amount) public onlyOperator {
        if (_amount != 0) {
            IMasterChef(rewardPool).emergencyWithdraw(poolId());
        }
    }

    function invest() public vaultControllerAndGeneralUser override {
        // this check is needed, because most of the SNX reward pools will revert if
        // you try to stake(0).
        if (IERC20(underlying()).balanceOf(address(this)) > 0) {
            enterRewardPool();
        }
    }

    function withdrawAllToVault() public override restricted {
        if (rewardPool != address(0)) {
            exitRewardPool();
        }
        _liquidateReward();
        TransferHelper.safeTransfer(underlying(), vault(), IERC20(underlying()).balanceOf(address(this)));
    }

    function withdrawToVault(uint256 amount) public override restricted {
        // Typically there wouldn't be any amount here
        // however, it is possible because of the emergencyExit
        uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));

        if (amount > entireBalance) {
            // While we have the check above, we still using SafeMath below
            // for the peace of mind (in case something gets changed in between)
            uint256 needToWithdraw = amount.sub(entireBalance);
            uint256 toWithdraw = Math.min(balanceOfPool(), needToWithdraw);
            IMasterChef(rewardPool).withdraw(poolId(), toWithdraw);
        }

        TransferHelper.safeTransfer(underlying(), vault(), amount);
    }

    /*
    *   Note that we currently do not have a mechanism here to include the
    *   amount of reward that is accrued.
    */
    function underlyingBalance() external override view returns (uint256) {
        if (rewardPool == address(0)) {
            return IERC20(underlying()).balanceOf(address(this));
        }
        // Adding the amount locked in the reward pool and the amount that is somehow in this contract
        // both are in the units of "underlying"
        // The second part is needed because there is the emergency exit mechanism
        // which would break the assumption that all the funds are always inside of the reward pool
        return balanceOfPool().add(IERC20(underlying()).balanceOf(address(this)));
    }

    function harvest() external override vaultControllerAndGeneralUser {
        getPoolReward();
        _liquidateReward();
        invest();
    }

    // deposit 0 can claim all pending amount
    function getPoolReward() internal {
        IMasterChef(rewardPool).deposit(poolId(), 0);
    }

    function poolId() public view returns (uint256) {
        return poolID;
    }

}
