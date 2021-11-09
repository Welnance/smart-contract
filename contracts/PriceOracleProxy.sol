pragma solidity ^0.5.16;

import "./WBep20.sol";
import "./WLToken.sol";
import "./PriceOracle.sol";

interface V1PriceOracleInterface {
    function assetPrices(address asset) external view returns (uint);
}

contract PriceOracleProxy is PriceOracle {
    /// @notice Indicator that this is a PriceOracle contract (for inspection)
    bool public constant isPriceOracle = true;

    /// @notice The v1 price oracle, which will continue to serve prices for v1 assets
    V1PriceOracleInterface public v1PriceOracle;

    /// @notice Address of the guardian, which may set the SAI price once
    address public guardian;

    /// @notice Address of the aBnb contract, which has a constant price
    address public aBnbAddress;

    /// @notice Address of the aUSDC contract, which we hand pick a key for
    address public aUsdcAddress;

    /// @notice Address of the aUSDT contract, which uses the aUSDC price
    address public aUsdtAddress;

    /// @notice Address of the aSAI contract, which may have its price set
    address public aSaiAddress;

    /// @notice Address of the aDAI contract, which we hand pick a key for
    address public aDaiAddress;

    /// @notice Handpicked key for USDC
    address public constant usdcOracleKey = address(1);

    /// @notice Handpicked key for DAI
    address public constant daiOracleKey = address(2);

    /// @notice Frozen SAI price (or 0 if not set yet)
    uint public saiPrice;

    /**
     * @param guardian_ The address of the guardian, which may set the SAI price once
     * @param v1PriceOracle_ The address of the v1 price oracle, which will continue to operate and hold prices for collateral assets
     * @param aBnbAddress_ The address of vBNB, which will return a constant 1e18, since all prices relative to bnb
     * @param aUsdcAddress_ The address of vUSDC, which will be read from a special oracle key
     * @param aSaiAddress_ The address of vSAI, which may be read directly from storage
     * @param aDaiAddress_ The address of vDAI, which will be read from a special oracle key
     * @param aUsdtAddress_ The address of vUSDT, which uses the vUSDC price
     */
    constructor(address guardian_,
                address v1PriceOracle_,
                address aBnbAddress_,
                address aUsdcAddress_,
                address aSaiAddress_,
                address aDaiAddress_,
                address aUsdtAddress_) public {
        guardian = guardian_;
        v1PriceOracle = V1PriceOracleInterface(v1PriceOracle_);

        aBnbAddress = aBnbAddress_;
        aUsdcAddress = aUsdcAddress_;
        aSaiAddress = aSaiAddress_;
        aDaiAddress = aDaiAddress_;
        aUsdtAddress = aUsdtAddress_;
    }

    /**
     * @notice Get the underlying price of a listed wlToken asset
     * @param wlToken The wlToken to get the underlying price of
     * @return The underlying asset price mantissa (scaled by 1e18)
     */
    function getUnderlyingPrice(WLToken wlToken) public view returns (uint) {
        address wlTokenAddress = address(wlToken);

        if (wlTokenAddress == aBnbAddress) {
            // bnb always worth 1
            return 1e18;
        }

        if (wlTokenAddress == aUsdcAddress || wlTokenAddress == aUsdtAddress) {
            return v1PriceOracle.assetPrices(usdcOracleKey);
        }

        if (wlTokenAddress == aDaiAddress) {
            return v1PriceOracle.assetPrices(daiOracleKey);
        }

        if (wlTokenAddress == aSaiAddress) {
            // use the frozen SAI price if set, otherwise use the DAI price
            return saiPrice > 0 ? saiPrice : v1PriceOracle.assetPrices(daiOracleKey);
        }

        // otherwise just read from v1 oracle
        address underlying = WBep20(wlTokenAddress).underlying();
        return v1PriceOracle.assetPrices(underlying);
    }

    /**
     * @notice Set the price of SAI, permanently
     * @param price The price for SAI
     */
    function setSaiPrice(uint price) public {
        require(msg.sender == guardian, "only guardian may set the SAI price");
        require(saiPrice == 0, "SAI price may only be set once");
        require(price < 0.1e18, "SAI price must be < 0.1 BNB");
        saiPrice = price;
    }
}
