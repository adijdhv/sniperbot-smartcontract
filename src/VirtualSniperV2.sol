// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/**
 * @title VirtualsSniper
 * @dev A contract for sniping tokens on Uniswap V2 compatible DEXs using $VIRTUAL token
 * with improved security features and better error handling using custom errors
 */
contract VirtualsSniper is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    // Custom Errors
    error InvalidAddress();
    error InvalidAmount();
    error InsufficientBalance();
    error SlippageTooHigh();
    error InvalidPath();
    error SwapFailed(string reason);
    error DeadlineExceeded();
    
    // Events
    event SnipeAttempted(address indexed token, uint256 amountIn, uint256 amountOut);
    event SnipeFailed(address indexed token, string reason);
    event FundsWithdrawn(address indexed token, uint256 amount);
    event VirtualTokenUpdated(address oldVirtual, address newVirtual);
    event RouterUpdated(address oldRouter, address newRouter);
    event MinSlippageUpdated(uint256 oldMinSlippage, uint256 newMinSlippage);
    
    // State variables
    IUniswapV2Router02 public router;
    address public virtualToken;
    uint256 public minSlippagePercent = 1;
    uint256 public constant MAX_DEADLINE = 30 minutes;

    constructor(address _router, address _virtualToken) Ownable(msg.sender) {
        if (_router == address(0)) revert InvalidAddress();
        if (_virtualToken == address(0)) revert InvalidAddress();

        router = IUniswapV2Router02(_router);
        virtualToken = _virtualToken;
    }

    function setMinSlippagePercent(uint256 _minSlippagePercent) external onlyOwner {
        if (_minSlippagePercent == 0 || _minSlippagePercent > 100) revert InvalidAmount();
        
        uint256 oldMinSlippage = minSlippagePercent;
        minSlippagePercent = _minSlippagePercent;
        emit MinSlippageUpdated(oldMinSlippage, _minSlippagePercent);
    }

    function updateRouter(address _router) external onlyOwner {
        if (_router == address(0)) revert InvalidAddress();
        
        address oldRouter = address(router);
        router = IUniswapV2Router02(_router);
        emit RouterUpdated(oldRouter, _router);
    }

    function updateVirtualToken(address _virtualToken) external onlyOwner {
        if (_virtualToken == address(0)) revert InvalidAddress();
        
        address oldVirtual = virtualToken;
        virtualToken = _virtualToken;
        emit VirtualTokenUpdated(oldVirtual, _virtualToken);
    }

    function _validateAndNormalizeDeadline(uint256 _deadline) internal view returns (uint256) {
        if (_deadline <= block.timestamp || _deadline > block.timestamp + MAX_DEADLINE) {
            return block.timestamp + MAX_DEADLINE;
        }
        return _deadline;
    }

    function approveVirtual(uint256 _amount) external onlyOwner {
        IERC20(virtualToken).approve(address(router), _amount); 
    }
    function changeVirtualTokenAddress(address _virtualToken) external onlyOwner {
        if (_virtualToken == address(0)) revert InvalidAddress();
        virtualToken = _virtualToken;
    }
    function changeRouterAddress(address _router) external onlyOwner {
        if (_router == address(0)) revert InvalidAddress();
        router = IUniswapV2Router02(_router);
    }
    function snipeToken(
        address _tokenOut,
        uint256 _amountIn,
        uint256 _minAmountOut,
        uint256 _deadline
    ) external onlyOwner whenNotPaused nonReentrant returns (uint256 amountOut) {
        if (_tokenOut == address(0)) revert InvalidAddress();
        if (_amountIn == 0) revert InvalidAmount();
        if (_minAmountOut == 0) revert InvalidAmount();
        
        uint256 balance = IERC20(virtualToken).balanceOf(address(this));
        if (balance < _amountIn) revert InsufficientBalance();
        
        address[] memory path = new address[](2);
        path[0] = virtualToken;
        path[1] = _tokenOut;
        
        uint256 normalizedDeadline = _validateAndNormalizeDeadline(_deadline);

        try router.getAmountsOut(_amountIn, path) returns (uint256[] memory amounts) {
            uint256 minExpectedWithSlippage = amounts[1] * (100 - minSlippagePercent) / 100;
            if (_minAmountOut < minExpectedWithSlippage) revert SlippageTooHigh();
        } catch {
            revert SwapFailed("Failed to get expected output amounts");
        }

        try router.swapExactTokensForTokens(
            _amountIn,
            _minAmountOut,
            path,
            address(this),
            normalizedDeadline
        ) returns (uint256[] memory amounts) {
            emit SnipeAttempted(_tokenOut, _amountIn, amounts[1]);
            return amounts[1];
        } catch Error(string memory reason) {
            emit SnipeFailed(_tokenOut, reason);
            revert SwapFailed(reason);
        } catch {
            emit SnipeFailed(_tokenOut, "Unknown error during swap");
            revert SwapFailed("Unknown error during swap");
        }
    }

    function snipeTokenWithPath(
        address[] calldata path,
        uint256 _amountIn,
        uint256 _minAmountOut,
        uint256 _deadline
    ) external onlyOwner whenNotPaused nonReentrant returns (uint256 amountOut) {
        if (path.length < 2) revert InvalidPath();
        if (path[0] != virtualToken) revert InvalidPath();
        if (_amountIn == 0) revert InvalidAmount();
        if (_minAmountOut == 0) revert InvalidAmount();
        
        uint256 balance = IERC20(virtualToken).balanceOf(address(this));
        if (balance < _amountIn) revert InsufficientBalance();

        uint256 normalizedDeadline = _validateAndNormalizeDeadline(_deadline);

        try router.getAmountsOut(_amountIn, path) returns (uint256[] memory amounts) {
            uint256 minExpectedWithSlippage = amounts[amounts.length - 1] * (100 - minSlippagePercent) / 100;
            if (_minAmountOut < minExpectedWithSlippage) revert SlippageTooHigh();
        } catch {
            revert SwapFailed("Failed to get expected output amounts");
        }

        try router.swapExactTokensForTokens(
            _amountIn,
            _minAmountOut,
            path,
            address(this),
            normalizedDeadline
        ) returns (uint256[] memory amounts) {
            emit SnipeAttempted(path[path.length - 1], _amountIn, amounts[amounts.length - 1]);
            return amounts[amounts.length - 1];
        } catch Error(string memory reason) {
            emit SnipeFailed(path[path.length - 1], reason);
            revert SwapFailed(reason);
        } catch {
            emit SnipeFailed(path[path.length - 1], "Unknown error during swap");
            revert SwapFailed("Unknown error during swap");
        }
    }

    function withdrawToken(address _token, uint256 _amount) external onlyOwner nonReentrant {
        if (_token == address(0)) revert InvalidAddress();

        uint256 balance = IERC20(_token).balanceOf(address(this));
        if (balance < _amount) revert InsufficientBalance();

        IERC20(_token).safeTransfer(owner(), _amount);
        emit FundsWithdrawn(_token, _amount);
    }

    function getTokenBalance(address _token) external view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }
}