// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract Dex {
    ERC20 public tokenX;
    ERC20 public tokenY;
    

    uint256 public LPtotalSupply;
    mapping(address => uint256) public LPbalance;

    constructor(address _tokenX, address _tokenY) {
        tokenX = ERC20(_tokenX);
        tokenY = ERC20(_tokenY);
    }

    function addLiquidity(uint256 amountX, uint256 amountY, uint256 minLPReturn) external returns (uint256){
        uint256 LPReturn;
        uint256 reserveX = tokenX.balanceOf(address(this));
        uint256 reserveY= tokenY.balanceOf(address(this));
        
        require(tokenX.allowance(msg.sender, address(this)) >= amountX, "ERC20: insufficient allowance");
        require(tokenY.allowance(msg.sender, address(this)) >= amountY, "ERC20: insufficient allowance");
        require(tokenX.balanceOf(msg.sender) >= amountX, "ERC20: transfer amount exceeds balance");
        require(tokenY.balanceOf(msg.sender) >= amountY, "ERC20: transfer amount exceeds balance");

        require(amountX > 0 && amountY > 0, "amount must be greater than 0");

        if (LPtotalSupply == 0) {
            LPReturn = sqrt(amountX * amountY);
        } else {
            LPReturn = min((amountX * LPtotalSupply) / reserveX, (amountY * LPtotalSupply) / reserveY);
        }
        require(LPReturn >= minLPReturn, "slippage limit reached");
        LPtotalSupply += LPReturn;
        LPbalance[msg.sender] += LPReturn;

        

        tokenX.transferFrom(msg.sender, address(this), amountX);
        tokenY.transferFrom(msg.sender, address(this), amountY);

        
        return LPReturn;
    }

    function removeLiquidity(uint256 liquidity, uint256 minAmountX, uint256 minAmountY) external returns (uint256 amountX, uint256 amountY){
        uint256 reserveX = tokenX.balanceOf(address(this));
        uint256 reserveY= tokenY.balanceOf(address(this));
        
        require(LPbalance[msg.sender] >= liquidity, "insufficient LP balance");
        require(liquidity > 0, "liquidity must be greater than 0");
        
        amountX = (liquidity * reserveX) / LPtotalSupply;
        amountY = (liquidity * reserveY) / LPtotalSupply;
        require(amountX >= minAmountX && amountY >= minAmountY, "slippage limit reached");

        LPtotalSupply -= liquidity;
        LPbalance[msg.sender] -= liquidity;

        tokenX.transfer(msg.sender, amountX);
        tokenY.transfer(msg.sender, amountY);

        return (amountX, amountY);
    }

     function swap(uint256 amountX, uint256 amountY, uint256 minAmountOut) external returns (uint256 amountOut) {

        uint256 reserveX = tokenX.balanceOf(address(this));
        uint256 reserveY= tokenY.balanceOf(address(this));
        uint256 newReserveX;
        uint256 newReserveY;

        require((amountX > 0 && amountY == 0) || (amountX == 0 && amountY > 0), "Invalid swap amounts");

        if (amountX > 0) {
            newReserveX = reserveX + amountX;
            newReserveY = (reserveX * reserveY) / newReserveX;
            amountOut = reserveY - newReserveY;

            amountOut = (amountOut * 999) / 1000; // 0.1% fee
            require(amountOut >= minAmountOut, "Insufficient output amount");
            
            tokenX.transferFrom(msg.sender, address(this), amountX);
            tokenY.transfer(msg.sender, amountOut);
        } else {
            newReserveY = reserveY + amountY;
            newReserveX = (reserveX * reserveY) / newReserveY;
            amountOut = reserveX - newReserveX;

            amountOut = (amountOut * 999) / 1000; // 0.1% fee
            require(amountOut >= minAmountOut, "Insufficient output amount");

            tokenY.transferFrom(msg.sender, address(this), amountY);
            tokenX.transfer(msg.sender, amountOut);
        }
     }


    function sqrt(uint x) internal pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }

}