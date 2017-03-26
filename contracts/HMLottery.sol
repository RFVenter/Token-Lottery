pragma solidity ^0.4.8;

import 'zeppelin/ownership/Ownable.sol';        // set specific function for owner only
import 'zeppelin/ownership/Contactable.sol';    // contract has contact info
import 'zeppelin/lifecycle/Killable.sol';       // contract may be killed
import 'zeppelin/SafeMath.sol';                 // safe mathematics functions
import 'zeppelin/token/ERC20.sol';              // ERC20 interface
import './ExampleToken.sol';

/// @title Hadi Morrow's Lottery
/// @author Riaan F Venter~ RFVenter~ <msg@rfv.io>
contract HMLottery is Ownable, SafeMath, Killable {

    // represents one bet made by a player
    struct bet {
        address player;             // the player that makes a bet
        uint tokensPlaced;          // the amount of tokens the player placed for the bet
        uint8[4] numbers;           // the selected power numbers that the player selected
        uint ratioIndex;            // the index of the payout ratios list item, relevant for this bet
        uint timestamp;             // timestamp that this bet was made
        uint rollIndex;             // the index of the roll that this bet is for
        uint winAmount;             // initialized to -1, in the event of a win this will be the amount
    }

    // the set ratios in case of winning 1, 2, 3 or 4 correct numbers
    struct ratio {
        uint[4] numberRatios;       // multiples of payouts (based on 2 decimals)
        uint timestamp;             // timestamp that these payout ratios where set
    }

    // represents a roll
    struct roll {
        uint8[4] numbers;           // the winning numbers generated based on the random seed
        string seed;                // the seed that was used
        uint totalWinnings;         // the grand total of all winners for this roll
        uint timestamp;             // timestamp that this roll was generated
    }

    bet[] public bets;              // history of all bets done
    ratio[] public ratios;          // history of all set ratios

    bytes32[] public hashedSeeds;   // list of hashes to prove that the seeds are pre-generated
    uint public nextHashedSeedIndex;// index of the next hash to use to verify the seed for RND

    roll[] public rolls;            // history of all rolls
    uint public nextRollIndex;      // the index for the first bet for the next roll
    uint public nextPayoutIndex;    // index of the next payout (for winners)

    uint public minimumBet;         // the minimum bet allowed
    uint public maximumBet;         // the maximum bet allowed
    address public tokenAddress;    // address of the token being used for this lottery

    string public codeAuthor = "Riaan Francois Venter <msg@rfv.io>";
    
    function HMLottery() {
        owner = msg.sender;         // set the owner of this contract to the creator of the contract
        minimumBet = 100;           // set the minimum bet
        maximumBet = 500;
        ratio memory nextRatio;

        // at these payout ratios the game pays out 50% tokens taken in (based on probability)
        nextRatio.numberRatios[0] = 3200;
        nextRatio.numberRatios[1] = 819200;
        nextRatio.numberRatios[2] = 209715200;
        nextRatio.numberRatios[3] = 53687091200;  
        nextRatio.timestamp = now;  // timestamp
        ratios.push(nextRatio);     // set the payout ratio

        nextRollIndex = 0;          // initialize the list index
        nextPayoutIndex = 0;        // initialize the list index

        // put one hash in for the next draw
        hashedSeeds.push(0x72e474042cda031650034d87b8fa155d65eccc294ac18e891bcf1c6b2d0cd031);
        nextHashedSeedIndex = 0;    // initialize the list index
    }

    // sets the ratios that will be used to multiply winnings based on correct numbers
    // !!! (based on 2 decimal precision [to select a multiple of 23.5 specify 2350])
    function setPayoutRatios(uint _oneNum, uint _twoNums, uint _threeNums, uint _fourNums) external onlyOwner {
        ratio memory nextRatio;

        nextRatio.numberRatios = [_oneNum, _twoNums, _threeNums, _fourNums];
        nextRatio.timestamp = now;
        ratios.push(nextRatio);
    }

    function setMinimumBet(uint _minimumBet) external onlyOwner {
        minimumBet = _minimumBet;
    }

    function setMaximumBet(uint _maximumBet) external onlyOwner {
        maximumBet = _maximumBet;
    }

    function setToken(address _token) external onlyOwner returns (bool) {     
        if (tokenAddress != 0) {
            // return all existing bets (because they will be in another token)
            //ERC20 token = ERC20(tokenAddress);
            // calculate all current bets total
            //uint allBets = 0;
            //for (var i = nextRollIndex; i < bets.length; i++) {
            //    allBets += bets[i].tokensPlaced;    
            //}
            // check if there is enough tokens in reserve to pay these players back
            //if (token.balanceOf(this) < allBets) return false;
            // refund each player
            //for (var j = nextRollIndex; j < bets.length; j++) {
            //    token.transfer(bets[j].player, bets[j].tokensPlaced); 
            //}
            // remove those bets from the list
            //bets.length = nextRollIndex;
            return false;
        }
    
        // change the token
        tokenAddress = _token;
        return true;
    }


    function rollNumbers(string _seed, string _nextHashedSeed) external onlyOwner returns (bool) {
        // check if the last payout was done
        if (nextRollIndex != nextPayoutIndex) return false;

        // make sure the given seed is correct for the next seedHash
        if (hashedSeeds[nextHashedSeedIndex] != sha3(_seed)) return false;

        // create the random number based on seed
        bytes20 combinedRand = ripemd160(_seed);
       
        uint8[4] memory numbers; 
        uint8 i = 0;
        while (i < 4) {
            numbers[i] = uint8(combinedRand);      // same as '= combinedRand % 256;'
            combinedRand >>= 8;                    // same as combinedRand /= 256;
            for (uint8 j = 0; j <= i; j++) {       // is newly picked val in a set?
                if (numbers[j] == numbers[i]) {    // if true then break to while loop and look for another Num[i]
                    i--;
                    break;
                }
            }
            i++;
        }
        // check all bets to see who won and how much, tally up the grand total
        uint totalWinnings = 0;

        for (uint b = nextRollIndex; b < bets.length; b++) {
            uint8 correctNumbers = 0;
            for (uint8 k = 0; k < 4; k++) {
                for (uint8 l = 0; l < 4; l++) {
                    if (bets[b].numbers[k] == numbers[l]) correctNumbers++;
                }
            }
            if (correctNumbers > 0) {
                bets[b].winAmount = bets[b].tokensPlaced * ratios[bets[b].ratioIndex].numberRatios[correctNumbers - 1];
                PlayerWon(bets[b].player, bets[b].winAmount);
                totalWinnings += bets[b].winAmount;
            }
            else bets[b].winAmount = 0;
        }

        // add a new roll with the numbers
        roll memory newRoll = roll(numbers, _seed, totalWinnings, now);
        rolls.push(newRoll);

        // move the nextRollIndex to end of the bets list
        nextRollIndex = bets.length;

        RollCompleted(numbers[0], numbers[1], numbers[2], numbers[3], totalWinnings);

        hashedSeeds.push(_nextHashedSeed);  // add the next Hashed Seed for the next draw
    }

    function payOut() external onlyOwner returns (bool) {
        ERC20 token = ERC20(tokenAddress);

        // check if the last payout was done
        if (nextRollIndex == nextPayoutIndex) return false;

        // check if there is enough tokens in reserve to pay these players back
        if (token.balanceOf(this) < rolls[rolls.length].totalWinnings) return false;

        // payout each winner
        for (uint p = nextPayoutIndex; p < nextRollIndex; p++) {
            if (bets[p].winAmount > 0) {
                token.transfer(bets[p].player, bets[p].winAmount);
                nextPayoutIndex++;                                  // move the nextPayoutIndex on
            }
        }
    }

    //// PUBLIC interface

    function placeBet(uint8 _numOne, uint8 _numTwo, uint8 _numThree, uint8 _numFour, uint _value) external returns (bool) {

        // check that the bet is within the min and max bet limits
        if ((_value < minimumBet) || (_value > maximumBet)) return false;

        // make sure that make sure that all numbers are different from each other!
        if (_numOne == _numTwo || _numOne == _numThree || _numOne == _numFour ||
            _numTwo == _numThree || _numTwo == _numFour ||
            _numThree == _numFour) return false;

        ERC20 token = ERC20(tokenAddress);
        // transfer the required tokens to this contract
        var success = token.transferFrom(msg.sender, address(this), _value);
        if (!success) return false;

        // tokens transfered so can now create a new bet
        bet memory newBet;
        newBet.player = msg.sender;
        newBet.tokensPlaced = _value;
        newBet.numbers = [_numOne, _numTwo, _numThree, _numFour];
        newBet.ratioIndex = ratios.length - 1;
        newBet.timestamp = now;

        // place it into the bets list
        bets.push(newBet);

        BetPlaced(msg.sender, _numOne, _numTwo, _numThree, _numFour, _value);
        return true;
    }

    // test functions, there are used for the unit testing and are not meant for production
    function testBetsLength() constant returns (uint) {
        return bets.length;
    }

    function testReturnBet(uint index) constant returns (address player, 
                                                     uint tokensPlaced, 
                                                     uint8 number1,
                                                     uint8 number2,
                                                     uint8 number3,
                                                     uint8 number4,
                                                     uint ratioIndex,
                                                     uint timestamp,
                                                     uint rollIndex,
                                                     uint winAmount) {
        bet outBet = bets[index];
        return (outBet.player, outBet.tokensPlaced, outBet.numbers[0], outBet.numbers[1], outBet.numbers[2], outBet.numbers[3], outBet.ratioIndex, outBet.timestamp, outBet.rollIndex, outBet.winAmount);
    }

    /////////////////

    event BetPlaced(address player, uint8 _numOne, uint8 _numTwo, uint8 _numThree, uint8 _numFour, uint _value);
    
    event PlayerWon(address player, uint _value);

    event RollCompleted(uint8 _numOne,
                        uint8 _numTwo, 
                        uint8 _numThree, 
                        uint8 _numFour, 
                        uint _totalWinnings);
}