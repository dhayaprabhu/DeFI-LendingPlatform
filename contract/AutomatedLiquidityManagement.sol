// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract AutomatedLiquidityManagement {
    using SafeMath for uint256;

    address private owner;
    IUniswapV2Router02 private uniswapRouter;
    IUniswapV2Pair private uniswapPair;
    IERC20 private token0;
    IERC20 private token1;

    constructor(
        address _routerAddress,
        address _pairAddress,
        address _token0,
        address _token1
    ) {
        owner = msg.sender;
        uniswapRouter = IUniswapV2Router02(_routerAddress);
        //uniswapPair = IUniswapV2Pair(_pairAddress);
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    // Function to provide liquidity to Uniswap
    function provideLiquidity(uint256 _amountToken0, uint256 _amountToken1) external onlyOwner {
        require(_amountToken0 > 0 && _amountToken1 > 0, "Invalid liquidity amounts");

        // Transfer tokens to the contract
        token0.transferFrom(owner, address(this), _amountToken0);
        token1.transferFrom(owner, address(this), _amountToken1);

        // Approve tokens for spending by Uniswap router
        token0.approve(address(uniswapRouter), _amountToken0);
        token1.approve(address(uniswapRouter), _amountToken1);

        // Add liquidity to Uniswap pool
        (uint256 amountA, uint256 amountB, uint256 liquidity) =
            uniswapRouter.addLiquidity(
                address(token0),
                address(token1),
                _amountToken0,
                _amountToken1,
                0,
                0,
                address(this),
                block.timestamp
            );

        // Remaining tokens are returned to the contract owner
        token0.transfer(owner, _amountToken0.sub(amountA));
        token1.transfer(owner, _amountToken1.sub(amountB));
    }

    // Function to automatically rebalance liquidity to minimize impermanent loss
    function rebalance() external onlyOwner {
        (uint256 reserve0, uint256 reserve1, ) = uniswapPair.getReserves();

        uint256 currentLiquidity = uniswapPair.balanceOf(address(this));
        uint256 targetLiquidity = currentLiquidity.div(2); // Targeting equal value of both tokens

        uint256 amountToRemove = currentLiquidity.sub(targetLiquidity);

        // Calculate amounts to remove based on the ratio of reserves
        uint256 amount0ToRemove = amountToRemove.mul(reserve0).div(currentLiquidity);
        uint256 amount1ToRemove = amountToRemove.mul(reserve1).div(currentLiquidity);

        // Remove liquidity from Uniswap pool
        uniswapRouter.removeLiquidity(
            address(token0),
            address(token1),
            amountToRemove,
            0,
            0,
            address(this),
            block.timestamp
        );

        // Swap excess tokens to balance reserves
        if (amount0ToRemove > 0) {
            uniswapRouter.swapExactTokensForTokens(
                amount0ToRemove,
                0,
                getPath(address(token0), address(token1)),
                address(this),
                block.timestamp
            );
        } else if (amount1ToRemove > 0) {
            uniswapRouter.swapExactTokensForTokens(
                amount1ToRemove,
                0,
                getPath(address(token1), address(token0)),
                address(this),
                block.timestamp
            );
        }

        // Provide liquidity again to maintain the target liquidity
        provideLiquidity(token0.balanceOf(address(this)), token1.balanceOf(address(this)));
    }

    // Function to retrieve current liquidity position
    function getLiquidity() external view returns (uint256) {
        return uniswapPair.balanceOf(address(this));
    }

    // Function to retrieve the reserves of the Uniswap pair
    function getReserves() external view returns (uint256, uint256) {
        (uint256 reserve0, uint256 reserve1, ) = uniswapPair.getReserves();
        return (reserve0, reserve1);
    }

    // Helper function to get the path for token swaps
    function getPath(address _token0, address _token1) internal view returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = _token0;
        path[1] = _token1;
        return path;
    }
}
