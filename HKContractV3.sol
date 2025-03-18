/**
 *Submitted for verification at sepolia.basescan.org on 2025-03-12
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BetHistory {
    address public owner;
    uint256 public minBet = 1;
    uint256 public maxBet = 99;
    uint256 public betPrice = 0.000175 ether;

    struct Bet {
        address player;
        uint256 number;
        uint256 betAmount;
        uint256 timestamp;
        uint256 blockNumber;
        bytes32 txHash;
        bool isETH;
    }

    struct Comment {
        address commenter;
        string text;
        uint256 timestamp;
        bool isDeleted;
    }

    struct BetResult {
        uint256 drawId;
        uint256 winningNumber;
        bool isProcessed;
    }

    Bet[] public betHistory;
    mapping(address => Bet[]) public userBets;
    mapping(uint256 => BetResult) public betResults;
    mapping(bytes32 => mapping(address => bool)) public betLikes;
    mapping(bytes32 => Comment[]) public betComments;
    mapping(address => uint256) public winnings;

    event BetPlaced(
        address indexed player,
        bytes32 betId,
        uint256 number,
        uint256 betAmount,
        uint256 timestamp,
        uint256 blockNumber,
        bytes32 txHash
    );

    event BetResultSet(uint256 drawId, uint256 winningNumber);
    event BetLiked(bytes32 betId, address indexed user);
    event CommentAdded(bytes32 betId, address indexed user, string comment, uint256 timestamp);
    event CommentUpdated(bytes32 betId, address indexed user, uint256 commentIndex, string newComment);
    event CommentDeleted(bytes32 betId, address indexed user, uint256 commentIndex);
    event WinnerSet(address indexed winner, uint256 amount);
    event ETHClaimed(address indexed winner, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function placeBet(uint256 _number, uint256 _times, bool _isETH) external payable {
        require(_number >= 0 && _number <= 9999, "Invalid number (0 - 9999)");
        require(_times >= minBet && _times <= maxBet, "Bet count out of range");

        uint256 totalCost = _times * betPrice;
        require(msg.value == totalCost, "Incorrect ETH amount");

        bytes32 betId = keccak256(abi.encodePacked(msg.sender, block.timestamp, block.number));
        uint256 blockNumber = block.number;
        bytes32 txHash = blockhash(block.number - 1);

        Bet memory newBet = Bet({
            player: msg.sender,
            number: _number,
            betAmount: _times,
            timestamp: block.timestamp,
            blockNumber: blockNumber,
            txHash: txHash,
            isETH: _isETH
        });

        betHistory.push(newBet);
        userBets[msg.sender].push(newBet);

        emit BetPlaced(msg.sender, betId, _number, _times, block.timestamp, blockNumber, txHash);
    }

    function setBetResult(uint256 _drawId, uint256 _winningNumber) external onlyOwner {
        betResults[_drawId] = BetResult({
            drawId: _drawId,
            winningNumber: _winningNumber,
            isProcessed: true
        });

        emit BetResultSet(_drawId, _winningNumber);
    }

    function setWinner(address _winner, uint256 _amount) external onlyOwner {
        require(_amount > 0, "Invalid amount");
        require(address(this).balance >= _amount, "Insufficient contract balance");

        winnings[_winner] += _amount;
        emit WinnerSet(_winner, _amount);
    }

    function claimETH() external {
        uint256 amount = winnings[msg.sender];
        require(amount > 0, "No winnings to claim");

        winnings[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Claim failed");

        emit ETHClaimed(msg.sender, amount);
    }

    function likeBet(bytes32 betId) external {
        require(!betLikes[betId][msg.sender], "You already liked this bet");
        betLikes[betId][msg.sender] = true;
        emit BetLiked(betId, msg.sender);
    }

    function addComment(bytes32 betId, string memory _comment) external {
        require(bytes(_comment).length > 0, "Comment cannot be empty");

        betComments[betId].push(Comment({
            commenter: msg.sender,
            text: _comment,
            timestamp: block.timestamp,
            isDeleted: false
        }));

        emit CommentAdded(betId, msg.sender, _comment, block.timestamp);
    }

    function editComment(bytes32 betId, uint256 commentIndex, string memory newComment) external {
        require(bytes(newComment).length > 0, "New comment cannot be empty");
        require(commentIndex < betComments[betId].length, "Invalid comment index");
        require(betComments[betId][commentIndex].commenter == msg.sender, "Not your comment");
        require(!betComments[betId][commentIndex].isDeleted, "Comment is deleted");

        betComments[betId][commentIndex].text = newComment;
        emit CommentUpdated(betId, msg.sender, commentIndex, newComment);
    }

    function deleteComment(bytes32 betId, uint256 commentIndex) external {
        require(commentIndex < betComments[betId].length, "Invalid comment index");
        require(betComments[betId][commentIndex].commenter == msg.sender, "Not your comment");
        require(!betComments[betId][commentIndex].isDeleted, "Already deleted");

        betComments[betId][commentIndex].isDeleted = true;
        emit CommentDeleted(betId, msg.sender, commentIndex);
    }

    function getAllBets() public view returns (Bet[] memory) {
        return betHistory;
    }

    function getUserBets(address _user) public view returns (Bet[] memory) {
        return userBets[_user];
    }

    function getComments(bytes32 betId) public view returns (Comment[] memory) {
        return betComments[betId];
    }

    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function withdrawETH(uint256 _amount) external onlyOwner {
        require(address(this).balance >= _amount, "Insufficient balance");
        (bool success, ) = payable(owner).call{value: _amount}("");
        require(success, "ETH withdrawal failed");
    }

    receive() external payable {}
}
