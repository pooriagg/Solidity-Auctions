// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

interface IERC721 {
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
}

contract DutchAuction {

    uint public constant TIME = 60 minutes;

    IERC721 public immutable nft;
    uint public immutable nftId;

    address payable public immutable seller;
    uint public immutable startAt;
    uint public immutable endAt;
    uint public immutable startingPrice;
    uint public immutable discountRate;

    constructor(
        address _nft,
        uint _nftId,
        uint _startingPrice,
        uint _discountRate
    ) {
        require(_startingPrice > (60 * _discountRate), "You need bigger starting price.");

        startAt = block.timestamp;
        endAt = block.timestamp + TIME;
        nft = IERC721(_nft);
        nftId = _nftId;
        startingPrice = _startingPrice;
        discountRate = _discountRate;
        seller = payable(msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == seller, "Only owner can access.");
        _;
    }

    /// @dev get the current nft price
    /// @return current price of the nft
    function getPrice() public view returns(uint) {
        uint timeElaped = (block.timestamp - startAt) / 60 seconds; // every 1 min discount will be applied.
        uint discountAmount = timeElaped * discountRate;
        return startingPrice - discountAmount;
    }

    /// @dev user can buy the nft by calling this method and sending sufficient amount of ether
    function buy() external payable {
        require(msg.sender != seller, "You cannot buy!");
        require(block.timestamp < endAt, "Auction time ended.");

        uint price = getPrice();
        require(msg.value >= price, "Insufficient ether amount.");
        uint refund = msg.value - price;

        try nft.transferFrom(address(this), msg.sender, nftId) {
            if (refund > 0) {
                payable(msg.sender).transfer(refund);
            }

            selfdestruct(seller);
        } catch {
            revert("External call failed! (2)");
        }
    }

    /// @dev if there is no buyer the owner of the nft can end this auction and receive back his nft from the contract
    /// note after receiving the nft this contract will be deleted
    /// note this method can only be call by the owner of the nft after aution time expires
    function closeAuction() external onlyOwner {
        require(block.timestamp >= endAt, "You cannot close the auction.");

        try nft.transferFrom(address(this), msg.sender, nftId) {
            selfdestruct(payable(msg.sender));
        } catch {
            revert("External call failed! (3)");
        }
    }

}