// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/interfaces/IUniswap.sol";

contract MockUniswapPool is IUniswapV3Pool {
    struct Observation {
        uint32 blockTimestamp;
        int56 tickCumulative;
        uint160 secondsPerLiquidityCumulativeX128;
        bool initialized;
    }

    Observation[65535] public observations;
    uint16 public index;
    uint16 public cardinality;
    uint16 public cardinalityNext;
    
    int24 public currentTick;

    function setTick(int24 _tick) external {
        currentTick = _tick;
    }

    // Determine the observation for the start of a logical second
    function observe(uint32[] calldata secondsAgos)
        external
        view
        override
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s)
    {
        tickCumulatives = new int56[](secondsAgos.length);
        secondsPerLiquidityCumulativeX128s = new uint160[](secondsAgos.length);

        for (uint i = 0; i < secondsAgos.length; i++) {
            // Simplified mock logic: 
            // We assume lineartick accumulation for simplicity in basic tests, 
            // OR we can just return values set by the test to simulate specific scenarios.
            
            // To properly mock OracleLib.getTickAtTime:
            // It calls observe([secondsAgo + 1, secondsAgo])
            // And calculates (tickCumulatives[1] - tickCumulatives[0])
            
            // If we want to simulate a tick of X at time T:
            // cumulative at T = C
            // cumulative at T-1 = C - X
            
            // So if `secondsAgos[i]` is 0 (now), we return a large cumulative.
            // If `secondsAgos[i]` is 1 (1 sec ago), we return cumulative - currentTick.
            
            // But we specifically want to mock the *change* over time.
            // verifying `(currentTick - pastTick) < threshold`
            
            // Let's rely on a helper in the test to force return values? 
            // Or just implement basic linear time travel logic.

            // Simplest Mock:
            // tickCumulative = currentTick * (block.timestamp - secondsAgos[i])
            // This assumes tick has been constant forever.
            // To simulate a drop, we need to change what `currentTick` returns vs what "past" returns.
            
            // Hack for testing: 
            // We interpret `secondsAgos[i]` > 0 as "past".
            // If we want to simulate a drop, "past" needs to be higher tick.
            
            if (secondsAgos[i] > 0) {
                 // Return a value that implies a SPECIFIC past tick.
                 // We can use a public mapping to set "past ticks"
                 tickCumulatives[i] = int56(mockPastTick) * int56(int32(secondsAgos[i])); 
                 // This doesn't work well with the subtraction logic in library.
            } else {
                tickCumulatives[i] = 0;
            }
        }
        // Actually, let's make this dumber and controllable by the test.
        // We will just expose a way to overwrite the return values.
        revert("Use MockUniswapPoolDynamic for observation mocking");
    }

    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked) {
        return (0, currentTick, 0, 0, 0, 0, true);
    }
    
    // Better Mock for OracleLib
    int56 public mockPastTick; // The tick we want the oracle to think it was X seconds ago.
    
    // In OracleLib:
    // tick = (cumulatives[1] - cumulatives[0])
    // [1] is secondsAgo
    // [0] is secondsAgo + 1
    
    // We want (cumulatives[secondsAgo] - cumulatives[secondsAgo+1]) = mockPastTick
    
    function setMockPastTick(int56 _tick) external {
        mockPastTick = _tick;   
    }
}

contract MockUniswapPoolSimple is IUniswapV3Pool {
    int24 public currentTick;
    int56 public pastTick; // The tick X seconds ago

    function setResult(int24 _currentTick, int56 _pastTick) external {
        currentTick = _currentTick;
        pastTick = _pastTick;
    }

    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked) {
        return (0, currentTick, 0, 0, 0, 0, true);
    }

    function observe(uint32[] calldata secondsAgos)
        external
        view
        override
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s)
    {
        tickCumulatives = new int56[](secondsAgos.length);
        secondsPerLiquidityCumulativeX128s = new uint160[](secondsAgos.length);
        
        // OracleLib calls with [secondsAgo+1, secondsAgo]
        // result = tickCumulatives[1] - tickCumulatives[0]
        
        // We want result to be `pastTick` if secondsAgos[1] is the target time.
        // Let's just say:
        // if secondsAgos includes 0 (now), we calculate based on currentTick?
        
        // Actually the OracleLib calls:
        // getTickAtTime(pool, secondsAgo) -> observe([secondsAgo+1, secondsAgo])
        // getTickAtTime(pool, 0)          -> observe([1, 0])
        
        // Case 1: Checking "Now" (secondsAgo=0)
        // We want return = currentTick.
        // tickCumulatives[1] (0 ago) - tickCumulatives[0] (1 ago) = currentTick
        // Let's set tickCumulatives[1] = 0, tickCumulatives[0] = -currentTick
        
        // Case 2: Checking "Past" (secondsAgo=Window)
        // We want return = pastTick.
        // tickCumulatives[1] (Window ago) - tickCumulatives[0] (Window+1 ago) = pastTick
        // Let's set tickCumulatives[1] = 0, tickCumulatives[0] = -pastTick
        
        // This works if we assume the caller is always invoking it in pairs like that.
        // But the 0th element is secondsAgo+1.
        
        for(uint i=0; i<secondsAgos.length; i++) {
             // We can't easily correlate them individually without context of the pair.
             // But we know the Lib's implementation.
             
             // If we implement a simple linear model it works for everything:
             // Cumulative(t) = tick * t
             // But tick CHANGES.
             
             // Let's blindly trust the specific layout of the oracle lib for this mock.
             // If input is 0, we treat it as T_now.
             // If input is > 0, we treat it as T_past.
             
             if (secondsAgos[i] == 0) {
                 tickCumulatives[i] = int56(currentTick) * 1000000; // Large number
             } else if (secondsAgos[i] == 1) {
                 // For "current tick" calculation: (cumulative[0] - cumulative[1]) where 0 is T_now, 1 is T_now-1
                 // Wait, Lib does: [secondsAgo+1, secondsAgo]
                 // For Now(0): [1, 0]. Res = C[0] - C[1] => C[now] - C[now-1].
                 tickCumulatives[i] = int56(currentTick) * (1000000 - 1);
             } else {
                 // Ideally we recognize the window
                 tickCumulatives[i] = int56(pastTick) * int56(int32(secondsAgos[i])); // rough
             }
        }
    }
}

// A focused mock specifically for the OracleLib logic
contract MockUniswapPoolTargeted is IUniswapV3Pool {
    int24 public currentTick;
    int56 public targetPastTick;
    
    function setPrice(int24 _currentTick, int56 _pastTick) external {
        currentTick = _currentTick;
        targetPastTick = _pastTick;
    }

    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked) {
        return (0, currentTick, 0, 0, 0, 0, true);
    }
    
    function observe(uint32[] calldata secondsAgos)
        external
        view
        override
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s)
    {
        tickCumulatives = new int56[](secondsAgos.length);
        secondsPerLiquidityCumulativeX128s = new uint160[](secondsAgos.length);

        // Implementation that works with `return (tickCumulatives[1] - tickCumulatives[0]);`
        // If we are asking for "Now" (0), we get [1, 0]. Res = Cumul[0] - Cumul[1]. 
        // We want result = currentTick.
        // So Cumul[0] = 0, Cumul[1] = -currentTick ? No Order is [1, 0] in params?
        // OracleLib: secondsAgos[0] = secondsAgo + 1; secondsAgos[1] = secondsAgo;
        // returns (camul[1] - cumul[0])
        
        // Scenario A: secondsAgo = 0. Params: [1, 0]. Returns C[0] - C[1].
        // We want currentTick. 
        // e.g. C[0]=0, C[1]=-currentTick.
        
        // Scenario B: secondsAgo = 300. Params: [301, 300]. Returns C[300] - C[301].
        // We want targetPastTick.
        // e.g. C[300]=0, C[301]=-targetPastTick.
        
        for (uint i = 0; i < secondsAgos.length; i++) {
            uint32 t = secondsAgos[i];
            if (t == 0) {
                tickCumulatives[i] = int56(currentTick);
            } else if (t == 1) {
                tickCumulatives[i] = 0; 
                // C[0] - C[1] = currentTick - 0 = currentTick. Correct for "Now".
            } else {
                 // Assume it's the past query
                 // We need C[300] - C[301] = pastTick.
                 // If t == 300 (even index in pair), set to pastTick.
                 // If t == 301 (odd index in pair), set to 0.
                 if (t % 2 == 0) {
                     tickCumulatives[i] = targetPastTick;
                 } else {
                     tickCumulatives[i] = 0;
                 }
            }
        }
    }
}
