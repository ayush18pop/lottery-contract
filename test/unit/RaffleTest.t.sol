//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployRaffle();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitialization() external {
        assert((raffle.getRaffleState()) == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouDontPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        //arrange
        vm.prank(PLAYER);
        //act
        raffle.enterRaffle{value: entranceFee}();
        //assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit Raffle.RaffleEntered(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhenRaffleIsCalculating() public {
        //arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        //act
        vm.warp(block.timestamp + interval + 1);
        //warp means to move the time forward, here's how it works:
        // 1. The current block timestamp is increased by the interval + 1 second
        // 2. The block number is incremented by 1
        vm.roll(block.number + 1);
        //this is what vm.roll does:
        // 1. It sets the block number to the next block number
        // 2. It sets the block timestamp to the current time

        raffle.performUpkeep("");
        //assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /*///////////////////////////////////////////////
                CHECK UPKEEP TESTS
    ///////////////////////////////////////////////*/

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        //ARRANGE
        //explanation: we are not sending any ether to the raffle contract
        //so it has no balance
        //this is needed because the checkUpkeep function checks if the time has passed
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //ACT
        //explanation: we are calling checkUpkeep with an empty calldata
        //why empty? because we are not using it in this test
        //why not using it? because we are just testing the balance
        //why we are testing the balance? because we want to see if it returns false
        //why we want to see if it returns false? because we want to see if it has no balance
        //why we want to see if it has no balance? because we want to see if it returns false
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //ASSERT

        //why are we checking upkeepNeeded if we're testing it for balance checking
        //so we're making sure that raffle is open while testing the balance
        assert(!upkeepNeeded);
    }

    function testCheckUpKeepReturnsFalseIfRaffleIsNotOpen() public {
        //arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        //act
        //this makes sure that the raffle is not open
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //this will change the raffle state to calculating
        raffle.performUpkeep("");
        //assert
        //this checks if the upkeep is needed
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();
        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                rState
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsEvent()
        public
        raffleEntered
    {
        //arranged already in the modifier

        //act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // Find the log with the event signature for RandomWordsRequested
        uint256 requestId;
        for (uint256 i = 0; i < entries.length; i++) {
            // The event signature for RandomWordsRequested is: keccak256("RandomWordsRequested(...)")
            // But you can just check if topics[0] matches the expected event hash
            if (
                entries[i].topics.length > 1 &&
                uint256(entries[i].topics[1]) != 0
            ) {
                requestId = uint256(entries[i].topics[1]);
                break;
            }
        }
        // Now use requestId for fulfillRandomWords
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            requestId,
            address(raffle)
        );

        //assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert((uint256(requestId)) > 0);
        assert(uint256(raffleState) == 1);
    }

    /*///////////////////////////////////////////////
                FULFILLRANDOMWORDS
    ///////////////////////////////////////////////*/

    function testFulfillrandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 requestId
    ) public raffleEntered {
        // Arrange / Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            requestId,
            address(raffle)
        );
    }

    // function testFulfillRandomWordsPicksAWinnerResetsAndSendMoney()
    //     public
    //     raffleEntered
    // {
    //     uint256 startingIndex = 1;
    //     address expectedWinner = address(1);
    //     uint256 additionalEntrants = 3;
    //     for (
    //         uint256 i = startingIndex;
    //         i < startingIndex + additionalEntrants;
    //         i++
    //     ) {
    //         address newPlayer = address(uint160(i));
    //         hoax(newPlayer, 1 ether);
    //         raffle.enterRaffle{value: entranceFee}();
    //     }

    //     uint256 startingTimestamp = raffle.getLastTimeStamp();
    //     uint256 winnerStartingBalance = expectedWinner.balance;
    //     //act
    //     vm.recordLogs();
    //     raffle.performUpkeep("");
    //     Vm.Log[] memory entries = vm.getRecordedLogs();
    //     bytes32 requestId = entries[1].topics[1];

    //     VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
    //         uint256(requestId),
    //         address(raffle)
    //     );

    //     //assert
    //     address recentWinner = raffle.getRecentWinner();
    //     Raffle.RaffleState raffleState = raffle.getRaffleState();
    //     uint256 winnerBalance = recentWinner.balance;
    //     uint256 endingTimeStamp = raffle.getLastTimeStamp();
    //     uint256 prize = entranceFee * (additionalEntrants + 1);

    //     assert(recentWinner == expectedWinner);
    //     assert(uint256(raffleState) == 0);
    //     assert(winnerBalance == winnerStartingBalance + prize);
    //     assert(endingTimeStamp > startingTimestamp);
    // }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendMoney()
        public
        raffleEntered
    {
        // Arrange
        uint256 additionalEntrance = 3; // 4 people total
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrance;
            i++
        ) {
            address newPlayer = address(uint160(i));
            // prank & deal
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs(); // record logs emitted from events
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrance + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
