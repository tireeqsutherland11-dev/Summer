# Scratch — MetaTrader 5 conversion

`Scratch.mq5` converts the TradingView **indicator** in `Scratch.pine` to an
MT5 Expert Advisor. It intentionally sends no orders: the Pine source contains
market-structure drawing and alerts, but no entry, exit, lot-size, stop-loss,
or take-profit rules.

The EA exposes the Pine script's eight reversal triggers (smart engulfment,
SMA, ATR expansion, displacement, loopback, area, candle direction, and linear
regression), its LTF/MTF/HTF structure modes, source selections, SMA lengths,
line/label styling, quantitative labels, and alerts. It draws alternating
swings, HH/HL/LH/LL labels, ZigZag legs, BoS, CHoCH, and liquidity sweeps using
names prefixed with `ScratchMT5_` so it never deletes unrelated chart objects.
`Show_ZigZag_Lines` toggles the connecting ZigZag legs independently of swing
labels and structure lines. BoS, CHoCH, and liquidity-sweep lines stop at the
first later candle whose high-to-low range touches their horizontal level.

## Install

1. Copy `Scratch.mq5` to `MQL5/Experts` and compile it in MetaEditor.
2. Attach **Scratch** to a chart and enable Algo Trading if terminal alerts or
   push notifications are wanted (the EA never trades).
3. Set `Timeframe` to `PERIOD_CURRENT` to match Pine's blank Timeframe input,
   or select an explicit analysis timeframe.
4. Keep the same trigger, source, structure mode, and SMA settings in both
   platforms when comparing output. The EA evaluates completed bars and
   rebuilds its deterministic history whenever a new analysis bar opens.

## Platform mapping notes

TradingView bar indexes have no durable MT5 equivalent, so every Pine drawing
is anchored to its bar's `datetime`. Pine `alertcondition()` entries map to
terminal `Alert()` messages, with optional `SendNotification()`. TradingView's
transparent label backgrounds do not have a direct `OBJ_TEXT` equivalent;
the MT5 labels therefore preserve text, placement, and foreground color.
