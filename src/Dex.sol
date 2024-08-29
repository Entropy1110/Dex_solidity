// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract Dex is ERC20("Dex", "DEX") {

    event LogUint(uint256 value);
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
        uint256 reserveY = tokenY.balanceOf(address(this));
        
        require(tokenX.allowance(msg.sender, address(this)) >= amountX, "ERC20: insufficient allowance");
        require(tokenY.allowance(msg.sender, address(this)) >= amountY, "ERC20: insufficient allowance");
        require(tokenX.balanceOf(msg.sender) >= amountX, "ERC20: transfer amount exceeds balance");
        require(tokenY.balanceOf(msg.sender) >= amountY, "ERC20: transfer amount exceeds balance");

        require(amountX > 0 && amountY > 0, "Amount must be greater than 0");


        // 초기 100:200 -> LP=141..
        // 이후 200:100 -> LP=70.5
        // min((200 * 141) / 100, (100 * 141) / 200) = 70.5

        // 현재 X 1000 있는 상태
        // 초기 3000:4000 -> LP=3464..
        // 이후 X 1000 추가
        // 이후 5000:4000 -> LP=1732
        // min((5000 * 3464) / 10000, (4000 * 3464) / 8000) = 1732

        if (LPtotalSupply == 0) { // for the first liquidity provider
            LPReturn = sqrt(amountX * amountY);
            LPtotalSupply += LPReturn;
            LPbalance[msg.sender] += LPReturn;
        } else { // same ratio as the pool's ratio
            uint a = (amountX * LPtotalSupply) / reserveX;
            uint b = (amountY * LPtotalSupply) / reserveY;

            bool isXSmaller = false;

            if (a < b)
                isXSmaller = true;
            
            LPReturn = isXSmaller ? a : b;
            LPbalance[msg.sender] += LPReturn;

            if (isXSmaller) 
                amountY = (LPReturn * reserveY) / LPtotalSupply;
             else 
                amountX = (LPReturn * reserveX) / LPtotalSupply;
            
            LPtotalSupply += LPReturn;
        }

        require(LPReturn >= minLPReturn, "Slippage limit reached");

        _mint(msg.sender, LPReturn);
        

        tokenX.transferFrom(msg.sender, address(this), amountX);
        emit LogUint(amountX);
        tokenY.transferFrom(msg.sender, address(this), amountY);
        emit LogUint(amountY);

        return LPReturn;
    }

    function removeLiquidity(uint256 liquidity, uint256 minAmountX, uint256 minAmountY) external returns (uint256 amountX, uint256 amountY){
        uint256 reserveX = tokenX.balanceOf(address(this));
        uint256 reserveY= tokenY.balanceOf(address(this));
        
        require(LPbalance[msg.sender] >= liquidity, "Insufficient LP balance");
        require(liquidity > 0, "Liquidity must be greater than 0");
        
        amountX = (liquidity * reserveX) / LPtotalSupply;
        amountY = (liquidity * reserveY) / LPtotalSupply;
        require(amountX >= minAmountX && amountY >= minAmountY, "Slippage limit reached");

        LPtotalSupply -= liquidity;
        LPbalance[msg.sender] -= liquidity;

        _burn(msg.sender, liquidity);

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