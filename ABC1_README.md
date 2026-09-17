# ABC1 — Hybrid Multi-timeframe Market Structure EA

`ABC1.mq5` is a MetaTrader 5 Expert Advisor for charting market
structure on Deriv Synthetic Indices (and any MT5 symbol with sufficient price
history). It performs analysis only: the requested specification defines swing
and trend qualification, but does not define entry, stop-loss, take-profit, or
risk rules, so ABC1 deliberately does not place orders.

## Structure rules

ABC1 classifies each confirmed swing high against the preceding confirmed high
as `HH` or `LH`, and each confirmed swing low against the preceding confirmed
low as `HL` or `LL`.

- Bullish: latest high is above the previous high **and** latest low is above
  the previous low (`HH + HL`).
- Bearish: latest low is below the previous low **and** latest high is below
  the previous high (`LL + LH`).
- Anything else is reported explicitly as consolidation/transition.

A high or low must differ from its predecessor by at least
`Minimum_Structure_Change_ATR × max(ATR of both swings)` before it can become
`HH`, `HL`, `LH`, or `LL`. Smaller changes are classified internally as
`EQH`/`EQL` and do not create a directional market-structure state. Equal
labels are hidden by default to keep the chart clean; set
`Show_Equal_Labels=true` when they are useful for review. This filters
insignificant candle-to-candle changes without introducing repainting. The two
same-side pivots must also be at least `Minimum_Structure_Separation_Bars`
apart. Consequently, two otherwise valid highs or lows which form only a few
candles apart are treated as equal/noise instead of producing tightly packed
HH/LH or HL/LL labels.

The rules are evaluated independently on `Higher_Timeframe` and
`Structure_Timeframe`. The dashboard reports both trends and their alignment.
Labels are drawn from the structure timeframe.

`Bars_To_Scan` is an exact per-timeframe depth. The EA waits for all requested
bars and matching ATR values to load instead of silently analyzing a shorter
window while a newly selected timeframe is synchronizing. Thus, a value of
1000 analyzes 1000 bars on both the higher and structure timeframes regardless
of which timeframe values are selected.

When the structure timeframe is lower than the chart timeframe, many valid
structure points can fall inside one visible chart candle. By default,
`Avoid_Label_Overlap` keeps only the newest label within each
`Minimum_Label_Chart_Bars` interval. This is display-only filtering: the
underlying swing construction, classification, trend state, and alerts still
use the complete scan. Disable it when every lower-timeframe label is desired.

## Hybrid swing pipeline

A swing is published only when all enabled stages pass:

1. **Fractal:** the price is strictly more extreme than `Fractal_Length` closed
   candles on both sides.
2. **ATR significance:** a later closed candle has moved at least
   `ATR(candidate) × Minimum_Swing_ATR` away from the candidate. Set
   `ATR_Filter=false` to bypass this stage.
3. **ZigZag confirmation:** the candidate is a depth-window extreme, exceeds
   both `ZigZag_Deviation` points and `Minimum_Reversal_ATR × ATR` from the
   opposite leg, respects `ZigZag_Backstep`, and has subsequently been locked
   by an opposite pivot. The ATR reversal gate removes the frequent shallow
   fluctuations that a points-only threshold can admit on volatile symbols.

Nearby same-side pivots are smoothed when they occur within
`Swing_Smoothing_Bars`, even when a small counter-pivot lies between them.
Pivots within `Swing_Cluster_ATR × ATR` are also treated as one price area for
up to `Swing_Cluster_Bars`. Each cluster is represented by only its highest
high or lowest low. This makes repeated HH/HL or LH/LL tests in the same area
produce a single, extreme structure point rather than a cluster of labels.

The newest ZigZag leg is supplied to market structure as a provisional point.
It follows a more-extreme high or low on the live candle on every tick; older
legs remain locked. This deliberately allows the newest HH/HL/LH/LL label to
move until an opposite pivot confirms it, rather than leaving the display a
full ZigZag leg behind current price.

After bullish structure is established, its latest significant HL becomes the
protected low. A bearish change of character (CHoCH) occurs only when a later
low breaks that protected level by more than `CHoCH_Break_ATR × ATR`. The
inverse applies to a bearish trend: its latest significant LH is protected and
must be broken by a later high. This stateful rule avoids marking every minor
LL/HH as a CHoCH. Each red CHoCH segment starts at the protected swing (where
the eventual counter-trend move originates), ends at least at the breaking
swing, and carries a `CHoCH` caption. `CHoCH_Line_Bars` sets its minimum visual
length.

The EA also retries its calculation on a two-second timer while history or ATR
buffers are synchronizing. This keeps the dashboard and labels alive after an
MT5 chart-timeframe change instead of waiting indefinitely for another
structure-timeframe candle.

## Installation

1. Copy `ABC1.mq5` into the terminal's `MQL5/Experts` directory.
2. Open the file in MetaEditor and compile it.
3. Attach **ABC1** to the desired Synthetic Index chart.
4. Enable enough history for both selected timeframes, then adjust the swing
   inputs for the volatility profile of the selected index.

`ZigZag_Deviation` is expressed in the active symbol's points. ATR-derived
distances automatically use the active symbol's price units.
