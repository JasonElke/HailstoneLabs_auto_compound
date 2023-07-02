### Auto-Compound Contract
The AutoCompounder contract automates the process of compounding rewards for users. It allows users to deposit USDC into a main pool and stake LP tokens to earn additional rewards. The contract handles the compounding process and updates the user's balances accordingly.

### Contract Structure
The AutoCompounder contract consists of the following key components:

1. Variables
- `womTokenContract`: WOM token contract instance.
- `usdcTokenContract`: USDC token contract instance.
- `lpTokenContract`: LP token contract instance.
- `mainPoolContract`: MainPool contract instance.
- `masterWombatV2Contract`: MasterWombatV2 contract instance.
- `swapRouter`: SwapRouter contract instance.

2. Events
- `Deposit`: Emitted when a user makes a deposit. Contains the user's address, the amount of USDC deposited, and the corresponding amount of LP tokens.
- `Withdraw`: Emitted when a user withdraws their deposit. Contains the user's address, the amount of USDC withdrawn, and the corresponding amount of LP tokens.

3. Structs
- `DepositInfo`: Stores information about a user's deposit, including the amount of deposited USDC, compounded USDC balance, amount of LP tokens deposited, and compounded LP balance.

4. Storage
- `deposits`: Mapping of user addresses to their deposit information.
- `depositAddresses`: Array of user addresses who have made deposits.
- `isUserIncluded`: Mapping to keep track of whether a user address is included in depositAddresses.

5. Functions
- `deposit`: Allows a user to deposit USDC into the main pool. It checks the user's USDC balance, compounds rewards if the contract holds WOM tokens, deposits USDC into the main pool, and stakes LP tokens in the MasterWombatV2 contract. It also updates the user's deposit balance and emits the Deposit event.
- `compound`: Compounds rewards by swapping WOM tokens for USDC, depositing the obtained USDC back into the main pool, and staking the LP tokens in the MasterWombatV2 contract. It updates the compound balance for each user.
- `withdraw`: Allows a user to withdraw their deposit. It compounds rewards if the contract holds WOM tokens, unstakes LP tokens from the MasterWombatV2 contract, swaps WOM tokens for USDC, withdraws USDC from the main pool, transfers the USDC to the user, and updates the user's deposit information. It emits the Withdraw event.
- `totalDeposits`: Returns the total amount of deposited USDC and LP tokens across all users.
getUserDepositInfo: Returns the deposit information for a specific user, including the amount of USDC deposited, compounded USDC balance, amount of LP tokens deposited, and compounded LP balance.

### Deployment and Verification
Change env.example to .env

1. Deployment
- To deploy the Auto-Compound contract run the deployment script using Hardhat: `npx hardhat run-deploy --network bscTestnet`.

2. Verification
- To verify the Auto-Compound contract, run the verification script using Hardhat: `npx hardhat run-verify --network bscTestnet`.

3. Tests
- To run the tests, execute the following command: `npx hardhat test`.

### Answer the question
1.  I spent about 10 hours completing the configuration, developing the smart contract logic and creating the test cases for the unit tests.
2. Based on the specs of the Auto-Compound smart contract, here are some suggestions to improve and optimize the contract if I have more time to construct:
 - Added risk-reducing features: Contracts can be enhanced by adding risk-reducing features, including checking and verifying actions before executing them. For example, check the balance is sufficient for USDC deposit or USDC withdrawal, verify the validity of user and contract addresses before interacting with them.

 - Security and Decentralization: Ensure that only authorized users can deposit and withdraw USDC, and only have access to contract management and update functions. This helps prevent unauthorized access and protect user data.

 - Gas optimization: Consider optimizing gas costs for contract operations. This can be achieved by using tricks like using the lowest gas for transactions, reducing the number of function calls, and using gas-saving libraries like SafeERC20.
