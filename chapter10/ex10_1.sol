//SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract Ramdom{
    event PaidAddress(address indexed sender, uint256 payment);
    event WinnerAddress(address indexed winner);

    modifier onlyOwner(){
        require(msg.sender == owner, "Ownable : Caller is not the owner");
        _;
    }

    mapping (uint256=> mapping(address => bool)) public paidAddressList;

    address public owner;
    uint private winnerNumber = 0;
    string private key1;
    uint private key2;
    uint public round = 1;
    uint public playNumber = 0;

    constructor(string memory _key1, uint _key2){
        owner = msg.sender;
        key1 = _key1;
        key2 = _key2;
        winnerNumber = randomNumber();
    }

    receive() external payable{
        require(msg.value == 10**16, "Must be 0.01 ether."); 
        //0.01 ether만 받을 수 있음을 의미한다.
        //1 ether는 1018을 나타내므로 0.01 ether는 1016을 나타낸다.

        require(paidAddressList[round][msg.sender]==false, "Must be the first time.");
        //중복 참여 여부를 판가름한다.
        //즉, 참여하는 주소가 paidAddressList 매핑에 false를 반환한다면 중복 참여한 주소가 아니므로 트랜잭션은 실패하지 않는다.

        paidAddressList[round][msg.sender] = true;
        //게임에 참여한 주소는 paidAddressList 매핑에 ture로 값이 변경된다.
        //즉, 게임에 참여한 주소로 더 이상 참여를 할 수 없다.

        ++playNumber;
        //변수가 1만큼 증가한다.
        //즉, playNumber변수는 현재 주소가 몇 번째 참가자인지 나타내며 게임에 정상적으로 참가했기에 1이 증가한다.
        //현재 참가 번째를 나타내는 playNumber와 우승자를 나타내는 숫자 winnerNumber가 같지 않다면 현재 참가자는 우승자가 아닌 것을 의미한다.
        
        //이때는 if 조건문의 else문이 실행돼 바로 paidAddress 이벤트가 출력된다.
        //반면에 두 변수의 값이 같다면 우승자를 나타내므로 if 조건문의 로직이 실행될 것이다.


        if(playNumber == winnerNumber){
            (bool success, ) = msg.sender.call{value:address(this).balance}("");
            require(success, "Failed");
            playNumber = 0;
            ++round;
            winnerNumber=randomNumber();
            emit WinnerAddress(msg.sender);

            //call 함수를 통해 Random 스마트 컨트랙트에 누적된 잔액을 msg.sender의 주소로 보낸다.
            //여기서 msg.sender의 주소는 게임을 참여한 사람의 주소, 즉 우승자의 주소가 된다.
            //결론적으로 우승자에게 누적된 이더를 보낸다.
            //그러고 나서 playNumber를 0으로 초기화하고 변수 round에 1을 증가하여 다음 게임의 회차가 되게 한다.
            //즉 매핑 paidAddressList의 첫 번째 매핑의 키가 변경됐으므로 게임 참가 중복 여부를 나타내는 두 번째 매핑은 초기화된다.
            //그러고 나서 winnerNumber는 함수 randomNumber를 통해 새로운 값을 입력받고 이벤트 WinnerAddress가 출력된다. 
        
        }else{
            emit PaidAddress(msg.sender, msg.value);
        }
    }

    function randomNumber() private view returns(uint){
        //난수 값을 생성해 반환하며 반환된 난수는 변수 winnerNumber에 대입된다.
        uint num = uint(keccak256(abi.encode(key1))) + key2 + (block.timestamp) + (block.number);
        return (num-((num/10)*10))+1;

        //먼저 문자열형 kwy1과 정수형 key2는 Random 스마트 컨트랙트를 배포할 때 생성자의 매개변수로 입력받으며 배포자만 이 두 개의 변수의 값을 알 것이다.
        //전역 변수 block.timestamp와 block.number는 블록의 현재 시간과 블록의 현재 번호
        //즉 블록의 현재 시간과 블록의 현재 번호는 트랜잭션이 일어나서 새로운 블록이 생성될 때마다 항상 변하므로 우승자가 나올 때마다 이 함수는 난수를 반환한다.
    }
    //위의 함수처럼 난수를 생성하는 것은 보안적으로 취약하며 key1과 key2를 스마트 컨트랙트에 저장하는 것은 보안적으로 치명적이다.



     //모디파이어 onlyOwner가 적용되어 있어 배포자맞 setSecreteKey와 getSecretkey 함수를 실행할 수 있다.
    function setSecretKey(string memory _key1, uint _key2) public onlyOwner(){
        key1 = _key1;
        key2 = _key2;
    }

    function getSecretKey() public view onlyOwner() returns(string memory, uint){
        return(key1, key2);
    }

    function getWinnerNumber() public view onlyOwner() returns(uint256){
        return winnerNumber;
    }

    function getRound() public view returns(uint256){
        return round;
    }

    function getbalance() public view returns(uint256){
        return address(this).balance;
    }
}