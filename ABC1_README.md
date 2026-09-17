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
`HH`, `HL`, `LH`, or `LL`. Smaller changes are labelled `EQH`/`EQL` and do not
create a directional market-structure state. This filters insignificant
candle-to-candle changes without introducing repainting.

The rules are evaluated independently on `Higher_Timeframe` and
`Structure_Timeframe`. The dashboard reports both trends and their alignment.
Labels are drawn from the structure timeframe.

## Hybrid swing pipeline

A swing is published only when all enabled stages pass:

1. **Fractal:** the price is strictly more extreme than `Fractal_Length` closed
   candles on both sides.
2. **ATR significance:** a later closed candle has moved at least
   `ATR(candidate) × Minimum_Swing_ATR` away from the candidate. Set
   `ATR_Filter=false` to bypass this stage.
3. **ZigZag confirmation:** the candidate is a depth-window extreme, exceeds
   `ZigZag_Deviation` points from the opposite leg, respects
   `ZigZag_Backstep`, and has subsequently been locked by an opposite pivot.

Nearby same-side pivots are smoothed when they occur within
`Swing_Smoothing_Bars`, even when a small counter-pivot lies between them. The
cluster is represented by its highest high or lowest low, preventing several
labels from accumulating around the same short consolidation.

The newest ZigZag leg is supplied to market structure as a provisional point.
It follows a more-extreme high or low on the live candle on every tick; older
legs remain locked. This deliberately allows the newest HH/HL/LH/LL label to
move until an opposite pivot confirms it, rather than leaving the display a
full ZigZag leg behind current price.

After a bullish structure has been established, the first LL is marked as a
change of character (CHoCH). After a bearish structure, the first HH is marked
the same way. Each event is shown by a short red horizontal segment starting at
the breaking swing and a red `CHoCH` caption. `CHoCH_Line_Bars` controls the
segment length.

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
