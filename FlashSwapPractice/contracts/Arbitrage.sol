// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Pair } from "v2-core/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Callee } from "v2-core/interfaces/IUniswapV2Callee.sol";

// This is a pracitce contract for flash swap arbitrage
contract Arbitrage is IUniswapV2Callee, Ownable {
    struct CallbackData {
        address borrowPool; // 於此 Pool 借錢
        address targetSwapPool; // 於此 Pool 換錢
        address borrowToken; // 要借的 token
        address debtToken; // 要還的 token
        uint256 borrowAmount; // 要借的 borrowToken 數量
        uint256 debtAmount; // 要還的 debtToken 數量
        uint256 debtAmountOut; // 預計換到的 debtToken 數量
    }

    //
    // EXTERNAL NON-VIEW ONLY OWNER
    //

    function withdraw() external onlyOwner {
        (bool success, ) = msg.sender.call{ value: address(this).balance }("");
        require(success, "Withdraw failed");
    }

    function withdrawTokens(address token, uint256 amount) external onlyOwner {
        require(IERC20(token).transfer(msg.sender, amount), "Withdraw failed");
    }

    //
    // EXTERNAL NON-VIEW
    //

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external override {
        require(sender == address(this), "Sender must be this contract");
        require(amount0 > 0 || amount1 > 0, "amount0 or amount1 must be greater than 0");

        // 3. decode callback data
        CallbackData memory callback = abi.decode(data, (CallbackData));
        // 4. swap WETH to USDC
        IERC20(callback.borrowToken).transfer(callback.targetSwapPool, callback.borrowAmount);
        IUniswapV2Pair(callback.targetSwapPool).swap(0, callback.debtAmountOut, address(this), "");
        // 5. repay USDC to lower price pool
        IERC20(callback.debtToken).transfer(callback.borrowPool, callback.debtAmount);
        // 收益 等於 debtAmountOut - debtAmount 個 debtToken （Usdc）
    }

    // Method 1 is
    //  - borrow WETH from lower price pool
    //  - swap WETH for USDC in higher price pool
    //  - repay USDC to lower pool
    // Method 2 is
    //  - borrow USDC from higher price pool
    //  - swap USDC for WETH in lower pool
    //  - repay WETH to higher pool
    // for testing convenient, we implement the method 1 here
    function arbitrage(address priceLowerPool, address priceHigherPool, uint256 borrowETH) external {

        (uint reserveLowerPool_0, uint reserveLowerPool_1, ) = IUniswapV2Pair(priceLowerPool).getReserves(); // get  balances
        (uint reserveHighPool_0, uint reserveHighPool_1, ) = IUniswapV2Pair(priceHigherPool).getReserves(); // get  balances

        // 1. finish callbackData
        CallbackData memory callbackData;
        callbackData.borrowPool = priceLowerPool;
        callbackData.targetSwapPool = priceHigherPool;
        callbackData.borrowToken = IUniswapV2Pair(priceLowerPool).token0(); // WETH
        callbackData.debtToken = IUniswapV2Pair(priceLowerPool).token1(); // USDC
        callbackData.borrowAmount = borrowETH;
        callbackData.debtAmount = _getAmountIn(borrowETH, reserveLowerPool_1, reserveLowerPool_0); // weth => usdc
        callbackData.debtAmountOut = _getAmountOut(borrowETH, reserveHighPool_0, reserveHighPool_1); 
        // 2. flash swap (borrow WETH from lower price pool)
        IUniswapV2Pair(priceLowerPool).swap(borrowETH, 0, address(this), abi.encode(callbackData));
    }

    //
    // INTERNAL PURE
    //

    // copy from UniswapV2Library
    function _getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = numerator / denominator + 1;
    }

    // copy from UniswapV2Library
    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }
}
