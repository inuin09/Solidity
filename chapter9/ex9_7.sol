//SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract ex9_7{
    event Obtain(address from, uint amount);

    fallback() external payable{
        emit Obtain(msg.sender, msg.value);
    }
    function getBalance() public view returns(uint){
        return address(this).balance;
    }
    function sendEther() public payable{
        payable(address(this)).transfer(msg.value);
    }
}