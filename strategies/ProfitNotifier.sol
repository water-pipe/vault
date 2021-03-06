// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import "openzeppelin/contracts/math/SafeMath.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interfaces/yearn/IController.sol";
import "../interfaces/mdex/IMdexPair.sol";
import "../interfaces/yearn/IStrategy.sol";
import "../interfaces/mdex/ISwapMining.sol";
import "..//Operatable.sol";
import "../lib/TransferHelper.sol";

abstract contract ProfitNotifier is Operatable, IStrategy {
    using SafeMath for uint;

    uint256 public constant  MAX_FEE = 100;

    uint256 public profitSharingFee;
    address public controller;
    address public routerToken;
    address public swapRouter;
    address public swapMining;
    address public rewardToken;

    address internal  _underlying;
    address internal _vault;

    event ProfitLog(
        uint256 oldBalance,
        uint256 newBalance,
        uint256 feeAmount,
        uint256 timestamp
    );

    //mdx
    //_vault vault_address 0x8352eee26b01f23043fbf386f7da80b9c2cee954 > 0x0e8fc3197985046Bd95d3Bd018Fe704D661f9d9B
    //_controller 0xcB04e174e6A1416bb6aF59549cf6ecea0B034830 > 0xDd1c877a4699Bc5450fedA189b45aAe752557803
    // _want > _underlying 0x615E6285c5944540fd8bd921c9c8c56739Fd1E13
    // _pswapRouter 0xED7d5F38C79115ca12fe6C0041abb22F0A06C300
    constructor(
        address _pvault,
        address _controller,
        address _want,
        address _pswapRouter

    ) Operatable() public {
        _vault = _pvault;
        controller = _controller;
        _underlying = _want;
        swapRouter = _pswapRouter;

        // persist in the state for immutability of the fee
        profitSharingFee = 30;
    }


    modifier restricted() {
        require(msg.sender == _vault || msg.sender == address(controller),
            "The sender has to be the controller or vault");
        _;
    }

    modifier vaultControllerAndGeneralUser() {
        require(IController(controller).check(msg.sender) || msg.sender == vault() || msg.sender == controller,
            "address is ban");
        _;
    }

    function setRouterAddress(address _address) onlyOperator external {
        swapRouter = _address;
    }

    function setSwapMining(address _address) onlyOperator external {
        swapMining = _address;
    }

    function setRouterToken(address _address) onlyOperator external {
        routerToken = _address;
    }

    function withdrawSwapMining() external {
        ISwapMining(swapMining).takerWithdraw();
    }

    function notifyProfit(uint256 oldBalance, uint256 newBalance) internal {
        if (newBalance > oldBalance) {
            uint256 profit = newBalance.sub(oldBalance);
            uint256 feeAmount = profit.mul(profitSharingFee).div(MAX_FEE);
            emit ProfitLog(oldBalance, newBalance, feeAmount, block.timestamp);
            TransferHelper.safeTransfer(_underlying, IController(controller).feeManager(), feeAmount);
        } else {
            emit ProfitLog(oldBalance, newBalance, 0, block.timestamp);
        }
    }

    function salvageToken(address _asset) external override returns (uint balance) {
        require(msg.sender == controller, "not operator");
        require(_underlying != _asset, "want");
        balance = IERC20(_asset).balanceOf(address(this));
        TransferHelper.safeTransfer(_asset, controller, balance);
    }

    function setPerformanceFee(uint _performanceFee) onlyOperator external {
        require(_performanceFee <= 35, "fee < 35");
        profitSharingFee = _performanceFee;
    }

    function setController(address payable _controller) onlyOperator external {
        controller = _controller;
    }

    function underlying() public override view returns (address){
        return _underlying;
    }

    function vault() public override view returns (address){
        return _vault;
    }

}
