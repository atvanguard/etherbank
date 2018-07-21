pragma solidity ^0.4.24;

contract Escrow {
  struct Collateral {
    address tokenAddress;
    uint amount;
  }

  enum State { Active, Loaned, Fulfilled }

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
    State state;
  }

  struct ExecutedLoan {
    address borrower;
    uint expiration;
  }

  struct Balance {
    uint available;
    uint loaned;
    uint inloans;
    // total = available + loaned + inloans
    uint[] loanIds;
  }

  address owner;
  mapping(address => Balance) public balances;
  // whitelisted ERC20 tokens that can be held as collateral
  address[] public whitelistedTokens;
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
    balances[msg.sender].available += msg.value;
  }

  function advertiseLoan(
      uint min, uint max, uint duration, uint expiration,
      bytes3[] tokens, // collateral tokens
      uint[] tokenAmounts /* respective amounts of collateral tokens */) public returns (uint loanID) {
    uint balance = balances[msg.sender].available;
    if (balance >= max) {
      balances[msg.sender].available -= max;
      balances[msg.sender].inloans += max;
      // bytes32 loanId = keccak256(msg.sender); // @todo pass something unique as 2nd parameter, account nonce?
      // @todo validate tokens against whitelisted tokens (otherwise users can place random tokens as collateral resulting in insignificant fees)
      loanID = numLoan++;
      loans[loanID] = loan(msg.sender, min, max, duration, expiration, tokens, tokenAmounts, State.Active);
      balances[msg.sender].loanIds.push(loanID);
    }
  }

  /// only the ether that is not loaned or in loans can be withdrawn
  /// good idea to call cancelAllAdvertisedLoans before withdraw
  function withdraw(uint _amount) public {
    uint amount = _amount;
    uint available = balances[msg.sender].available;
    if (amount > available) {
      amount = available;
      if (amount > 0) {
        balances[msg.sender].available -= amount;
        msg.sender.transfer(amount);
      }
    }
  }

  function cancelAdvertisedLoan(uint loanID) public lender(loanID) {
    if (loans[loanID].state == State.Active) {
      uint amount = loans[loanID].max;
      delete loans[loanID];
      balances[msg.sender].inloans -= amount;
      balances[msg.sender].available += amount;
    }
  }

  function cancelAllAdvertisedLoans() public {
    uint loanId;
    for (uint i = 0; i < balances[msg.sender].loanIds.length; i++) {
      loanId = balances[msg.sender].loanIds[i];
      cancelAdvertisedLoan(loanId);
    }
  }

  function getLoans() public view returns (uint[], uint[], uint[]) {
    uint[] memory mins = new uint[](numLoan);
    uint[] memory maxs = new uint[](numLoan);
    uint[] memory expirations = new uint[](numLoan);
    
    for (uint i = 0; i < numLoan; i++) {
      if (loans[i].state == State.Active) {
        loan storage _loan = loans[i];
        mins[i] = _loan.min;
        maxs[i] = _loan.max;
        expirations[i] = _loan.expiration;
      }
    }
    return (mins, maxs, expirations);
  }

  function takeLoan(uint loanID, uint amount) public {
    loan storage _loan = loans[loanID];
    if (_loan.state == State.Active
        && now <= _loan.expiration
        && borrowers[loanID].borrower == 0
        && amount <= _loan.max
        && amount >= _loan.min) {
      // @todo check collateral has been transferred in proportion to requested amount
      _loan.state = State.Loaned;
      balances[_loan.lender].inloans -= amount;
      balances[_loan.lender].loaned += amount;
      borrowers[loanID] = ExecutedLoan(msg.sender, now + _loan.duration);
    }
  }

  function fullfilLoan(uint loanID) public payable {
    // transfer the amount to lender
    loan storage _loan = loans[loanID];
    _loan.state = State.Fulfilled;
    balances[_loan.lender].loaned -= msg.value;
    balances[_loan.lender].available += msg.value;
    // @todo transfer collateral to borrower
  }
}