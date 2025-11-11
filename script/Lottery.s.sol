// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Lottery} from "src/Lottery.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract LotteryScript is Script {
    function run() external {}

    function deployLottery() public returns (Lottery, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast();
        Lottery lottery = new Lottery(
            config.entranceFee,
            config.lotteryInterval,
            config.vrfCoordinatorAddress,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        return (lottery, helperConfig);
    }
}
