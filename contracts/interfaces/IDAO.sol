// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.11;

interface IDAO {
    event Received(address indexed sender, uint256 amount);
    event ETHWithdrawn(address indexed receiver, uint256 indexed amount);

    event Credited(address indexed user, uint256 amount);
    event TokensWithdrawn(address indexed user, uint256 amount);

    event ProposalAdded(uint256 indexed id, uint256 time);
    event Voted(address indexed user, uint256 indexed proposal, bool answer);
    event FinishedEmergency(uint256 indexed proposalId);
    event Finished(
        uint256 indexed ProposalId,
        bool status,
        address indexed callContract,
        uint256 votesAmount,
        uint256 usersVoted
    );

    struct User {
        uint256 balance;
        uint256 lastVoteEndTime;
        mapping(uint256 => bool) _isVoted;
    }

    struct Proposal {
        uint256 endTime;
        uint256 consenting;
        uint256 dissenters;
        uint256 usersVoted;
        address callContract;
        bool isFinished;
        bytes encodedMessage;
        string description;
    }
}
