# Proteus AMM Engine

This is a demonstration repository of Shell Protocol's new [Proteus AMM Engine](./Proteus_AMM_Engine_-_Shell_v2_Part_1.pdf). The Proteus engine offers the ability to create any bonding curve by leveraging the power of conic sections.

## Contents

A reference implementation of the Proteus algorithm can be found in [`contracts/DemoPool.sol`](./contracts/DemoPool.sol). There is also a copy of the [white paper](./Proteus_AMM_Engine_-_Shell_v2_Part_1.pdf). The deployed smart contract can be queried to receive quotes on various pool actions (e.g. swap, deposit, and withdraw). A sample script has been provided in [`scripts/DemoPool.js`](./scripts/DemoPool.js) to deploy and interact with the contract via Hardhat.

## Functions

There are three main functions in [`DemoPool.sol`](./contracts/DemoPool.sol) that correspond to the main pool actions

### Deposit
```solidity
function deposit(
        uint256 balanceOfXToken,
        uint256 balanceOfYToken,
        uint256 totalSupplyOfLPToken,
        uint256 amountDeposited,
        uint256 idOfTokenDeposited
    ) public view returns (uint256 amountOfLPTokensMinted)
```
Given the pool's current balances/shell supply and the amount of a token to be deposited, this function will return the amount of shells minted.

### Withdraw
```solidity
function withdraw(
        uint256 balanceOfXToken,
        uint256 balanceOfYToken,
        uint256 totalSupplyOfLPToken,
        uint256 amountOfLPTokensBurned,
        uint256 idOfTokenWithdrawn
    ) public view returns (uint256 amountWithdrawn)
```
Given the pool's current balances/shell supply and the amount of shells to be burned, this function will return the amount received of the given output token.   

### Swap
```solidity
function swap(
        uint256 balanceOfXToken,
        uint256 balanceOfYToken,
        uint256 inputAmount,
        uint256 idOfInputToken
    ) public view returns (uint256 outputAmount)
```
Given the pool's current balances and the amount of a token to be swapped, this function will return the amount received of the other token.


## Usage

`DemoPool.js` contains helpful functions that enable interaction with the Solidity smart contract in minimal lines of code. 

```javascript
const curveParams = [0, 1, 0, 0, 0, -10000];
const pool = await deployPool(curveParams);
const balances = { xBal: 1000, yBal: 1000, totalSupply: 2000 }
const inputData = { amt: 100, token: 0 }
const result = await swap(pool, balances, inputData);
```

The example code snippet above demonstrates the process of deploying a pool with the given curve parameters and querying a swap given a set of balances and inputs. The result of this swap query is stored in the `result` variable, which evaluates to 90.9090909090909 in this example. 

The shape of the bonding curve can be modified by altering `curveParams`, an array of six values that correspond to the six coefficients of the conic section. 

Use the `deposit`, `withdraw`, and `swap` JavaScript functions provided in [`DemoPool.js`](./scripts/DemoPool.js) along with various values for `balances` and `inputData` to experiment with different pool queries.

To view a sample result for each type of query, running the demo script using 
```shell
npm run demo
```

note that to use the project you must first run
```shell
npm install
```

## Disclaimer
This code is meant for demonstration purposes only and should not be used in a production environment
