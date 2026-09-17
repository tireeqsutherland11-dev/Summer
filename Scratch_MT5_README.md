# Scratch — Pine market-structure port for MetaTrader 5

`Scratch.mq5` is an analysis-only Expert Advisor containing the swing, trend,
Break of Structure (BOS), and Change of Character (CHoCH) logic from the
supplied **Market Trend Analyser** Pine script. It never sends trading orders.

## Identification rules

* A swing high/low is confirmed only after `Swing_Detection_Length` bars have
  appeared on its right. The default of 5 therefore matches
  `ta.pivothigh(high, 5, 5)` and `ta.pivotlow(low, 5, 5)`.
* A bullish break occurs when a completed candle crosses from at-or-below the
  latest swing high to a close above it. A bearish break is the inverse at the
  latest swing low.
* Each confirmed swing may generate at most one break. Confirming a newer swing
  resets that side's broken flag, exactly as in the Pine state machine.
* In an undefined or already bullish market, a bullish break is BOS; in a
  bearish market it is bullish CHoCH. Bearish classification is symmetrical.
  A qualifying break immediately changes the persistent market structure.

These rules intentionally replace the earlier trigger/zigzag and two-swing
confirmation model in `Scratch.mq5`.

## Signal filters

The LTF MA, HTF MA, session, ADX, and ATR filters from the supplied script are
also applied before a break is accepted. BOS uses every enabled filter. CHoCH
uses every enabled filter except ADX when `ADX_Filter_Scope` is
`ADX_BOS_Only`. As in Pine, a detected crossing marks that swing as broken even
when a filter rejects the signal; it does not change the market structure.

MA filters support EMA/SMA and price-side/full-body modes. ATR supports minimum,
maximum, and range modes. The HTF full-body mode evaluates the HTF candle that
contains the event candle.

Pine accepts IANA time zones and automatically applies their historical DST
rules. Native MQL5 does not expose an IANA time-zone database, so MT5 session
hours are evaluated in the broker server time carried by `MqlRates.time`.
Adjust the preset/custom hours when broker time differs from the Pine session's
local time. Overnight custom sessions are supported.

## Use

1. Copy `Scratch.mq5` to `MQL5/Experts` and compile it in MetaEditor.
2. Attach it to a chart. It processes completed candles and rebuilds history
   deterministically when a new analysis-timeframe candle opens.
3. Configure swing length, history depth, colors, line style, labels, and
   alerts. All chart objects use the `ScratchMT5_` prefix, so cleanup cannot
   delete unrelated objects.

The upper-left chart comment reports `BULLISH`, `BEARISH`, or `UNDEFINED` plus
the latest confirmed swing levels. Alerts fire only for a signal on the newly
completed candle, not while historical objects are rebuilt.
