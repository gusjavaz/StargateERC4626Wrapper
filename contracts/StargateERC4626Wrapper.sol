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

    uint8 internal constant TYPE_REDEEM_LOCAL_RESPONSE = 1;
    uint8 internal constant TYPE_REDEEM_LOCAL_CALLBACK_RETRY = 2;
    uint8 internal constant TYPE_SWAP_REMOTE_RETRY = 3;

    //---------------------------------------------------------------------------
    // STRUCTS
    struct CachedSwap {
        address token;
        uint256 amountLD;
        address to;
        bytes payload;
    }

    //---------------------------------------------------------------------------
    // VARIABLES
    Factory public factory; // used for creating pools
    address public protocolFeeOwner; // can call methods to pull Stargate fees collected in pools
    address public mintFeeOwner; // can call methods to pull mint fees collected in pools
    Bridge public bridge;
    mapping(uint16 => mapping(bytes => mapping(uint256 => bytes)))
        public revertLookup; //[chainId][srcAddress][nonce]
    mapping(uint16 => mapping(bytes => mapping(uint256 => CachedSwap)))
        public cachedSwapLookup; //[chainId][srcAddress][nonce]

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
