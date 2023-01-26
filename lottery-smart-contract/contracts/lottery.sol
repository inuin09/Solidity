//SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract Lottery{
    struct BetInfo{
        uint256 answerBlockNumber;
        address payable bettor;
        bytes1 challenges; //1bytes의 값의 글자가 저장됨. 이 글자와 맞춰서 정답을 확인할 수 있는 것임 
    }

    mapping (uint256=>BetInfo) private _bets;
    uint256 private _tail;
    uint256 private _head;

    address payable public owner;
    //owner가 public이기 때문에 외부에서 바로 owner(주소값)을 확인할 수 있다.

    uint256 private _pot;
    uint256 constant internal BET_AMOUNT = 5 * 10 ** 15;
    uint256 constant internal BET_BLOCK_INTERVAL = 3;
    uint256 constant internal BLOCK_LIMIT = 256;

    bool private mode = false; //false : test mode, true : use real block hash
    bytes32 public answerForTest;

    enum BlockStatus {Checkable, NotRevealed, BlockLimitPassed}
    enum BettingResult {Fail, Win, Draw} //fail 0, win 1, draw 2
    event BET(uint256 index, address bettor, uint256 amount, bytes1 challenges, uint256 answerBlockNumber);
    event WIN(uint256 index, address bettor, uint256 amount, bytes1 challenges, bytes1 answer, uint256 answerBlockNumber);
    event FAIL(uint256 index, address bettor, uint256 amount, bytes1 challenges, bytes1 answer, uint256 answerBlockNumber);
    event DRAW(uint256 index, address bettor, uint256 amount, bytes1 challenges, bytes1 answer, uint256 answerBlockNumber);
    event REFUND(uint256 index, address bettor, uint256 amount, bytes1 challenges, uint256 answerBlockNumber);

    constructor() {
        //배포가 될 때 가장 먼저 실행되는 함수
        //배포가 될 때 보낸 사람으로 owner을 설정하겠다는 의미
        owner = payable(msg.sender);
    }

    function getPot() public view returns(uint256 pot){
        return _pot;
    }

    //queue 생성
    function getBetInfo(uint256 index) public view returns(uint256 answerBlockNumber, address bettor, bytes1 challenges){
        BetInfo memory b = _bets[index];
        answerBlockNumber = b.answerBlockNumber;
        bettor = b.bettor;
        challenges = b.challenges;
    }

    //push
    function pushBet(bytes1 challenges) internal returns(bool){
        BetInfo memory b;
        b.bettor = payable(msg.sender);
        b.answerBlockNumber = block.number + BET_BLOCK_INTERVAL;
        b.challenges = challenges;

        _bets[_tail] = b;
        _tail++;

        return true;
    }

    //pop
    function popBet(uint256 index) internal returns(bool){
        delete _bets[index];

        return true;
    }

    function betAndDistribute(bytes1 challenges) public payable returns(bool result){
        bet(challenges);

        distribute();

        return true;
    }

    //배팅
    /*
    * @dev 배팅을 한다. 유저는 0.005ETH를 보내야 하고, 배팅용 1byte 글자를 보낸다.
    * 큐에 저장된 배팅 정보는 이후  distribute 함수에서 해결된다. 
    * @param challenges 유저가 배팅하는 글자.
    * @return 함수가 잘 수행되었는지 확인하는 bool 값
    */
    function bet(bytes1 challenges) public payable returns(bool result){
        //돈이 제대로 들어왔는지 확인하기
        require(msg.value == BET_AMOUNT, "Not enough ETH");
        //큐에 bet 정보를 넣기
        require(pushBet(challenges), "Fail to add a new Bet Info");
        //event log 찍어보기
        emit BET(_tail - 1, msg.sender, msg.value, challenges, block.number+BET_BLOCK_INTERVAL);
        

        return true;
    }

    //검증(distribute) : 정답을 체크하고, 정답을 맞춘 사람에게는 돈을 돌려주고, 정답을 못 맞춘 사람의 돈은 팟 머니에 저장한다.
        //결괏값을 검증
        //결과값이 다르면 팟머니에 넣고, 맞으면 돌려준다.
    /**
    *@dev 배팅 결괏값을 확인하고 팟머니를 분배한다.
    *정답 실패 : 팟머니 축적 / 정답 맞춤 : 팟머니 획득 / 한글자 맞춤 or 정답 확인 불가 : 배팅 금액만 획득
     */
    function distribute() public{
        /*
        queue에 저장된 배팅 정보가 (head)3 4 5 6 7 8 9 10(tail) 으로 저장되어 있다고 가정하자.
        새로운 정보가 들어오면 tail 방향으로 들어옴 => 3 4 5 6 7 8 9 10 11 12...
        우리는 3번에 있는 값을 확인해봐서 정답이 맞으면 정답이 맞은 사용자에게 돈을 주고, 3을 pop해야함.
        이런식으로 진행하다가 더이상 정답을 확인할 수 없을 때(내가 배팅한 블록이 아직 마이닝 되지 않았을 때를 의미함) 게임을 멈추게 됨.
        */

        //haed부터 tail까지 도는 roof를 하나 만들어 준다.
        uint256 cur; //roof의 시작! 
        uint256 transferAmount;
        BetInfo memory b;
        BlockStatus currentBlockStatus;
        BettingResult currentBettingResult;

        for(cur=_head;cur<_tail;cur++){
            b=_bets[cur];
            currentBlockStatus = getBlockStatus(b.answerBlockNumber);

            //1. 정답을 체크할 수 있을 때(가장 기본적인 상태) : 현재 blockNumber가 내가 확인해야하는 blockNumber보다 커야함. (block.number > AnswerBlockNumber && block.number < BLOCK_LIMIT + AnswerBlockNumber)
            if(currentBlockStatus == BlockStatus.Checkable){
                bytes32 answerBlockHash = getAnswerBlockHash(b.answerBlockNumber);
                currentBettingResult = isMatch(b.challenges, getAnswerBlockHash(b.answerBlockNumber)); //가져온 결괏값
                //두 글자 모두 맞췄을 때(win), bettor가 pot money를 가져간다.
                if(currentBettingResult == BettingResult.Win){
                    //transfer pot
                    transferAmount = transferAfterPayingFee(b.bettor, _pot + BET_AMOUNT);
                    //pot = 0
                    _pot = 0;
                    //emit Win
                    emit WIN(cur, b.bettor, transferAmount, b.challenges, answerBlockHash[0], b.answerBlockNumber);
                }
                //두 글자 모두 못 맞췄을 때(fail), bettor의 돈이 pot money로 들어간다.
                if(currentBettingResult == BettingResult.Fail){
                    //pot = pot + BET_AMOUNT
                    _pot += BET_AMOUNT;
                    //emit FAIL
                    emit FAIL(cur, b.bettor, 0, b.challenges, answerBlockHash[0], b.answerBlockNumber);
                }
                //한 글자만 맞췄을 때(draw), bettor의 돈이 환불된다.
                if(currentBettingResult == BettingResult.Draw){
                    //transfer only BET_AMOUNT
                    transferAmount = transferAfterPayingFee(b.bettor, BET_AMOUNT);
                    //emit DRAW
                    emit DRAW(cur, b.bettor, transferAmount, b.challenges, answerBlockHash[0], b.answerBlockNumber);
                }
                
            }
            //blockhash를 확인할 수 없는 경우 2가지 : 아직 blockhash가 마이닝 되지 않았을 때 / block이 마이닝 되었지만 너무 오래전 block이어서 확인할 수 없을 때
            //2. block이 마이닝 되지 않았을 때 : block.number <= AnswerBlockNumber
            if(currentBlockStatus == BlockStatus.NotRevealed){
                break;
            }
            //3. block이 너무 오래되었을 때 : block.number >= AnswerBlockNumber + BLOCK_LIMIT
            if(currentBlockStatus == BlockStatus.BlockLimitPassed){
                //환불 && emit refund
                //refund
                transferAmount = transferAfterPayingFee(b.bettor, BET_AMOUNT);
                //emit refund
                emit REFUND(cur, b.bettor, transferAmount, b.challenges, b.answerBlockNumber);
                
            }
            popBet(cur);
        }
        _head = cur;
    }

    function transferAfterPayingFee(address payable addr, uint256 amount) internal returns(uint256){
        //uint256 fee = amount / 100;
        uint256 fee = 0;
        uint256 amountWithoutFee = amount - fee;

        //transfer to addr
        addr.transfer(amountWithoutFee);
        //transfer to owner
        owner.transfer(fee);

        return amountWithoutFee; 
    }

    function setAnswerForTest(bytes32 answer) public returns(bool result){
        require(msg.sender == owner, "Only owner can set the answer for test mode");
        answerForTest = answer;
        return true;
    }

    function getAnswerBlockHash(uint256 answerBlockNumber) internal view returns(bytes32 answer){
        return mode ? blockhash(answerBlockNumber) : answerForTest;
    }

    /*
    @dev 배팅글자와 정답을 확인한다.
    @param challenges 배팅 글자
    @param answer blockhash
    @return 정답결과
    */
    function isMatch(bytes1 challenges, bytes32 answer) public pure returns(BettingResult){
        /*
        정답을 확인하는 함수
        challenges = 0xab와 같은 글자
        answer = 0xab....같은 32bytes의 글자
        우리가 할 일 : challenges와 answer의 각각 첫번째를 뽑아와서 비교하기 && 각각의 두 번째 글자를 뽑아와서 비교하기
        */

        bytes1 c1 = challenges;
        bytes1 c2 = challenges;

        bytes1 a1 = answer[0];
        bytes1 a2 = answer[0];

        //1. 첫 번째 글자 뽑아와서 비교하기
        c1 = c1>>4; //0xab를 오른쪽으로 shift 4를 하게 되면 0x0a가 됨
        c1 = c1<<4; //다시 왼쪽으로 4 shift를 하게 되면 0xa0이 됨

        a1 = a1>>4;
        a1 = a1<<4;

        //2. 두 번째 글자 뽑아와서 비교하기
        c2 = c2<<4; //0xab -> 0xb0
        c2 = c2>>4; //0xb0 -> 0x0b

        a2 = a2<<4;
        a2 = a2>>4;

        if(a1 == c1 && a2 == c2){
            return BettingResult.Win;
        }

        if(a1 == c1 || a2 == c2){
            return BettingResult.Draw;
        }

        return BettingResult.Fail;
    }

    function getBlockStatus(uint256 AnswerBlockNumber) internal view returns(BlockStatus){
        if(block.number > AnswerBlockNumber && block.number < BLOCK_LIMIT + AnswerBlockNumber){
            return BlockStatus.Checkable;
        }
        if(block.number <= AnswerBlockNumber){
            return BlockStatus.NotRevealed;
        }
        if(block.number >= AnswerBlockNumber + BLOCK_LIMIT){
            return BlockStatus.BlockLimitPassed;
        }

        return BlockStatus.BlockLimitPassed;
    }

}