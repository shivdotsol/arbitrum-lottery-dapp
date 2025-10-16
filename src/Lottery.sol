// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Lottery is VRFConsumerBaseV2Plus {
    /* errors */
    error InsufficientEntryFee();
    error TransferFailed();
    error LotteryNotOpen();

    /* types */
    enum LotteryState {
        OPEN,
        CALCULATING
    }

    /* state variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint256 private immutable ENTRANCE_FEE;
    uint256 private s_lastTimeStamp; // last time winner was picked
    uint256 private immutable LOTTERY_INTERVAL; // seconds after which winner is picked
    bytes32 private immutable KEY_HASH;
    uint256 private immutable SUBSCRIPTION_ID;
    uint32 private immutable CALLBACK_GAS_LIMIT;
    address payable[] private s_players;
    address private s_latestWinner;
    LotteryState private s_lotteryState;

    /* events */
    event PlayerJoined(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 entranceFee,
        uint256 lotteryInterval,
        address vrfCoordinatorAddress,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinatorAddress) {
        ENTRANCE_FEE = entranceFee;
        LOTTERY_INTERVAL = lotteryInterval;
        s_lastTimeStamp = block.timestamp;
        KEY_HASH = gasLane;
        SUBSCRIPTION_ID = subscriptionId;
        CALLBACK_GAS_LIMIT = callbackGasLimit;
        s_lotteryState = LotteryState.OPEN;
    }

    function enterLottery() external payable {
        if (s_lotteryState != LotteryState.OPEN) {
            revert LotteryNotOpen();
        }
        if (msg.value < ENTRANCE_FEE) {
            revert InsufficientEntryFee();
        }
        s_players.push(payable(msg.sender));
        emit PlayerJoined(msg.sender);
    }

    // get a random num from Chainlink VRF
    // pick a winner using that num
    // automate this function call using Chainlink

    function pickWinner() external {
        uint256 interval = block.timestamp - s_lastTimeStamp;
        if (interval < LOTTERY_INTERVAL) {
            revert();
        }

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: KEY_HASH,
                subId: SUBSCRIPTION_ID,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                numWords: 1,
                callbackGasLimit: CALLBACK_GAS_LIMIT,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 winningIndex = randomWords[0] % s_players.length;
        address payable winner = s_players[winningIndex];
        s_latestWinner = winner;
        s_lotteryState = LotteryState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(winner);
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert TransferFailed();
        }
    }

    // getter functions

    function getEntranceFee() external view returns (uint256) {
        return ENTRANCE_FEE;
    }
}
