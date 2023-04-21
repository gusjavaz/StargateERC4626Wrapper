// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8;
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./external/interfaces/IStargateRouter.sol";
import "./external/Factory.sol";
import "./external/Pool.sol";
import "./external/LPTokenERC20.sol";
import "./external/Router.sol";

contract StargateERC4626Wrapper is ERC4626 {
    using SafeMath for uint256;

    address public router;
    uint16 public poolId;
    ERC20 public underlying;
    Pool public pool;

    constructor(
        address _factory,
        address _router,
        address _underlying,
        uint16 _poolId
    ) ERC20("Token LP", "S*TOKEN") ERC4626(IERC20(_underlying)) {
        router = _router;
        poolId = _poolId;
        underlying = ERC20(_underlying);
        pool = Factory(_factory).getPool(poolId);
    }

    /** @dev See {IERC4626-deposit}. */
    function deposit(
        uint256 assets,
        address receiver
    ) public virtual override returns (uint256) {
        require(
            assets <= maxDeposit(receiver),
            "ERC4626: deposit more than max"
        );
        uint256 shares = previewDeposit(assets);
        ERC20(underlying).transferFrom(receiver, address(this), assets);
        ERC20(underlying).approve(router, assets);
        IStargateRouter(router).addLiquidity(poolId, assets, receiver);
        return shares;
    }

    /** @dev See {IERC4626-redeem}. */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        require(shares <= maxRedeem(owner), "ERC4626: redeem more than max");

        uint256 assets = previewRedeem(shares);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    /** @dev See {IERC4626-withdraw}. */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        require(
            assets <= maxWithdraw(owner),
            "ERC4626: withdraw more than max"
        );
        uint256 shares = previewWithdraw(assets);
        Router(router).composableInstantRedeemLocal(
            poolId,
            assets,
            receiver,
            owner
        );
        return shares;
    }

    function totalAssets() public view override returns (uint256) {
        return ERC20(underlying).balanceOf(address(pool));
    }

    function balanceOf(
        address account
    ) public view virtual override(ERC20, IERC20) returns (uint256) {
        return pool.balanceOf(account);
    }

    function previewMint(
        uint256 shares
    ) public view virtual override returns (uint256) {
        if (pool.totalLiquidity() == 0) return 0;
        return pool.amountLPtoLD(shares);
    }

    function previewRedeem(
        uint256 shares
    ) public view virtual override returns (uint256) {
        if (pool.totalLiquidity() == 0) return 0;
        return pool.amountLPtoLD(shares);
    }

    function previewWithdraw(
        uint256 assets
    ) public view virtual override returns (uint256) {
        if (pool.totalLiquidity() == 0) return assets;
        return assets.mul(pool.totalLiquidity()).div(pool.totalSupply());
    }

    function previewDeposit(
        uint256 assets
    ) public view virtual override returns (uint256) {
        if (pool.totalLiquidity() == 0) return assets;
        return assets.mul(pool.totalLiquidity()).div(pool.totalSupply());
    }


    function maxDeposit(
        address
    ) public view virtual override returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(
        address owner
    ) public view virtual override returns (uint256) {
        if (pool.totalLiquidity() == 0) return 0;
        return pool.amountLPtoLD(LPTokenERC20(pool).balanceOf(owner));
    }

    function totalSupply()
        public
        view
        virtual
        override(ERC20, IERC20)
        returns (uint256)
    {
        return LPTokenERC20(pool).totalSupply();
    }
}
