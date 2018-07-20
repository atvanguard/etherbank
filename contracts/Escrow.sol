pragma solidity ^0.4.24;

contract Escrow {
  struct Collateral {
    address tokenAddress;
    uint amount;
  }

  struct loan {
    address lender;
    // min amout to loan
    uint min;
    // max amout to loan
    uint max;
    // duration after which the collateral tokens will be released to the lender
    uint duration;
    // expire loan if not taken
    uint expiration;
    // acceptable collaterals, tokens and amounts
    bytes3[] tokens;
    uint[] tokenAmounts;
  }

  struct ExecutedLoan {
    address borrower;
    uint expiration;
  }

  address owner;
  mapping(address => uint) balances;
  // whitelisted ERC20 tokens that can be held as collateral
  address[] whitelistedTokens;
  uint numLoan;
  // maps loanID to loan object
  mapping(uint => loan) loans;
  // maps loanID to borrower
  mapping(uint => ExecutedLoan) borrowers;

  constructor() public {
    owner = msg.sender;
  }

  modifier isOwner() {
    if (msg.sender == owner) _;
  }

  modifier lender(uint loanID) {
    if (msg.sender == loans[loanID].lender) _;
  }

  function deposit() public payable {
    balances[msg.sender] += msg.value;
  }

  function withdraw(uint _amount) public {
    uint amount = _amount;
    uint balance = getBalance(msg.sender);
    if (amount > balance) {
      amount = balance;
      if (amount > 0) {
        balances[msg.sender] -= amount;
        msg.sender.transfer(amount);
      }
    }
  }

  function advertiseLoan(
      uint min, uint max, uint duration, uint expiration,
      bytes3[] tokens, // collateral tokens
      uint[] tokenAmounts /* respective amounts of collateral tokens */) public returns (uint loanID) {
    uint balance = getBalance(msg.sender);
    if (balance >= max) {
      balances[msg.sender] -= max;
      // bytes32 loanId = keccak256(msg.sender); // @todo pass something unique as 2nd parameter, account nonce?
      loanID = numLoan++;
      // @todo validate tokens against whitelisted tokens (otherwise users can place random tokens as collateral resulting in insignificant fees)
      loans[loanID] = loan(msg.sender, min, max, duration, expiration, tokens, tokenAmounts);
    }
  }

  function cancelAdvertisedLoan(uint loanID) public lender(loanID) {
    delete loans[loanID];
  }

  function takeLoan(uint loanID, uint amount) public {
    loan storage _loan = loans[loanID];
    if (now <= _loan.expiration && borrowers[loanID].borrower == 0 && amount <= _loan.max && amount >= _loan.min) {
      // @todo check collateral has been transferred in proportion to requested amount
      borrowers[loanID] = ExecutedLoan(msg.sender, now + _loan.duration);
    }
  }

  function getBalance(address _address) internal view returns(uint) {
    return balances[_address];
  }
}