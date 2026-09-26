# Road for MetaTrader 5

Road is a **chart-analysis and alerting Expert Advisor (EA)**. It reconstructs
market structure from closed candles, draws BOS/CHoCH and boundary overlays,
and reports multi-timeframe tradeability and market conditions. It never
places, modifies, or closes trades.

## Install and start

1. Copy `Road.mq5` into the terminal's `MQL5/Experts` directory.
2. Open the file in MetaEditor and compile it. Resolve every compiler error or
   warning before continuing.
3. In MetaTrader 5, refresh **Navigator > Expert Advisors**, then drag **Road**
   onto a chart.
4. Leave the default timeframes for the intended H4 boundary / H1 structure /
   M15 setup / M5 confirmation workflow, or deliberately select alternatives.
5. Keep **Algo Trading** enabled if you want the EA event loop to run. Road
   itself does not submit orders.
6. Enable terminal push notifications and provide a MetaQuotes ID before
   turning on `Enable_Push_Notifications`.

Road may initially show no output while MT5 downloads the requested histories
and calculates indicator buffers. Its two-second timer retries automatically.
Attach one instance per chart; each instance owns only chart objects bearing its
chart-specific prefix.

## Reading the dashboard

- **Market Bias** shows the independently replayed Structure, Setup, and LTF
  state. A transition means the latest break is CHoCH rather than continuation.
- A reversal is not declared on a level break alone: bearish-to-bullish CHoCH
  requires an LH break followed by a confirmed HL, while bullish-to-bearish
  CHoCH requires an HL break followed by a confirmed LH.
- **Tradable** requires all three directions to agree and the LTF's latest break
  to be BOS. It is an analytical state, not an instruction to place a trade.
- **Optimal Conditions** additionally checks boundary clearance, extension,
  relative tick volume, and relative true-range momentum.
- BOS/CHoCH alerts describe confirmed structure events and are intentionally
  independent of the qualification filters.

All calculations use closed candles. A wick beyond a swing is not considered a
break; a candle must close beyond it.

## Configuration notes

- `Bars_To_Process` controls replay depth and therefore startup/rebuild cost.
  Start with the default 100 and raise it only when more context is needed.
- The structure, setup, and LTF inputs are all monitored for new bars, so custom
  timeframe orders still refresh correctly.
- Preset session UTC offsets are fixed and do not adjust for daylight-saving
  time. Set the broker server offset correctly and use a custom session where
  seasonal handling matters.
- A custom session must use exactly `HHMM-HHMM` with numeric digits. Equal start
  and end means all day; ranges such as `2200-0600` cross midnight.
- ATR thresholds use raw symbol price units, not points or pips.

See [`Roadmap.txt`](Roadmap.txt) for the complete processing model and input
reference.

## Validation checklist

Before relying on a release, compile in the current MetaEditor, attach it to a
Strategy Tester visual run with enough history for every selected timeframe,
and verify the Experts/Journal tabs contain no runtime errors. Test popup and
push delivery separately because terminal notification configuration is
outside the EA.
