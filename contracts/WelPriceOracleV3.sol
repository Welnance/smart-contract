pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "./PriceOracle.sol";
import "./WBep20.sol";
import "./BEP20Interface.sol";
import "./SafeMath.sol";

interface IStdReference {
    /// A structure returned whenever someone requests for standard reference data.
    struct ReferenceData {
        uint256 rate; // base/quote exchange rate, multiplied by 1e18.
        uint256 lastUpdatedBase; // UNIX epoch of the last time when base price gets updated.
        uint256 lastUpdatedQuote; // UNIX epoch of the last time when quote price gets updated.
    }

    /// Returns the price data for the given base/quote pair. Revert if not available.
    function getReferenceData(string calldata _base, string calldata _quote) external view returns (ReferenceData memory);

    /// Similar to getReferenceData, but with multiple base/quote pairs at once.
    function getReferenceDataBulk(string[] calldata _bases, string[] calldata _quotes) external view returns (ReferenceData[] memory);
}

interface ITwapPriceOracle {
    function consult(address token, uint amountIn) external view returns (uint amountOut);
}

contract WelPriceOracleV3 is PriceOracle {
    using SafeMath for uint256;
    address public admin;
    address public twapPriceOracle;
    address public welToken;

    mapping(address => uint) prices;
    event PricePosted(address asset, uint previousPriceMantissa, uint requestedPriceMantissa, uint newPriceMantissa);
    event NewAdmin(address oldAdmin, address newAdmin);

    IStdReference ref;

    constructor(IStdReference _ref, address _welToken) public {
        ref = _ref;
        welToken = _welToken;
        admin = msg.sender;
    }
    
    function getUnderlyingPrice(WLToken wlToken) public view returns (uint) {
        if (compareStrings(wlToken.symbol(), "wlWEL")) {
            return ITwapPriceOracle(twapPriceOracle).consult(welToken, 1000000000000000000);
        } else if (compareStrings(wlToken.symbol(), "wlBNB")) {
            IStdReference.ReferenceData memory data = ref.getReferenceData("BNB", "USD");
            return data.rate;
        } else {
            uint256 price;
            BEP20Interface token = BEP20Interface(WBep20(address(wlToken)).underlying());

            if(prices[address(token)] != 0) {
                price = prices[address(token)];
            } else {
                IStdReference.ReferenceData memory data = ref.getReferenceData(token.symbol(), "USD");
                price = data.rate;
            }

            uint decimalDelta = 18-uint(token.decimals());
            return price.mul(10**decimalDelta);
        }
    }

    function assetPrices(address asset) external view returns (uint) {
        return prices[asset];
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function setAdmin(address newAdmin) external {
        require(msg.sender == admin, "only admin can set new admin");
        address oldAdmin = admin;
        admin = newAdmin;

        emit NewAdmin(oldAdmin, newAdmin);
    }
}
