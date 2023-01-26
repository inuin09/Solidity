const Lottery = artifacts.require("Lottery");
const assertRevert = require('./assertRevert');
const expectEvent = require('./expectEvent');

contract('Lottery', function([deployer, user1, user2]){
    let lottery;
    let betAmount = 5 * 10 ** 15;
    let betAmountBN = new web3.utils.BN('5000000000000000');
    let bet_block_interval = 3;
    //ganache에 있는 10개의 주소가 차례대로 들어오게 됨으로 deployer는 0번 주소가 user1은 1번 주소, user2는 2번 주소가 들어오게 된다.
    beforeEach(async()=>{
        lottery = await Lottery.new(); //lottery contract를 배포하는 , 괄호안에 아무것도 안 적어주면 기본적으로 0번 주소가 배포자가 됨.
    })

    it('getPot should return current pot', async()=>{
        let pot = await lottery.getPot();
        assert.equal(pot, 0)
    })

    describe('Bet', function(){
        it('sholud fail when the bet money is not 0.005ETH', async () =>{
            //돈(0.005ETH)이 적절하게 들어오지 않았을 때 test , 0.005ETH가 안들어오면 다시 돌려줘야함.
            //fail transaction
            await assertRevert(lottery.bet('0xab', {from : user1, value : 4000000000000000}))
            //transaction object : chainId, value, to, from, gas(Limit), gasPrice 등등을 말함.
        })
        it('should put the bet to the bet queue with 1 bet', async () =>{
            //betting
            let receipt = await lottery.bet('0xab', {from : user1, value : betAmount})
            let pot = await lottery.getPot();
            assert.equal(pot, 0);

            //컨트랙트에 밸런스가 제대로 잘 쌓였는지 확인 == 0.005ETH와 같은지 확인
            //이더를 스마트 컨트랙트에 보내면 그 스마트 컨트랙트 주소가 이더를 들고 있게 되면서 밸런스가 발생함.
            let contractBalance = await web3.eth.getBalance(lottery.address);
            assert.equal(contractBalance, betAmount);

            //betting Info 확인
            let currentBlockNumber = await web3.eth.getBlockNumber();
            let bet = await lottery.getBetInfo(0); 

            assert.equal(bet.answerBlockNumber, currentBlockNumber + bet_block_interval);
            assert.equal(bet.bettor, user1);
            assert.equal(bet.challenges, '0xab');

            //log가 제대로 찍혔는지 확인
            await expectEvent.inLogs(receipt.logs, 'BET');
        })
    })

    describe('distribute', function(){
        describe('When the answer is checkable', function(){
            //정답을 확인할 수 있었던 상황
            it.only('should give the user the pot when the answer matches', async () =>{
                //1. 두글자 전부 맞았을 때

                //정답을 정해주는 부분
                await lottery.setAnswerForTest('0xabce7a59a4103574244a090e8e515840531fb08bbe91555954f5e2f381239280', {from : deployer})
                await lottery.betAndDistribute('0xef', {from : user2, value:betAmount}) //1 block -> 4 block에 배팅, user2가 던지고, user1이 맞추는 방식으로 정해보자.
                await lottery.betAndDistribute('0xef', {from : user2, value:betAmount}) //2 -> 5
                await lottery.betAndDistribute('0xab', {from : user1, value:betAmount}) //3 -> 6 , 정답을 맞춘 block
                await lottery.betAndDistribute('0xef', {from : user2, value:betAmount}) //4 -> 7
                await lottery.betAndDistribute('0xef', {from : user2, value:betAmount}) //5 -> 8
                await lottery.betAndDistribute('0xef', {from : user2, value:betAmount}) //6 -> 9
                
                let potBefore = await lottery.getPot(); //2번 쌓여야 하니까 0.005ETH * 2 = 0.01ETH가 있어야 함
                let user1BalanceBefore = await web3.eth.getBalance(user1); //기존에 가지고 있던 밸런스

                let receipt7 = await lottery.betAndDistribute('0xef', {from : user2, value:betAmount}) //7 , 3 block에 배팅한 사람의 결과가 여기서 확인 가능함.

                let potAfter = await lottery.getPot(); //0 ETH
                let user1BalanceAfter = await web3.eth.getBalance(user1); //before에 비해서 0.015만큼 증가해야 한다.

                //pot money의 변화 확인
                assert.equal(potBefore.toString(), new web3.utils.BN('10000000000000000').toString());
                assert.equal(potAfter.toString(), new web3.utils.BN('0').toString());

                //user(winner)의 밸런스 확인
                user1BalanceBefore = new web3.utils.BN(user1BalanceBefore);
                assert.equal(user1BalanceBefore.add(potBefore).add(betAmountBN).toString(), new web3.utils.BN(user1BalanceAfter).toString())

            })
            it('should give the user the amount he or she bet when a single character mathces', async () =>{
                //2. 한글자만 맞았을 때 (배팅한 금액만 주기로 함)
                await lottery.setAnswerForTest('0xabce7a59a4103574244a090e8e515840531fb08bbe91555954f5e2f381239280', {from : deployer})
                await lottery.betAndDistribute('0xef', {from : user2, value:betAmount}) //1 block -> 4 block에 배팅, user2가 던지고, user1이 맞추는 방식으로 정해보자.
                await lottery.betAndDistribute('0xef', {from : user2, value:betAmount}) //2 -> 5
                await lottery.betAndDistribute('0xaf', {from : user1, value:betAmount}) //3 -> 6 , 정답을 맞춘 block
                await lottery.betAndDistribute('0xef', {from : user2, value:betAmount}) //4 -> 7
                await lottery.betAndDistribute('0xef', {from : user2, value:betAmount}) //5 -> 8
                await lottery.betAndDistribute('0xef', {from : user2, value:betAmount}) //6 -> 9
                
                let potBefore = await lottery.getPot(); //2번 쌓여야 하니까 0.005ETH * 2 = 0.01ETH가 있어야 함
                let user1BalanceBefore = await web3.eth.getBalance(user1); //기존에 가지고 있던 밸런스

                let receipt7 = await lottery.betAndDistribute('0xef', {from : user2, value:betAmount}) //7 , 3 block에 배팅한 사람의 결과가 여기서 확인 가능함.

                let potAfter = await lottery.getPot(); //0.01 ETH
                let user1BalanceAfter = await web3.eth.getBalance(user1); //before + 0.005 ETH

                //pot money의 변화 확인
                assert.equal(potBefore.toString(),potAfter.toString());

                //user(winner)의 밸런스 확인
                user1BalanceBefore = new web3.utils.BN(user1BalanceBefore);
                assert.equal(user1BalanceBefore.add(betAmountBN).toString(), new web3.utils.BN(user1BalanceAfter).toString())
                
            })
            it('should get the eth of user when the answer does not natch at all', async () =>{
                //3. 다 틀렸을 때
                await lottery.setAnswerForTest('0xabce7a59a4103574244a090e8e515840531fb08bbe91555954f5e2f381239280', {from : deployer})
                await lottery.betAndDistribute('0xef', {from : user2, value:betAmount}) //1 block -> 4 block에 배팅, user2가 던지고, user1이 맞추는 방식으로 정해보자.
                await lottery.betAndDistribute('0xef', {from : user2, value:betAmount}) //2 -> 5
                await lottery.betAndDistribute('0xef', {from : user1, value:betAmount}) //3 -> 6 , 정답을 맞춘 block
                await lottery.betAndDistribute('0xef', {from : user2, value:betAmount}) //4 -> 7
                await lottery.betAndDistribute('0xef', {from : user2, value:betAmount}) //5 -> 8
                await lottery.betAndDistribute('0xef', {from : user2, value:betAmount}) //6 -> 9
                
                let potBefore = await lottery.getPot(); //2번 쌓여야 하니까 0.005ETH * 2 = 0.01ETH가 있어야 함
                let user1BalanceBefore = await web3.eth.getBalance(user1); //기존에 가지고 있던 밸런스

                let receipt7 = await lottery.betAndDistribute('0xef', {from : user2, value:betAmount}) //7 , 3 block에 배팅한 사람의 결과가 여기서 확인 가능함.

                let potAfter = await lottery.getPot(); //0.015 ETH
                let user1BalanceAfter = await web3.eth.getBalance(user1); //before 

                //pot money의 변화 확인
                assert.equal(potBefore.add(betAmountBN).toString(),potAfter.toString());

                //user(winner)의 밸런스 확인
                user1BalanceBefore = new web3.utils.BN(user1BalanceBefore);
                assert.equal(user1BalanceBefore.toString(), new web3.utils.BN(user1BalanceAfter).toString())
               
            })

        })
        describe('When the answer is not revealed (Not Minned)', function(){
            //blockhash값을 확인할 수 없는 상황 중 첫번째 : block이 마이닝 되지 않았을 때

        })
        describe('When the answer is not revealed (Block limit is passed)', function(){
            //blockhash값을 확인할 수 없는 상황 중 두번째 : 아예 채굴되지 않았을 때
        })
    })

    describe('isMatch', function(){
        let blockHash='0xabce7a59a4103574244a090e8e515840531fb08bbe91555954f5e2f381239280'

        it('should be BettingResult.Win when two characters match', async () =>{
            let matchingResult = await lottery.isMatch('0xab', blockHash);
            assert.equal(matchingResult, 1);
        })
        it('should be BettingResult.Fail when two characters match', async () =>{
            let matchingResult = await lottery.isMatch('0xcd', blockHash);
            assert.equal(matchingResult, 0);
        })
        it('should be BettingResult.Draw when two characters match', async () =>{
            let matchingResult = await lottery.isMatch('0xaf', blockHash);
            assert.equal(matchingResult, 2);

            matchingResult = await lottery.isMatch('0xfb', blockHash);
            assert.equal(matchingResult, 2);
        })
    })
});