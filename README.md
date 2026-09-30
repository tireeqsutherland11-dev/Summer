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
- The dashboard's Market Tradability is **Tradable**.
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
reports multi-timeframe tradability and market conditions. It also marks
equal highs and lows (EQH/EQL), Strong/Weak High/Low, and a finer Internal
Structure with its own BOS/CHoCH. It never places, modifies, or closes
trades.

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

- **Swings.** A swing high is a pivot of the timeframe's Swing Detection
  Length (default 10): at least as high as that many candles on its left
  and strictly higher than as many on its right. It is also how many candles
  it takes to confirm the swing. Equal highs (a double top) form one swing at
  the latest of the equal candles. Swing lows mirror this. Swings alternate
  high, low, high, low: several highs confirmed before the next low are one
  leg, and only its highest high is kept (likewise the lowest low). This is
  the swing detection of WillyAlgoTrader's Smart Money Engine (SME).
- **Swing Detection Length (2-50), one per timeframe.**
  `HTF_Swing_Length`, `MTF_Swing_Length` and `LTF_Swing_Length` (default 10
  each) set the swing size of each timeframe. The chart's own labels use the
  length of the timeframe the chart is on, or the HTF length on any other
  chart period. Lower it for more, faster swings; raise it for fewer, cleaner
  ones. It replaces the Swing Sensitivity (0-100) of v2.37 and earlier,
  which blended a 2-4 candle strength with a 1-3 ATR size filter; at length
  10 a size filter removes almost nothing, so there is none.

  On real market data (EURUSD H1, an index on M1 and M5, the S&P 500 on M1,
  and six stocks on D1; about 60,000 candles), length 10 compared with the
  old default (Swing Sensitivity 50) as follows:

  | | Sensitivity 50 (v2.37) | Length 10 (v2.38) |
  |---|---|---|
  | BOS/CHoCH/LS per 1,000 candles | 36.9 | 19.3 |
  | BOS follow-through (1 ATR before a close back) | 71.3% | 77.7% |
  | CHoCH follow-through | 70.7% | 73.3% |
  | CHoCH followed by a BOS in its direction | 74.6% | 72.3% |
  | Trend flips per 1,000 candles | 16.6 | 9.1 |

  So about half as many breaks, each more reliable, and half as many trend
  flips. The trade-off is that each swing confirms 10 candles after its
  pivot instead of 3, so trend changes are recognised later (see
  `Roadmap.txt`). Length 5 is close to the old default in count and speed.
- **HH / LH / LL / HL.** Each swing is compared with the extreme of the
  previous leg on its side: a higher high is HH, otherwise LH; a lower low is
  LL, otherwise HL. Every accepted swing inside the displayed window is
  labelled; the first high and first low of the replay have nothing to compare
  with, which is why the replay starts well before the displayed window (see
  `Bars_To_Process`).
- **EQH / EQL (equal highs and lows).** A swing within
  `Equal_Highs_Lows_Threshold` ATR (default 0.1) of that previous swing is an
  equal high or low. The two swings form one liquidity pool, so it is not
  called higher or lower by a hair:
  - It is labelled **EQH** (**EQL**), with a dotted line to the swing it
    equals.
  - It keeps that swing's role (HH, LH, LL or HL), and the pool's outer edge
    is the level a close must break. For example, equal lows under a bullish
    trend act as the HL, so a close below them is a bearish CHoCH, not a BOS
    that flips the trend.
  - It neither confirms nor cancels a CHoCH, because it did not go beyond the
    swing it equals. A pending CHoCH waits for the next real HH (LL), and a
    close that pokes through an LH by a hair then stalls at an equal high
    is not yet a CHoCH.
  - The threshold is measured with the 14-candle ATR of the swing candle; 0
    turns EQH/EQL off.
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
  - The CHoCH line ends no later than the candle that closed through the
    LH/HL (see **Captions and lines**). The trend and the alert change when
    it is confirmed, which happens when the HH (LL) swing is confirmed.
  - A wick may make the HH (LL) before a candle closes through the LH (HL).
    If no LL (HH) has formed since, the CHoCH is confirmed by that close; a
    close that is also beyond the HH (LL) prints the BOS on the same candle.
  - No CHoCH is printed in these cases:
    - the swing high made by the break is an LH (bullish), or the swing low
      is an HL (bearish);
    - an LL forms before the HH (an HH before the LL);
    - a BOS in the old direction happens before the HH (LL) is confirmed.

    A swing printed before the breaking close never cancels it.
- **LS (liquidity sweep): a CHoCH that failed.** A CHoCH that reversed a
  trend becomes an LS when the old trend carries on instead. For a bullish
  CHoCH (bearish mirrors it):
  - **Protected low:** the swing low the breaking rally started from (the
    last low before the HH that confirmed the CHoCH).
  - **Old LL:** the most recent identified LL before the CHoCH. It is the
    protected low itself when that low is an LL.
  - **Trigger:** a candle closes below the protected low.
  - **Confirmation:** the old trend carries on below the old LL, by a close
    (which is also a bearish BOS) or by a swing low. This must happen while
    the CHoCH is still the latest event.
  - **The CHoCH stands** when a bullish BOS or a bearish CHoCH prints first.
    If the low after the trigger holds above the old LL, it is an ordinary
    bearish CHoCH (chop), not an LS.

  When it is confirmed, the CHoCH label and line become **LS** in deep yellow,
  in the same place, and the trend returns to what it was before the CHoCH
  (usually Bearish), as if the CHoCH had never printed. The break of the
  protected low is then a pullback inside that trend, so no bearish CHoCH
  prints for it.
- **Captions and lines.** A BOS, CHoCH or LS line runs from the broken swing
  to the first later candle whose wick or body touches its level, so it
  never clips through a candle. That is the candle that closed through the
  level, unless an earlier wick already swept it; then the line stops at
  that wick. The caption is centred on the line, on the candle midway
  between its two ends: above a line broken upwards, below one broken
  downwards. The lines are solid and 2 pixels wide by default
  (`Line_Style`, `Line_Width`), as in SME, so they stand out from the
  dashed, thinner Internal Structure.
- **Pullbacks inside a trend.** A broken LH while the trend is already bullish
  (or a broken HL while it is bearish) prints nothing.
- **Trend.** Bullish after a bullish BOS: the market is breaking HH
  structure to create new HHs. Bullish Transition after a bullish CHoCH,
  until the next bullish BOS, or until the CHoCH fails as an LS, which
  restores the previous trend. Bearish and Bearish Transition mirror this.
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

  It also applies before the first structure break of the replay. An LS is
  not a break: it counts in neither condition.

## Strong / Weak High / Low

From SME. Each break protects the latest swing on the other side of the
trend:

- A bullish break (a bullish BOS, a confirmed bullish CHoCH, or an LS that
  restores a bullish trend) makes the latest swing low the **Strong Low**: it
  holds the trend. While the trend is bullish, the highest high since then is
  the **Weak High**: the next target.
- A bearish break mirrors this: **Strong High** and **Weak Low**.
- Both are drawn as dashed lines that extend 20 candles right of the latest
  candle, where their names sit, and are listed in each Market Trend's
  breakdown (`Show_Strong_Weak_High_Low` hides the lines).

## Internal Structure

Also from SME: minor structure inside the swings, from shorter pivots of the
timeframe's Internal Structure Length (`HTF_Internal_Length`,
`MTF_Internal_Length`, `LTF_Internal_Length`, 2-50, default 5). It shows
what price is doing between the swings. It never changes the Market Trend
or alerts; its only effect on the rest of the dashboard is Tradable (Early),
which requires the internal structure to agree (see Reading the dashboard).

- Each internal pivot high (low) becomes the internal high (low) level.
- The first close above the internal high is an internal bullish BOS, or an
  internal bullish CHoCH when the internal trend was bearish; bearish mirrors
  this. Each level is broken once, and the break sets the internal trend.
- On the chart its breaks are dashed 1-pixel lines with faded captions
  (`Internal_Bullish_Color`, `Internal_Bearish_Color`). Like the main ones,
  each line ends on the first candle that touches its level and its caption
  is centred on it. Where the internal pivot is also a swing of the main structure,
  only the main structure draws that level, so the chart does not double up.
- Keep it shorter than the Swing Detection Length. At or above it, almost
  every internal pivot is also a main swing, so almost nothing is drawn.
- `Show_Internal_Structure` hides the chart drawings and
  `Show_Internal_On_Dashboard` its dashboard rows.

## Reading the dashboard

The dashboard has no background and no border. Every component name is black
and bold, for example **Market Trend (H4):**. Only the outputs are coloured:

| Output | Green | Red | Grey | Amber |
|---|---|---|---|---|
| Market Trend | Bullish, Bullish Transition | Bearish, Bearish Transition | Consolidation / Undefined | |
| Internal Structure | Bullish | Bearish | Undefined | |
| Market Tradability | Tradable | Not Tradable | | Tradable (Early) |
| Optimal Conditions and each condition | OPTIMAL, PASS | NOT OPTIMAL, BLOCKED | | EARLY |

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
  - **Strong/Weak:** that timeframe's Strong/Weak High/Low, for example
    `Weak High 1.09800 | Strong Low 1.07900`.
  - **Trade Recommendations:** that timeframe's recommendation (see below).

  Each trend is replayed independently with its own Swing Detection Length,
  and new swings that break nothing never change it.
- **Internal Structure.** Below each Market Trend, indented, that
  timeframe's internal trend with its latest internal break, for example
  `Bullish (CHoCH)`, or Undefined before the first break (green, red or
  grey). Hover it for:
  - the break that set it, for example `Internal trend: Bullish since a
    bullish CHoCH through 1.08500`;
  - how it relates to the Market Trend: `Agrees with the H4 Market Trend.`,
    or `Opposes the H4 Market Trend: a bearish move inside the bullish trend
    (a pullback until the swing structure breaks).`

  `Show_Internal_On_Dashboard` hides these rows.
- **Market Tradability.** Tradable, Tradable (Early) or Not Tradable. It is
  an analytical state, not an instruction to place a trade.
  - **Tradable** always requires an established Bullish or Bearish HTF trend
    (latest break a BOS, not Consolidation / Undefined). Every timeframe
    selected in **Trend Analysis Timeframes** must have a direction (a
    Consolidation / Undefined trend has none), and they must agree. The MTF
    may be transitional, but a selected LTF must itself be established.
  - **Tradable (Early)**, in amber: the same, except that the HTF (or a
    selected LTF) is only in transition (a CHoCH not yet confirmed by a
    BOS). The HTF must agree with every selected timeframe, and the internal
    structure of the HTF and of every selected timeframe must agree with
    that direction. For example, H4 and H1 both Bearish Transition with
    both internal structures bearish. `Allow_Early_Tradability` (on by
    default) turns it off. It works even when `Show_Internal_On_Dashboard`
    hides the Internal Structure rows.
  - Why a separate state: internal agreement made a transition much more
    likely to reach its confirming BOS, but it still failed about a third
    of the time (see below).
  - Hover it to see the entry filters (HTF MA, MTF MA, session, ADX, ATR)
    for the latest closed structure candle: whether a long or short
    BOS/CHoCH setup would pass, and each filter's reading.
- **Tradability Reason.** One sentence that names the timeframes. It says
  why the market is tradable, or gives the first rule that fails:
  - `H4 and H1 are both bullish, and the H4 trend is confirmed by a BOS.`
  - `H4 is bullish but H1 is bearish.`
  - `H4 and H1 are both bearish and their internal structure agrees, but the
    H4 trend is only a transition (a CHoCH not yet confirmed by a BOS).`
    (Tradable (Early))
  - `H4 is only in a bullish transition (a CHoCH not yet confirmed by a BOS).`
  - `H4 is only in a bearish transition (a CHoCH not yet confirmed by a BOS),
    and the H1 internal structure is not bearish yet.` (it would be Tradable
    (Early) once the H1 internal structure turns bearish)
  - `H1 is ranging (repeated CHoCHs in one area with no BOS).`
  - `H4 has no structure break yet.`
- **Trade Recommendations.** One action for the HTF trend, with the price that
  decides it:
  - Bullish: `Look for buys on pullbacks while price holds above HL 1.08450.`
    A close below that HL would start a bearish CHoCH.
  - Bullish Transition: `Wait for a close above HH 1.09120 (bullish BOS)
    before buying.`
  - Consolidation / Undefined: `Stand aside or trade only the range edges
    (1.08010 to 1.09350); a close above HH 1.09350 or below LL 1.08010 starts
    a new trend.` The range edges are the extremes of the last 5 labels.
  - No break yet: `Stand aside until a BOS sets the trend.`
  - Bearish mirrors Bullish.

  When the HTF trend is established but a selected lower timeframe holds
  Tradable back, it names that timeframe instead, for example `H4 is bullish,
  but wait for H1 to turn bullish before buying.` When the market is
  Tradable (Early), it gives the early entry and what confirms it, for
  example `Early sells only, while price holds below LH 1.10500; a close
  below LL 1.09500 (bearish BOS) confirms the trend.`
- **Optimal Conditions.** OPTIMAL when every requirement enabled in the
  **Optimal Conditions** input group passes. Below it, each enabled
  requirement shows PASS or BLOCKED; hover any of these rows for the reason.
  - By default it checks timeframe correlation (the Tradable rules above) and
    relative tick volume. Tradable (Early) shows EARLY (amber) on the
    Timeframe Correlation row and does not pass it, unless
    `Early_Passes_Timeframe_Correlation` is on (then PASS (Early)).
  - Healthy Extension measures from the latest LTF HL (in a bullish HTF
    trend) or LH (in a bearish one) to the latest LTF close, and passes from
    0 to 3 LTF ATR.
  - Price Momentum compares the latest LTF true range with its 20-candle
    average (0.5x to 2x).
- BOS/CHoCH/LS alerts describe confirmed structure events on the latest
  closed structure candle and are intentionally independent of the
  qualification filters.
  - A CHoCH confirmed by a second break alerts as `CHoCH bullish + BOS bullish`
    (or bearish).
  - An LS alerts as `LS (bullish CHoCH failed)`, or together with the old
    trend's BOS as `LS (bullish CHoCH failed) + BOS bearish` (or the mirror).

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
  Market Tradability.
  - At least one must remain enabled. This supports HTF-only, HTF/MTF,
    all-three, and other combinations.
  - The established HTF trend prerequisite always applies, even when the HTF
    row is hidden. Tradable (Early) also always uses the HTF and its internal
    structure.
- **Tradable (Early).** `Allow_Early_Tradability` (default on) shows it;
  `Early_Passes_Timeframe_Correlation` (default off) lets it pass Optimal
  Conditions' Timeframe Correlation.

  How it was tested: Base's engine and internal structure (defaults: Swing
  Detection Length 10, Internal Structure Length 5) ran on HTF/MTF pairs
  built from real data (EURUSD H4/H1, an index M15/M5, five stocks W1/D1)
  and 60 generated H4/H1 markets. Each HTF transition with the MTF agreeing
  was followed until it reached its confirming BOS (success) or failed (an
  LS or an opposite break), counting each transition once:

  | | Internals agree (Tradable (Early)) | Internals do not both agree |
  |---|---|---|
  | Generated markets | 70% of 302 reached the BOS | 50% of 378 |
  | Real data | 58% of 36 | 44% of 34 |

  Other lengths gave the same picture (generated: 66-70% against 44-50%;
  real: +17 points at length 5, +4 at length 15). On the generated markets
  the gap is well beyond chance; on the real data the sample is small and it
  is not. Candle by candle on single timeframes of real data, the agreement
  was sharper still: 48% against 21% reached the BOS. After Tradable (Early)
  candles, price moved on in the trend's direction on the generated markets
  (+0.8 ATR after 20 candles) but not on the real data, where moves were no
  better than chance. So Tradable (Early) marks the stronger transitions,
  not confirmed trends.
- The four `Use_*_For_Optimal` inputs independently choose which requirements
  determine the Optimal Conditions result. At least one must remain enabled;
  disabled requirements are omitted from both the result and the dashboard.
- Preset session UTC offsets are fixed and do not adjust for daylight-saving
  time. Set the broker server offset correctly and use a custom session where
  seasonal handling matters.
- A custom session must use exactly `HHMM-HHMM` with numeric digits. Equal start
  and end means all day; ranges such as `2200-0600` cross midnight.
- ATR thresholds use raw symbol price units, not points or pips.
- **EQH/EQL.** `Equal_Highs_Lows_Threshold` (0 to 0.5 ATR, default 0.1; 0
  turns it off) decides which swings are equal. `Show_Equal_Highs_Lows` only
  changes the labels and dotted lines; with it off, equal swings show their
  role (HH/LH/LL/HL) but still act as one pool. On real EURUSD H1 and daily
  stock data about 3.5% of swings were equal, and BOS/CHoCH follow-through,
  CHoCH-to-BOS confirmation and the LS rate stayed within noise of the
  version without EQH/EQL (see `Roadmap.txt`).
- **Swing Detection and Internal Structure.** Each timeframe has its own
  Swing Detection Length (default 10) and Internal Structure Length (default
  5), both 2 to 50. The Real Time Swing Structure (LuxAlgo) of v2.36-v2.37
  was removed: SME's Strong/Weak High/Low and Internal Structure replace it.
- **MA filters.** `MA Filter (HTF)` compares the latest closed HTF candle
  with an MA of the HTF (default EMA 50). `MA Filter (MTF)` compares the latest
  closed MTF candle with an MA of the MTF (default EMA 100). Each can draw its
  line on the chart. They only qualify setups in the Market Tradability
  tooltip and never change structure, trend or alerts.

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
`Base.mq5`. It uses the same structure engine: per-timeframe Swing Detection
Length, HH/HL/LH/LL and EQH/EQL labels, close-only BOS/CHoCH/LS with centred
captions, trend, Consolidation / Undefined, Strong/Weak High/Low, the
Internal Structure with its dashed BOS/CHoCH, and the same dashboard (Market
Trends with their breakdowns and Internal Structure, Market Tradability with
the entry-filter tooltip, the trade recommendation, and Optimal Conditions). It has the same inputs,
groups and defaults, except for the session and alert inputs described below.
Every input has an info icon in the settings dialog whose tooltip says what
it does, as in the Smart Money Engine. Like the EA, it only analyses the
chart and never places orders.

To install it, open the **Pine Editor** in TradingView, paste the contents of
`Base.pine`, save the script, and click **Add to chart**.

The engine was checked bar by bar against the EA's engine on 30 generated
markets. The check covered Swing Detection Lengths 2, 3, 5, 10, 15 and 20,
Internal Structure Lengths 2, 3, 5, 8 and 15, and both forex and gold price
scales. The labels (including EQH/EQL), BOS/CHoCH/LS events, trend,
Consolidation / Undefined flags, break levels, Strong/Weak High/Low, the
internal trend, where every BOS/CHoCH/LS line ends, and the drawn internal
BOS/CHoCH (including where each line ends and which are left to the main
structure) were identical. The EA searches the candles for each line's end;
the Pine engine records each level's first touch as candles close, since
Pine cannot look back an unlimited number of candles. Both give the same
ends.

Differences from the EA:

- **History.** Structure and the Internal Structure are replayed over all
  loaded history, not over three times `Bars To Process`. `Bars To Process`
  only limits how far back labels are drawn.
- **Internal captions.** They are faded with 30% transparency; the EA blends
  them 30% towards the chart background, which looks the same.
- **Timeframes.** Each timeframe is read with `request.security` from its
  latest closed candle, so nothing repaints. Use a chart timeframe at or below
  the lowest of the three structure timeframes.
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
    `Alert On Structure-Timeframe BOS / CHoCH / LS`, then create an alert with
    **Any alert() function call**. The message matches the EA, for example
    `EURUSD H4 CHoCH bullish + BOS bullish`.
  - There are also six alert conditions: bullish and bearish BOS, bullish and
    bearish CHoCH, and LS of a bullish or bearish CHoCH.
- **Indicators.**
  - ADX is TradingView's Wilder ADX (`ta.dmi`), so its values can differ
    slightly from MT5's `iADX`.
  - Market Volume uses the symbol's volume, which is tick volume on most forex
    feeds.
  - The HTF and MTF MA filters each read the latest closed candle of their
    timeframe.
