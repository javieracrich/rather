//SPDX-License-Identifier: Unlicense
pragma solidity ^0.6.12;

import "hardhat/console.sol";
import "@sushiswap/core/contracts/MasterChef.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@sushiswap/core/contracts/uniswapv2/interfaces/IUniswapV2Pair.sol";

interface IMasterChef {
    function deposit(uint256 _pid, uint256 _amount) external;
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);
}

interface IUniswapV2Router02 {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );
}

contract RatherWaller is Ownable {
    // WALLET FEATURES
    // needs to be able to deposit erc20 tokens
    // needs to be able to withdraw erc20 tokens
    // needs to be able to get token balance

    // CONTRACT FEATURES
    // 1. needs to approve sushiswap router
    // 2. needs to be able to deposit a pair of erc20tokens to sushiswap contract (provide liquidity) and receive the corresponding SLP token
    // 3. approve masterchef to use tokens
    // 4. needs to be able to deposit the SLP tokens to a sushiswap farm to earn SUSHI tokens.
    // 5. needs to be able to withdraw liquidity from the sushiswap pool.

    mapping(string => address) public registeredTokens;

    /// @dev address of the sushiswap v2 router
    // https://dev.sushi.com/sushiswap/contracts MAINNET
    IUniswapV2Router02 public constant SUSHI_V2_ROUTER_02 =
        IUniswapV2Router02(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);

    IUniswapV2Factory public constant SUSHI_V2_FACTORY =
        IUniswapV2Factory(0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac);

    IMasterChef public constant SUSHI_V2_MASTERCHEF =
        IMasterChef(0xEF0881eC094552b2e128Cf945EF17a6752B4Ec5d);

    constructor() public {}

    function provideLiquidityToSushiswap(
        ERC20 tokenA,
        ERC20 tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) public {
        require(tokenA != IERC20(address(0)), "tokenA address is not valid");
        require(tokenB != IERC20(address(0)), "tokenB address is not valid");
        require(amountADesired > 0, "amountADesired must be greater than 0");
        require(amountBDesired > 0, "amountBDesired must be greater than 0");

        require(
            registeredTokens[tokenA.name()] != address(0),
            "token A is not registered"
        );
        require(
            registeredTokens[tokenB.name()] != address(0),
            "token B is not registered"
        );

        require(
            tokenA.balanceOf(msg.sender) >= amountADesired,
            "insufficient balance in tokenA"
        );

        require(
            tokenB.balanceOf(msg.sender) >= amountBDesired,
            "insufficient balance in tokenB"
        );

        /// @dev STEP 1 - approve the sushiswap router to use the tokens
        tokenA.approve(address(SUSHI_V2_ROUTER_02), amountADesired);
        tokenB.approve(address(SUSHI_V2_ROUTER_02), amountBDesired);

        /// @dev STEP 2 - deposit the tokens to the sushiswap router
        uint256 deadline = block.timestamp + 10 minutes;

        (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        ) = SUSHI_V2_ROUTER_02.addLiquidity(
                address(tokenA),
                address(tokenB),
                amountADesired,
                amountBDesired,
                amountAMin,
                amountBMin,
                address(this),
                deadline
            );

        /// @dev STEP 3 - approve masterchef contract to use the tokens
        tokenA.approve(address(SUSHI_V2_MASTERCHEF), amountADesired);
        tokenB.approve(address(SUSHI_V2_MASTERCHEF), amountBDesired);

        IUniswapV2Pair pair = IUniswapV2Pair(
            SUSHI_V2_FACTORY.getPair(address(tokenA), address(tokenB))
        );

        /// @dev STEP 4 - deposit the tokens to the sushiswap farm
        //how can i get the pair id ? to pass a parameter ?
        //      SUSHI_V2_MASTERCHEF.deposit(pair, liquidity);
    }

    /// @dev registers name and address of erc20 token so it can be used in this contract
    function registerToken(string memory tokenName, address _tokenAddress)
        public
        onlyOwner
    {
        require(
            registeredTokens[tokenName] == address(0),
            "token already registered"
        );
        registeredTokens[tokenName] = _tokenAddress;
    }

    ///// @dev deposit liquidity of a registered token
    function depositToken(string memory tokenName, uint256 amount)
        external
        onlyOwner
    {
        require(
            registeredTokens[tokenName] != address(0),
            "token is not registered"
        );

        IERC20 tokenAddress = IERC20(registeredTokens[tokenName]);

        require(
            tokenAddress.balanceOf(msg.sender) >= amount,
            "insufficient balance"
        );

        tokenAddress.approve(address(this), amount);

        bool success = tokenAddress.transferFrom(
            _msgSender(),
            address(this),
            amount
        );
        if (!success) {
            revert("transfer failed");
        }
    }

    /// @dev removes liquidity of a registered token
    function withdrawToken(string memory tokenName, uint256 amount)
        external
        onlyOwner
    {
        require(
            registeredTokens[tokenName] != address(0),
            "token is not registered"
        );

        IERC20 tokenAddress = IERC20(registeredTokens[tokenName]);

        require(
            tokenAddress.balanceOf(address(this)) >= amount,
            "insufficient balance"
        );

        bool success = tokenAddress.transfer(msg.sender, amount);
        if (!success) {
            revert("transfer failed");
        }
    }

    /// @dev checks current balance of of a registered token
    function balanceOf(string memory tokenName)
        external
        view
        onlyOwner
        returns (uint256)
    {
        IERC20 tokenAddress = IERC20(registeredTokens[tokenName]);
        return tokenAddress.balanceOf(address(this));
    }
}
