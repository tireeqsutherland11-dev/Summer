# MetaTrader 5 Indicators and Tools

## Liquidity Sweep Strategy

`Liquidity Sweep Strategy.mq5` combines the Base market-structure EA and Model
Base liquidity-zone rendering in one Expert Advisor. Base owns the shared
pivot detection and HH/HL/LH/LL classification; Model Base retains its
overlap-count, volume, zone, and level rendering.

The active chart period decides which engine may draw. The liquidity engine
draws only when the chart period equals `Setup_Entry_Timeframe` (MTF). Base
draws its full overlays and dashboard on `Structure_Timeframe` or
`Boundary_Timeframe` (HTF). On all other chart periods nothing is drawn, while
Base's analytical processing and optional alerts remain active.

On the MTF chart one structure replay of the setup timeframe supplies both the
`HH`, `HL`, `LH`, and `LL` labels and the liquidity swings, so a zone can never
disagree with the labels beside it. The replay covers the same elapsed time as
`Bars_To_Process` does on the structure timeframe (100 H1 candles become 400
M15 candles) and uses `Swing_Detection_Length`; numeric volume labels are not
drawn. With an established bearish HTF bias, an `LH` becomes a liquidity swing
when the next structure low is an `LL`. With an established bullish bias, an
`HL` becomes a liquidity swing when the next structure high is an `HH`. Each
swing is identified once, even if a more extreme `HH`/`LL` later replaces the
first one in the same leg. This rule does not wait for or inspect a BOS close.
A transitional or consolidating HTF bias identifies no liquidity swing, and the
status line in the top-left corner says so.

The status line reports the setup timeframe, the HTF bias, the number of
liquidity swings, and how many were swept.

### Liquidity sweeps

A liquidity level stays live until a candle closes beyond it (the level then
turns dashed, as in Model Base). When a candle's wick trades beyond a live
level but the candle closes back inside, the resting liquidity has been swept:
the first sweep of each level is marked with an arrow on that candle (hover
it for the level). `Show_Liquidity_Sweeps` toggles the markers.

With `Alert_On_Liquidity_Sweep` enabled (the default), a sweep on the newest
closed MTF candle raises an alert through the same `Enable_Popup_Alerts` and
`Enable_Push_Notifications` switches as the structure alerts; both are off by
default. Sweep alerts work on any chart period: away from the MTF chart the
liquidity engine runs without drawing whenever sweep alerts can be delivered.
No alert is raised by the initial build after attaching.

### Performance and refresh

Both engines only work when a relevant candle closes (LTF, MTF, or HTF) or the
HTF state changes; other ticks and timer events cost a few time lookups.
Scrolling, zooming, and resizing never redraw the chart, because every window
is fixed in candles rather than taken from the visible range. Changing the
chart period reinitialises the EA, and the shared two-second timer retries a
build until MT5 has synchronised every requested history, so a chart restart
is not required. All series are loaded before any chart object is replaced, so
a build that is still waiting for data keeps the previous drawing. When
enabled, `Intrabar_Timeframe` must be lower than `Setup_Entry_Timeframe`; its
candles are loaded with one copy per build.

Install the EA in `MQL5/Experts`, compile it in MetaEditor, and attach
**Liquidity Sweep Strategy** to one chart.

### Trading and the Strategy Tester

The EA can trade the liquidity zones it identifies. `Trade_Mode` chooses where:
**Strategy Tester only** (the default), **Strategy Tester and live charts**, or
**Off**. The default means a chart that runs the EA for analysis never places
orders; choose the live option deliberately.

A trade waits for the live liquidity zone on the setup timeframe to be
swept: an MTF candle's wick trades beyond the zone's level (above the LH high
for a sell in a bearish bias, below the HL low for a buy in a bullish bias)
and the candle closes back inside. This is the candle marked with the sweep
arrow. A zone is live while its level is visible and no MTF candle has closed
beyond it. The entry is taken within the next `Entry_Window_Candles` (default
3) MTF candles, on the first tick at which the zone is still live, price is
back inside the swept level, and all of the following hold:

- The HTF bias is established in the trade direction: its latest break is a
  BOS, not a transitional CHoCH, and not consolidating.
- The dashboard's Market Tradeability is **Tradable**.
- Every enabled Optimal Conditions requirement passes. Technical space is
  checked at the actual entry price rather than the price at the last candle
  close.
- Price is not at or approaching a Market High/Low or trendline: the entry is
  farther than the dashboard's clearance (`Boundary_Clearance_ATR` x LTF ATR)
  from each of them, and with `Require_Clear_Path_To_Target` (on by default)
  none of them lies between the entry and the take profit. Trading waits
  until enough `Boundary_Timeframe` history exists to find these levels.
- The zone has not been traded before, and no other position with this EA's
  `Magic_Number` is open on the symbol.

A zone's liquidity is taken by its first sweep, so if the window closes
without an entry, or a candle in it closes beyond the level, the zone is not
traded.

Exits:

- **Stop loss** sits beyond the most extreme wick since the sweep (the sweep
  wick, or a deeper one printed later in the window, including the forming
  candle) by `SL_Buffer_ATR` (default 0.5) setup-timeframe ATRs; sells add the
  spread because their stop triggers on the ask. A setup is skipped rather
  than squeezed when that stop would exceed `Max_SL_ATR` (default 2.0) ATRs,
  which keeps the target realistic.
- **Take profit** is `Reward_Risk_Ratio` (default 2.0) times the risk, 1:2.
- **Breakeven**: once price has moved `Breakeven_At_R` (default 1.0) times the
  risk in favour, the stop moves to the entry price. The risk is recovered
  from the take profit, so this also works after a restart.
- **Size** risks `Risk_Percent` (default 1%) of the balance at the stop, or
  uses `Fixed_Lots` when `Lot_Sizing` is set to fixed lots.

Each rejected zone is written to the Journal once with its reason (for example
"at or approaching the Market High" or "optimal conditions not met (market
volume)"), and each entry with its lots, stop and target. On the MTF chart a
second status line shows the trading state.

To run a test, open the Strategy Tester (Ctrl+R), select **Liquidity Sweep
Strategy**, the symbol and a date range, and use **Every tick based on real
ticks** or **Every tick** modelling so the entry conditions and stops are
checked tick by tick; **Open prices only** cannot reproduce them. Any chart period works and gives
the same trades; choose the setup timeframe (M15 by default) to watch the
zones in visual mode. Non-visual runs and optimisation skip all drawing for
speed. The EA needs about 320 candles of `Boundary_Timeframe` history (roughly
three months of H4) before it trades.

## Model Base

`Model Base.mq5` is an MQL5 Expert Advisor conversion of the supplied
Liquidity Swings PineScript. It detects delayed pivot highs and lows, draws
their wick-extremity or full-range liquidity areas, counts overlapping bars,
accumulates tick volume, and marks levels as dashed after price crosses them.
Optional lower-timeframe sampling approximates Pine's intrabar volume mode.
It is analysis/visualisation software only and never places trades.

Install it in `MQL5/Experts`, compile it in MetaEditor, refresh **Navigator >
Expert Advisors**, and attach **Model Base** to a chart. Keep Algo Trading
enabled so its event loop runs. The EA attaches immediately and reconstructs
the latest 400 closed candles, independently of the visible chart range, so a
partly formed candle can neither confirm a pivot nor cross a level. It rebuilds
once per new chart candle; scrolling and zooming do not redraw it. A two-second
retry timer runs only while chart or intrabar history is still loading and
stops as soon as a build completes. MetaTrader tick volume is used because
broker-independent centralized volume is not universally available.

As in the Pine source, only the newest swing on each side is tracked. When a
new pivot replaces it, its live projection box is removed, an unbroken level
ends at the new pivot's candle, and a level that never passed the filter is
removed. Zone widths are measured in candles, so they stay correct across
weekends and session gaps. With `Intrabar_Precision`, the lower-timeframe
candles are loaded with one copy per build.

By default, every geometrically valid pivot is eligible to display so a newly
attached EA produces useful output without requiring symbol-specific impulse
calibration. Enable `Require_Strong_Departure` to keep only pivots whose
confirmation window demonstrates a strong departure from the level. The
optional qualification favours directional tick-volume pressure, candle-body
momentum, and an efficient one-way move, with relative volume as confirmation.
Raw distance is only 10% of the score, so a large but hesitant move does not
outrank a smaller, decisive impulse. The thresholds are available under
**Impulse Qualification**.

Equal-high and equal-low plateaus are treated as a single liquidity swing at
the latest bar in the plateau. This prevents a lower-high liquidity level (or
higher-low counterpart) from disappearing merely because adjacent candles
printed the same extremity, while also avoiding duplicate levels.

The top-left status line is always created when the EA attaches. It immediately
reports the number of detected high and low swings, or identifies when the
chart does not yet contain a complete pivot window. If the chart reports zero
swings with strong-departure qualification enabled, disable that option first
and then tune its thresholds for the symbol and timeframe.

## Base

`Base.mq5` (formerly Road) is a **chart-analysis and alerting Expert Advisor
(EA)**. It reconstructs
market structure from closed candles, draws BOS/CHoCH and boundary overlays,
and reports multi-timeframe tradeability and market conditions. It never
places, modifies, or closes trades.

## Install and start

1. Copy `Base.mq5` into the terminal's `MQL5/Experts` directory.
2. Open the file in MetaEditor and compile it. Resolve every compiler error or
   warning before continuing.
3. In MetaTrader 5, refresh **Navigator > Expert Advisors**, then drag **Base**
   onto a chart. An invalid input is reported in the Experts tab with the
   input's name and valid range.
4. Leave the default timeframes for the intended H4 boundary / H1 structure /
   M15 setup / M5 confirmation workflow, or deliberately select alternatives.
5. Keep **Algo Trading** enabled if you want the EA event loop to run. Base
   itself does not submit orders.
6. Enable terminal push notifications and provide a MetaQuotes ID before
   turning on `Enable_Push_Notifications`.

Base may initially show no output while MT5 downloads the requested histories
and calculates indicator buffers. Its two-second timer retries automatically,
including straight after a chart timeframe change. Every series is loaded
before existing chart objects are replaced, so a retry never blanks the chart.
Attach one instance per chart; each instance owns only chart objects bearing its
chart-specific prefix.

## Reading the dashboard

- **Market Bias** shows the independently replayed Structure, Setup, and LTF
  state. A transition means the latest break is CHoCH rather than continuation.
- New pivot labels formed during an ordinary pullback do not change an
  established bias to transitional. The bias transitions only after price
  closes through the opposing corrective swing and confirms a CHoCH.
- A bearish-to-bullish CHoCH requires price to close above an LH, creating an
  HH, and then form an HL as the immediately following opposite-side structure
  point. A bullish-to-bearish CHoCH requires price to close below an HL,
  creating an LL, and then form an LH next. Until that corrective pivot is
  confirmed, the break is only a CHoCH candidate. The corrective pivot must
  form after the breaking close: a swing printed before the close (for
  example the low of a sharp V-reversal, confirmed a few candles later) can
  neither confirm nor cancel the candidate. Wicks beyond the broken levels
  remain liquidity sweeps rather than CHoCH.
- **Tradable** always requires an established Bullish or Bearish HTF bias: its
  latest break must be a continuation BOS that creates a new HH or LL, rather
  than a transitional CHoCH. The enabled tradeability timeframe directions
  must also agree, and when LTF participation is enabled its latest break must
  be BOS. It is an analytical state, not an instruction to place a trade.
- Hover **Market Tradeability** to see the entry filters (MA, HTF MA,
  session, ADX, ATR) for the latest closed structure candle: whether a long or
  short BOS/CHoCH setup would pass, and each filter's reading.
- **Optimal Conditions** applies only the requirements enabled in the
  **Optimal Conditions** input group. By default it checks timeframe
  correlation, boundary clearance, extension, relative tick volume, and
  relative true-range momentum.
- BOS/CHoCH alerts describe confirmed structure events and are intentionally
  independent of the qualification filters.

All calculations use closed candles. A wick beyond a swing is not considered a
break; a candle must close beyond it. A swing high must be above the
`Swing_Detection_Length` candles on its left and above the same number on its
right; equal highs (a double top) form one swing at the latest of the equal
candles rather than no swing at all. Swing lows mirror this rule.

## Configuration notes

- `Bars_To_Process` controls replay depth and therefore startup/rebuild cost.
  Start with the default 100 and raise it only when more context is needed.
- `Boundary_Lookback_Bars` is the Market High and Market Low search window on
  `Boundary_Timeframe`. Market High is the highest confirmed swing high in the
  window and is drawn only while it is above the current price; Market Low is
  the lowest confirmed swing low and is drawn only while it is below price.
- The structure, setup, and LTF inputs are all monitored for new bars, so custom
  timeframe orders still refresh correctly.
- `Use_HTF_For_Tradeability`, `Use_MTF_For_Tradeability`, and
  `Use_LTF_For_Tradeability` independently control which market biases must
  correlate. At least one must remain enabled. This supports HTF-only, HTF/MTF,
  all-three, and other combinations. Disabled timeframe biases are hidden from
  the dashboard, but the established HTF-bias prerequisite always applies.
- The five `Use_*_For_Optimal` inputs independently choose which requirements
  determine the Optimal Conditions result. At least one must remain enabled;
  disabled requirements are omitted from both the result and the dashboard.
- Preset session UTC offsets are fixed and do not adjust for daylight-saving
  time. Set the broker server offset correctly and use a custom session where
  seasonal handling matters.
- A custom session must use exactly `HHMM-HHMM` with numeric digits. Equal start
  and end means all day; ranges such as `2200-0600` cross midnight.
- ATR thresholds use raw symbol price units, not points or pips.
- `Trendline_Zones_Per_Side` selects how many distinct resistance and support
  trendlines may be drawn. The ATR-derived zone remains part of proximity
  calculations, while the chart renders its centre as a thin line so crossings
  stay clean. `Trendline_Minimum_Touches` is selectable from
  3 through 8; no trendline with fewer than three confirmed pivot touches is
  considered valid.

See [`Roadmap.txt`](Roadmap.txt) for the complete processing model and input
reference.

## Validation checklist

Before relying on a release, compile in the current MetaEditor, attach it to a
Strategy Tester visual run with enough history for every selected timeframe,
and verify the Experts/Journal tabs contain no runtime errors. Test popup and
push delivery separately because terminal notification configuration is
outside the EA.
