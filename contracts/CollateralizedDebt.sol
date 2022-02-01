//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CollateralizedDebt {
    struct Terms {
        uint256 loanDaiAmount;
        // amount of DAI to be repaid on top of the loan amount as a fee --> represent interest rate
        uint256 feeDaiAmount;
        // amount of collateral in ETH, should be more valuable than the loanDaiAmount
        uint256 ethCollateralAmount;
        // timestamp by which the loan should be repaid, after that the lender can liquidate the collateral
        uint256 repayByTimestamp;
    }

    Terms public terms;
    enum LoanState {
        Created,
        Funded,
        Taken
    } // Repaid and Liquidated --> not included
    LoanState public state;

    modifier onlyInState(LoanState expectedState) {
        require(state == expectedState, "Not allowed in this state");
        _;
    }

    address payable public lender;
    address payable public borrower;
    address public daiAddress;

    constructor(Terms memory _terms, address _daiAddress) {
        terms = _terms;
        daiAddress = _daiAddress;
        lender = payable(msg.sender);
        state = LoanState.Created;
    }

    function fundLoan() public onlyInState(LoanState.Created) {
        state = LoanState.Funded;
        IERC20(daiAddress).transferFrom(
            msg.sender,
            address(this),
            terms.loanDaiAmount
        );
    }

    function takeALoanAndAcceptLoanTerms()
        public
        payable
        onlyInState(LoanState.Funded)
    {
        require(
            msg.value == terms.ethCollateralAmount,
            "Invalid collateral amount"
        );
        borrower = payable(msg.sender);
        state = LoanState.Taken;
        IERC20(daiAddress).transfer(borrower, terms.loanDaiAmount);
    }

    function repay() public onlyInState(LoanState.Taken) {
        require(msg.sender == borrower, "Only borrower can repay the loan");
        IERC20(daiAddress).transferFrom(
            borrower,
            lender,
            terms.loanDaiAmount + terms.feeDaiAmount
        );
        // destroy the current contract and send funds to the borrower
        selfdestruct(borrower);
    }

    function liquidate() public onlyInState(LoanState.Taken) {
        require(msg.sender == lender, "Only the lender can liquidate the loan");
        require(
            block.timestamp >= terms.repayByTimestamp,
            "can not liquidate before the loan is due"
        );
        selfdestruct(lender);
    }
}
