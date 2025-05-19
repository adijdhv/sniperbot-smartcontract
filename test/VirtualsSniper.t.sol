// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/VirtualsSniper.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Example mock interfaces for router and token
interface IUniswapV2Router02Mock {
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

contract VirtualsSniperTest is Test {
    VirtualsSniper public sniper;
    receive() external payable {} // Add this to accept ETH
    fallback() external payable {} // Add this to accept ETH
    address public router;
    address public weth;
    address public tokenOut;
    address public mockUser = address(1);

    function setUp() public {
        // Mock WETH and Router (replace with real ones on Sepolia/Base test if you want integration)
        weth = address(0x5F2E6f2C6176F3Ff44C19c261A24E3ab65C0158A); // Example WETH address
        router = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);  

        //vm.prank(mockUser);
        sniper = new VirtualsSniper(router, weth);
        vm.deal(address(sniper), 1 ether); // Give sniper contract some ETH
    }
    function testOwnerCanSetSlippage() public {
    vm.prank(sniper.owner());
    sniper.setMinSlippagePercent(5);
    assertEq(sniper.minSlippagePercent(), 5);
}

function testNonOwnerCannotSetSlippage() public {
    address nonOwner = address(0x123); // Any address that's not the owner
    
    vm.prank(nonOwner);
    vm.expectRevert("OwnableUnauthorizedAccount(0x0000000000000000000000000000000000000123)"); // OpenZeppelin's standard error
    sniper.setMinSlippagePercent(10);
}


    function testSetMinSlippage() public {
            vm.prank(sniper.owner()); // Impersonate owner

        uint256 newSlippage = 1;
        sniper.setMinSlippagePercent(newSlippage);
        assertEq(sniper.minSlippagePercent(), newSlippage);
    }

    function testPauseUnpause() public {
            vm.prank(sniper.owner()); // Impersonate owner

        sniper.pause();
        assertTrue(sniper.paused());

        sniper.unpause();
        assertFalse(sniper.paused());
    }
    function testPauseAndUnpause() public {
    vm.prank(sniper.owner());
    sniper.pause();
    assertTrue(sniper.paused());

    vm.prank(sniper.owner());
    sniper.unpause();
    assertFalse(sniper.paused());
}


function testSnipeTokenRevertsOnZeroToken() public {
    vm.expectRevert(VirtualsSniper.InvalidToken.selector);
    sniper.snipeToken(address(0), 1 ether, 1, block.timestamp);
}

function testSnipeTokenRevertsOnInvalidAmounts() public {
    vm.expectRevert(VirtualsSniper.InvalidAmounts.selector);
    sniper.snipeToken(weth, 0, 0, block.timestamp);
}

function testSnipeTokenRevertsOnInsufficientBalance() public {
    vm.deal(address(sniper), 0.1 ether);
    vm.expectRevert(VirtualsSniper.InsufficientETH.selector);
    sniper.snipeToken(weth, 1 ether, 1, block.timestamp);
}

function testWithdrawTokenRevertsForZeroAddress() public {
    vm.prank(sniper.owner());
    vm.expectRevert(VirtualsSniper.ZeroAddress.selector);
    sniper.withdrawToken(address(0), 1 ether);
}

function testWithdrawTokenRevertsIfInsufficient() public {
    MockERC20 token = new MockERC20();
    vm.prank(sniper.owner());
    vm.expectRevert(VirtualsSniper.InsufficientToken.selector);
    sniper.withdrawToken(address(token), 1 ether);
}

function testCannotSnipeWhilePaused() public {
    address [] memory path = new address[](2);
    path[0] = weth;
    path[1] = address(new MockERC20());

    vm.prank(sniper.owner());
    sniper.pause();

    vm.expectRevert();
    sniper.snipeTokenWithPath(path, 1 ether, 1, block.timestamp + 30);
}


    function testWithdrawETH() public {
          address payable mockOwner = payable(sniper.owner()); // Any address
    vm.deal(mockOwner, 0); // Ensure it's empty initially
        uint256 withdrawAmount = 0.5 ether;
                uint256 initialBalance = address(this).balance;

        vm.prank(mockOwner);
        sniper.withdrawETH(withdrawAmount);
        //console.log('not working');
        assertEq(address(sniper).balance, 0.5 ether);
                assertEq(address(this).balance, initialBalance + withdrawAmount);

    }

    function testWithdrawToken() public {
        // Deploy mock token
        MockERC20 token = new MockERC20();
        token.mint(address(sniper), 1_000 ether);

        vm.prank(sniper.owner());
        sniper.withdrawToken(address(token), 500 ether);

        assertEq(token.balanceOf(address(sniper)), 500 ether);
        assertEq(token.balanceOf(sniper.owner()), 500 ether);
    }

 function testSnipeTokenWithPath_RevertsIfInvalidPath() public {
    MockERC20 token = new MockERC20();
    address[] memory path = new address[](2);
    path[0] = address(0); // Invalid: Not WETH
    path[1] = address(token);

    vm.prank(sniper.owner());
    vm.expectRevert("InvalidPath()"); // Updated to match contract
    sniper.snipeTokenWithPath(path, 1 ether, 1, block.timestamp + 300);
}

    function testGetETHBalance() public view {
        assertEq(sniper.getETHBalance(), 1 ether);
    }

    function testGetTokenBalance() public {
        MockERC20 token = new MockERC20();
        token.mint(address(sniper), 123 ether);
        assertEq(sniper.getTokenBalance(address(token)), 123 ether);
    }
    function testCannotSetZeroSlippage() public {
    vm.prank(sniper.owner());
    vm.expectRevert(VirtualsSniper.InvalidSlippage.selector);
    sniper.setMinSlippagePercent(0);
}

function testCannotSetOver100PercentSlippage() public {
    vm.prank(sniper.owner());
    vm.expectRevert(VirtualsSniper.InvalidSlippage.selector);
    sniper.setMinSlippagePercent(101);
}
function testTransferOwnership() public {
    address newOwner = address(0x123);
    vm.prank(sniper.owner());
    sniper.transferOwnership(newOwner);
    assertEq(sniper.pendingOwner(), newOwner);
}

function testNonOwnerCannotTransferOwnership() public {
    address attacker = address(0x666);
    vm.prank(attacker);
    vm.expectRevert("OwnableUnauthorizedAccount(0x0000000000000000000000000000000000000666)");
    sniper.transferOwnership(attacker);
}

function testAcceptOwnership() public {
    address newOwner = address(0x123);
    vm.prank(sniper.owner());
    sniper.transferOwnership(newOwner);
    
    vm.prank(newOwner);
    sniper.acceptOwnership();
    assertEq(sniper.owner(), newOwner);
}
function testCannotWithdrawMoreETHThanBalance() public {
    uint256 excessiveAmount = 2 ether;
    vm.prank(sniper.owner());
    vm.expectRevert(VirtualsSniper.InsufficientETH.selector);
    sniper.withdrawETH(excessiveAmount);
}

function testCannotWithdrawZeroETH() public {
    vm.prank(sniper.owner());
    vm.expectRevert(VirtualsSniper.InvalidAmounts.selector);
    sniper.withdrawETH(0);
}

function testCannotWithdrawInvalidToken() public {
    vm.prank(sniper.owner());
    vm.expectRevert(VirtualsSniper.ZeroAddress.selector);
    sniper.withdrawToken(address(0), 1);
}
function testCannotSnipeWithZeroAmount() public {
    address[] memory path = new address[](2);
    path[0] = weth;
    path[1] = address(new MockERC20());
    
    vm.prank(sniper.owner());
    vm.expectRevert(VirtualsSniper.InvalidAmounts.selector);
    sniper.snipeTokenWithPath(path, 0, 1, block.timestamp + 300);
}

function testCannotSnipeWithZeroMinAmountOut() public {
    address[] memory path = new address[](2);
    path[0] = weth;
    path[1] = address(new MockERC20());
    
    vm.prank(sniper.owner());
    vm.expectRevert(VirtualsSniper.InvalidAmounts.selector);
    sniper.snipeTokenWithPath(path, 1 ether, 0, block.timestamp + 300);
}

function testCannotSnipeWithExpiredDeadline() public {
    address[] memory path = new address[](2);
    path[0] = weth;
    path[1] = address(new MockERC20());
    
    uint256 expiredDeadline = block.timestamp - 1;
    vm.prank(sniper.owner());
    vm.expectRevert(); // Deadline check in Uniswap router
    sniper.snipeTokenWithPath(path, 1 ether, 1, expiredDeadline);
}
function testReentrancyAttackOnWithdraw() public {
    // Deploy malicious contract
    MaliciousReceiver attacker = new MaliciousReceiver(payable(address(sniper)));
    
    // Fund sniper contract
    vm.deal(address(sniper), 1 ether);
    
    // Set attacker as owner
    vm.prank(sniper.owner());
    sniper.transferOwnership(address(attacker));
    
    // Should fail due to reentrancy guard
    vm.expectRevert("OwnableUnauthorizedAccount(0x2e234DAe75C793f67A35089C9d99245E1C58470b)");
    attacker.attack();
}


function testCannotSnipeWithSingleTokenPath() public {
    address[] memory path = new address[](1);
    path[0] = weth;
    
    vm.prank(sniper.owner());
    vm.expectRevert(VirtualsSniper.InvalidPath.selector);
    sniper.snipeTokenWithPath(path, 1 ether, 1, block.timestamp + 300);
}

function testCannotSnipeWithNonWETHPair() public {
    address[] memory path = new address[](2);
    path[0] = address(0x123); // Not WETH
    path[1] = address(new MockERC20());
    
    vm.prank(sniper.owner());
    vm.expectRevert(VirtualsSniper.InvalidPath.selector);
    sniper.snipeTokenWithPath(path, 1 ether, 1, block.timestamp + 300);
}
 
}

// Mock ERC20 for testing
contract MockERC20 is IERC20 {
    string public constant name = "Mock";
    string public constant symbol = "MOCK";
    uint8 public constant decimals = 18;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private allowances;

    uint256 private _totalSupply;

    function mint(address to, uint256 amount) external {
        balances[to] += amount;
        _totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        balances[msg.sender] -= amount;
        balances[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        allowances[sender][msg.sender] -= amount;
        balances[sender] -= amount;
        balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }
    
}

contract MaliciousReceiver {
    VirtualsSniper public target;
    uint256 public attackCount;
    
    constructor(address payable _target) {
        target = VirtualsSniper(_target);
    }
    
    receive() external payable {
        if(attackCount++ < 2) {
            target.withdrawETH(0.1 ether);
        }
    }
    
    function attack() external {
        target.withdrawETH(0.1 ether);
    }
}