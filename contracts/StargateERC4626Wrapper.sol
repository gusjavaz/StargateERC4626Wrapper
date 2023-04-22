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
    ) ERC20("X", "S*X") ERC4626(IERC20(_underlying)) {
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
        LPTokenERC20(pool).approve(address(this), assets);
        LPTokenERC20(pool).transferFrom(receiver, address(this), assets);
        Router(router).instantRedeemLocal(poolId, assets, receiver);
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
        withdraw(assets, receiver, owner);
        return assets;
    }

    function totalAssets() public view override returns (uint256) {
        return ERC20(underlying).balanceOf(address(pool));
    }

    function convertToShares(
        uint256 assets
    ) public view virtual override returns (uint256 shares) {
        if (pool.totalSupply() == 0) return 0;
        return assets.mul(pool.totalLiquidity()).div(pool.totalSupply());
    }

    /** @dev See {IERC4626-convertToAssets}. */
    function convertToAssets(
        uint256 shares
    ) public view virtual override returns (uint256 assets) {
        if (pool.totalLiquidity() == 0) return 0;
        return pool.amountLPtoLD(shares);
    }

    function previewWithdraw(
        uint256 assets
    ) public view virtual override returns (uint256) {
        return convertToShares(assets);
    }

    /** @dev See {IERC4626-previewRedeem}. */
    function previewRedeem(
        uint256 shares
    ) public view virtual override returns (uint256) {
        return convertToAssets(shares);
    }

    function previewDeposit(
        uint256 shares
    ) public view virtual override returns (uint256) {
        return convertToShares(shares);
    }

    function balanceOf(
        address account
    ) public view virtual override(ERC20, IERC20) returns (uint256) {
        return pool.balanceOf(account);
    }

    /** @dev See {IERC4626-asset}. */
    function asset() public view virtual override returns (address) {
        return address(pool);
    }

    /** @dev See {IERC4626-maxDeposit}. */
    function maxDeposit(
        address
    ) public view virtual override returns (uint256) {
        return type(uint256).max;
    }

    /** @dev See {IERC4626-maxWithdraw}. */
    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        return convertToAssets(balanceOf(owner));
    }

    /** @dev See {IERC4626-maxRedeem}. */
    function maxRedeem(address owner) public view virtual override returns (uint256) {
        return balanceOf(owner);
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
