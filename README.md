# DeFI-LendingPlatform
The contract uses OpenZeppelin's ERC-20 implementation to create two ERC-20 tokens, loanToken and collateralToken, representing loans and collateral, respectively.
When a new loan is created, the createLoan function mints ERC-20 tokens representing the loan and transfers them to the borrower.
The repayLoan function expects the borrower to transfer ERC-20 tokens representing the repayment, and the contract transfers the corresponding amount (excluding interest) to the lender.
Collateral deposits and withdrawals are similarly handled using ERC-20 tokens representing collateral.
The liquidateLoan function transfers ERC-20 tokens representing collateral to the liquidator when a loan is liquidated.
The `AggregatorV3Interface` is used to interact with the Chainlink Price Feed oracle for ETH/USD.
The contract constructor takes the address of the oracle as an argument and initializes the `priceFeed` variable.
The `getLoanLTV` function fetches the latest ETH/USD price from the oracle and calculates the Loan-to-Value (LTV) ratio based on that price.
The LTV ratio is then used in the `liquidateLoan` function to determine whether a loan should be liquidated.
The `setOracleAddress` function allows the contract owner to update the oracle address if needed.
AutomatedLiquidityManagement, allows the owner to provide liquidity to Uniswap, rebalance the liquidity to minimize impermanent loss, and retrieve information about the current liquidity position and reserves. 
