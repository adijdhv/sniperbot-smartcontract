// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract VirtualsSniper is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // ──────────────── Custom Errors ────────────────
    error ZeroAddress();
    error InvalidSlippage();
    error InvalidToken();
    error InvalidAmounts();
    error InsufficientETH();
    error SlippageTooHigh();
    error AmountOutError();
    error SwapFailed();
    error InvalidPath();
    error InsufficientToken();
    error ETHTransferFailed();
    error NotOwner();
    error NotPaused();
    error NotUnpaused();

    // ──────────────── Events ────────────────
    event SnipeAttempted(address indexed token, uint256 amountIn, uint256 amountOut);
    event SnipeFailed(address indexed token);
    event FundsWithdrawn(address indexed token, uint256 amount);
    event ETHWithdrawn(uint256 amount);
    event MinSlippageUpdated(uint256 oldMinSlippage, uint256 newMinSlippage);

    // ──────────────── State ────────────────
    IUniswapV2Router02 public immutable router;
    address public immutable WETH;
    uint256 public minSlippagePercent = 1;
    uint256 public constant MAX_DEADLINE = 30 minutes;

    constructor(address _router, address _weth) Ownable(msg.sender) {
        if (_router == address(0) || _weth == address(0)) revert ZeroAddress();
        router = IUniswapV2Router02(_router);
        WETH = _weth;
    }

    receive() external payable {}
    fallback() external payable {}

    function setMinSlippagePercent(uint256 _minSlippagePercent) external onlyOwner {
        if (_minSlippagePercent == 0 || _minSlippagePercent > 100) revert InvalidSlippage();
        emit MinSlippageUpdated(minSlippagePercent, _minSlippagePercent);
        minSlippagePercent = _minSlippagePercent;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _validateAndNormalizeDeadline(uint256 _deadline) internal view returns (uint256) {
        return (_deadline <= block.timestamp || _deadline > block.timestamp + MAX_DEADLINE)
            ? block.timestamp + MAX_DEADLINE
            : _deadline;
    }

    function snipeToken(
        address _tokenOut,
        uint256 _amountIn,
        uint256 _minAmountOut,
        uint256 _deadline
    ) external onlyOwner whenNotPaused nonReentrant returns (uint256 amountOut) {
        if (_tokenOut == address(0)) revert InvalidToken();
        if (_amountIn == 0 || _minAmountOut == 0) revert InvalidAmounts();
        if (address(this).balance < _amountIn) revert InsufficientETH();

        address [] memory path = new address[](2);
        path[0] = WETH;
        path[1] = _tokenOut;

        uint256 normalizedDeadline = _validateAndNormalizeDeadline(_deadline);

        try router.getAmountsOut(_amountIn, path) returns (uint256[] memory expectedAmounts) {
            uint256 minExpectedWithSlippage = expectedAmounts[1] * (100 - minSlippagePercent) / 100;
            if (_minAmountOut < minExpectedWithSlippage) revert SlippageTooHigh();

            try router.swapExactETHForTokens{value: _amountIn}(
                _minAmountOut,
                path,
                address(this),
                normalizedDeadline
            ) returns (uint256[] memory amounts) {
                emit SnipeAttempted(_tokenOut, _amountIn, amounts[1]);
                return amounts[1];
            } catch {
                emit SnipeFailed(_tokenOut);
                revert SwapFailed();
            }

        } catch {
            revert AmountOutError();
        }
    }

    function snipeTokenWithPath(
        address[] calldata path,
        uint256 _amountIn,
        uint256 _minAmountOut,
        uint256 _deadline
    ) external onlyOwner whenNotPaused nonReentrant returns (uint256 amountOut) {
        uint256 pathLength = path.length;
        if (pathLength < 2 || path[0] != WETH) revert InvalidPath();
        if (_amountIn == 0 || _minAmountOut == 0) revert InvalidAmounts();
        if (address(this).balance < _amountIn) revert InsufficientETH();

        uint256 normalizedDeadline = _validateAndNormalizeDeadline(_deadline);

        try router.getAmountsOut(_amountIn, path) returns (uint256[] memory expectedAmounts) {
            uint256 minExpectedWithSlippage = expectedAmounts[pathLength - 1] * (100 - minSlippagePercent) / 100;
            if (_minAmountOut < minExpectedWithSlippage) revert SlippageTooHigh();

            try router.swapExactETHForTokens{value: _amountIn}(
                _minAmountOut,
                path,
                address(this),
                normalizedDeadline
            ) returns (uint256[] memory amounts) {
                emit SnipeAttempted(path[pathLength - 1], _amountIn, amounts[pathLength - 1]);
                return amounts[pathLength - 1];
            } catch {
                emit SnipeFailed(path[pathLength - 1]);
                revert SwapFailed();
            }

        } catch {
            revert AmountOutError();
        }
    }

    function withdrawToken(address _token, uint256 _amount) external onlyOwner nonReentrant {
        if (_token == address(0)) revert ZeroAddress();
        if (_amount == 0) revert InvalidAmounts();

        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));
        if (balance < _amount) revert InsufficientToken();

        emit FundsWithdrawn(_token, _amount);
        token.safeTransfer(owner(), _amount);
    }

    function withdrawETH(uint256 _amount) external onlyOwner nonReentrant {
        if (address(this).balance < _amount) revert InsufficientETH();
        if (_amount == 0) revert InvalidAmounts();

        emit ETHWithdrawn(_amount);
        (bool success, ) = owner().call{value: _amount}("");
        if (!success) revert ETHTransferFailed();
    }

    function getTokenBalance(address _token) external view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function getETHBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
