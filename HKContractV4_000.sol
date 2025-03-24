// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BetHistory {
    address public owner;
    address[] public players;
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
        uint256 likeCount;

    }

    struct PlayerStats {
        uint256 totalBets;
        uint256 totalAmountBet;
        uint256 totalWins;
        uint256 totalPayout;
    }

    struct LeaderboardReward {
        address player;
        uint256 totalBets;
    }

    struct WinnerData {
        address winner;
        uint256 amount;
        uint256 number;
        uint256 timestamp;
        uint256 prizesETH;
    }

    struct LikeData {
        address liker;
        uint256 timestamp;
        string likeType;

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
    mapping(bytes32 => address[]) public betLikers;
    mapping(address => uint256) public totalBetsByPlayer;
    mapping(uint256 => uint256) public totalPayoutPerDraw;
    mapping(bytes32 => uint256) public betToDrawId;
    mapping(uint256 => WinnerData) public winnerHistory; 
    uint256 public totalWinners;
    mapping(bytes32 => uint256) public betLikeCount;
    mapping(uint256 => uint256) private likeCounts;
    mapping(address => PlayerStats) public playerStats;
    LeaderboardReward public topBettor;
    uint256 public lastLeaderboardReset;
    uint256 public rewardAmount;
    mapping(bytes32 => LikeData[]) public betLikes;
    mapping(bytes32 => mapping(address => bool)) public hasLiked;
    mapping(bytes32 => uint256) public betLikeCount;
    mapping(bytes32 => mapping(address => bool)) public hasLiked;

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
    event TotalCommentsUpdated(bytes32 betId, uint256 totalComments);
    event CommentUpdated(bytes32 betId, address indexed user, uint256 commentIndex, string newComment);
    event CommentDeleted(bytes32 betId, address indexed user, uint256 commentIndex);
    event WinnerSet(bytes32 betId, address indexed winner, uint256 amount);
    event BetWon(bytes32 indexed betId, address indexed winner, uint256 winningNumber, uint256 prize);
    event ETHClaimed(address indexed winner, uint256 amount);
    event TotalPlayersUpdated(uint256 totalPlayers);
    event TotalPayoutUpdated(uint256 totalPayout);
    event LastWinnerUpdated(address indexed winner);
    event WinnerSet(bytes32 indexed betId, address indexed winner, uint256 amount, uint256 number);
    event BetLiked(bytes32 indexed betId, address indexed liker, uint256 likeCount);
    event BetLiked(bytes32 indexed betId, address indexed liker);
    event RewardDistributed(address indexed winner, uint256 amount);
    event CommentAdded(bytes32 indexed betId, address indexed commenter, string comment, uint256 timestamp);
    event BetLiked(bytes32 indexed betId, address indexed liker, uint256 timestamp, string likeType);
    event BetUnliked(bytes32 indexed betId, address indexed liker, uint256 likeCount);
    event BetLiked(bytes32 indexed betId, address indexed liker, uint256 timestamp, string likeType, uint256 newLikeCount);
    event BetUnliked(bytes32 indexed betId, address indexed liker, uint256 timestamp, uint256 newLikeCount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
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
            likeCount: 0
        });

        betHistory.push(newBet);
        userBets[msg.sender].push(newBet);
        totalBetsByPlayer[msg.sender] += _times;

        if (totalBetsByPlayer[msg.sender] > topBettor.totalBets) {
        topBettor = LeaderboardReward(msg.sender, totalBetsByPlayer[msg.sender]);

    }

        playerStats[msg.sender].totalBets += 1;
        playerStats[msg.sender].totalAmountBet += totalCost;

        emit BetPlaced(msg.sender, betId, _number, _times, block.timestamp, block.number, blockhash(block.number - 1));
        emit TotalPlayersUpdated(betHistory.length);
        emit TotalPayoutUpdated(totalPayout());
    }

    function getPlayerStats(address _player) external view returns (uint256, uint256, uint256, uint256) {
        PlayerStats memory stats = playerStats[_player];
        return (stats.totalBets, stats.totalAmountBet, stats.totalWins, stats.totalPayout);
    }

    function getTopPlayers(uint256 topN) external view returns (address[] memory) {
    require(topN > 0, "topN must be greater than 0");
    require(topN <= players.length, "topN exceeds total players");

    address[] memory sortedPlayers = new address[](players.length);

    for (uint256 i = 0; i < players.length; i++) {
        sortedPlayers[i] = players[i];
    }

    // Sorting bisa diterapkan di sini (misalnya berdasarkan jumlah taruhan)
    // Namun sorting dalam Solidity mahal dalam gas, lebih baik sorting dilakukan off-chain

    address[] memory topPlayers = new address[](topN);
    for (uint256 j = 0; j < topN; j++) {
        topPlayers[j] = sortedPlayers[j];
    }

    return topPlayers;
}

    function distributeReward() external onlyOwner {
        require(block.timestamp >= lastLeaderboardReset + 7 days, "Leaderboard reset not yet due");

        address winner = topBettor.player;
        uint256 reward = address(this).balance * 1 / 1000; // 0.1% dari saldo kontrak

        require(winner != address(0), "No top bettor yet");
        require(address(this).balance >= reward, "Not enough funds");

    // Kirim reward ke top bettor
        payable(winner).transfer(reward);

        emit RewardDistributed(winner, reward);

    // Reset leaderboard
        lastLeaderboardReset = block.timestamp;
        topBettor = LeaderboardReward(address(0), 0);
    }

    function setWinner(address _winner, uint256 _amount, uint256 _betId, uint256 _number) external onlyOwner {
        require(_amount > 0, "Invalid amount");
        require(address(this).balance >= _amount, "Insufficient contract balance");

        winnings[_winner] += _amount;

        winnerHistory[_betId] = WinnerData({
            winner: _winner,
            amount: _amount,
            number: _number,
            timestamp: block.timestamp,
            prizesETH: _amount
        });

        totalWinners++;

        emit WinnerSet(bytes32(_betId), _winner, _amount, _number);
        emit LastWinnerUpdated(_winner);
    }

    function getWinnerByBetId(uint256 _betId) external view returns (WinnerData memory) {
        return winnerHistory[_betId];
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

    function likeBet(bytes32 betId, string memory likeType) external {
    require(!hasLiked[betId][msg.sender], "You already liked this bet");

    LikeData memory newLike = LikeData({
        liker: msg.sender,
        timestamp: block.timestamp,
        likeType: likeType
    });

    function likeBet(bytes32 betId, string memory likeType) external {
    require(!hasLiked[betId][msg.sender], "You already liked this bet");

    LikeData memory newLike = LikeData({
        liker: msg.sender,
        timestamp: block.timestamp,
        likeType: likeType
    });

    betLikes[betId].push(newLike);
    hasLiked[betId][msg.sender] = true;
    betLikeCount[betId]++; // 🔹 Tambah jumlah like

    emit BetLiked(betId, msg.sender, block.timestamp, likeType, betLikeCount[betId]);
}

function unlikeBet(bytes32 betId) external {
    require(hasLiked[betId][msg.sender], "You haven't liked this bet yet");

    // Cari dan hapus like dari user
    LikeData[] storage likes = betLikes[betId];
    for (uint256 i = 0; i < likes.length; i++) {
        if (likes[i].liker == msg.sender) {
            likes[i] = likes[likes.length - 1];
            likes.pop();
            break;
        }
    }

    hasLiked[betId][msg.sender] = false;
    betLikeCount[betId]--; // 🔹 Kurangi jumlah like

    emit BetUnliked(betId, msg.sender, block.timestamp, betLikeCount[betId]);
}

    function hasUserLiked(bytes32 betId, address user) external view returns (bool) {
        return hasLiked[betId][user];
    }

    function getBetLikers(bytes32 betId) external view returns (address[] memory) {
        return betLikers[betId];
    }

    function getAllLikes(bytes32 betId) public view returns (address[] memory) {
        return betLikers[betId];
    }

    function getLikeCount(bytes32 betId) public view returns (uint256) {
        return betLikeCount[betId];
    }

    function getLikeCount(bytes32 betId) public view returns (uint256) {
        return bets[betId].likeCount;
    }

    function hasLikedBet(address user, bytes32 betId) external view returns (bool) {
        return betLikes[betId][user];
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

    function getAllPlayers() public view returns (address[] memory) {
    address[] memory tempPlayers = new address[](betHistory.length);
    uint256 count = 0;

    for (uint i = 0; i < betHistory.length; i++) {
        address player = betHistory[i].player;
        bool alreadyAdded = false;

        for (uint j = 0; j < count; j++) {
            if (tempPlayers[j] == player) {
                alreadyAdded = true;
                break;
            }
        }

        if (!alreadyAdded) {
            tempPlayers[count] = player;
            count++;
        }
    }

    address[] memory uniquePlayers = new address[](count);
    for (uint j = 0; j < count; j++) {
        uniquePlayers[j] = tempPlayers[j];
    }

    return uniquePlayers;
}


function getAllWinners() public view returns (address[] memory) {
    address[] memory tempWinners = new address[](betHistory.length);
    uint256 count = 0;

    for (uint i = 0; i < betHistory.length; i++) {
        address player = betHistory[i].player;
        bool alreadyAdded = false;

        for (uint j = 0; j < count; j++) {
            if (tempWinners[j] == player) {
                alreadyAdded = true;
                break;
            }
        }

        if (!alreadyAdded && winnings[player] > 0) {
            tempWinners[count] = player;
            count++;
        }
    }

    address[] memory uniqueWinners = new address[](count);
    for (uint j = 0; j < count; j++) {
        uniqueWinners[j] = tempWinners[j];
    }

    return uniqueWinners;
}


    function withdrawETH(uint256 _amount) external onlyOwner {
        require(address(this).balance >= _amount, "Insufficient balance");
        (bool success, ) = payable(owner).call{value: _amount}("");
        require(success, "ETH withdrawal failed");
    }

    receive() external payable {}
}
