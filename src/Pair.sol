// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract Pair {

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

            bool ok = IERC20(tokenAddress).transferFrom(msg.sender, address(this), _tokenAmount);
            require(ok, "Token transfer failed");
            ethAmount = ethAmount + msg.value;
            tokenAmount = tokenAmount + _tokenAmount;
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
            bool tokenSent = IERC20(tokenAddress).transfer(msg.sender, tokenToReturn);
            require(tokenSent, "token transfer failed");
            (bool ethSent, ) = msg.sender.call{value: ethToReturn}("");
            require(ethSent, "eth transfer failed");

            }
    }
