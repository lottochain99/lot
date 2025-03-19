// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BetHistory {
    address public owner;
    uint256 public minBet = 1;
    uint256 public maxBet = 99;
    uint256 public betPrice = 0.000256 ether;

    struct Bet {
        address player;
        bytes32 betId;
        string number;
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
    mapping(bytes32 => uint256) public totalLikes;
    mapping(bytes32 => Comment[]) public betComments;
    mapping(bytes32 => uint256) public totalComments;
    mapping(address => uint256) public winnings;
    mapping(bytes32 => address) public betWinners;
    mapping(bytes32 => Bet) public bets;
    mapping(uint256 => address[]) public betLikers;
    mapping(address => uint256) public totalBetsByPlayer;
    mapping(uint256 => uint256) public totalPayoutPerDraw;
    mapping(bytes32 => uint256) public betToDrawId;

    event PlayerJoined(address indexed player, uint256 totalPlayers);
    event WinnerAnnounced(address indexed winner, uint256 prize, uint256 totalWinners);
    event TotalPrizesUpdated(uint256 newTotalPrizes);

    event BetPlaced(
        address indexed player,
        bytes32 betId,
        string number,
        uint256 betAmount,
        uint256 timestamp,
        uint256 blockNumber,
        bytes32 txHash
    );

    event BetResultSet(uint256 drawId, uint256 winningNumber);
    event BetLiked(bytes32 indexed betId, address indexed liker);
    event TotalLikesUpdated(bytes32 indexed betId, uint256 totalLikes);
    event CommentAdded(bytes32 betId, address indexed user, string comment, uint256 timestamp);
    event TotalCommentsUpdated(bytes32 betId, uint256 totalComments);
    event CommentUpdated(bytes32 betId, address indexed user, uint256 commentIndex, string newComment);
    event CommentDeleted(bytes32 betId, address indexed user, uint256 commentIndex);
    event WinnerSet(bytes32 betId, address indexed winner, uint256 amount);
    event BetWon(bytes32 indexed betId, address indexed winner, uint256 winningNumber, uint256 prize);
    event ETHClaimed(address indexed winner, uint256 amount);
    event TotalPlayersUpdated(uint256 totalPlayers);
    event TotalPayoutUpdated(uint256 totalPayout);
    event LastWinnerUpdated(address indexed winner);

    modifier onlyOwner() {
    require(msg.sender == owner, "Only owner can call this function");
    _;
}

constructor() {
    owner = msg.sender;
}

function getAllPlayers() public view returns (address[] memory) {
    address[] memory players = new address[](betHistory.length);
    uint256 count = 0;
    mapping(address => bool) memory seen;

    for (uint i = 0; i < betHistory.length; i++) {
        address player = betHistory[i].player;
        if (!seen[player]) {
            seen[player] = true;
            players[count] = player;
            count++;
        }
    }

    address[] memory uniquePlayers = new address[](count);
    for (uint j = 0; j < count; j++) {
        uniquePlayers[j] = players[j];
    }

    return uniquePlayers;
}

function getAllWinners() public view returns (address[] memory) {
    address[] memory winners = new address[](betHistory.length);
    uint256 count = 0;
    mapping(address => bool) memory seen;

    for (uint i = 0; i < betHistory.length; i++) {
        address player = betHistory[i].player;
        if (winnings[player] > 0 && !seen[player]) {
            seen[player] = true;
            winners[count] = player;
            count++;
        }
    }

    address[] memory uniqueWinners = new address[](count);
    for (uint j = 0; j < count; j++) {
        uniqueWinners[j] = winners[j];
    }

    return uniqueWinners;
}

function getTotalPrizes() public view returns (uint256) {
    return totalPrizes;
}

function placeBet(string memory _number, uint256 _times, bool _isETH) external payable {
    require(bytes(_number).length >= 1 && bytes(_number).length <= 4, "Invalid number length");
    uint256 totalCost = _times * betPrice;
    require(msg.value == totalCost, "Incorrect ETH amount");

    bytes32 betId = keccak256(abi.encodePacked(msg.sender, block.timestamp, block.number));
    Bet memory newBet = Bet({
        player: msg.sender,
        betId: betId,
        number: _number,
        betAmount: _times,
        timestamp: block.timestamp,
        blockNumber: block.number,
        txHash: blockhash(block.number - 1),
        isETH: _isETH
    });

    betHistory.push(newBet);
    userBets[msg.sender].push(newBet);

    emit BetPlaced(msg.sender, betId, _number, _times, block.timestamp, block.number, blockhash(block.number - 1));
    emit PlayerJoined(msg.sender, getAllPlayers().length);
    emit TotalPlayersUpdated(betHistory.length);
    emit TotalPayoutUpdated(totalPayout());
}

function claimPrize() public {
    uint256 prize = winnings[msg.sender];
    require(prize > 0, "No winnings");

    winnings[msg.sender] = 0;
    payable(msg.sender).transfer(prize);

    totalPrizes += prize;
    emit WinnerAnnounced(msg.sender, prize, getAllWinners().length);
    emit TotalPrizesUpdated(totalPrizes);
}

function setWinner(address _winner, uint256 _amount) external onlyOwner {
    require(_amount > 0, "Invalid amount");
    require(address(this).balance >= _amount, "Insufficient contract balance");

    winnings[_winner] += _amount;
    emit WinnerSet(bytes32(0), _winner, _amount);
    emit LastWinnerUpdated(_winner);
}

function setBetResult(uint256 _drawId, uint256 _winningNumber) external onlyOwner {
    betResults[_drawId] = BetResult({
        drawId: _drawId,
        winningNumber: _winningNumber,
        isProcessed: true
    });

    emit BetResultSet(_drawId, _winningNumber);
}

function claimETH() external {
    uint256 amount = winnings[msg.sender];
    require(amount > 0, "No winnings to claim");

    winnings[msg.sender] = 0;
    (bool success, ) = payable(msg.sender).call{value: amount}("");
    require(success, "Claim failed");

    emit ETHClaimed(msg.sender, amount);
}

function contractBalance() external view returns (uint256) {
    return address(this).balance;
}

function totalPlayers() public view returns (uint256) {
    return betHistory.length;
}

function totalPayout() public view returns (uint256) {
    uint256 total;
    for (uint256 i = 0; i < betHistory.length; i++) {
        total += betHistory[i].betAmount;
    }
    return total * betPrice;
}

function lastWinner() public view returns (address) {
    if (betHistory.length == 0) {
        return address(0);
    }
    return betHistory[betHistory.length - 1].player;
}

function likeBet(uint256 betId) public {
        require(!bets[betId].likedBy[msg.sender], "You already liked this bet");
        
        bets[betId].likedBy[msg.sender] = true;
        bets[betId].likeCount++;
        betLikers[betId].push(msg.sender);

        emit BetLiked(betId, msg.sender, bets[betId].likeCount);
    }

    function dislikeBet(uint256 betId) public {
        require(bets[betId].likedBy[msg.sender], "You haven't liked this bet");

        bets[betId].likedBy[msg.sender] = false;
        bets[betId].likeCount--;

        // Hapus alamat dari daftar like
        for (uint i = 0; i < betLikers[betId].length; i++) {
            if (betLikers[betId][i] == msg.sender) {
                betLikers[betId][i] = betLikers[betId][betLikers[betId].length - 1];
                betLikers[betId].pop();
                break;
            }
        }

        emit BetDisliked(betId, msg.sender, bets[betId].likeCount);
    }

    function getAllLikes(uint256 betId) public view returns (address[] memory) {
        return betLikers[betId];
    }

    function hasLiked(uint256 betId, address user) public view returns (bool) {
        return bets[betId].likedBy[user];
    }
}

    function likeBet(uint256 betId) public {
        likeCounts[betId] += 1;
    }

    function getLikeCount(uint256 betId) public view returns (uint256) {
        return likeCounts[betId];
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

function totalPlayers() public view returns (uint256) {
    return betHistory.length;
}

function totalPayout() public view returns (uint256) {
    uint256 total;
    for (uint256 i = 0; i < betHistory.length; i++) {
        total += betHistory[i].betAmount;
    }
    return total * betPrice;
}

function lastWinner() public view returns (address) {
    if (betHistory.length == 0) {
        return address(0);
    }
    return betHistory[betHistory.length - 1].player;
}

function getAllBetIds() public view returns (bytes32[] memory) {
    bytes32[] memory betIds = new bytes32[](betHistory.length);
    for (uint i = 0; i < betHistory.length; i++) {
        betIds[i] = betHistory[i].betId;
    }
    return betIds;
}

function getAllWinningBets() public view returns (Bet[] memory) {
    uint256 count = 0;
    for (uint i = 0; i < betHistory.length; i++) {
        if (winnings[betHistory[i].player] > 0) {
            count++;
        }
    }

    Bet[] memory winningBets = new Bet[](count);
    uint256 index = 0;
    for (uint i = 0; i < betHistory.length; i++) {
        if (winnings[betHistory[i].player] > 0) {
            winningBets[index] = betHistory[i];
            index++;
        }
    }
    return winningBets;
}

function getAllComments() public view returns (Comment[] memory) {
    uint256 totalComments = 0;
    for (uint i = 0; i < betHistory.length; i++) {
        bytes32 betId = betHistory[i].betId;
        totalComments += betComments[betId].length;
    }

    Comment[] memory allComments = new Comment[](totalComments);
    uint256 index = 0;
    for (uint i = 0; i < betHistory.length; i++) {
        bytes32 betId = betHistory[i].betId;
        for (uint j = 0; j < betComments[betId].length; j++) {
            allComments[index] = betComments[betId][j];
            index++;
        }
    }
    return allComments;
}

function getAllBetsByPlayer(address _player) public view returns (Bet[] memory) {
    return userBets[_player];
}

function getAllLike() public view returns (uint256) {
    uint256 totalLikes = 0;
    for (uint i = 0; i < betHistory.length; i++) {
        bytes32 betId = betHistory[i].betId;
        for (uint j = 0; j < betHistory.length; j++) {
            if (betLikes[betId][betHistory[j].player]) {
                totalLikes++;
            }
        }
    }
    return totalLikes;
}

function withdrawETH(uint256 _amount) external onlyOwner {
    require(address(this).balance >= _amount, "Insufficient balance");
    (bool success, ) = payable(owner).call{value: _amount}("");
    require(success, "ETH withdrawal failed");
}

receive() external payable {}

}
