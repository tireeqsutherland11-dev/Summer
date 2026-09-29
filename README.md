# MetaTrader 5 Indicators and Tools

## Liquidity Sweep Strategy

`Liquidity Sweep Strategy.mq5` combines the Base market-structure EA and Model
Base liquidity-zone rendering in one Expert Advisor. Base owns the shared
pivot detection, HH/HL/LH/LL classification and BOS/bias rules (see
[Reading the structure](#reading-the-structure)). One difference is the
Strategy's CHoCH: after the LH (HL) is broken and the HH (LL) forms, it also
waits for the HL (LH) that follows. Model Base retains its overlap-count,
volume, zone, and level rendering.

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

A trade is taken on a liquidity sweep of the zone on the setup timeframe:
price breaks past the zone and then re-enters it. For a sell in a bearish bias
that means trading above the LH zone's top and coming back inside it; for a
buy in a bullish bias, trading below the HL zone's bottom and coming back
inside. The break can be a wick or a full candle close beyond the zone. The
entry is taken immediately, on the first tick back inside the zone, provided
the break happened no more than `Entry_Window_Candles` (default 3) MTF
candles earlier and all of the following hold:

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

If price does not re-enter within that window, the break is treated as a
genuine breakout and the zone is not traded.

Exits:

- **Stop loss** sits beyond the furthest price reached since the break
  (including the forming candle) by `SL_Buffer_ATR` (default 0.5)
  setup-timeframe ATRs; sells add the spread because their stop triggers on
  the ask. A setup is skipped rather
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
market structure from closed candles, draws HH/HL/LH/LL, BOS and CHoCH, and
reports multi-timeframe tradeability and market conditions. It never
places, modifies, or closes trades.

## Install and start

1. Copy `Base.mq5` into the terminal's `MQL5/Experts` directory.
2. Open the file in MetaEditor and compile it. Resolve every compiler error or
   warning before continuing.
3. In MetaTrader 5, refresh **Navigator > Expert Advisors**, then drag **Base**
   onto a chart. An invalid input is reported in the Experts tab with the
   input's name and valid range.
4. Leave the default timeframes for the intended H1 structure / M15 setup /
   M5 confirmation workflow, or deliberately select alternatives.
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

## Reading the structure

Base prints every structure event from closed candles only. A wick beyond a
swing is a liquidity sweep, never a break; a candle must close beyond it. The
label of the swing that is broken decides the event.

- **Swings.** Two filters decide what counts as a swing:
  - **Swing strength:** a swing high must be at least as high as that many
    candles on its left and strictly higher than as many on its right. It is
    also how many candles it takes to confirm the swing. Equal highs (a
    double top) form one swing at the latest of the equal candles.
  - **Swing size:** a new swing must travel at least that many ATR from the
    previous opposite swing. A smaller bounce is a pullback inside the
    current leg, not a swing. A swing beyond the previous high or low (an
    HH or LL) always counts, because it takes out a structure level.

  Swing lows mirror this. Swings alternate high, low, high, low: several
  highs confirmed before the next low are one leg, and only its highest high
  is kept (likewise the lowest low).
- **Swing Sensitivity (0-100), one per timeframe.** Base keeps two sets of
  these filters.

  | Set | Strength | Size | Finds |
  |---|---|---|---|
  | Sensitive | 2 candles | 1.0 ATR | quick, detailed swings |
  | Smooth | 4 candles | 3.0 ATR | only major swings |

  `HTF_Swing_Sensitivity`, `MTF_Swing_Sensitivity` and
  `LTF_Swing_Sensitivity` (default 50 each) blend the two sets for their
  timeframe. The chart's own labels use the sensitivity of the timeframe the
  chart is on, or the HTF sensitivity on any other chart period.

  | Value | Strength | Size | Meaning |
  |---|---|---|---|
  | 0 | 4 | 3.0 ATR | the Smooth set |
  | 25 | 4 | 2.5 ATR | |
  | **50 (default)** | **3** | **2.0 ATR** | **Balanced: the exact average of both sets** |
  | 75 | 3 | 1.5 ATR | |
  | 100 | 2 | 1.0 ATR | the Sensitive set |

  Lower it for a cleaner chart with fewer, bigger swings; raise it for more
  detail and faster swings. On 40 synthetic markets, Balanced finds about as
  many swings as the previous fixed 5-candle setting. Its swings confirm 2
  candles sooner and it kept every major market swing. 70% of its CHoCHs were
  followed by a BOS in their direction, against 61% before.
- **HH / LH / LL / HL.** Each swing is compared with the extreme of the
  previous leg on its side: a higher high is HH, otherwise LH; a lower low is
  LL, otherwise HL. Every accepted swing inside the displayed window is
  labelled; the first high and first low of the replay have nothing to compare
  with, which is why the replay starts well before the displayed window (see
  `Bars_To_Process`).
- **Identified swings.** Only an identified and marked swing can be broken.
  A swing is identified once the opposite leg after it has begun, for
  example an LL once the next swing high is confirmed.
  - Until then, a more extreme pivot in the same leg can still replace the
    swing and remove its label.
  - A close through a swing that is not yet identified breaks nothing. The
    last identified swing stays the level to break.
  - Every BOS and CHoCH line therefore starts at a labelled swing of the
    right kind: HH for a bullish BOS, LL for a bearish BOS, LH for a bullish
    CHoCH and HL for a bearish CHoCH.
  - A break is drawn only when its swing is inside the drawn window, so
    that swing's label is on the chart too.
- **BOS (bullish):** the most recent identified HH is broken, creating a new
  HH. **BOS (bearish):** the most recent identified LL is broken, creating a
  new LL.
- **CHoCH (becoming bullish):** while the trend is not already bullish, the
  most recent identified LH is broken, subsequently forming an HH.
  **CHoCH (becoming bearish):** while the trend is not already bearish, the
  most recent identified HL is broken, subsequently forming an LL. No HL
  (LH) is needed.
  - The CHoCH is drawn on the candle that closed through the LH/HL. The trend
    and the alert change when it is confirmed, which happens when the HH (LL)
    swing is confirmed.
  - A wick may make the HH (LL) before a candle closes through the LH (HL).
    If no LL (HH) has formed since, the CHoCH is confirmed by that close; a
    close that is also beyond the HH (LL) prints the BOS on the same candle.
  - No CHoCH is printed in these cases:
    - the swing high made by the break is an LH (bullish), or the swing low
      is an HL (bearish);
    - an LL forms before the HH (an HH before the LL);
    - a BOS in the old direction happens before the HH (LL) is confirmed.

    A swing printed before the breaking close never cancels it.
- **Pullbacks inside a trend.** A broken LH while the trend is already bullish
  (or a broken HL while it is bearish) prints nothing.
- **Trend.** Bullish after a bullish BOS: the market is breaking HH
  structure to create new HHs. Bullish Transition after a bullish CHoCH,
  until the next bullish BOS. Bearish and Bearish Transition mirror this.
  Because the label decides the event, an HH broken while the trend is bearish
  (or an LL broken while it is bullish) is a BOS and turns the trend straight
  round. This happens when no LH (HL) formed after the last event. For
  example: an LH broken, then an HH (CHoCH,
  Bullish Transition), then a close below the LL before that HH is "LL
  broken, creating a new LL". That is a BOS, and the trend returns to Bearish.

- **Consolidation / Undefined.** The trend is Consolidation / Undefined, with
  no direction, when either condition holds:
  1. **Sporadic 5-label sequence.** Look at the BOS/CHoCH breaks since the
     oldest of the last 5 HH/HL/LH/LL labels. It applies when they flip
     direction at least twice, for example bullish, bearish, bullish. A
     single flip is an ordinary change of character and is shown as a
     Transition.
  2. **Multiple CHoCHs without BoS (the CHoCH trap).** Two or more CHoCHs
     have printed since the last BoS that confirmed its direction, and the
     latest is within 4 ATR of an earlier one (the same price area). A BoS
     that confirms the latest CHoCH ends the trap.

  It also applies before the first structure break of the replay.

## Reading the dashboard

The dashboard has no background and no border. Component names are black,
and the main components are bold. Only the outputs are coloured:

| Output | Green | Red | Grey |
|---|---|---|---|
| Market Trend | Bullish, Bullish Transition | Bearish, Bearish Transition | Consolidation / Undefined |
| Market Tradeability | Tradable | Not Tradable | |
| Optimal Conditions and each condition | OPTIMAL, PASS | NOT OPTIMAL, BLOCKED | |

The black text is made for a light chart background.

- **HTF / MTF / LTF Market Trend.** One row for each timeframe selected in
  **Trend Analysis Timeframes**. Each shows Bullish, Bearish, Bullish
  Transition, Bearish Transition, or Consolidation / Undefined. Hover a row
  for its breakdown:
  - **Current Trend Classification:** the trend shown in the row.
  - **Trigger Condition Met:** Sporadic 5-label sequence, Multiple CHoCHs
    without BoS, or clear trending structure.
  - **Structural Evidence:** the last 5 labels, plus the alternating breaks or
    the CHoCHs of the trap. For a clear structure, the latest break.
  - **Trade Recommendations:** that timeframe's recommendation (see below).

  Each trend is replayed independently with its own Swing Sensitivity, and
  new swings that break nothing never change it.
- **Market Tradeability.** Tradable always requires an established Bullish or
  Bearish HTF trend (latest break a BOS, not Consolidation / Undefined).
  - Every timeframe selected in **Trend Analysis Timeframes** must have a
    direction (a Consolidation / Undefined trend has none), and they must
    agree.
  - The MTF may be transitional, but a selected LTF must itself be
    established.
  - It is an analytical state, not an instruction to place a trade.
  - Hover it to see the entry filters (MA, HTF MA, session, ADX, ATR) for the
    latest closed structure candle: whether a long or short BOS/CHoCH setup
    would pass, and each filter's reading.
- **Tradeability Reason.** Which timeframes correlate, or the first failed
  rule.
- **Trade Recommendations.** For the HTF trend:
  - Consolidation / Undefined: stay on the sidelines, or trade only the range
    boundaries (the extremes of the last 5 labels), until a valid BoS. It
    gives the HH/LL closes that would be one.
  - Transition: wait for the BoS that confirms it.
  - Trend: trade with it, and watch the level whose break would start a
    CHoCH.
- **Optimal Conditions.** OPTIMAL when every requirement enabled in the
  **Optimal Conditions** input group passes. Below it, each enabled
  requirement shows PASS or BLOCKED; hover any of these rows for the reason.
  - By default it checks timeframe correlation (the Tradable rules above) and
    relative tick volume.
  - Healthy Extension measures from the latest LTF HL (in a bullish HTF
    trend) or LH (in a bearish one) to the latest LTF close, and passes from
    0 to 3 LTF ATR.
  - Price Momentum compares the latest LTF true range with its 20-candle
    average (0.5x to 2x).
- BOS/CHoCH alerts describe confirmed structure events on the latest closed
  structure candle and are intentionally independent of the qualification
  filters. A CHoCH confirmed by a second break alerts as
  `CHoCH bullish + BOS bullish` (or bearish).

## Configuration notes

- `Bars_To_Process` is the number of Structure_Timeframe candles drawn. Each
  replay runs over three times that many closed candles so the trend, its
  break levels and the first labels are settled before the first drawn
  candle. The MTF and LTF trends, and the labels on any other chart period,
  cover the same elapsed time (100 H1 candles become 400 M15 candles). Start
  with the default 100 and raise it only when more context is needed.
- The structure, setup, and LTF inputs are all monitored for new bars, so custom
  timeframe orders still refresh correctly.
- **Trend Analysis Timeframes:** `Use HTF`, `Use MTF` and `Use LTF`
  independently choose which Market Trends are shown and must correlate for
  Market Tradeability.
  - At least one must remain enabled. This supports HTF-only, HTF/MTF,
    all-three, and other combinations.
  - The established HTF trend prerequisite always applies, even when the HTF
    row is hidden.
- The four `Use_*_For_Optimal` inputs independently choose which requirements
  determine the Optimal Conditions result. At least one must remain enabled;
  disabled requirements are omitted from both the result and the dashboard.
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

## Base for TradingView (`Base.pine`)

`Base.pine` is a Pine Script v6 indicator with the same functionality as
`Base.mq5`. It uses the same structure engine: the two swing filter sets and
per-timeframe Swing Sensitivity blend, HH/HL/LH/LL labels, close-only
BOS/CHoCH, trend, Consolidation / Undefined, and the same dashboard (Market
Trends with their breakdowns, Market Tradeability with the entry-filter
tooltip, the trade recommendation, and Optimal Conditions). It has the same inputs,
groups and defaults, except for the session and alert inputs described below.
Like the EA, it only analyses the chart and never places orders.

To install it, open the **Pine Editor** in TradingView, paste the contents of
`Base.pine`, save the script, and click **Add to chart**.

The engine was checked bar by bar against the EA's engine on generated data.
The check covered Swing Sensitivity 0, 25, 50, 75 and 100, and both forex and
gold price scales. The labels, BOS/CHoCH events, trend, Consolidation / Undefined
flags and break levels were identical.

Differences from the EA:

- **History.** Structure is replayed over all loaded history, not over three
  times `Bars To Process`. `Bars To Process` only limits how far back labels
  are drawn.
- **Timeframes.** Each timeframe is read with `request.security` from its
  latest closed candle, so nothing repaints. Use a chart timeframe at or below
  the lowest of the three structure timeframes. If the chart is higher, the
  dashboard shows a note.
- **Sessions.** The session presets use named time zones, so daylight saving
  time is handled:
  - New York `America/New_York`
  - London `Europe/London`
  - Tokyo `Asia/Tokyo`
  - Sydney `Australia/Sydney`

  A custom session uses `Custom Session Timezone` (for example `UTC`, `GMT+2`
  or `America/New_York`), which replaces the EA's offset inputs.
- **Dashboard.** The dashboard is a two-column table with the same styling.
  `Dashboard Position` chooses its corner.
- **Alerts.**
  - One input replaces the EA's popup and push inputs. Enable
    `Alert On Structure-Timeframe BOS / CHoCH`, then create an alert with
    **Any alert() function call**. The message matches the EA, for example
    `EURUSD H4 CHoCH bullish + BOS bullish`.
  - There are also four alert conditions: bullish and bearish BOS, and bullish
    and bearish CHoCH.
- **Indicators.**
  - ADX is TradingView's Wilder ADX (`ta.dmi`), so its values can differ
    slightly from MT5's `iADX`.
  - Market Volume uses the symbol's volume, which is tick volume on most forex
    feeds.
  - The HTF MA filter reads the latest closed candle of its timeframe.
