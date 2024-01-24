# DeFI-LendingPlatform
1. The contract uses OpenZeppelin's ERC-20 implementation to create two ERC-20 tokens, loanToken and collateralToken, representing loans and collateral, respectively.
2. When a new loan is created, the createLoan function mints ERC-20 tokens representing the loan and transfers them to the borrower.
3. The repayLoan function expects the borrower to transfer ERC-20 tokens representing the repayment, and the contract transfers the corresponding amount (excluding interest) to the lender.
4. Collateral deposits and withdrawals are similarly handled using ERC-20 tokens representing collateral.
5. The liquidateLoan function transfers ERC-20 tokens representing collateral to the liquidator when a loan is liquidated.
6. The `AggregatorV3Interface` is used to interact with the Chainlink Price Feed oracle for ETH/USD.
7. The contract constructor takes the address of the oracle as an argument and initializes the `priceFeed` variable.
8. The `getLoanLTV` function fetches the latest ETH/USD price from the oracle and calculates the Loan-to-Value (LTV) ratio based on that price.
9. The LTV ratio is then used in the `liquidateLoan` function to determine whether a loan should be liquidated.
10. The `setOracleAddress` function allows the contract owner to update the oracle address if needed.
11. AutomatedLiquidityManagement, allows the owner to provide liquidity to Uniswap, rebalance the liquidity to minimize impermanent loss, and retrieve information about the current liquidity position and reserves. 
