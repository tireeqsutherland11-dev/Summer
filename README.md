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

- **Swings.** A swing high is a pivot of N candles on each side (set by the
  timeframe's Swing Detection Length, below): at least as high as the N
  candles on its left and strictly higher than the N on its right. It is
  also how many candles it takes to confirm the swing. Equal highs (a double
  top) form one swing at the latest of the equal candles. Swing lows mirror
  this. Swings alternate high, low, high, low: several highs confirmed
  before the next low are one leg, and only its highest high is kept
  (likewise the lowest low). A candle that is both a swing high and a swing
  low (an outside candle, about 4% of swing candles at level 1) is taken in
  the order its price most likely went: a bullish candle made its low
  first, a bearish or flat one its high first. This is the swing detection
  of WillyAlgoTrader's Smart Money Engine (SME).
- **Swing Detection Length (1-10), one per timeframe.**
  `HTF_Swing_Level`, `MTF_Swing_Level` and `LTF_Swing_Level` (defaults 3, 5
  and 7: 3, 7 and 14 candles) set the swing size of each timeframe on a 1-10 scale, 1 finest and
  10 broadest. The chart's own labels use the level of the timeframe the
  chart is on, or the HTF level on any other chart period.

  The scale is not N itself. Swings found with N candles are mostly the
  same swings found with N+1, so with N as the input one step at 10 changed
  only 11% of the drawn labels, and nothing much seemed to happen until a
  jump such as 10 to 5 (half the labels). Each level is the N that changes
  about a third of the drawn labels from the level before. Measured on real
  data (EURUSD H1, an index on M1 and M5, the S&P 500 on M1, six stocks on
  D1; about 60,000 candles):

  | Level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
  |---|---|---|---|---|---|---|---|---|---|---|
  | Candles each side (N) | 1 | 2 | 3 | 5 | 7 | 10 | 14 | 19 | 26 | 36 |
  | Swing labels per 1,000 candles | 317 | 195 | 144 | 93 | 70 | 50 | 36 | 27 | 20 | 15 |
  | Labels changed from the level before | | 42% | 29% | 38% | 28% | 30% | 30% | 27% | 27% | 30% |
  | BOS/CHoCH/LS per 1,000 candles | 99 | 68 | 52 | 35 | 27 | 19 | 14 | 11 | 8 | 6 |

  Generated markets gave the same picture (23-43% per step), and on the
  EA's own H4 chart every step changed 27-56% of the drawn labels. A swing
  confirms N candles after its pivot, so higher levels also react later.
  The defaults are HTF 3 (3 candles), MTF 5 (7 candles) and LTF 7 (14
  candles).

  Swing detection by length replaced the Swing Sensitivity (0-100) of v2.37
  and earlier, which blended a 2-4 candle strength with a 1-3 ATR size
  filter; at 10 candles a size filter removes almost nothing, so there is
  none. On the same real data, 10 candles compared with the old default
  (Swing Sensitivity 50) as follows:

  | | Sensitivity 50 (v2.37) | 10 candles (level 6) |
  |---|---|---|
  | BOS/CHoCH/LS per 1,000 candles | 36.9 | 19.3 |
  | BOS follow-through (1 ATR before a close back) | 71.3% | 77.7% |
  | CHoCH follow-through | 70.7% | 73.3% |
  | CHoCH followed by a BOS in its direction | 74.6% | 72.3% |
  | Trend flips per 1,000 candles | 16.6 | 9.1 |

  So about half as many breaks, each more reliable, and half as many trend
  flips. The trade-off is that each swing confirms 10 candles after its
  pivot instead of 3, so trend changes are recognised later (see
  `Roadmap.txt`). Level 4 (5 candles) is close to the old default in count
  and speed.
- **HH / LH / LL / HL.** Each swing is compared with the extreme of the
  previous leg on its side: a higher high is HH, otherwise LH; a lower low is
  LL, otherwise HL. Every accepted swing inside the displayed window is
  labelled; the first high and first low of the replay have nothing to compare
  with, which is why the replay starts well before the displayed window (see
  `Bars_To_Process`).
- **EQH / EQL (equal highs and lows).** A swing within
  `Equal_Highs_Lows_Threshold` ATR (default 0.2) of that previous swing is an
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
timeframe's Internal Structure Length (`HTF_Internal_Level`,
`MTF_Internal_Level`, `LTF_Internal_Level`, 1-10, default 4 = 5 candles; the
same scale as the Swing Detection Length, with internal breaks per 1,000
candles of 117, 79, 62, 42, 32, 24, 18, 13, 10 and 8 from level 1 to 10 on
the real data above). It shows
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
- Keep its level below the timeframe's Swing Detection Length to see
  internal breaks on the chart. At or above it, almost every internal pivot
  is also a main swing, so almost nothing is drawn. With the defaults the
  HTF Internal Structure Length (4) is above the HTF Swing Detection Length
  (3), so an HTF chart shows almost no internal breaks, while its dashboard
  row and Tradable (Early) still use it; set the HTF Internal Structure
  Length to 2 or lower, or the HTF Swing Detection Length to 5 or higher,
  to see them. The MTF (5) and LTF (7) are above their internal level (4).
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
| Optimal Conditions and each condition | OPTIMAL, PASS | NOT OPTIMAL, BLOCKED | | |

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
  why the market is tradable, or gives the first rule that fails. Like the
  Trade Recommendations, it wraps onto further lines of at most 48
  characters so the dashboard stays narrow:
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
  - By default it checks timeframe correlation and relative tick volume.
    Timeframe Correlation passes whenever Market Tradability is Tradable or
    Tradable (Early): in both, every selected timeframe agrees on the
    direction.
  - Healthy Extension blocks only an overextended market: the latest LTF
    close more than 10 MTF ATR beyond the latest MTF swing low (in a bullish
    HTF trend) or swing high (in a bearish one). The row shows the distance,
    for example `PASS (4.2 H1 ATR)`. With no HTF direction or no MTF swing
    yet, or price back beyond that swing, it passes. See **Healthy
    Extension** below for how the limit was chosen.
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
- **Tradable (Early).** `Allow_Early_Tradability` (default on) shows it. It
  passes Optimal Conditions' Timeframe Correlation, like Tradable.

  How it was tested: Base's engine and internal structure (Swing Detection
  Length 10, Internal Structure Length 5) ran on HTF/MTF pairs
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
  not confirmed trends. With HTF swings of 2 candles and MTF swings of 9 the gap held:
  57% of 77 against 43% of 127 on real data (90% interval +3 to +26
  points), 56% against 41% on the generated markets.
- **Healthy Extension.** Until v2.40 it passed only from 0 to 3 LTF ATR
  above the latest LTF HL (below the latest LTF LH in a bearish trend). On
  real data (an index H1/M15/M5, EURUSD D1/H4/H1, five stocks MN/W1/D1) that
  blocked 83% of Tradable candles, mostly because the latest LTF swing was
  not an HL/LH or price was more than 3 LTF ATR away, and the blocked
  candles did no worse afterwards than the passed ones. The v2.41 measure,
  the distance beyond the latest MTF swing in MTF ATR, showed a real
  overextension effect:

  | Latest LTF close beyond the latest MTF swing | Tradable candles | 1 ATR pullback before a 1 ATR move on | Move after 50 LTF candles |
  |---|---|---|---|
  | up to 10 MTF ATR (passes) | 94% | 48% | +0.3 ATR |
  | more than 10 MTF ATR (blocked) | 6% | 56% | -0.9 ATR |
  | more than 12 MTF ATR | 2% | 64% | -2.2 ATR |

  Six of the seven real datasets showed the same, and it held with MTF swing
  lengths 5 and 14. The generated markets have no mean reversion (their
  most extended candles did best), so they could not set the limit.
- The four `Use_*_For_Optimal` inputs independently choose which requirements
  determine the Optimal Conditions result. At least one must remain enabled;
  disabled requirements are omitted from both the result and the dashboard.
- Preset session UTC offsets are fixed and do not adjust for daylight-saving
  time. Set the broker server offset correctly and use a custom session where
  seasonal handling matters.
- A custom session must use exactly `HHMM-HHMM` with numeric digits. Equal start
  and end means all day; ranges such as `2200-0600` cross midnight.
- ATR thresholds use raw symbol price units, not points or pips.
- **EQH/EQL.** `Equal_Highs_Lows_Threshold` (0 to 0.5 ATR, default 0.2; 0
  turns it off) decides which swings are equal. `Show_Equal_Highs_Lows` only
  changes the labels and dotted lines; with it off, equal swings show their
  role (HH/LH/LL/HL) but still act as one pool. On real EURUSD H1 and daily
  stock data at the earlier default of 0.1 about 3.5% of swings were equal, and BOS/CHoCH follow-through,
  CHoCH-to-BOS confirmation and the LS rate stayed within noise of the
  version without EQH/EQL (see `Roadmap.txt`).
- **Swing Detection and Internal Structure.** Each timeframe has its own
  Swing Detection Length (defaults HTF 3, MTF 5, LTF 7) and Internal
  Structure Length (default 4), both on the 1-10 scale above. Settings saved
  before v2.42 (2-50 candles) do not carry over: the inputs were renamed so
  that an old 9 is not read as level 9 (26 candles). The Real Time Swing Structure (LuxAlgo) of v2.36-v2.37
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

The engine was checked bar by bar against the EA's engine on 38 generated
markets. The check covered swings and internal swings of 1 to 36 candles
each side (levels 1 to 10), and both forex and gold price
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

## Fib Base for TradingView (`Fib Base.pine`)

`Fib Base.pine` is a Pine Script v6 indicator with the Fibonacci retracement
of the Smart Money Engine (v1.6.1): the grid, the OTE zone, the dashboard's
Fibonacci section and the OTE entry alerts. It is anchored on Base's
structure instead of the Smart Money Engine's own swings:

- **Leg.** The leg runs between Base's Strong/Weak High and Strong/Weak Low.
  The structure engine is copied unchanged from `Base.pine`, so with the same
  `Structure (match Base)` inputs (timeframes, Swing Detection Lengths and
  EQH/EQL Threshold) the grid spans the Strong/Weak lines Base draws. Only
  closed candles move the leg.
- **Levels.** Each ratio is measured along the leg from level 0. In
  `Auto (trend)` level 0 is the high in a bullish (or undefined) trend and
  the low in a bearish one, as in the Smart Money Engine; `Measure From` can
  fix it to the high or the low. `Fib Levels` has 12 rows, each with its own
  checkbox, ratio and color. The defaults are 0, 0.236, 0.382, 0.5, 0.618,
  0.786 and 1, plus 0.705, 0.886, 1.272, -0.272 and -0.618 switched off.
  Ratios above 1 lie beyond the other end of the leg; ratios below 0 extend
  past level 0, as targets.
- **Style.** `Fib Style` sets the line color (`Auto (theme)` is the Smart
  Money Engine's faded grey; `Single Color` or `Per Level` are the other
  options), line style and width, and the labels: text (ratio, price or
  both), size, side and color. `Fibonacci` sets the right offset and line
  extension.
- **OTE zone.** A box between `OTE From` and `OTE To` (0.618 and 0.786 by
  default), with its own fill, border color and border width.
- **Dashboard.** The Smart Money Engine's Fibonacci section: a trend-colored
  header, then Leg High, Leg Low and OTE (Inside, Outside or no leg). It sits
  at the bottom right by default, clear of Base's dashboard.
- **Alerts.** `OTE Entry Alerts` sends an alert() the first time a close is
  inside the OTE zone (create the alert with **Any alert() function call**).
  The alert can be plain text or webhook JSON, on the bar close or intrabar.
  The `OTE Zone Entry` alert condition always fires.

To install it, open the **Pine Editor** in TradingView, paste the contents of
`Fib Base.pine`, save the script, and click **Add to chart**. It can run
alongside Base or on its own.

## 83% Strategy (`83% Strategy.mq5` and `83% Strategy.pine`)

The 83% Strategy trades the 83% retracement of a heavy lower-timeframe
impulse in the direction of an established trend. It is built on Base: the
EA is `Base.mq5` (v2.43) with the strategy added, and the TradingView
strategy is `Base.pine` with the same addition. Both keep Base's structure
engine, labels and dashboard unchanged. Both use Fib Base's Fibonacci engine
(`fibLevelCalc`) for the levels.

### The rules

Buys (bullish market):

1. **Market filters.** The dashboard's Market Tradability reads **Tradable**
   (bullish) and the Optimal Conditions read **OPTIMAL**.
   `Allow_Tradable_Early_Entries` also accepts Tradable (Early); it is off by
   default.
2. **MTF trend.** The most recent MTF structure is a bullish BOS (the break of
   an HH that makes a new HH). It must not be a CHoCH or Consolidation /
   Undefined.
3. **LTF setup.** The LTF is M30 with LTF Swing Detection level 3 (3 candles
   each side) by default. The setup is searched within the last
   `LTF_Bars_To_Process` (the LTF Independent Processed Bars, 25) closed LTF
   candles.
   - **A** is the most recent HL from which there was heavy buying pressure.
   - **B** is the HH that move formed.
   - The Fibonacci runs from B (0%) back to A (100%).
4. **Entry.** Price touches the 83% level (`Entry_Level`, 0.83).
5. **Invalid.** If price makes a new HH (trades above B) before reaching 83%,
   the setup is dead and its HL is used up. A new setup needs a new HL.

Sells mirror this: an LH with heavy selling pressure, the LL it formed, a
sell at the 83% retracement, and invalidation on a new LL.

How the rules are made exact:

- **Heavy pressure.** Within `Impulse_Candles` (3) candles of A, counting A's
  own candle, a candle closes at least `Impulse_Min_ATR` (2.0) LTF ATR beyond
  A. The ATR is the 14-candle ATR at A. On real data (an index on M15 and
  M30, EURUSD H1 and five stocks D1), 2.0 selected the strongest 43% of
  HL-to-HH legs. Set it to 0 to accept every leg.
- **HL and HH labels.** A must be an HL (or an EQL with an HL's role). B must
  be a true HH, not an EQH.
- **When a setup becomes known.** A setup exists once B is a confirmed swing,
  3 candles after it. If price already reached 83% during those candles, the
  setup is **missed** and is not traded late.
- **The processed bars.** A must lie within the processed candles. A setup
  whose A leaves them **expires**. On the LTF chart, Base's structure is also
  drawn over just those candles.

### Risk management (all adjustable)

- **Trading days.** Monday to Saturday (`Trade_Monday` ... `Trade_Sunday`).
- **Trades per day.** At most `Max_Trades_Per_Day` (5) entries a day, with
  one position open at a time.
- **Risk per trade.** `Risk_Percent` (5%) of the balance is lost at the stop.
  - After every `Losses_Before_Risk_Cut` (2) consecutive losses within a day,
    the risk is multiplied by `Risk_Cut_Factor` (0.5): 5%, then 2.5% after two
    losses, then 1.25% after two more.
  - A win, or an exit at breakeven, ends a run of losses, but the risk stays
    cut until the day ends. It resets at the start of the next day.
  - The EA reads the day's trades and losses back from the deal history, so
    a restart keeps them.
- **Lot size.** Balance x risk % / the loss of one lot at the stop. This is
  the strategy's `(Balance x Risk %) / Stop Loss in points` rule, using MT5's
  tick value so it works on any symbol. TradingView uses
  `quantity = balance x risk % / (stop distance x point value)`.
- **Take profit.** `TP_Buffer_ATR` (0.1) LTF ATR before B, the HH (LL) of the
  Fibonacci's 0%.
- **Stop loss and reward-to-risk.**
  - A stop `SL_Buffer_ATR` (0.5) LTF ATR behind A gives the position's
    natural reward-to-risk.
  - The trade uses whichever of 1:2 and 1:3 (`Reward_Risk_Low`,
    `Reward_Risk_High`) is closer, and moves the stop to match while keeping
    the take profit. For example, 1:2.4 uses 1:2.
  - With 0.5 ATR, the natural ratio fell between 1:2.2 and 1:3.0 for 80% of
    the real-data setups, as the strategy describes. The adjusted stop is
    always behind A.
- **Breakeven.** The stop moves to the entry price once price has covered
  `Breakeven_At_Percent` (60%) of the way to the take profit.

### What you see on the LTF chart

On the LTF chart, each setup within the processed candles is drawn as in the
strategy's examples:

- **Fibonacci levels.** Fib Base's levels: 0% at B, 100% at A, and the entry
  level in orange.
  - Labels read `0.00%`, `83.00%` and `100.00%`. They can show ratios or
    prices instead.
  - Four optional levels (0.5, 0.618, 0.705, 0.886) can be switched on, and
    every level's ratio and colour can be changed.
- **Points.** A, B and C (the entry).
- **Position zones.** The target zone (blue, entry to take profit) and the
  stop zone (red, entry to stop loss), drawn from C.
  - An armed setup shows its planned zones from the latest candle.
  - Failed setups are drawn dotted with their reason: invalidated, expired,
    or missed.

The dashboard gains these rows under Base's own:

- **83% Strategy.** Waiting, a buy or sell setup armed, or a position open.
- **Setup.** A, B and the 83% price.
- **Entry Filters.** PASS, or BLOCKED with the reason.
- **Risk Today.** Trades taken out of the maximum, the current risk %, and
  losses in a row.
- **Last Setup.** What happened to the latest setup that reached its level:
  traded, or the reason it was not.

### MetaTrader 5

- **Installing and testing.** Install `83% Strategy.mq5` in `MQL5/Experts`,
  compile it in MetaEditor, and attach it to a chart. To backtest it, open
  the Strategy Tester (Ctrl+R) and select **83% Strategy**, the symbol and a
  date range. Use **Every tick** or **Every tick based on real ticks**
  modelling, since entries happen on the first tick at the level.
- **Viewing the trades.** Choose the M30 chart in visual mode to watch the
  setups. Non-visual runs and optimisation skip all drawing.
- **Trade Mode.** `Trade_Mode` is **Strategy Tester only** by default, so a
  chart running the EA for analysis never places orders. Choose **Strategy
  Tester and live charts** deliberately.
- **Entries.** The EA enters at the market on the first tick at which the
  chart price (bid) touches the level. It invalidates a setup on the first
  tick beyond B.
  - The take profit and stop of a sell include the spread, because they
    trigger on the ask.
  - Each untraded touch is written to the Journal once, with its reason.
- **Alerts.** `Enable_Popup_Alerts` and `Enable_Push_Notifications` also
  announce armed setups and entries.

### TradingView

- **Installing.** Paste `83% Strategy.pine` into the Pine Editor, save it,
  and add it to an M30 chart (the LTF). Setups, orders and drawings follow
  that chart; on any other chart the dashboard asks for the LTF chart.
- **Entries.** Entries are limit orders at the level, placed at a candle's
  close. A buy and a sell order cancel each other.
- **Differences from the EA:**
  - A limit order fills at the level, or better on a gap.
  - Breakeven is checked at candle closes.
  - Pine has no spread.
  - Days follow the exchange time zone.
  - A new MTF/HTF candle reaches the filters one LTF candle after it closes,
    because Base's `request.security` reads the latest closed candle.

### Deriv synthetic indices

Both versions are set up for Deriv's synthetic indices: Volatility (including
the 1s versions), Crash / Boom, Jump, Step, Range Break, DEX and Drift Switch.

- **Symbol Profile.** `Symbol_Profile` (`Symbol Profile` on TradingView) is
  Auto by default.
  - Auto recognises a synthetic index by its name, description or symbol
    path, or by Deriv's `R_` / `1HZ` codes and the `DERIV` prefix on
    TradingView.
  - You can also force **Deriv Synthetic Index** or **Standard symbol**.
  - The dashboard's new **Symbol** row shows which profile applies, and the
    EA writes it to the Journal at start.
- **Market Volume.** Synthetic indices tick at a fixed rate around the
  clock, so their volume measures nothing, and on TradingView it is often
  missing entirely.
  - Base's Market Volume requirement is therefore not applied to them, or to
    any symbol without volume data. The dashboard then shows
    `PASS (not applied: ...)`.
  - The other Optimal Conditions are unchanged.
  - Before this change, a symbol without volume could never read OPTIMAL, so
    the TradingView strategy took no trades.
- **Lot size limits.** Each symbol's minimum lot, maximum lot per order and
  total volume limit are respected.
  - A risk-based size below the minimum is skipped. The Journal and the
    dashboard name the minimum.
  - With `Minimum_Lot_Max_Risk_Multiple` above 0, the minimum lot is traded
    instead, but only if its loss at the stop is at most that many times the
    planned risk.
  - A size above the maximum is capped, which risks less than planned. The
    trade's note says so.
  - On TradingView, set `Minimum Quantity` (and the same multiple) to the
    Deriv minimum lot.
- **Price deviation (EA).** Synthetic indices move many points per tick, so
  the EA allows a market order to fill up to a tenth of the LTF ATR from the
  requested price, instead of a fixed 20 points. This avoids requotes.
- **History messages (EA).** When the EA is waiting for history (for
  example, a symbol with too little H4 or H1 data), it writes the reason to
  the Journal, such as `waiting - no H4 candles yet`. A symbol that never
  trades in the Strategy Tester shows why.
- **Margin (TradingView).** The strategy no longer simulates margin. The
  default 100% margin rejected the leveraged position sizes that 5% risk
  per trade needs. To model your account's leverage instead, set the margin
  in the strategy's Properties.
- **Timing.**
  - Deriv's MT5 server runs on GMT, so a trading day is a UTC day.
  - The indices trade around the clock; the strategy keeps your Monday to
    Saturday trading days, and `Trade_Sunday` adds Sunday.

### How it was checked

Nothing here has been compiled in MetaEditor or run in TradingView. The
checks used the test harness (MQL5 compiled as C++ against a mock terminal)
and Python mirrors:

- **Base's behaviour is unchanged.** Base's whole test suite passes against
  the EA.
- **Every trade follows the rules.** Tick-level backtests ran on 20
  generated markets of 120 days each. Every trade was rechecked with
  independent code, including:
  - A and B are swings of the LTF candles;
  - the level is the 83% retracement;
  - the heavy-pressure rule;
  - A lies within the processed candles;
  - the setup was not missed and no new HH/LL came first;
  - the entry is at the first touch;
  - the filters at the entry;
  - the take profit, stop and 1:2 / 1:3 choice;
  - the lot size, including the risk cuts;
  - the day and trade limits;
  - breakeven.

  All 138 trades passed. Every one of the 450 touches of an armed setup was
  either traded or rejected for a genuine reason: Market Tradability, the
  MTF's latest structure, or a position already open.
- **Deriv tests.** Separate tests cover:
  - recognising synthetic indices: 18 of 18 names, codes, descriptions and
    paths classified correctly;
  - leaving Market Volume out on a synthetic index or a symbol without
    volume;
  - sizing at the minimum, maximum and total volume limits;
  - the Journal reason while history is missing.

  Half of the 20 backtest markets ran as `Volatility 75 Index`.
- **Unit tests.** Separate tests cover:
  - the daily risk bookkeeping (losses, breakeven exits, cuts and the daily
    reset);
  - the daily trade limit and excluded days;
  - the LTF drawings.
- **The EA and the Pine strategy agree.** The EA's setup scan was compared,
  setup by setup, with a Python mirror of the Pine strategy's setup logic on
  14 generated markets. These covered several swing levels, windows and
  pressure settings, at both forex and gold price scales. All 2,361 setups
  matched: A, B, the level, the outcome, and when the setup was armed and
  ended.
