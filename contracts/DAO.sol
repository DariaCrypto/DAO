//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./interfaces/IERC20.sol";
import "./interfaces/IDAO.sol";

contract DAO is AccessControl, ReentrancyGuard {
    using Counters for Counters.Counter;

    Counters.Counter private proposalsCounter;
    Counters.Counter private activeUsers;

    bytes32 private constant CHAIRMAN_ROLE = keccak256("CHAIRMAN_ROLE");

    IERC20 private voteToken;
    uint256 private minimumQuorum;
    uint256 private debatingPeriodDuration;
    uint256 private minimumVotes;

    mapping(address => User) private _users;
    mapping(uint256 => Proposal) private _proposals;

    modifier endProposalCondition(uint256 proposalId) {
        require(
            _proposals[proposalId].EndTime <= block.timestamp,
            "DAO: Voting time is not over yet"
        );
        require(
            _proposals[proposalId].isFinished == false,
            "DAO: Voting has already ended"
        );
        _;
    }

    constructor(
        address _voteToken,
        uint256 _minimumQuorum,
        uint256 _debatingPeriodDuration,
        uint256 _minimumVotes
    ) {
        _grantRole(CHAIRMAN_ROLE, msg.sender);
        voteToken = IERC20(_voteToken);
        minimumQuorum = _minimumQuorum;
        debatingPeriodDuration = _debatingPeriodDuration;
        minimumVotes = _minimumVotes;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    /**
     *@notice Entering the number of votes for voting
     *@param amount number of votes entered
     */
    function deposit(uint256 amount) external {
        voteToken.transferFrom(msg.sender, address(this), amount);
        _users[msg.sender].balance += amount;
        activeUsers.increment();
        emit Credited(msg.sender, amount);
    }

    /**
     *@notice Adding a proposal for voting
     *@param callContract the address of the contract where the called function is stored
     *@param signature called function signature
     *@param description description of the proposal
     */
    function addProposal(
        address callContract,
        bytes calldata signature,
        string calldata description
    ) external onlyRole(CHAIRMAN_ROLE) nonReentrant {
        uint256 current = proposalsCounter.current();

        uint256 endTime;
        uint256 consenting;
        uint256 dissenters;
        uint256 usersVoted;
        address callContract;
        bool isFinished;
        bytes encodedMessage;
        string description;

        _proposals[current] = Proposal(
            block.timestamp + debatingPeriodDuration,
            0,
            0,
            0,
            callContract,
            false,
            signature,
            description
        );

        proposalsCounter.increment();
        emit ProposalAdded(current, block.timestamp);
    }

    /**
     *@notice Voting function
     *@param proposalId proposal id to vote
     *@param answer accept or reject proposal
     */
    function vote(uint256 proposalId, bool answer) external nonReentrant {
        require(_users[msg.sender].balance > 0, "DAO: No tokens on balance");
        require(
            _proposals[proposalId].EndTime > block.timestamp,
            "DAO: The voting is already over or does not exist"
        );
        require(
            _users[msg.sender]._isVoted[proposalId] == false,
            "DAO: You have already voted in this proposal"
        );

        answer
            ? _proposals[proposalId].consenting += _users[msg.sender].balance
            : _proposals[proposalId].dissenters += _users[msg.sender].balance;

        _users[msg.sender]._isVoted[proposalId] = true;
        _users[msg.sender].lastVoteEndTime = _proposals[proposalId].EndTime;
        _proposals[proposalId].usersVoted++;

        emit Voted(msg.sender, proposalId, answer);
    }

    /**
     *@notice End voting function
     *@param proposalId proposal id to end vote
     */
    function finishProposal(uint256 proposalId)
        external
        endProposalCondition(proposalId)
        nonReentrant
    {
        uint256 votersPercentage = _calculateVotersPercentage();
        Proposal storage proposal = _proposals[proposalId];

        uint256 votesAmount = proposal.consenting + proposal.dissenters;
        uint256 users = proposal.usersVoted * 10**3;

        if (votesAmount >= minimumVotes && users >= votersPercentage) {
            (bool success, bytes memory returnedData) = proposal
                .callContract
                .call{value: 0}(proposal.encodedMessage);
            require(success, string(returnedData));

            emit Finished(
                proposalId,
                true,
                proposal.callContract,
                votesAmount,
                proposal.usersVoted
            );
        } else {
            emit Finished(
                proposalId,
                false,
                proposal.callContract,
                votesAmount,
                proposal.usersVoted
            );
        }
        proposal.isFinished = true;
    }

    /**
     *@notice Finish voting function
     *@param proposalId proposal id to finish vote
     */
    function endProposal(uint256 proposalId)
        external
        endProposalCondition(proposalId)
    {
        require(
            msg.sender == address(this),
            "Only a contract can end proposal"
        );
        _proposals[proposalId].isFinished = true;
        emit FinishedEmergency(proposalId);
    }

    /**
     *@notice Withdraw vote tokens
     *@param amount of tokens for withdrawal
     */
    function withdrawTokens(uint256 amount) external {
        require(
            _users[msg.sender].balance >= amount,
            "DAO: Insufficient funds on the balance"
        );
        require(
            _users[msg.sender].lastVoteEndTime < block.timestamp,
            "DAO: The last vote you participated in hasn't ended yet"
        );

        _users[msg.sender].balance -= amount;

        if (_users[msg.sender].balance == 0) {
            activeUsers.decrement();
        }

        emit TokensWithdrawn(msg.sender, amount);
    }

    /**
     *@notice Get info about proposal
     *@param id proposals for which we want to receive data
     */
    function getProposalById(uint256 id)
        external
        view
        returns (Proposal memory)
    {
        return _proposals[id];
    }

    function getLastProposalId() external view returns (uint256) {
        return proposalsCounter.current();
    }

    function getActiveUsers() external view returns (uint256) {
        return activeUsers.current();
    }

    /**
     *@notice find out if the user voted or not
     *@param voter user's address to find out if he voted
     *@param proposalId proposal to find out if the user has voted
     */
    function isUserVoted(address voter, uint256 proposalId)
        external
        view
        returns (bool)
    {
        return _users[voter]._isVoted[proposalId];
    }

    /**
     *@notice find out the last voting time
     *@param voter the address where we want to receive information
     */
    function userLastVoteEndTime(address voter)
        external
        view
        returns (uint256)
    {
        return _users[voter].lastVoteEndTime;
    }

    function getBalance(address voter) external view returns (uint256) {
        return _users[voter].balance;
    }

    function getToken() external view returns (address) {
        return address(voteToken);
    }

    function getMinQuorum() external view returns (uint256) {
        return minimumQuorum;
    }

    function getDebatePeriod() external view returns (uint256) {
        return debatingPeriodDuration;
    }

    function getMinVotes() external view returns (uint256) {
        return minimumVotes;
    }

    /**
     *@notice find out the last voting time
     */
    function _calculateVotersPercentage() private view returns (uint256) {
        return ((activeUsers.current() * 10**3) / 100) * minimumQuorum;
    }
}
