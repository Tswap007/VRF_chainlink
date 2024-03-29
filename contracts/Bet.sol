// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";

/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/docs/link-token-contracts/
 */

contract Bet is VRFConsumerBaseV2, ConfirmedOwner {
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus)
        public s_requests; /* requestId --> requestStatus */
    VRFCoordinatorV2Interface COORDINATOR;

    // Your subscription ID.
    uint64 s_subscriptionId;

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    bytes32 keyHash =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 2;

    /**
     * HARDCODED FOR SEPOLIA
     * COORDINATOR: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
     */
    constructor(
        uint64 subscriptionId
    )
        VRFConsumerBaseV2(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625)
        ConfirmedOwner(msg.sender)
    {
        COORDINATOR = VRFCoordinatorV2Interface(
            0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
        );
        s_subscriptionId = subscriptionId;
    }

    // Assumes the subscription is funded sufficiently.
    function requestRandomWords()
        external
        onlyOwner
        returns (uint256 requestId)
    {
        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);
    }

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256[] memory randomWords) {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }

    // Structure to hold bet-related information for each user
    struct BetInfo {
        uint256 betNumber; // Chosen number for the bet (1-10)
        bool hasBetPlaced;
        uint256 betAmount;
    }

    // Mapping to store the BetInfo for each user
    mapping(address => BetInfo) public userBets;

    // Minimum and maximum bet amounts allowed
    uint256 public minBet;
    uint256 public maxBet;

    bool public roundIsActive;

    event BetPlaced(address userAddress, uint256 number, uint256 amount);

    // Function to check bet information for a specific user
    function checkBetInfo(
        address userAddress
    ) public view returns (uint256, bool, uint256) {
        BetInfo memory userBet = userBets[userAddress];

        uint256 betNumber = userBet.betNumber;
        bool hasBetPlaced = userBet.hasBetPlaced;
        uint256 betAmount = userBet.betAmount;

        return (betNumber, hasBetPlaced, betAmount);
    }

    function setRoundState() internal {
        if (roundIsActive) {
            roundIsActive = false;
        } else {
            roundIsActive = true;
        }
    }

    // Function to get the bet amount for a specific user
    function getBetAmount(address userAddress) public view returns (uint256) {
        (, , uint256 betAmount) = checkBetInfo(userAddress);
        return betAmount;
    }

    // Function to check if a user has placed a bet
    function getHasBetPlaced(address userAddress) public view returns (bool) {
        (, bool hasBetPlaced, ) = checkBetInfo(userAddress);
        return hasBetPlaced;
    }

    // Function to allow users to place a bet
    function placeBet(uint256 number) public payable {
        require(
            roundIsActive,
            "Round is inactive please wait for the next round"
        );
        // Check if the sent value falls within the specified range
        require(
            msg.value >= minBet && msg.value <= maxBet,
            "Bet amount should be within the specified range"
        );
        // Check if the chosen number is within the valid range
        require(
            number >= 1 && number <= 10,
            "Number should be within the range of 1 - 10"
        );
        // Check if the user has not already placed a bet
        require(
            getHasBetPlaced(msg.sender) == false,
            "User has bet placed, please wait for round to be finalized"
        );

        // Create a new BetInfo instance with the provided values
        BetInfo memory newBet = BetInfo({
            betNumber: number,
            hasBetPlaced: true,
            betAmount: msg.value
        });

        // Assign the new BetInfo instance to the user's address in the mapping
        userBets[msg.sender] = newBet;

        emit BetPlaced(msg.sender, number, msg.value);
    }

    function settleBet(uint256 winningNumber) public {}
}
