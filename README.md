1. We are going to make a stable coin that is anchored, with relative stability -> $1_USD.
   1. Use Chainlink pricefeec
   2. Set a function to exchange ETH/BTC/Solana -> $$$

2. The stability method will be algortithmic to maintain decentralization.
   1. People can only mint the if provided with enough collateral (coded) 

3. Collateral (exogenous) -> crypto backed.
   1. wETH
   2. wBTC
   3. Solana??




- What are our invariants/properties?
1) Protocol must always be overcollateralized. 
2) Every user with DSC minted must maintain min collateralization ratio. 
3) Total DSC minted must equal sum of all user balances.
4) Engine's collateral balances must be equal to all user deposits.
5) Users under 150% ratio must be liquidatable.
6) Price feeds should always return postive values.
7) Liquidators should always recieve exactly 15% bonus.
8) DSC tokes should always be owned by engine.
9) Only engine should be able to mint/burn.
10) Only approved tokens should return a price feed.
11) No function should accept zero amount.
12) All state-changing function should be protected from re-entrancy.
13) Price calculations should maintain 18 decimal points precision.
14) Collateralization ratio should be calculated correctly.
15) Contract should handle type(uint256).max values appropriately.
16) Contract should work correctly with no users/collateral.
17) Getter functions should never revert.


This was by far the hardest and the most time consuming project i have ever done so far.

THE MAJOR ISSUE OF THIS PROTOCOL IS IF THE PRICE OF THE COLLATERAL FALLS DRAMATICALLY UNDER
THE COLLATERALIZATION RATIO WITHIN A BLOCK. INSOLVENCY WILL OCCUR. 

