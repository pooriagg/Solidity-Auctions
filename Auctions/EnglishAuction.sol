// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

interface IERC721 {
    function ownerOf(uint256 _tokenId) external view returns (address);
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;
    function getApproved(uint256 _tokenId) external view returns (address);
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}

contract EnglishAuction {

    IERC721 public immutable nft;
    uint public immutable nftId;

    address public immutable seller;
    uint32 public endAt;
    bool public isStarted;
    bool public isEnded;

    uint public highestBid;
    address public highestBidder;
    mapping (address => uint) public bids;

    event Start();
    event Bid(address indexed sender, uint amount);
    event Withdraw(address indexed bidder, uint amount);
    event End(address winner, uint amount);

    constructor(
        IERC721 _nft,
        uint _nftId,
        uint _startingPrice
    ) { 
        require(_nft.ownerOf(_nftId) == msg.sender, "not the owner");

        nft = _nft;
        nftId = _nftId;

        highestBid = _startingPrice;

        seller = msg.sender;
    }

    function start() external {
        require(msg.sender == seller, "not seller");
        require(isStarted == false, "started");
        require(isEnded == false, "ended");
        
        isStarted = true;
        endAt = uint32(block.timestamp + 10 days);

        try nft.safeTransferFrom(msg.sender, address(this), nftId) {
            emit Start();
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert("This Contract Doesn't Impelemnted ERC721 Properly");
            } else {
                revert("Error While Transfering The NFT");
            }
        }
    }

    function bid() external payable {
        require(isStarted == true, "not started");
        require(block.timestamp < endAt, "ended");
        require(msg.value > highestBid, "ether < highest bid");

        if (highestBidder != address(0)) {
            bids[highestBidder] += highestBid;
        }

        highestBid = msg.value;
        highestBidder = msg.sender;

        emit Bid(msg.sender, msg.value);
    }

    function refund() external payable {
        uint amount = bids[msg.sender];
        require(amount > 0, "0 balance");

        bids[msg.sender] = 0;

        payable(msg.sender).transfer(amount);

        emit Withdraw(msg.sender, amount);
    }

    function end() external payable {
        require(isStarted == true, "not started");
        require(block.timestamp > endAt, "not ended yet");
        require(isEnded == false, "ended");

        isEnded = true;

        if (highestBidder != address(0)) {
            
            try nft.safeTransferFrom(address(this), highestBidder, nftId) {
                payable(seller).transfer(highestBid);

                emit End(highestBidder, highestBid);
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("This Contract Doesn't Impelemnted ERC721 Properly");
                } else {
                    revert("Error While Transfering The NFT");
                }
            }

        } else {

            try nft.safeTransferFrom(address(this), seller, nftId) {
                emit End(highestBidder, highestBid);
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("This Contract Doesn't Impelemnted ERC721 Properly");
                } else {
                    revert("Error While Transfering The NFT");
                }
            }

        }
    }
    
}
