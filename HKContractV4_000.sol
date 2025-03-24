//v4.0
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
        uint256 likeCount;
        uint256 commentCount;
        uint256 payoutAmount;
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
        uint256 number;
        uint256 amount;
        uint256 prizesETH;
        uint256 betId;
        uint256 timestamp;
    }

    struct LikeData {
        address liker;
        uint256 timestamp;
        string likeType;
        string reason;
    }

    struct BetComment {
        address commenter;
        uint256 timestamp;
        string commentText;
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
    mapping(address => uint256) public totalBetsByPlayer;
    mapping(address => PlayerStats) public playerStats;
    mapping(address => bool) public isPlayerRegistered;
    address[] public players;
    mapping(address => uint256) public winnings;
    mapping(uint256 => WinnerData) public winnerHistory;
    uint256 public totalWinners;
    uint256 public lastLeaderboardReset;
    mapping(address => uint256) public winnings;
    mapping(bytes32 => LikeData[]) public betLikeList;
    mapping(bytes32 => mapping(address => bool)) public betLikes;
    mapping(bytes32 => mapping(address => bool)) public hasLiked;
    mapping(bytes32 => uint256) public betLikeCount;
    mapping(bytes32 => LikeData[]) public betLikesArray;
    mapping(bytes32 => address[]) public betLikers;
    mapping(bytes32 => uint256) public likeCounts;
    mapping(uint256 => bool) public betExists;
    mapping(bytes32 => BetComment[]) public betComments;
    mapping(bytes32 => uint256) public commentCount;
    mapping(address => Bet[]) public userBets;
    mapping(bytes32 => BetComment[]) public betComments;
    mapping(bytes32 => uint256) public commentCount;
    mapping(address => bool) public uniquePlayers;
    mapping(address => bool) public hasWon;
    mapping(bytes32 => uint256) public betLikeCount;

    LeaderboardReward public topBettor;
    uint256 public lastLeaderboardReset;
    uint256 public rewardAmount;
    uint256 public totalWinners;

   event PlayerStatsUpdated(
       address indexed player,
       uint256 totalBets,
       uint256 totalAmountBet,
       uint256 totalWins,
       uint256 totalPayout
   );

    event BetPlaced(
        address indexed player,
        bytes32 betId,
        string number,
        uint256 betAmount,
        uint256 timestamp,
        uint256 blockNumber,
        bytes32 txHash
    );

    event BetLiked(
        bytes32 indexed betId, 
        address indexed liker, 
        uint256 timestamp, 
        string likeType, 
        string reason, 
        uint256 totalLikes
    );

    event TotalPlayersUpdated(uint256 totalPlayers);
    event TotalPayoutUpdated(uint256 totalPayout);
    event TopBettorUpdated(address indexed player, uint256 totalBets);
    event RewardDistributed(address indexed winner, uint256 amount);
    event WinnerSet(bytes32 indexed betId, address indexed winner, uint256 amount, uint256 number);
    event LastWinnerUpdated(address indexed lastWinner);
    event ETHClaimed(address indexed claimer, uint256 amount);
    event BetUnliked(bytes32 indexed betId, address indexed unliker, uint256 timestamp, uint256 totalLikes);
    event CommentAdded(bytes32 indexed betId, address indexed commenter, string commentText, uint256 timestamp);
    event CommentUpdated(bytes32 indexed betId, address indexed commenter, uint256 commentIndex, string newComment);
    event CommentDeleted(bytes32 indexed betId, address indexed commenter, uint256 commentIndex);
    event BetPlaced(address indexed user, bytes32 indexed betId, uint256 amount, uint256 timestamp);
    event CommentAdded(bytes32 indexed betId, address indexed commenter, string commentText, uint256 timestamp);
    event CommentUpdated(bytes32 indexed betId, address indexed commenter, uint256 commentIndex, string newComment);
    event CommentDeleted(bytes32 indexed betId, address indexed commenter, uint256 commentIndex);
    event PayoutUpdated(uint256 newTotalPayout);
    event WinnerUpdated(address indexed winner);
    event PlayerRegistered(address indexed player);
    event WinnerRegistered(address indexed winner);
    event ETHWithdrawn(address indexed owner, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function placeBet(string memory _number, uint256 _times, bool _isETH, uint256 _payoutAmount) external payable {
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
        likeCount: 0,
        commentCount: 0,
        payoutAmount: _payoutAmount,
        isETH: _isETH

    });

    betHistory.push(newBet);
    userBets[msg.sender].push(newBet);
    totalBetsByPlayer[msg.sender] += _times;

    if (totalBetsByPlayer[msg.sender] > topBettor.totalBets) {
    topBettor = LeaderboardReward(msg.sender, totalBetsByPlayer[msg.sender]);
    emit TopBettorUpdated(msg.sender, totalBetsByPlayer[msg.sender]);
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

    function getTopPlayers(uint256 topN) external view returns (address[] memory, uint256[] memory) {
        require(topN > 0, "topN must be greater than 0");
        require(topN <= players.length, "topN exceeds total players");

        address[] memory topPlayers = new address[](topN);
        uint256[] memory topBets = new uint256[](topN);

        for (uint256 i = 0; i < topN; i++) {
            topPlayers[i] = players[i];
            topBets[i] = playerStats[players[i]].totalAmountBet;
         }

         return (topPlayers, topBets);
    }

    function distributeReward() external {
        require(block.timestamp >= lastLeaderboardReset + 7 days, "Leaderboard reset not yet due");
    
    // Pastikan pemanggilan hanya dilakukan pada hari Minggu pukul 08:00 UTC
        require((block.timestamp / 1 days) % 7 == 0 && (block.timestamp % 1 days) / 1 hours == 8, "Not Sunday 08:00 UTC");

        address winner = topBettor.player;
        require(winner != address(0), "No top bettor yet");

        uint256 totalBet = topBettor.totalBetAmount; // Total taruhan bettor tertinggi
        uint256 reward = (totalBet * 5) / 100; // 5% dari total taruhan bettor tersebut

        require(address(this).balance >= reward, "Not enough funds");

    // Kirim reward ke top bettor
        payable(winner).transfer(reward);

        emit RewardDistributed(winner, reward);

    // Reset leaderboard untuk periode berikutnya
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
            prizesETH: _amount,
            betId: _betId
        });

        totalWinners++;

        emit WinnerSet(bytes32(_betId), _winner, _amount, _number);
        emit LastWinnerUpdated(_winner);
    }

    function getWinnerByBetId(bytes32 _betId) external view returns (WinnerData memory) {
        require(winnerHistory[_betId].winner != address(0), "Pemenang tidak ditemukan");
        return winnerHistory[_betId];
    }

    function claimETH() external {
        uint256 amount = winnings[msg.sender];
        require(amount > 0, "No winnings to claim");

        winnings[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Claim failed");

        emit ETHClaimed(msg.sender, amount);
    }

    function likeBet(bytes32 betId, string memory likeType, string memory reason) external {
        require(!hasLiked[betId][msg.sender], "You already liked this bet");

        LikeData memory newLike = LikeData({
            liker: msg.sender,
            timestamp: block.timestamp,
            likeType: likeType,
            reason: reason // 🔹 Simpan alasan
        });

        betLikeList[betId].push(newLike); // Simpan data like
        betLikes[betId][msg.sender] = true;
        hasLiked[betId][msg.sender] = true;
        betLikeCount[betId]++; // 🔹 Tambah jumlah like

        emit BetLiked(betId, msg.sender, block.timestamp, likeType, reason, betLikeCount[betId]);
    }

    function getBetLikersPaginated(bytes32 betId, uint256 start, uint256 limit) external view returns (LikeData[] memory) {
        LikeData[] storage likers = betLikeList[betId];
        uint256 likersCount = likers.length;

         if (start >= likersCount) {
            return new LikeData ; // Jika di luar batas, kembalikan array kosong
        }

        uint256 end = start + limit > likersCount ? likersCount : start + limit;
        LikeData[] memory paginatedLikers = new LikeData[](end - start);

        for (uint256 i = start; i < end; i++) {
            paginatedLikers[i - start] = likers[i];
        }

        return paginatedLikers;
    }

    function unlikeBet(bytes32 betId) external {
        require(hasLiked[betId][msg.sender], "You haven't liked this bet yet");

    // Cari dan hapus like dari user
    betLikes[betId][msg.sender] = true; // Pastikan betLikes benar sebagai mapping

        LikeData[] storage likes = betLikesArray[betId]; // Ambil array dari mapping betLikesArray
        for (uint256 i = 0; i < likes.length; i++) {
            if (likes[i].liker == msg.sender) {
                likes[i] = likes[likes.length - 1]; // Ganti dengan elemen terakhir
                likes.pop(); // Hapus elemen terakhir
                break;
            }
        }

    hasLiked[betId][msg.sender] = false;
    betLikeCount[betId]--; // 🔹 Kurangi jumlah like

    emit BetUnliked(betId, msg.sender, block.timestamp, betLikeCount[betId]);
}

    function hasUserLikedWithCount(bytes32 betId, address user) external view returns (bool, uint256) {
        return (hasLiked[betId][user], likeCounts[betId]);
    }

    function getBetLikers(bytes32 betId, uint256 start, uint256 limit) public view returns (address[] memory) {
        require(betExists[betId], "Bet ID tidak valid");
        address[] storage likers = betLikers[bytes32(betId)];
        uint256 likersCount = likers.length;
        require(likersCount > 0, "Belum ada yang like");
    
        if (start >= likersCount) {
            return new address ; // Jika start di luar batas, kembalikan array kosong
        }
    
        uint256 end = start + limit > likersCount ? likersCount : start + limit;
        address[] memory paginatedLikers = new address[](end - start);
    
        for (uint256 i = start; i < end; i++) {
            paginatedLikers[i - start] = likers[i];
         }
    
        return paginatedLikers;
    }

    function getLikeCount(bytes32 betId) public view returns (uint256) {
        require(likeCounts[betId] > 0 || betExists[betId], "Bet ID tidak valid"); 
        return likeCounts[betId];
    }

    function addComment(bytes32 betId, string memory _comment) external {
    require(bytes(_comment).length > 0, "Comment cannot be empty");

    BetComment memory newComment = BetComment({
    commenter: msg.sender,
    commentText: _comment, // ✅ Sesuaikan nama dengan struct
    timestamp: block.timestamp,
    isDeleted: false
});


    betComments[betId].push(newComment);

    commentCount[betId]++; // ✅ Tambah jumlah komentar dengan benar

    emit CommentAdded(betId, msg.sender, _comment, block.timestamp);
}


    function editComment(bytes32 betId, uint256 commentIndex, string memory newComment) external {
    require(bytes(newComment).length > 0, "New comment cannot be empty");
    require(commentIndex < betComments[betId].length, "Invalid comment index");
    require(betComments[betId][commentIndex].commenter == msg.sender, "Not your comment");
    require(!betComments[betId][commentIndex].isDeleted, "Comment is deleted"); // ✅ Sekarang ini valid

    betComments[betId][commentIndex].commentText = newComment;

    emit CommentUpdated(betId, msg.sender, commentIndex, newComment);
}


    function deleteComment(bytes32 betId, uint256 commentIndex) external {
        require(commentIndex < betComments[betId].length, "Invalid comment index");
        require(betComments[betId][commentIndex].commenter == msg.sender, "Not your comment");
        require(!betComments[betId][commentIndex].isDeleted, "Already deleted");

        betComments[betId][commentIndex].isDeleted = true;
        bets[betId].commentCount--;

        emit CommentDeleted(betId, msg.sender, commentIndex);
    }

    function getAllBets(uint256 limit) public view returns (Bet[] memory) {
        uint256 betCount = betHistory.length;
        uint256 fetchCount = limit > 0 && limit < betCount ? limit : betCount;

        Bet[] memory bets = new Bet[](fetchCount);
        for (uint256 i = 0; i < fetchCount; i++) {
            bets[i] = betHistory[i];
        }

        return bets;
    }

    function getUserBets(address _user, uint256 startIndex, uint256 limit) public view returns (Bet[] memory) {
        Bet[] storage bets = userBets[_user];
        uint256 betCount = bets.length;
    
        if (betCount == 0 || startIndex >= betCount) {
            return new Bet ; // Jika tidak ada taruhan atau startIndex di luar batas, kembalikan array kosong
        }

        uint256 fetchCount = (limit > 0 && startIndex + limit <= betCount) ? limit : betCount - startIndex;
        Bet[] memory paginatedBets = new Bet[](fetchCount);

        for (uint256 i = 0; i < fetchCount; i++) {
            paginatedBets[i] = bets[startIndex + i];
        }

        return paginatedBets;
    }

    function getPaginatedComments(bytes32 betId, uint256 start, uint256 limit) external view returns (CommentData[] memory) {
        BetComment[] storage comments = betComments[betId];
        uint256 totalComments = comments.length;

        if (start >= totalComments) {
            return new CommentData ;  // Kembalikan array kosong jika di luar batas
        }

        uint256 end = start + limit > totalComments ? totalComments : start + limit;
        CommentData[] memory commentList = new CommentData[](end - start);

        for (uint256 i = start; i < end; i++) {
            commentList[i - start] = CommentData({
                commenter: comments[i].commenter,
                text: comments[i].commentText,
                timestamp: comments[i].timestamp,
                isDeleted: comments[i].isDeleted
            });
        }

        return commentList;
    }

    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function totalUniquePlayers() public view returns (uint256) {
        return uniquePlayerCount;
    }

    uint256 private totalPayoutAmount;

    function updatePayout(uint256 amount) internal {
        totalPayoutAmount += amount;
    }

    function getTotalPayout() public view returns (uint256) {
        return totalPayoutAmount;
    }

    address private lastWinningPlayer;

    function updateWinner(address winner) internal {
        lastWinningPlayer = winner;
    }

    function getLastWinner() public view returns (address) {
        return lastWinningPlayer;
    }

    function registerPlayer(address player) internal {
        if (!uniquePlayers[player]) {
            uniquePlayers[player] = true;
            playerList.push(player);
        }
    }

    function getAllPlayers() public view returns (address[] memory) {
        return playerList;
    }


    function registerWinner(address player) internal {
        if (!hasWon[player]) {
            hasWon[player] = true;
            winnerList.push(player);
        }
    }

    function getAllWinners() public view returns (address[] memory) {
        return winnerList;
    }

    function withdrawETH(uint256 _amount) external onlyOwner {
        require(address(this).balance >= _amount, "Insufficient balance");
        (bool success, ) = payable(owner).call{value: _amount}("");
        require(success, "ETH withdrawal failed");
    }

    receive() external payable {}
}
