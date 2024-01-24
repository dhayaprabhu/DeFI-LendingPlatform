// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract LendingPlatform is Ownable{
    // Struct to represent a loan
        struct Loan {
        address borrower;
        uint256 amount;
        uint256 interestRate; // in basis points (1% = 100 basis points)
        uint256 term; // in seconds
        uint256 collateralValue;
        uint256 startTime;
        bool active;
        uint256 tokenId; // ERC-20 token ID representing the loan
    }

    // Mapping to store loans
    mapping (uint256 => Loan) public loans;
    uint256 public nextLoanId;

    // Mapping to store collateral balances
    mapping (address => uint256) public collateralBalances;

    // Liquidation threshold (expressed as LTV in basis points)
    uint256 public liquidationThreshold = 8000; // 80%

    // ERC-20 token representing loans
    ERC20 public loanToken;

    // ERC-20 token representing collateral
    ERC20 public collateralToken;

    // Chainlink Price Feed oracle for ETH/USD
    AggregatorV3Interface public priceFeed;

    // Events for loan and collateral actions
    event LoanCreated(uint256 loanId, address borrower, uint256 amount, uint256 interestRate, uint256 term, uint256 collateralValue, uint256 tokenId);
    event LoanRepaid(uint256 loanId, address borrower, uint256 amountRepaid, uint256 interestPaid);
    event CollateralDeposited(address depositor, uint256 amount);
    event CollateralWithdrawn(address withdrawer, uint256 amount);
    event LoanLiquidated(uint256 loanId, address liquidator, uint256 amountRecovered);

    constructor (address _priceFeedAddress, ERC20 _loanToken, ERC20 _collateralToken) Ownable (_priceFeedAddress) {
       // loanToken = ERC20("Loan Token", "LOAN");
        //collateralToken = new ERC20("Collateral Token", "COLL");
        loanToken = _loanToken;
        collateralToken = _collateralToken;
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
    }

    // Function to create a new loan
    function createLoan(uint256 _amount, uint256 _interestRate, uint256 _term, uint256 _collateralValue) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(_interestRate > 0, "Interest rate must be greater than 0");
        require(_term > 0, "Term must be greater than 0");
        require(_collateralValue > 0, "Collateral value must be greater than 0");

        uint256 startTime = block.timestamp;
        Loan memory newLoan = Loan(msg.sender, _amount, _interestRate, _term, _collateralValue, startTime, true, nextLoanId);
        loans[nextLoanId] = newLoan;    

        emit LoanCreated(nextLoanId, msg.sender, _amount, _interestRate, _term, _collateralValue, nextLoanId);

        // Mint ERC-20 tokens representing the loan to the borrower
        loanToken.mint(msg.sender, _amount);

    
        // Deduct collateral from borrower's balance
        require(collateralBalances[msg.sender] >= _collateralValue, "Insufficient collateral balance");
        collateralBalances[msg.sender] -= _collateralValue;

        nextLoanId++;
    }

    // Function to check the Loan-to-Value ratio of a loan using the oracle
    function getLoanLTV(uint256 _loanId) external view returns (uint256) {
        Loan storage loan = loans[_loanId];
        require(loan.active, "Loan is not active");

        // Get the latest ETH/USD price from the oracle
        (,int256 price,,,) = priceFeed.latestRoundData();

        // Calculate LTV ratio using the latest price
        if (loan.collateralValue > 0 && price > 0) {
            return (loan.amount * 10000 * uint256(price)) / loan.collateralValue; // LTV in basis points
        } else {
            return 0;
        }
    }

    // Function to repay a loan
    function repayLoan(uint256 _loanId, uint256 _amount) external {
        Loan storage loan = loans[_loanId];
        require(loan.active, "Loan is not active");
        require(msg.sender == loan.borrower, "Only the borrower can repay the loan");
        require(block.timestamp < loan.startTime + loan.term, "Loan term has expired");
        require(_amount > 0, "Repayment amount must be greater than 0");

        // Transfer ERC-20 tokens representing the repayment to the contract
        loanToken.transferFrom(msg.sender, address(this), _amount);

        uint256 interestPaid = (_amount * loan.interestRate) / 10000; // Calculate interest

        // Transfer the repaid amount to the lender
        // For simplicity, using the contract itself as the lender
        loanToken.transfer(msg.sender, _amount - interestPaid);

        // Emit event for loan repayment
        emit LoanRepaid(_loanId, msg.sender, _amount, interestPaid);

        // Mark the loan as inactive
        loan.active = false;
    }

    // Function to deposit collateral
    function depositCollateral(uint256 _amount) external {
        require(_amount > 0, "Deposit amount must be greater than 0");

        // Transfer ERC-20 tokens representing the collateral to the contract
        collateralToken.transferFrom(msg.sender, address(this), _amount);

        // Update collateral balance
        collateralBalances[msg.sender] += _amount;
        emit CollateralDeposited(msg.sender, _amount);
    }

    // Function to withdraw collateral
    function withdrawCollateral(uint256 _amount) external {
        require(_amount > 0, "Withdrawal amount must be greater than 0");
        require(collateralBalances[msg.sender] >= _amount, "Insufficient collateral balance");

        // Transfer ERC-20 tokens representing the collateral to the withdrawer
        collateralToken.transfer(msg.sender, _amount);

        // Update collateral balance
        collateralBalances[msg.sender] -= _amount;
        emit CollateralWithdrawn(msg.sender, _amount);
    }

    // Function to liquidate a loan if the LTV ratio is above the liquidation threshold
    function liquidateLoan(uint256 _loanId) external {
        Loan storage loan = loans[_loanId];
        require(loan.active, "Loan is not active");
    // Get the latest ETH/USD price from the oracle
    (,int256 price,,,) = priceFeed.latestRoundData();

    // Calculate LTV ratio using the latest price
    uint256 ltv = (loan.amount * 10000 * uint256(price)) / loan.collateralValue; // LTV in basis points

    // Check if LTV is above the liquidation threshold
    require(ltv > liquidationThreshold, "LTV is below the liquidation threshold");

    // Transfer the collateral ERC-20 tokens to the liquidator
    collateralToken.transfer(msg.sender, loan.collateralValue);

    // Emit event for loan liquidation
    emit LoanLiquidated(_loanId, msg.sender, loan.collateralValue);

    // Burn ERC-20 tokens representing the loan
    loanToken.burn(loan.borrower, loan.amount);

    // Mark the loan as inactive
    loan.active = false;
}

// Function to mint more ERC-20 tokens representing collateral (only callable by the owner)
function mintCollateral(uint256 _amount) external onlyOwner {
    require(_amount > 0, "Mint amount must be greater than 0");
    collateralToken.mint(address(this), _amount);
}

// Function to set the liquidation threshold (only callable by the owner)
function setLiquidationThreshold(uint256 _newThreshold) external onlyOwner {
    liquidationThreshold = _newThreshold;
}

// Function to set the oracle address (only callable by the owner)
function setOracleAddress(address _newOracleAddress) external onlyOwner {
    priceFeed = AggregatorV3Interface(_newOracleAddress);
}
}

