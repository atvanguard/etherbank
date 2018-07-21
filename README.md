# Loan Escrow Smart Contract
The smart contract matches ether lenders to borrowers. When the lender wishes to lend ether, her currency is held in the escrow. Then when a borrower wishes to avail the loan, she needs to deposit collateral (as decided by the lender) to the escrow.

## Lender
The lender decides on the following parameters.

- Minimum amount to lend
- Maximum amount to lend
- Expected return payment
- Due date of return payment
- Expected collateral: list of (token, amount) 

At this point the tokens that are willing to be lent will be held in escrow.

## Borrower
Assuming a borrower fulfills the lending conditions, her collateral tokens will be held in escrow and the loaned ether will be transferred. 
