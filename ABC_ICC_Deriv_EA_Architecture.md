# ABC/ICC Deriv Expert Advisor — Architecture Specification

## 1. Scope and design goals

This document is the approval gate for the MQL5 implementation. It defines the
architecture, module responsibilities, data flow, adjustable inputs, and trading
decision flow. It deliberately contains no executable EA implementation.

The EA will:

- run on the chart symbol returned by `_Symbol`/`Symbol()` and never hardcode a
  Deriv instrument;
- normalize all prices, volumes, stops, and monetary risk using the active
  symbol's MT5 properties;
- use only closed bars and confirmed historical pivots for decisions;
- calculate higher-timeframe direction on H1 by default, setup structure on M15,
  and confirmation on configurable M15 and M30 timeframes;
- keep analysis, scoring, execution, chart drawing, and persistence separate;
- use one deterministic evaluation pipeline in live trading and the Strategy
  Tester; and
- manage an opened position only through its original SL and TP (no trailing,
  partial close, discretionary exit, or break-even move).

### Explicit interpretation decisions

1. **M15 + M30 confirmation:** the confirmation policy is adjustable. The default
   requires a qualifying closed engulfing candle on both configured confirmation
   timeframes. `CONFIRM_ANY` permits either timeframe.
2. **Score maximum:** the specified weights total 20. The dashboard therefore
   displays `score/20`, not the illustrative `12/18`. The +3 Fibonacci/structure
   reaction is a distinct bonus and may be earned in addition to the +2 Fibonacci
   zone score.
3. **Fibonacci tolerance:** tolerance is expressed as a fraction of ATR by
   default, so it adapts across synthetic indices. A points mode is also exposed.
4. **Liquidity sweep requirement:** when enabled, a sweep is a hard eligibility
   gate as well as a +2 scoring component.
5. **Structure TP:** a setup is rejected when no confirmed structural target
   exists beyond entry, or when that target does not meet minimum RR.
6. **Risk default:** 10% is retained as requested, but documentation will flag it
   as aggressive. Sizing is capped and normalized to broker volume constraints.

## 2. Repository/file architecture

```text
ABC_ICC_Deriv_EA.mq5                 Composition root and MT5 event handlers
Include/ABC_ICC/Types.mqh            Shared enums, records, constants, utilities
Include/ABC_ICC/FractalEngine.mqh    Closed-bar fractal candidates
Include/ABC_ICC/ATRFilter.mqh        ATR handles and significance tests
Include/ABC_ICC/ZigZagConfirmation.mqh Confirmed, non-repainting pivot logic
Include/ABC_ICC/HybridSwingEngine.mqh Swing pipeline and canonical swing series
Include/ABC_ICC/MarketStructure.mqh  HH/HL/LH/LL classification and trend
Include/ABC_ICC/ABCICCModel.mqh       A/B/C state machine
Include/ABC_ICC/BoundaryEngine.mqh   S/R zones, touches, and trendlines
Include/ABC_ICC/FibonacciEngine.mqh  Anchors, 0.88 level, and entry zone
Include/ABC_ICC/LiquidityEngine.mqh  Sweep detection and validation
Include/ABC_ICC/PatternRecognition.mqh Closed-bar engulfing confirmation
Include/ABC_ICC/ScoreEngine.mqh      Weighted evidence and eligibility gates
Include/ABC_ICC/RiskManagement.mqh   SL/TP, RR, sizing, and exposure limits
Include/ABC_ICC/TradeExecution.mqh   Mode routing and CTrade operations
Include/ABC_ICC/Visualization.mqh    Dashboard and namespaced chart objects
Include/ABC_ICC/Logger.mqh           Journal/CSV setup and result logging
ABC_ICC_Deriv_EA_Documentation.txt   User, testing, and optimization guide
```

`Types.mqh` is an implementation support file in addition to the requested
modules. It prevents circular dependencies and gives every module the same typed
contracts.

## 3. Shared domain model

The implementation will use typed records rather than loosely related globals:

- `SwingPoint`: time, bar index, price, high/low type, ATR at formation,
  fractal/ATR/ZigZag flags, and confirmation time.
- `StructureSnapshot`: trend, labelled pivots, latest HH/HL/LH/LL, break level,
  and validity timestamp.
- `ABCState`: direction, stage (`NONE/A/B/C`), A/B/C anchors, correction bounds,
  breakout level, and invalidation level.
- `BoundarySnapshot`: support/resistance zones, touch counts, active trendline,
  distance/reaction flags, and next structural targets.
- `FibSetup`: direction, two confirmed anchors, 0.88 price, zone bounds,
  in-zone flag, and structural-reaction flag.
- `ConfirmationState`: per-timeframe closed-bar time, engulfing direction, body
  ratio, close confirmation, and combined policy result.
- `ConfluenceReport`: each named Boolean component, individual points, total,
  maximum (20), hard-gate failures, and human-readable reasons.
- `TradePlan`: setup ID, direction, entry quote, SL, TP, risk/reward distances,
  RR, effective risk percentage, normalized volume, and validation result.
- `RuntimeState`: last processed bar times, active setup ID, alert/execution
  deduplication markers, daily/weekly counters, and consecutive losses.

All modules return snapshots or reports and do not place trades implicitly.

## 4. Module breakdown

### `ABC_ICC_Deriv_EA.mq5`

- Declares user inputs and owns all module instances.
- `OnInit`: validates inputs and symbol capabilities, creates indicator handles,
  restores/account-scans counters, initializes logging, and builds the dashboard.
- `OnTick`: updates quotes/visual price only; runs full analysis once per newly
  closed structure-timeframe bar, preventing repeated intrabar signals.
- `OnTradeTransaction`: attributes closed deals by magic number and symbol,
  updates loss streak/counters, and writes final results.
- `OnDeinit`: releases handles and removes only objects carrying the EA prefix.

### `FractalEngine.mqh`

Detects a high when the candidate high is strictly greater than highs in the
configured number of bars on both sides; lows are symmetric. A candidate is not
available until the right-side bars have closed. Equal-price handling is
deterministic (the oldest point wins) to prevent duplicate pivots.

### `ATRFilter.mqh`

Owns cached `iATR` handles per timeframe. A candidate becomes ATR-significant
only after the opposite excursion reaches `ATR_at_candidate × Minimum_Swing_ATR`.
If disabled, the filter passes without altering downstream contracts.

### `ZigZagConfirmation.mqh`

Implements depth/deviation/backstep pivot confirmation internally rather than
depending on a broker-specific indicator path. The newest provisional leg may
move, but it is never exposed as confirmed. Only a pivot locked by a subsequent
opposite pivot and the configured constraints enters the canonical swing list.

### `HybridSwingEngine.mqh`

Coordinates fractal candidate → ATR significance → ZigZag confirmation. It
maintains alternating, time-ordered confirmed highs/lows, de-duplicates points,
and supplies recent swings to all structural modules.

### `MarketStructure.mqh`

Classifies confirmed highs relative to the prior confirmed high and confirmed
lows relative to the prior confirmed low. Bullish requires latest HH > previous
HH and latest HL > previous HL; bearish requires latest LL < previous LL and
latest LH < previous LH. Otherwise trend is neutral. It emits labels only for
confirmed points.

### `ABCICCModel.mqh`

Runs one state machine per direction:

- **A / Indication:** a closed bar breaks the prior confirmed HH (bullish) or LL
  (bearish), optionally with a close rather than wick according to input.
- **B / Correction:** price retraces countertrend after A; its confirmed extreme
  becomes B, must remain inside the invalidation boundary, and represents the
  liquidity-collection phase.
- **C / Continuation:** a closed bar breaks the correction's internal structure
  in the trend direction. After trade/expiry/invalidation, the state resets.

### `BoundaryEngine.mqh`

Clusters confirmed swing prices into horizontal zones whose half-width is
`ATR × Zone_Size_ATR`; a zone is major after the minimum number of distinct swing
touches. It connects the latest two confirmed HLs for a bullish trendline or LHs
for a bearish trendline. Reactions use configurable ATR proximity. It also finds
the nearest valid resistance above a buy or support below a sell for TP.

### `FibonacciEngine.mqh`

Selects the latest complete impulse pair aligned to structure. Bullish anchors
run low → high and compute the retracement price as
`high - (high-low) × level`; bearish anchors run high → low and compute
`low + (high-low) × level`. It provides anchors, level, tolerance zone, current
location, and whether a boundary/trendline reaction overlaps the zone.

### `LiquidityEngine.mqh`

A bullish sweep requires a closed candle low below a prior confirmed/equal low
and a close back above that liquidity reference; bearish logic is mirrored.
Sweep age and maximum penetration are bounded by inputs to avoid stale or extreme
events.

### `PatternRecognition.mqh`

Reads closed bars only (shift 1 and older). A bullish candle must close above its
open, fully engulf the previous real body, and have body size at least
`average_body × Minimum_Engulfing_Strength`; bearish logic is mirrored. It
evaluates both confirmation timeframes and combines them using the selected
policy.

### `ScoreEngine.mqh`

Builds a transparent report with these exact weights:

| Evidence | Points |
|---|---:|
| Trend timeframe alignment | 2 |
| HH/HL or LL/LH structure | 2 |
| Major support/resistance | 2 |
| Trendline reaction | 1 |
| 0.88 Fibonacci zone | 2 |
| Fibonacci + structure reaction | 3 |
| ABC/ICC pattern | 2 |
| Liquidity sweep | 2 |
| Engulfing candle | 2 |
| Confirmation candle closed | 2 |
| **Maximum** | **20** |

Score threshold does not override hard gates: data readiness, enabled Fibonacci
filter, required liquidity sweep, confirmation policy, structural TP, RR,
exposure/trade limits, and valid broker stops must all pass.

### `RiskManagement.mqh`

- Swing SL: beyond the relevant confirmed swing plus/minus ATR buffer.
- ATR SL: entry plus/minus `ATR × SL_ATR_Multiplier`.
- Hybrid SL: selects the farther protective price from swing and ATR candidates.
- TP: nearest confirmed target in the profitable direction, offset toward entry
  by `Structure_Target_Buffer × _Point`.
- Volume: uses `OrderCalcProfit` for one lot between entry and SL when possible,
  then `risk_money / abs(loss_per_lot)`; fallback uses tick value/tick size.
  Volume is floored to `SYMBOL_VOLUME_STEP`, bounded by min/max/optional cap, and
  rejected when minimum volume would exceed intended risk.
- Effective risk is halved after the configured consecutive-loss threshold.
- Limits use this EA's magic number. Daily/weekly counts derive from deal history
  using broker server time; the week begins Monday.

### `TradeExecution.mqh`

Routes an accepted `TradePlan` by mode:

1. `MODE_AUTOMATED`: revalidates current quote, spread, stops/freeze levels,
   margin, limits, and RR immediately before a market order through `CTrade`.
2. `MODE_SIGNAL_ONLY`: draws/logs the setup but sends no terminal alert and no
   order.
3. `MODE_ALERT_ONLY`: draws/logs and sends one deduplicated terminal alert (with
   optional push/email toggles), but sends no order.

Orders carry a unique magic number and compact setup ID comment. Netting and
hedging accounts are both handled by counting symbol/magic exposure safely.

### `Visualization.mqh`

Uses a unique prefix containing chart ID and magic number. It renders the
dashboard, HH/HL/LH/LL and A/B/C text, zones, confirmed trendline, Fibonacci
anchors/0.88 zone/current location, setup reasons, and entry/SL/TP lines. Drawing
can be disabled for faster optimization without changing the analysis path.

### `Logger.mqh`

Writes readable terminal messages and an optional CSV in `FILE_COMMON`. CSV rows
contain setup ID, date, symbol, direction, entry, SL, TP, RR, score, confluences,
mode, order/deal IDs, and result. Result rows are completed from trade
transactions, not inferred from price.

## 5. Data flow and scheduling

```text
MT5 rates + symbol/account properties
              |
              v
      Cached rates and ATR values
              |
              v
Fractals -> ATR significance -> confirmed ZigZag pivots
              |                         |
              +------------+------------+
                           v
           canonical confirmed swing series
              |             |             |
              v             v             v
       H1 structure     M15 structure   boundaries
              |             |             |
              +-------> ABC state <-------+
                            |
                  Fibonacci + liquidity
                            |
              closed M15/M30 confirmations
                            |
                            v
                 confluence score report
                            |
               hard gates + SL/TP/RR/sizing
                            |
                            v
                      validated plan
                  /          |          \
             automated    signal-only   alert-only
                  \          |          /
                    logging + visuals
                            |
                    trade transaction
                            |
                result/loss-streak update
```

Rates are copied in batches and arrays use series indexing consistently. Indicator
handles are created once, never per tick. A warm-up/data-readiness check requires
enough closed bars for fractals, ATR, ZigZag depth, body averaging, and structural
history. The signal identity combines symbol, direction, C confirmation close
time, and Fibonacci anchors, preventing duplicate orders and alerts.

## 6. Adjustable inputs

Exact input names may receive an `Inp` prefix in code; meanings and defaults will
remain as specified below.

### General and operating mode

| Input | Type | Default | Purpose |
|---|---|---:|---|
| `Trading_Mode` | enum | `MODE_AUTOMATED` | Automated, signal-only, or alert-only |
| `Magic_Number` | ulong | `880015` | Isolates EA orders and history |
| `Enable_Long_Trades` | bool | `true` | Permit buy setups |
| `Enable_Short_Trades` | bool | `true` | Permit sell setups |
| `Max_Spread_Points` | int | `0` | Maximum spread; 0 disables gate |
| `Max_Slippage_Points` | int | `20` | CTrade deviation |
| `Bars_To_Load` | int | `1000` | Analysis history/cache depth |

### Timeframes and confirmation

| Input | Type | Default | Purpose |
|---|---|---:|---|
| `Trend_Timeframe` | ENUM_TIMEFRAMES | `PERIOD_H1` | Direction and major structure |
| `Structure_Timeframe` | ENUM_TIMEFRAMES | `PERIOD_M15` | Setup/swing timeframe |
| `Confirmation_Timeframe_1` | ENUM_TIMEFRAMES | `PERIOD_M15` | First engulfing timeframe |
| `Confirmation_Timeframe_2` | ENUM_TIMEFRAMES | `PERIOD_M30` | Second engulfing timeframe |
| `Confirmation_Policy` | enum | `CONFIRM_ALL` | Require both or either timeframe |

### Hybrid swings and structure

| Input | Type | Default | Purpose |
|---|---|---:|---|
| `Fractal_Length` | int | `3` | Bars on each side of candidate |
| `ATR_Filter` | bool | `true` | Enable significance filter |
| `ATR_Period` | int | `14` | ATR calculation period |
| `Minimum_Swing_ATR` | double | `1.5` | Required opposite excursion |
| `ZigZag_Depth` | int | `12` | Minimum pivot search depth |
| `ZigZag_Deviation` | int | `5` | Minimum pivot deviation in points |
| `ZigZag_Backstep` | int | `3` | Pivot replacement separation |
| `Structure_Break_On_Close` | bool | `true` | Require close beyond structure |
| `ABC_Max_Age_Bars` | int | `100` | Expire stale pattern state |

### Boundaries, Fibonacci, and liquidity

| Input | Type | Default | Purpose |
|---|---|---:|---|
| `Minimum_Level_Touches` | int | `3` | Major zone qualification |
| `Zone_Size_ATR` | double | `0.25` | Zone half-width |
| `Trendline_Reaction_ATR` | double | `0.20` | Trendline proximity threshold |
| `Use_Fibonacci_Filter` | bool | `true` | Make Fibonacci zone a hard gate |
| `Primary_Fib_Level` | double | `0.88` | Deep-retracement level |
| `Fib_Tolerance_Mode` | enum | `FIB_TOL_ATR` | ATR fraction or points |
| `Fib_Tolerance` | double | `0.10` | ATR fraction (or points by mode) |
| `Require_Fib_Structural_Confluence` | bool | `true` | Require one listed structure factor |
| `Require_Liquidity_Sweep` | bool | `true` | Make sweep mandatory |
| `Liquidity_Lookback_Bars` | int | `20` | Prior-liquidity search window |
| `Liquidity_Max_Sweep_ATR` | double | `0.50` | Maximum accepted penetration |

### Pattern and scoring

| Input | Type | Default | Purpose |
|---|---|---:|---|
| `Minimum_Engulfing_Strength` | double | `1.25` | Body/average-body minimum |
| `Average_Body_Period` | int | `10` | Average real-body lookback |
| `Minimum_Entry_Score` | int | `8` | Required score out of 20 |
| `Score_Trend_Alignment` | int | `2` | Configurable component weight |
| `Score_Market_Structure` | int | `2` | Configurable component weight |
| `Score_Major_Boundary` | int | `2` | Configurable component weight |
| `Score_Trendline_Reaction` | int | `1` | Configurable component weight |
| `Score_Fibonacci_Zone` | int | `2` | Configurable component weight |
| `Score_Fib_Structure_Reaction` | int | `3` | Configurable component weight |
| `Score_ABCICC` | int | `2` | Configurable component weight |
| `Score_Liquidity_Sweep` | int | `2` | Configurable component weight |
| `Score_Engulfing` | int | `2` | Configurable component weight |
| `Score_Confirmation_Close` | int | `2` | Configurable component weight |

### Stops, targets, RR, and money management

| Input | Type | Default | Purpose |
|---|---|---:|---|
| `SL_Mode` | enum | `SL_HYBRID` | Swing, ATR, or hybrid stop |
| `SL_ATR_Buffer` | double | `0.25` | ATR beyond structural swing |
| `SL_ATR_Multiplier` | double | `2.0` | ATR-only stop distance |
| `Structure_Target_Buffer` | int | `20` | Points before structural target |
| `Minimum_RR` | double | `1.7` | Minimum reward/risk |
| `Risk_Percentage` | double | `10.0` | Balance percentage at risk |
| `Maximum_Open_Positions` | int | `1` | Simultaneous EA exposure |
| `Maximum_Trades_Per_Day` | int | `2` | Entry-deal daily limit |
| `Maximum_Trades_Per_Week` | int | `6` | Entry-deal weekly limit |
| `Loss_Reduction_After` | int | `2` | Losses before reduced risk |
| `Loss_Risk_Multiplier` | double | `0.50` | Risk multiplier after threshold |
| `Maximum_Volume` | double | `0.0` | Optional lot cap; 0 uses symbol max |
| `Margin_Safety_Percent` | double | `100.0` | Required free margin vs order margin |

### Visualization, alerts, and logging

| Input | Type | Default | Purpose |
|---|---|---:|---|
| `Enable_Visualization` | bool | `true` | Master chart drawing switch |
| `Show_Dashboard` | bool | `true` | Status and reason panel |
| `Show_Structure_Labels` | bool | `true` | HH/HL/LH/LL and A/B/C labels |
| `Show_Boundaries` | bool | `true` | Zones and trendline |
| `Show_Fibonacci` | bool | `true` | Anchors, 0.88, and zone |
| `Max_Chart_Swings` | int | `30` | Object-count bound |
| `Enable_Terminal_Alert` | bool | `true` | Alert in alert-only mode |
| `Enable_Push_Notification` | bool | `false` | Optional mobile notification |
| `Enable_Email_Notification` | bool | `false` | Optional email notification |
| `Enable_CSV_Logging` | bool | `true` | Detailed persistent records |
| `Log_File_Name` | string | `ABC_ICC_Deriv_Trades.csv` | Common CSV filename |
| `Verbose_Journal` | bool | `false` | Diagnostic journal output |

Input validation will reject nonsensical combinations (invalid periods, negative
weights/tolerances, Fib outside 0–1, RR ≤ 0, or ZigZag backstep ≥ depth) in
`OnInit` with a precise error.

## 7. Trading decision flowchart

```text
[New tick]
    |
    +-- position exists? --> [Leave SL/TP untouched; update display] --> END
    |
    +-- no newly closed M15 setup bar? --> [Quote/display update only] --> END
    |
    v
[Enough synchronized H1/M15/M30 closed history?] -- no --> [WAIT]
    |
   yes
    v
[Build confirmed hybrid swings: fractal + ATR + ZigZag]
    |
    v
[Classify H1 and M15 HH/HL or LL/LH]
    |
    +-- neutral/conflicting direction --> [NO SETUP]
    |
    v
[Advance A indication -> B correction -> C continuation state]
    |
    +-- incomplete/invalid/expired --> [WAIT or RESET]
    |
    v
[Build major S/R zones and confirmed HL/LH trendline]
    |
    v
[Anchor latest aligned impulse and calculate 0.88 zone]
    |
    +-- Fibonacci enabled and price outside zone --> [WAIT]
    |
    +-- no required structural overlap --> [REJECT]
    |
    v
[Detect closed-bar liquidity sweep]
    |
    +-- required but absent --> [REJECT]
    |
    v
[Detect closed M15 and M30 engulfing candles]
    |
    +-- confirmation policy fails --> [WAIT]
    |
    v
[Calculate named confluence components and score / 20]
    |
    +-- score below minimum --> [REJECT + EXPLAIN]
    |
    v
[Build SL behind swing/ATR; find next structural TP]
    |
    +-- invalid stop/target or RR < minimum --> [REJECT]
    |
    v
[Check duplicate, spread, positions, daily/weekly limits, margin]
    |
    +-- any gate fails --> [REJECT + EXPLAIN]
    |
    v
[Apply loss-streak risk factor; calculate broker-normalized volume]
    |
    +-- volume invalid / intended risk impossible --> [REJECT]
    |
    v
[SETUP FOUND: render and log complete plan]
    |
    +-- Mode 1 --> [Final quote validation] --> [Place one market order]
    +-- Mode 2 --> [Signal/chart/log only]
    +-- Mode 3 --> [Deduplicated alert + chart/log]
    |
    v
[If filled: fixed SL and structure TP; no active management]
    |
    v
[OnTradeTransaction: log TP/SL result and update loss streak]
```

## 8. Backtesting and optimization architecture

- The same new-bar pipeline will be used in tester and live execution; no
  forward-looking buffer values or forming candles are permitted.
- Visual objects and verbose logs can be disabled during optimization.
- Initialization preloads/caches rates and indicator handles; analysis avoids
  full-history rescans where incremental updates are safe.
- Primary optimization candidates are fractal length, swing ATR threshold,
  ZigZag parameters, zone/tolerance ATR factors, score threshold, engulfing
  strength, stop buffers, and minimum RR.
- Risk percentage should not be optimized to disguise weak expectancy. Validation
  should include out-of-sample periods, multiple Deriv indices, spread stress,
  Monte Carlo/order reshuffling, drawdown, trade count, and profit factor.
- Tester validation will include a no-lookahead audit: every logged pivot and
  confirmation records both source time and confirmation time.

## 9. Implementation acceptance criteria

Implementation is complete only when it compiles without errors/warnings in
MetaEditor, uses no hardcoded symbol, creates/releases handles correctly, avoids
duplicate signals, honors all three modes and limits, calculates broker-compliant
volume/stops, selects TP exclusively from confirmed structure, logs closed-deal
results, restores counters after restart, and demonstrates unchanged historical
confirmed signals as new bars arrive.

Approval of this specification authorizes the next phase: generating and testing
the MQL5 files module by module, followed by the user documentation file.
