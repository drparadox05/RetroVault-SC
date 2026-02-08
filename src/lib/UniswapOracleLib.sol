// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IUniswap.sol";

library UniswapOracleLib {
    // Throws if price drop condition is not met
    error PriceDropNotMet(int56 currentTick, int56 pastTick, int56 threshold);

    function getTickAtTime(address pool, uint32 secondsAgo) internal view returns (int56 tick) {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo + 1; // 1 second deeper window
        secondsAgos[1] = secondsAgo;

        (int56[] memory tickCumulatives, ) = IUniswapV3Pool(pool).observe(secondsAgos);
        
        // TWAP for that 1 second window at looking back `secondsAgo`
        // tickCumulatives[1] is at t = -secondsAgo
        // tickCumulatives[0] is at t = -(secondsAgo + 1)
        // difference is the cumulative tick over 1 second.
        // so average tick over that 1s is just the difference.
        tick = int56((tickCumulatives[1] - tickCumulatives[0]) /* / 1 */);
    }
    
    function getCurrentTick(address pool) internal view returns (int56 tick) {
        // We get a TWAP of the last X seconds to be slightly resistant to flash loan manipulation within the same block
        // Or we can just get the TWAP for 0 seconds ago? observing 0 seconds ago works if looking at block timestamp.
        // However, safest to take a small window like 10 seconds for "current" price to avoid instant manipulation.
        return getTickAtTime(pool, 0); 
    }

    // Function to check if price dropped by `tickDelta` amount
    // In Uniswap V3, 1 bp (0.01%) is approx 100 ticks? 
    // logic: 1.0001^tick = price.
    // ln(price) = tick * ln(1.0001)
    // ln(price_new / price_old) = (tick_new - tick_old) * ln(1.0001)
    // For 1% drop: price_new/price_old = 0.99
    // ln(0.99) = -0.01005
    // ln(1.0001) = 0.000099995
    // delta_tick = -0.01005 / 0.000099995 = -100.5
    // So ~100 ticks is 1%.
    function hasPriceDropped(address pool, uint32 secondsAgo, int24 tickDropThreshold) internal view returns (bool) {
        int56 pastTick = getTickAtTime(pool, secondsAgo); // Price X seconds ago
        int56 currentTick = getCurrentTick(pool); // Price now

        // If we want a DROP, currentTick should be LOWER than pastTick (for token1/token0 where we want token0 cheap?)
        // Depends on the pool pair direction.
        // Assuming we are checking pair token0/token1. Price is token1 per token0.
        // If price drops, tick goes down.
        
        // Return true if (current - past) < -threshold
        return (currentTick - pastTick) < -int56(tickDropThreshold);
    }

    function hasPriceIncreased(address pool, uint32 secondsAgo, int24 tickRiseThreshold) internal view returns (bool) {
        int56 pastTick = getTickAtTime(pool, secondsAgo); 
        int56 currentTick = getCurrentTick(pool); 

        // Return true if (current - past) > threshold
        return (currentTick - pastTick) > int56(tickRiseThreshold);
    }
}
