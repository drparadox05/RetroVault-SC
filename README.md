# 🦅 **MEVhawk: Autonomous Volatility Farming**
> *Stop letting your assets sit idle. Use MEV searchers to farm volatility for you.*

## 🚀 The Problem
In DeFi, passive liquidity providing or holding tokens often means missing out on short-term opportunities.
- **Limit Orders** are static and capital inefficient.
- **Centralized Bots** are risky and require constant maintenance.
- **Manual Trading** is impossible 24/7.

## 💡 The Solution
**MEVhawk** is a protocol that allows users to deploy capital into vaults that execute strategies **autonomously**, powered by MEV searchers. Instead of relying on a centralized keeper network or manual intervention, our strategies are designed to be profitable for **anyone** to execute.

When market conditions align with a strategy (e.g., "Buy the Dip" when ETH drops 5%), the protocol pays an immediate **ETH bounty** to the first person (or bot) who executes the trade. This ensures:
- **100% Uptime**: The entire global network of MEV searchers works for you.
- **Trustless Execution**: Code is law. The strategy only executes if conditions are met.
- **Capital Efficiency**: Assets are only moved when opportunities arise.

## ⚙️ How It Works

1. **User Deposits**: Users deposit assets (e.g. USDC, WETH) into the **Vault**.
2. **Strategy Activation**: The Vault activates strategies like `DipBuyingStrategy` or `PeakSellingStrategy`.
3. **Market Monitoring**:
    - The Strategy monitors Uniswap V3 pools using an on-chain Oracle.
    - It checks for specific conditions, like a 5% price drop over a 1-hour TWAP window.
4. **MEV Execution**:
    - Once the condition is met, the function `execute()` becomes callable.
    - MEV searchers race to call this function.
    - The winner executes the logic (e.g., swap USDC -> WETH on Uniswap) and receives an **ETH Bounty**.

## 🏗️ Architecture

- **`Vault.sol`**: The core contract holding user funds and managing strategy permissions.
- **`IStrategy.sol`**: A standard interface for all strategies.
- **`DipBuyingStrategy.sol`**: Buys a target token when its price drops by a configurable threshold.
- **`PeakSellingStrategy.sol`**: Sells a target token when its price rises by a configurable threshold.
- **`UniswapOracleLib.sol`**: Library for querying Uniswap V3 observations for time-weighted average prices (TWAP).
