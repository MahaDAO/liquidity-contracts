// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {INonfungiblePositionManager} from "../interfaces/INonfungiblePositionManager.sol";
import {IRouter} from "../interfaces/IRouter.sol";
import {VersionedInitializable} from "../proxy/VersionedInitializable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICurveCryptoV2} from "../interfaces/ICurveCryptoV2.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

// collect tokens and use it to add liquidity to ARTH/ETH and ARTH/MAHA LP pairs.
contract UniswapV3Router is Ownable, VersionedInitializable, IRouter {
    using SafeMath for uint256;
    address me;

    INonfungiblePositionManager public manager;
    uint256 public poolId;
    IERC20 public token0;
    IERC20 public token1;
    IUniswapV3Factory public factory =
        IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    ISwapRouter public swapRouter =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IUniswapV3Pool public pool;

    function initialize(
        address _treasury,
        INonfungiblePositionManager _manager,
        uint256 _poolId,
        IERC20 _token0,
        IERC20 _token1,
        uint24 _fee
    ) external initializer {
        me = address(this);

        manager = _manager;
        poolId = _poolId;

        pool = IUniswapV3Pool(
            factory.getPool(address(_token0), address(_token1), _fee)
        );

        token0 = IERC20(pool.token0());
        token1 = IERC20(pool.token1());

        token0.approve(address(manager), type(uint256).max);
        token1.approve(address(manager), type(uint256).max);

        token0.approve(address(swapRouter), type(uint256).max);
        token1.approve(address(swapRouter), type(uint256).max);

        _transferOwnership(_treasury);
    }

    function getRevision() public pure virtual override returns (uint256) {
        return 1;
    }

    function _swapExactInputSingle(
        address tokenIn_,
        address tokenOut_,
        uint256 amountIn_,
        uint24 fee_
    ) internal returns (uint256 amountOut) {
        TransferHelper.safeTransferFrom(tokenIn_, msg.sender, me, amountIn_);

        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn_,
                tokenOut: tokenOut_,
                fee: fee_,
                recipient: me,
                deadline: block.timestamp,
                amountIn: amountIn_,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        amountOut = swapRouter.exactInputSingle(params);
    }

    function _swapExactOutputSingle(
        address tokenIn_,
        address tokenOut_,
        uint256 amountOut_,
        uint24 fee_,
        uint256 amountInMaximum
    ) internal returns (uint256 amountIn) {
        TransferHelper.safeTransferFrom(
            tokenIn_,
            msg.sender,
            me,
            amountInMaximum
        );

        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter
            .ExactOutputSingleParams({
                tokenIn: tokenIn_,
                tokenOut: tokenOut_,
                fee: fee_,
                recipient: me,
                deadline: block.timestamp,
                amountOut: amountOut_,
                amountInMaximum: amountInMaximum,
                sqrtPriceLimitX96: 0
            });

        // Executes the swap returning the amountIn needed to spend to receive the desired amountOut.
        amountIn = swapRouter.exactOutputSingle(params);

        // For exact output swaps, the amountInMaximum may not have all been spent.
        // If the actual amount spent (amountIn) is less than the specified maximum amount, we must refund the msg.sender and approve the swapRouter to spend 0.
        if (amountIn < amountInMaximum) {
            TransferHelper.safeTransfer(
                tokenIn_,
                msg.sender,
                amountInMaximum - amountIn
            );
        }
    }

    function _execute(
        uint256 token0Amount,
        uint256 token1Amount,
        uint256 amount0Min,
        uint256 amount1Min
    ) internal {
        // take tokens from the master router
        token0.transferFrom(msg.sender, me, token0Amount);
        token1.transferFrom(msg.sender, me, token1Amount);

        INonfungiblePositionManager.IncreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .IncreaseLiquidityParams({
                    tokenId: poolId,
                    amount0Desired: token0Amount,
                    amount1Desired: token1Amount,
                    amount0Min: amount0Min,
                    amount1Min: amount1Min,
                    deadline: block.timestamp
                });

        manager.increaseLiquidity(params);
    }

    function _getPrice() internal view returns (uint256 price) {
        (uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
        assembly {
            price := shr(
                192,
                mul(mul(sqrtPriceX96, sqrtPriceX96), 1000000000000000000)
            )
        }
    }

    function execute(
        uint256 token0Amount,
        uint256 token1Amount,
        bytes calldata extraData
    ) external override {
        (uint256 amount0Min, uint256 amount1Min) = abi.decode(
            extraData,
            (uint256, uint256)
        );

        uint256 price = _getPrice();
        uint256 amount1ByExchangeRate = (token1Amount * price) / 1e18;

        // that means amount1 is more than amount0 so need to swap token1 to token0
        if (
            amount1ByExchangeRate > token0Amount &&
            amount1ByExchangeRate - token0Amount > 2 * 1e18
        ) {
            uint256 swapAmountOut = (amount1ByExchangeRate - token0Amount) / 2;
            _swapExactOutputSingle(
                address(token1),
                address(token0),
                swapAmountOut,
                10000,
                token1.balanceOf(me)
            );
        } else if (
            amount1ByExchangeRate < token0Amount &&
            token0Amount - amount1ByExchangeRate > 2 * 1e18
        ) {
            uint256 swapAmountIn = (token0Amount - amount1ByExchangeRate) / 2;
            _swapExactInputSingle(
                address(token0),
                address(token1),
                swapAmountIn,
                10000
            );
        }

        token0Amount = token0.balanceOf(me);
        token1Amount = token1.balanceOf(me);
        _execute(token0Amount, token1Amount, amount0Min, amount1Min);
    }

    function checkUpkeep(
        bytes calldata checkData
    )
        external
        pure
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        if (checkData.length > 0) {
            (uint256 token0Amount, uint256 token1Amount) = abi.decode(
                checkData,
                (uint256, uint256)
            );

            // uint256 minLptokens = pool.calc_token_amount([tokenArthAmount, 0]);
            return (true, abi.encode(token0Amount, token1Amount, 0, 0));
        }

        return (
            false,
            abi.encode(uint256(0), uint256(0), uint256(0), uint256(0))
        );
    }

    function performUpkeep(bytes calldata performData) external {
        (
            uint256 token0Amount,
            uint256 token1Amount,
            uint256 amount0Min,
            uint256 amount1Min
        ) = abi.decode(performData, (uint256, uint256, uint256, uint256));
        _execute(token0Amount, token1Amount, amount0Min, amount1Min);
        emit PerformUpkeep(msg.sender, performData);
    }

    function tokens() external view override returns (address, address) {
        return (address(token0), address(token1));
    }

    function refundPosition(uint256 nftId) external onlyOwner {
        manager.transferFrom(me, owner(), nftId);
    }

    function setPoolId(uint256 nftId) external onlyOwner {
        poolId = nftId;
    }
}
