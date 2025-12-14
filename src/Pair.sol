// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";



contract Pair {

    using SafeERC20 for IERC20; // protecting against fake revert on non-standard ERC20 implementations

    event SwapEth(
    address indexed sender,
    uint256 ethIn,
    uint256 tokensOut
    );

    event AddLiquidity(
    address indexed provider,
    uint256 ethAmount,
    uint256 tokenAmount,
    uint256 lpMinted
    );

    event RemoveLiquidity(
    address indexed provider,
    uint256 lpBurned,
    uint256 ethAmount,
    uint256 tokenAmount
    );

    event SwapToken(
    address indexed sender,
    uint256 tokensIn,
    uint256 ethOut
    );

    address public tokenAddress;
    uint256 public ethAmount = 0;
    uint256 public tokenAmount = 0;
    uint256 public totalLp;
    mapping (address => uint256) public balanceLp;

    constructor(address _tokenAddress) {tokenAddress = _tokenAddress;}

    function addLiquidity(uint256 _tokenAmount) public payable {
        require(msg.value > 0, "ethAmount cannot be zero");

        if (ethAmount == 0 && tokenAmount == 0) {

            ethAmount = ethAmount + msg.value;
            bool ok = IERC20(tokenAddress).transferFrom(msg.sender, address(this), _tokenAmount); // user have to approve
            require(ok, "Token transfer failed");
            tokenAmount = tokenAmount + _tokenAmount;
            balanceLp[msg.sender] += Math.sqrt(msg.value * _tokenAmount);
            totalLp += Math.sqrt(msg.value * _tokenAmount);
            emit AddLiquidity(
                msg.sender,
                msg.value,
                _tokenAmount,
                Math.sqrt(msg.value * _tokenAmount)
            );
        }
        else {
            uint256 expectedToken = (msg.value * tokenAmount) / ethAmount;

            require(
                _tokenAmount >= expectedToken && 
                _tokenAmount <= expectedToken + 1,
                "Wrong token amount for this ratio"
            );
            uint256 lpToMint;
            uint256 lpEth;
            uint256 lpToken;


            lpEth = msg.value * totalLp / ethAmount;
            lpToken = _tokenAmount * totalLp / tokenAmount;
            lpToMint = Math.min(lpEth, lpToken);  
            totalLp += lpToMint;
            balanceLp[msg.sender] += lpToMint;
            


            IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), _tokenAmount);
            ethAmount = ethAmount + msg.value;
            tokenAmount = tokenAmount + _tokenAmount;
            emit AddLiquidity(
                msg.sender,
                msg.value,
                _tokenAmount,
                lpToMint
            );
        }
    }
        
    function removeLiquidity(uint256 _lpAmount) public  {

            require(_lpAmount <= balanceLp[msg.sender]);
            require(_lpAmount > 0);

            uint256 ethToReturn = ethAmount * _lpAmount / totalLp;
            uint256 tokenToReturn = tokenAmount * _lpAmount / totalLp;
            require(ethToReturn > 0);
            require(tokenToReturn > 0);

            ethAmount -= ethToReturn;
            tokenAmount -= tokenToReturn;
            balanceLp[msg.sender] -= _lpAmount;
            totalLp -= _lpAmount;
            IERC20(tokenAddress).safeTransfer(msg.sender, tokenToReturn);
            (bool ethSent, ) = msg.sender.call{value: ethToReturn}("");
            require(ethSent, "eth transfer failed");

            emit RemoveLiquidity(
                msg.sender,
                _lpAmount,
                ethToReturn,
                tokenToReturn
            );


    }

    function swapEthForTokens(uint256 _minimumToReceive) external payable {
        // asking for a minimum to receive to protect user against slippage.

        require(msg.value > 0);
        require(tokenAmount > 0 && ethAmount > 0, "empty pool");
        uint256 k = ethAmount * tokenAmount;
        uint256 ethAmountBefore = ethAmount;
        uint256 realEthAmount = msg.value * 997 / 1000;
        uint256 ethAmountAfter = ethAmountBefore + realEthAmount;
        uint256 tokenAmountAfter = k / ethAmountAfter;
        uint256 tokenOut = tokenAmount - tokenAmountAfter; // cannot be greater than tokenAmount
        // tokenOut is rounded in favor of the pool
        require (tokenOut >= _minimumToReceive);
        ethAmount = ethAmount + msg.value;
        tokenAmount = tokenAmountAfter;
        IERC20(tokenAddress).safeTransfer(msg.sender, tokenOut);
        emit SwapEth(msg.sender, msg.value, tokenOut);
    }


    function swapTokensForEth(uint256 _minimumToReceive) external payable {

        require(tokenAmount > 0 && ethAmount > 0, "empty pool");
        uint256 k = ethAmount * tokenAmount;
        uint256 tokenBalBefore = IERC20(tokenAddress).balanceOf(address(this));
        
        IERC20(tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            IERC20(tokenAddress).allowance(msg.sender, address(this))
        );

        uint256 tokenBalAfter = IERC20(tokenAddress).balanceOf(address(this));
        uint256 realTokenAmount = tokenBalAfter - tokenBalBefore;
        require(realTokenAmount > 0, "no tokens received");
        uint256 realTokenForPricing = realTokenAmount * 997 / 1000;

        uint256 tokenAmountAfter = tokenAmount + realTokenForPricing;

        uint256 ethAmountAfter = k / tokenAmountAfter;
        uint256 ethOut = ethAmount - ethAmountAfter;
        require (ethOut > _minimumToReceive, "slippage too high");

        tokenAmount += realTokenAmount;
        ethAmount = ethAmountAfter;

        (bool ethSent, ) = msg.sender.call{value: ethOut}("");
        require(ethSent, "eth transfer failed");

        emit SwapToken(msg.sender, realTokenAmount, ethOut);


    }
    




        
}
