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
Structure with its own BOS/CHoCH, and measures trend persistence with the
Hurst exponent. It never places, modifies, or closes trades. Base 2.0 (see
below) is a separate version with a new trend and swing engine.

## Install and start

1. Copy `Base.mq5` into the terminal's `MQL5/Experts` directory.
2. Open the file in MetaEditor and compile it. Resolve every compiler error or
   warning before continuing.
3. In MetaTrader 5, refresh **Navigator > Expert Advisors**, then drag **Base**
   onto a chart. An invalid input is reported in the Experts tab with the
   input's name and valid range.
4. Leave the default timeframes (HTF H1, MTF M30, LTF M15; by default only
   the HTF decides Market Tradability), or deliberately select alternatives.
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
| Swing Structure | HH + HL | LL + LH | anything else | |
| Internal Structure | Bullish | Bearish | Undefined | |
| Hurst Exponent | above `Hurst_Minimum` | not above it | not available | |
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
- **Swing Structure.** Below each Market Trend, indented: the latest swing
  high against the previous one (HH, LH or EQH) and the same for lows (LL,
  HL or EQL), for example `HH + HL`. The previous swing is the previous
  leg's; a higher high within the same leg replaces it. Hover it for the
  prices.
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
- **Hurst Exponent (H1).** The Hurst exponent H of the last 100 closed HTF
  candles, with its reading: trending (above `Hurst_Minimum`, 0.50), random
  walk (0.45 up to the minimum) or mean-reverting (below 0.45). See **Hurst
  exponent** below.
- **Market Tradability.** Tradable, Tradable (Early) or Not Tradable. It is
  an analytical state, not an instruction to place a trade.
  - **Tradable** needs all of these to line up in one direction:
    1. **Market Trend.** The HTF trend, and the trend of every other
       timeframe selected in **Trend Analysis Timeframes**, is Bullish (or
       all Bearish): established by a BOS, not a transition and not
       Consolidation / Undefined.
    2. **Progressive structure** on each of them. Bullish: a Higher High
       (`Current_Swing_High > Previous_Swing_High`) and a Higher Low
       (`Current_Swing_Low > Previous_Swing_Low`). Bearish: a Lower Low and
       a Lower High.
    3. **HTF Internal Structure** in that direction, its latest break a BOS
       (not a CHoCH).
    4. **Hurst exponent** above `Hurst_Minimum` (0.50).
  - **Tradable (Early)**, in amber, off by default
    (`Allow_Early_Tradability`): every selected timeframe agrees with the
    HTF, but the HTF (or a selected MTF or LTF) is only in transition (a
    CHoCH not yet confirmed by a BOS), and the internal structure of the HTF
    and of every selected timeframe agrees with that direction. For
    example, H4 and H1 both Bearish Transition with both internal
    structures bearish. It does not check conditions 2 to 4. It works even
    when `Show_Internal_On_Dashboard` hides the Internal Structure rows.
  - Why a separate state: internal agreement made a transition much more
    likely to reach its confirming BOS, but it still failed about a third
    of the time (see below).
  - Hover it to see the entry filters (HTF MA, MTF MA, session, ADX, ATR)
    for the latest closed structure candle: whether a long or short
    BOS/CHoCH setup would pass, and each filter's reading.
- **Tradability Reason.** One sentence that names the timeframes. It says
  why the market is tradable. Otherwise it gives the trend problem, or, once
  the trends line up, every other condition that fails. Like the Trade
  Recommendations, it wraps onto further lines of at most 48 characters so
  the dashboard stays narrow:
  - `H1 is bullish (BOS) with HH + HL, the H1 internal structure is bullish
    (BOS), and the Hurst exponent 0.62 is above 0.50.` (Tradable)
  - `H1 is bearish (BOS), but the H1 swings are LH + HL (bearish needs LL +
    LH); the Hurst exponent 0.48 is not above 0.50 (random walk).`
  - `H1 is bullish (BOS), but the H1 internal structure is bullish (CHoCH),
    not bullish (BOS).`
  - `H1 is bullish but M30 is bearish.` (MTF selected)
  - `H1 is only in a bullish transition (a CHoCH not yet confirmed by a
    BOS).`
  - `H1 and M30 are both bearish and their internal structure agrees, but
    the H1 trend is only a transition (a CHoCH not yet confirmed by a BOS).`
    (Tradable (Early), when allowed)
  - `H1 is ranging (repeated CHoCHs in one area with no BOS).`
  - `H1 has no structure break yet.`
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
  Tradable back, it names that timeframe instead, for example `H1 is bullish,
  but wait for M30 to turn bullish before buying.` When another condition
  holds it back (the swings, the internal structure or the Hurst
  exponent), it says `H1 is bullish, but wait for Market Tradability (see
  Tradability Reason) before buying.` When the market is
  Tradable (Early), it gives the early entry and what confirms it, for
  example `Early sells only, while price holds below LH 1.10500; a close
  below LL 1.09500 (bearish BOS) confirms the trend.`
- **Optimal Conditions.** Shown only when at least one requirement in the
  **Optimal Conditions** input group is enabled; none is by default. It
  reads OPTIMAL when every enabled requirement passes. Below it, each
  enabled requirement shows PASS or BLOCKED; hover any of these rows for the
  reason.
  - Timeframe Correlation passes whenever Market Tradability is Tradable or
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
  independently choose which Market Trends are shown and must line up for
  Market Tradability. By default only the HTF (H1) is used.
  - At least one must remain enabled. This supports HTF-only, HTF/MTF,
    all-three, and other combinations.
  - The HTF conditions always apply, even when the HTF row is hidden: its
    established trend and progressive swings, its internal structure and
    the Hurst exponent. Tradable (Early) also always uses the HTF and its
    internal structure.
- **Hurst exponent.** `Hurst_Timeframe` (HTF, MTF or LTF; HTF by default),
  `Hurst_Candles` (100 closed candles, 50 to 400) and `Hurst_Minimum`
  (0.50; the 83% Strategy uses 0.55). It is calculated as in the 83%
  Strategy:
  - **Method.** With x = ln(close), for each lag tau from 2 to 20 candles,
    sigma(tau) is the root mean square of x[t + tau] - x[t] over the window.
    H is the least-squares slope of ln sigma(tau) against ln tau (the
    generalized Hurst exponent with q = 2).
  - **Readings.** A random walk gives about 0.5, a trending market more
    (from a steady drift or from momentum in its moves) and a
    mean-reverting market less.
  - **Why this variant.** The textbook version takes the standard deviation
    of the differences, which subtracts their average move. That removes the
    drift, so a steady trend read about 0.41, the same as a random walk.
  - **How often it passes.** On EURUSD H1 and H4, an index on M5 and M30
    and five stocks on D1, H was above 0.50 in about 29% to 47% of
    100-candle windows (13% to 30% above 0.55).
    - Over 100 candles even a pure random walk reads above 0.50 about 43%
      of the time (26% above 0.55), because the estimate is noisy.
    - So 0.50 lets through many markets with no real persistence. Raise
      `Hurst_Minimum` for a stricter filter.
- **Tradable (Early).** `Allow_Early_Tradability` (default off) shows it. It
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
  determine the Optimal Conditions result. All four are off by default, which
  hides Optimal Conditions from the dashboard; disabled requirements are
  omitted from both the result and the dashboard.
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
Internal Structure with its dashed BOS/CHoCH, the Hurst exponent, and the
same dashboard (Market Trends with their breakdowns, Swing Structure and
Internal Structure, the Hurst exponent, Market Tradability with the
entry-filter tooltip, the trade recommendation, and Optimal Conditions when
any is selected). It has the same inputs,
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

Market Tradability (v2.44) was checked the same way. A line-by-line Python
copy of the Pine rules, fed by the Pine engine copy and the Pine Hurst
calculation, gave the EA's state and reason, word for word:
- on every candle of 8 generated H1 markets (17,002 candles, Tradable on
  4,684);
- on 62,940 rule cases covering every timeframe selection and Tradable
  (Early).

The same cases also matched a separately written statement of the rule. A
deliberate slip in the copy (ignoring a CHoCH, or another separator in the
reason) made thousands of cases differ. Nothing in v2.44 has been compiled in
MetaEditor or run in TradingView yet.

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
  - The Hurst exponent on the MTF or LTF takes more calculation than on the
    HTF.

## Base 2.0 (`Base 2.0.mq5` and `Base 2.0.pine`)

Base 2.0 reads the trend purely from market structure: **Trending**,
**Transition** or **Consolidation**, with BOS, CHoCH and LS, and a swing
sensitivity that gives the same result on every symbol. `Base.mq5` and
`Base.pine` are unchanged. Base 2.0's chart objects use their own prefix
(`BASE2_`), so it can run next to Base.

### What changed in version 3.10

- **States.** Market Trend is Bullish/Bearish Trending, Bullish/Bearish
  Transition or Consolidation (it was Bullish, Bearish or Range).
- **BOS, CHoCH and LS follow the standard reading.**
  - A CHoCH is the first close through the trend's latest HL (or LH).
  - An LS is a CHoCH, or a break out of consolidation, that fails.
  - Every candle of 60 benchmark markets was checked against these
    definitions (see How it was checked). The check found two faults, both
    fixed:
    - When a trend went on to a new BOS while its CHoCH was still waiting,
      the CHoCH stayed a CHoCH. It is now relabelled LS.
    - When a failed Transition broke back and the old trend resumed, the
      trend's strong level was the Transition's extreme rather than the lower
      high (or higher low) it had just made. The next break of that level was
      then missed as a CHoCH: 88 of 8,593 CHoCHs.
- **Swing Sensitivity.**
  - The swing size is set automatically for each symbol (Auto, the default)
    or in ATR (Fixed).
  - Each timeframe's level runs from 1 to 20 in steps of about 10%. Before,
    1 to 10 went in steps of 25% to 50%.
- **Removed:**
  - the HTF and MTF MA filters, and the session, ADX and ATR filters;
  - the Hurst exponent;
  - Optimal Conditions;
  - the Swing Structure dashboard row;
  - colour and line-style inputs, the EQH/EQL threshold, and Use HTF.

  That leaves 23 inputs in each file (65 before).
- **Kept:**
  - the HTF Trend Quality in Market Tradability; it is not part of the
    trend reading;
  - the optional HH + HL and internal-agreement requirements;
  - the internal structure and the trade recommendation.

### The states (bullish wording; bearish mirrors it)

A break is a candle **close** beyond a swing level; a wick alone never breaks
anything.

- **Bullish Trending.** The market has broken structure upwards twice, with a
  higher low between the breaks.
  - A **BOS** is a close above the weak high: the highest swing high since the
    last BOS.
  - The **strong low** is the latest swing low (an HL).
- **CHoCH in a trend.** A close below the strong low is a bearish **CHoCH**.
  The trend has not changed yet: it stays Bullish Trending, shown as
  `Bullish Trending (CHoCH)`, until the Transition conditions are met.
- **Bearish Transition.** After the CHoCH, before it fails, either:
  - **A.** the pullback makes a lower high or equal high that does not go
    higher than the last HH of the bullish trend; or
  - **B.** two successive internal BOS follow downwards.
- **LS (liquidity sweep).** If the market fails to transition, the CHoCH is
  relabelled LS and the bullish trend continues. It fails when any of these
  comes first:
  - two successive internal breaks upwards (an internal CHoCH, then an
    internal BOS);
  - a close above the last HH;
  - a BOS of the bullish trend.

  The sweep's low becomes the new strong low.
- **From Transition to Trending.** A BOS (a close below the lowest swing low
  since the CHoCH) makes it Bearish Trending: the CHoCH and this BOS are the
  two downside breaks with a lower high between them.
- **A Transition that fails.** A close above its own lower high (or, after B,
  above the level the CHoCH broke):
  - if that close is also above the old trend's last HH, the old trend
    resumes with a BOS. Its strong level is the latest swing low since the
    old trend's high (the higher low the failed Transition left);
  - otherwise the market is in **Consolidation**, and that break waits for
    its own Transition conditions.
- **Consolidation.** Neither the Trending nor the Transition conditions were
  met within the last 5 swings:
  - a trend or Transition with no BOS for 5 swings becomes Consolidation;
  - its **range** is the highest high and lowest low of the last 5 swings;
  - a close beyond the range is a break that waits, like a CHoCH. Its
    Transition needs a pullback that holds the latest swing on the other
    side, or two internal BOS.

EQH/EQL (within 0.2 ATR of the previous swing on its side) are labels, and
count as holding for condition A.

Three amendments make the rules work from closes alone:
1. **The CHoCH counts as the first of the two breaks**, so a trend is a CHoCH
   (or a break out of consolidation), a higher low, then a BOS. Requiring two
   more BOS after the Transition would confirm every trend two swings later.
2. **An LS needs an internal CHoCH and then an internal BOS against the
   break.**
   - A single internal break is not enough: the pullback that makes the
     lower high always breaks the internal structure once.
   - A "close back through the broken level" rule was also tried. It
     wrongly rejected clean trends, whose pullbacks often dip back below the
     level they broke.
3. **Transition condition B is measured on the internal structure.** Two BOS
   on the main swings would already be Trending.

### Swing Sensitivity

A swing is confirmed by the first close one swing size back from the leg's
extreme. The swing size is a base size times the level's factor, in 14-candle
ATR.

| Level | 1 | 4 | 7 | 10 | 13 | 16 | 20 |
|---|---|---|---|---|---|---|---|
| Factor | 0.42 | 0.56 | 0.75 | 1.00 | 1.33 | 1.77 | 2.59 |

Each level is about 10% finer (lower) or broader (higher) than the one
before. Each timeframe has its own level (HTF, MTF, LTF), 10 by default.
Internal swings use `Internal Swing Size` (0.5) of the swing size.

- **Fixed (ATR):** the base is 1 ATR, so level 10 is a 1 ATR swing.
- **Auto (default):** the base comes from the symbol's own movement over the
  last 1,000 closed candles of each timeframe:

      VR   = sum of squared 20-candle moves / (20 x sum of squared 1-candle moves)
      base = 0.8 / sqrt(VR - 1), kept between 0.5 and 2.0 ATR (2.0 when VR <= 1)

  - VR, the variance ratio, is about 1 when the closes wander at random and
    higher when moves persist.
  - The more of a symbol's movement is trend rather than noise, the smaller
    a swing needs to be.
  - A level therefore means the same thing on every symbol.
  - The size in use is shown in each Market Trend tooltip.

**Why Auto fixes "a setting that suits one symbol does not suit another".**
Seven markets that behave differently were treated as seven symbols:
- the H1, M15 and H4 benchmark markets;
- clean, swingy, spiky and mixed markets.

For each, the best level (by accuracy) was found in each mode, and compared
with using one shared level everywhere:

| | Best level on each symbol | Cost of one shared level (average, worst) |
|---|---|---|
| Auto | 5 to 20, mostly 9 to 16 | level 10: 1.5 and 3.8 points |
| Fixed | 1 to 18 | best shared level (15): 2.3 and 13.4 points |

With Auto, one setting works across symbols to within about 4 points of each
symbol's own best. With Fixed, the setting has to be re-tuned per symbol.
Auto keeps the quality of the reading the same, not the number of swings: a
noisy symbol gets fewer, bigger swings.

### Inputs

| Group | Inputs (defaults) |
|---|---|
| Timeframes | HTF (H1), MTF (M30), LTF (M15), Use MTF (off), Use LTF (off) |
| Swing Sensitivity | Swing Size (Auto), HTF / MTF / LTF Swing Sensitivity (10), Internal Swing Size (0.5) |
| Market Tradability | Trend Quality Window (30), Tradable When The HTF Efficiency Is At Least (0.30), Also Require HH + HL (off), Also Require The HTF Internal Structure To Agree (off) |
| Display | Bars To Process (100), Show HH/HL/LH/LL, Show BOS/CHoCH/LS, Show Internal Structure, Show Internal Structure On Dashboard, Show Strong/Weak High/Low, Label Size |
| Alerts | EA: popup and push. Pine: one alert switch, and the dashboard position |

### Dashboard

- **Market Trend.** One row for the HTF, plus the MTF and LTF when selected.
  It shows the state, with `(CHoCH)` while a CHoCH waits. Its tooltip gives:
  - why it reads that state;
  - the latest swings;
  - Strong/Weak High/Low;
  - the swing size in use;
  - what a waiting CHoCH needs.
- **Internal Structure** (optional): the latest internal break under each
  Market Trend. Its tooltip says whether it agrees with the trend.
- **Trend Quality:** the efficiency of the last 30 closed HTF candles.
- **Market Tradability.** Tradable when all of these hold:
  - the HTF is Trending;
  - every selected MTF/LTF is Trending or in Transition the same way;
  - the HTF trend quality is at least 0.30 that way;
  - when required, HH + HL (LL + LH) and the HTF internal structure agree.
- **Tradability Reason:** names every condition that fails.
- **Trade Recommendations:**
  - in a trend, the pullback and continuation levels;
  - in a Transition, the BOS to wait for;
  - in Consolidation, the range edges;
  - while a CHoCH waits, to hold off.

The chart shows:
- swing labels;
- BOS (blue), CHoCH (red) and LS (deep yellow) lines with centred captions;
- dashed internal BOS/CHoCH;
- Strong/Weak High/Low (Range High/Low in Consolidation).

Alerts cover the HTF's BOS, CHoCH, LS and changes of state.

### Benchmark against the previous version and Base

These are the same generated markets as before (20 per timeframe, with a
known trend at every candle), with the default settings. Market Trend counts
a Transition as a direction, so it is compared with old Base including its
transitions.

**Market Trend**

| | Accuracy | Wrong way | Flat called trend | Lag | Missed | Precision |
|---|---|---|---|---|---|---|
| H1 Base | 52.0% | 16.6% | 95.0% | 13 | 1 of 154 | 51.7% |
| H1 Base 2.0 v3.00 | 58.8% | 8.9% | 64.2% | 27 | 11 of 154 | 59.9% |
| H1 Base 2.0 v3.10 | 54.3% | 12.3% | 72.4% | 11 | 4 of 154 | 55.3% |
| M15 Base | 45.1% | 23.7% | 94.7% | 7 | 0 of 57 | 44.7% |
| M15 Base 2.0 v3.00 | 54.7% | 10.3% | 64.6% | 31 | 2 of 57 | 54.9% |
| M15 Base 2.0 v3.10 | 49.7% | 14.7% | 77.5% | 24 | 0 of 57 | 49.8% |
| H4 Base | 41.1% | 33.1% | 96.9% | 8 | 54 of 426 | 40.8% |
| H4 Base 2.0 v3.00 | 44.4% | 18.8% | 74.8% | 12 | 99 of 426 | 46.1% |
| H4 Base 2.0 v3.10 | 55.5% | 11.6% | 70.5% | 6 | 3 of 426 | 56.1% |

**Market Tradability (HTF only)**

| | Accuracy | Wrong way | Flat called trend | Lag | Missed | Precision | Edge |
|---|---|---|---|---|---|---|---|
| H1 v3.00 | 62.7% | 1.1% | 15.0% | 31 | 13 of 154 | 82.4% | 0.159 |
| H1 v3.10 | 59.5% | 1.1% | 13.8% | 32 | 9 of 154 | 81.6% | 0.157 |
| M15 v3.00 | 52.6% | 1.5% | 15.5% | 37 | 2 of 57 | 70.4% | 0.075 |
| M15 v3.10 | 52.3% | 1.3% | 12.6% | 44 | 0 of 57 | 72.8% | 0.081 |
| H4 v3.00 | 56.0% | 4.3% | 25.5% | 20 | 107 of 426 | 68.3% | 0.203 |
| H4 v3.10 | 61.6% | 4.2% | 21.7% | 17 | 31 of 426 | 74.0% | 0.227 |

What this shows:
- **Market Trend is much earlier.** It calls a new trend sooner than the
  previous version on every timeframe:
  - H1: 11 candles against 27;
  - M15: 24 against 31;
  - H4: 6 against 12.

  It misses far fewer trends.
- **The cost is flat markets.** Structure alone cannot tell a driftless market
  from a trend; in a random walk, breaks followed by higher lows happen by
  chance. Market Trend therefore calls more flat candles a trend, and is less
  accurate than the previous version on H1 and M15. It is more accurate on
  H4.
- **Market Tradability:**
  - about as precise as before on H1, and more precise on M15 and H4;
  - fewer missed trends on every timeframe;
  - a longer wait on M15 (44 candles against 37).
- These are generated markets. A comparison on real prices needs candles
  exported from MT5 (**View > Symbols > Bars**, then **Export Bars**).

### Install

- **MetaTrader 5.** Copy `Base 2.0.mq5` into `MQL5/Experts`, compile it in
  MetaEditor, and attach **Base 2.0** to a chart.
- **TradingView.** Paste `Base 2.0.pine` into the Pine Editor, save it, and
  click **Add to chart**.

The swing levels have a new scale (1 to 20, with 10 the base size), and many
inputs were removed. Reset any saved MT5 presets from version 3.00.

The Pine indicator differs from the EA in these ways:
- **History.** It reads all loaded history. The EA replays three times
  `Bars To Process`, plus the 1,020 closes the Auto size needs, so the state
  at the left edge of a short history can differ until both have seen the
  same swings.
- **Scan limit.** It looks back at most 4,999 candles for a level or a
  line's end.
- **Dashboard position.** Its corner is an input.
- **Alerts.** One switch sends alert() messages. Eight alert conditions are
  also available.

### How it was checked

Nothing in this version has been compiled in MetaEditor or run in
TradingView. The checks used the test harness (MQL5 compiled as C++ against a
mock terminal) and Python copies:

- **The definitions, on every candle.** Separately written code walked every
  candle of 60 benchmark markets, at four sensitivity settings (240 runs). It
  confirmed:
  - every close through a trend's latest HL or LH is a CHoCH at that level:
    8,540 of 8,540;
  - every CHoCH followed by a BOS of the same trend, before a Transition, is
    relabelled LS: 1,256 of 1,256;
  - every Transition (15,392) follows a break waiting in its direction;
  - every start of a trend (11,203) comes with a BOS.

  The two faults described above were found and fixed this way.
- **The rules.** Six hand-built price paths, one for each rule, give the
  expected state sequence in the EA, including the range drawn in
  Consolidation:
  - a trend;
  - a CHoCH that fails (LS);
  - a CHoCH, then a lower high (Transition), then a BOS (Trending);
  - a CHoCH, then two internal BOS (Transition by B);
  - a Transition that breaks its lower high;
  - five swings without a BOS.
- **The EA against a Python reference.** On 13 generated markets, at six
  sensitivity settings (Auto and Fixed, levels 1 to 17, internal ratios 0.3
  to 0.9), the EA matched the reference with no differences in:
  - 25,907 swing sizes;
  - 7,868 swings;
  - 2,115 breaks (156 of them LS);
  - 3,500 internal breaks;
  - 7,596 state snapshots;
  - 736 replays of a 300-candle window.

  One market was chosen because it has the rare LS made by a resuming BOS.
- **The Pine engine.** A line-by-line Python copy of it matched the EA on the
  same markets and settings with no differences.
- **The tests catch mistakes.** Planting a mistake made the comparisons
  fail:
  - a 12% level step instead of 10%;
  - a fixed internal ratio;
  - no LS on a resuming BOS;
  - the old strong level after a resume;
  - Auto ignored.
- **Unit tests.** They passed for:
  - every Market Tradability reason, including trend quality and the
    optional requirements;
  - the swing size of each mode and level;
  - the chart objects and dashboard rows (no Hurst, MA, ADX, Optimal or
    Swing Structure rows);
  - the alerts;
  - recovery after a timeframe change;
  - no extra work on repeated ticks;
  - 72 randomised runs across modes, levels and settings with no array
    errors.
- **The Pine file parses** with pynescript (a syntax check only).

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

1. **Market Tradability (trend identification).** The dashboard's Market
   Tradability reads **Tradable (bullish)**. All three conditions must line
   up:
   - **HTF EMA trend filter.** The HTF EMAs are in order, 20 > 50 > 200
     (`HTF_20_EMA > HTF_50_EMA > HTF_200_EMA`), on the latest closed HTF
     candle.
     - The lengths are `HTF_EMA_Fast`, `HTF_EMA_Middle` and `HTF_EMA_Slow`
       (20, 50 and 200).
     - **Consistently.** `HTF_EMA_Candles` (1) sets on how many closed HTF
       candles in a row the order must hold. 1 is the latest one only; 3
       means each of the last three.
   - **MTF structural progression.** The MTF shows upward expansion:
     - a Higher High: its latest swing high is above the previous swing high
       (`Current_Swing_High > Previous_Swing_High`); and
     - a Higher Low: its latest swing low is above the previous swing low
       (`Current_Swing_Low > Previous_Swing_Low`).

     The swings are the MTF's structure swings (MTF Swing Detection Length).
     The previous swing high is the high of the previous leg; a higher high
     within the same leg replaces it. The same holds for lows.
   - **Hurst exponent.** H is above `Hurst_Minimum` (0.55): the market is
     trending, not a random walk (about 0.5) or mean-reverting (below 0.5).
     See "The Hurst exponent" below.

   Otherwise the market is Not Tradable, and the reason names every missing
   condition. This is the only market filter. The BOS / CHoCH Market Trends,
   the Internal Structure, Optimal Conditions and Tradable (Early) play no
   part. Base's own indicator keeps its rules.
2. **Only setups in the market's direction.** In a bullish market only buy
   setups are identified and taken; in a bearish market only sell setups.
   - The market's direction is the dashboard's HTF Trend: the HTF EMAs in
     bullish order (20 > 50 > 200) or bearish order (20 < 50 < 200), on the
     last `HTF_EMA_Candles` closed HTF candles.
   - It is read at each LTF candle's open, from the HTF candles closed by
     then.
   - While the EMAs are in neither order, no setups are identified.
   - A setup that is still armed when the market stops pointing its
     direction is cancelled. It is drawn dotted with "cancelled: the market
     is no longer bullish" (or bearish).
   - Entries still need all three Market Tradability conditions in the
     setup's direction.
3. **LTF setup.** The LTF is M30 with LTF Swing Detection level 3 (3 candles
   each side) by default. The setup is searched within the last
   `LTF_Bars_To_Process` (the LTF Independent Processed Bars, 40) closed LTF
   candles.
   - **A** is the most recent HL from which there was heavy buying pressure.
   - **Break of structure.** After A has formed, a candle closes above the
     swing high before A (its break level, as for Base's BOS). The setup is
     armed from that close.
   - **B** is the highest high since A. While B is forming, it follows price
     up. It becomes a confirmed swing once 3 candles (the swing detection
     length) close without reaching it.
   - The Fibonacci runs from B (0%) back to A (100%), so the 83% level moves
     up with B.
4. **Entry.** Price touches the 83% level (`Entry_Level`, 0.83). Any
   pullback to it after the break counts, including one while B is still
   forming.
5. **Invalid.** If price makes a new HH (trades above a confirmed B) before
   reaching 83%, the setup is dead and its HL is used up. A new setup needs
   a new HL.

Sells mirror this:
- the HTF EMAs in the opposite order, 20 < 50 < 200 (only sell setups are
  identified then);
- downward expansion on the MTF: a Lower Low (`Current_Swing_Low <
  Previous_Swing_Low`) and a Lower High (`Current_Swing_High <
  Previous_Swing_High`);
- the same Hurst exponent, above 0.55;
- an LH with heavy selling pressure, and a close below the swing low before
  it;
- the lowest low since then as B, and a sell at the 83% retracement;
- invalidation on a new LL beyond a confirmed B.

How the rules are made exact:

- **The Hurst exponent.** By default it is measured on the HTF over the
  last `Hurst_Candles` (100) closed candles. `Hurst_Timeframe` can be the
  HTF, MTF or LTF.
  - The method uses lagged differences (the generalized Hurst exponent with
    q = 2). With x = ln(close), for each lag tau from 2 to 20 candles,
    sigma(tau) is the root mean square of x[t + tau] - x[t] over the window.
  - H is the slope of the least-squares line through ln sigma(tau) against
    ln tau.
  - A random walk gives about 0.5. A trending market gives more, whether
    from a steady drift or from momentum in its moves. A mean-reverting
    market gives less.
  - **Why this variant.** The textbook version takes the standard deviation
    of the differences, which subtracts their average move. That removes
    the drift, so a steady trend read about 0.41, the same as a random walk.
  - **Simulated series** (100 closes each):
    - a random walk read 0.47 on average;
    - a moderate trend read 0.58, and a strong one 0.80.
  - **Real data** (EURUSD H1 and H4, an index on M5 and M30, five stocks on
    D1): H was above 0.55 in about 13% to 30% of 100-candle windows.
- **Heavy pressure.** Within `Impulse_Candles` (3) candles of A, counting A's
  own candle, a candle closes at least `Impulse_Min_ATR` (2.0) LTF ATR beyond
  A. The ATR is the 14-candle ATR at A. On real data (an index on M15 and
  M30, EURUSD H1 and five stocks D1), 2.0 selected the strongest 43% of
  HL-to-HH legs. Set it to 0 to accept every leg.
- **HL label.** A must be Base's latest swing low and an HL (or an EQL with an
  HL's role). The break level is Base's swing high just before it: its price,
  or the outer edge of an EQH pair.
- **When a setup becomes known.** A setup is armed at the close of the first
  candle by which:
  - A is a confirmed swing (3 candles after it);
  - the break of structure has closed; and
  - the heavy pressure is met.

  Usually that is the breaking candle itself. If A was confirmed later and
  price had already pulled back to 83% after B and the break, the setup is
  **missed** and is not traded late.
- **How B moves.** B moves only at candle closes:
  - each closed candle that reaches B becomes B, and the 83% level is
    recomputed;
  - the EA checks the touch on every tick against the level of the latest
    closed candle.

  A tick beyond a forming B does not invalidate the setup; B follows it at
  the close. Once the level is touched, B is fixed for that trade.
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
    the real-data setups, as the strategy describes.
  - The adjusted stop is always behind A. If a gap leaves the entry too far
    past the level for that, the trade is skipped with the reason.
- **Breakeven.** The stop moves to the entry price once price has covered
  `Breakeven_At_Percent` (60%) of the way to the take profit.

### What you see on the LTF chart

On the LTF chart, setups are drawn as in the strategy's examples.

- **Setups shown.** To keep the chart clean, only the latest
  `Setups_To_Show` (2) setups are drawn (`Setups To Show` on TradingView). A
  live setup is always drawn, even if it is older.

- **Fibonacci levels.** Fib Base's levels: 0% at B, 100% at A, and the entry
  level in orange.
  - Labels read `0.00%`, `83.00%` and `100.00%`. They can show ratios or
    prices instead.
  - Four optional levels (0.5, 0.618, 0.705, 0.886) can be switched on, and
    every level's ratio and colour can be changed.
- **Points.** A, B and C (the entry, where price touched the level).
- **Position zones.** The target zone (blue, entry to take profit) and the
  stop zone (red, entry to stop loss), drawn from C.
  - An armed setup shows its planned zones from the latest candle.
  - Failed setups are drawn dotted with their reason: invalidated, expired,
    missed, replaced or cancelled.

The dashboard shows the trend and the strategy:

- **HTF Trend (H4 20/50/200 EMA).**
  - Bullish (20 > 50 > 200) or Bearish (20 < 50 < 200).
  - Not in order, or in order on the latest candle but not on each of the
    last `HTF_EMA_Candles`.
  - Not available yet.

  The tooltip gives the three EMA values.
- **MTF Swings (H1).** The latest swing high against the previous one (HH,
  LH or EQH) and the same for lows (LL, HL or EQL). It is green for HH + HL
  (upward expansion) and red for LL + LH (downward expansion). The tooltip
  gives the prices.
- **Hurst Exponent (H4).** H with its reading (trending above 0.55, random
  walk from 0.45 to 0.55, mean-reverting below). It is green when H is above
  `Hurst_Minimum` and red when it is not.
- **Market Tradability.** Tradable (bullish or bearish) or Not Tradable. The
  tooltip keeps Base's session, ADX and ATR readings (information only).
- **Tradability Reason.** Which conditions hold or are missing.

Base's `MA Filter (HTF)` and `MA Filter (MTF)` inputs are gone. The
`HTF EMA Trend Filter` inputs replace them. `Show HTF EMA Lines` draws the
three EMAs, each in its own colour.

Base's BOS / CHoCH Market Trend rows, the Internal Structure rows and the
Trade Recommendations are no longer on the dashboard.

- **Internal Structure.** It is drawn on the chart only, and `Show Internal
  Structure` is off by default. Turn it on to see the internal BOS / CHoCH.
  It plays no part in Market Tradability.

Then come the strategy's rows:

- **83% Strategy.** A buy or sell setup armed, a position open, or the
  wait:
  - "Waiting for a buy setup" in a bullish market;
  - "Waiting for a sell setup" in a bearish market;
  - "No setups (H4 EMAs not in order)" when the market is in neither.
- **Setup.** A, B and the 83% price. B reads `(forming)` while it still
  follows price.
- **Entry Filters.** PASS, or BLOCKED with the reason (Market Tradability
  not Tradable, with its reason, or Tradable the other way).
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
  tick beyond a confirmed B.
  - The take profit and stop of a sell include the spread, because they
    trigger on the ask.
  - Each untraded touch is written to the Journal once, with its reason.
- **Alerts.** `Enable_Popup_Alerts` and `Enable_Push_Notifications` also
  announce armed setups and entries.

### TradingView

- **Installing.** Paste `83% Strategy.pine` into the Pine Editor, save it,
  and add it to an M30 chart (the LTF). Setups, orders and drawings follow
  that chart; on any other chart the dashboard asks for the LTF chart.
- **The dashboard.** It appears as soon as the strategy is added or its
  settings change, including while the current candle is still forming.
  - A strategy calculates only at candle closes. Its last-candle drawings
    (the dashboard, the strong/weak lines and the planned position) are
    therefore drawn on the last closed candle too.
  - Before this, on a market that was open (Deriv's synthetic indices
    always are), they stayed blank until the current M30 candle closed.
- **Entries.** Entries are limit orders at the level, placed at a candle's
  close. While B is forming, the order moves with the level at each close. A
  buy and a sell order cancel each other.
- **Differences from the EA:**
  - A limit order fills at the level, or better on a gap.
  - Breakeven is checked at candle closes.
  - Pine has no spread.
  - Days follow the exchange time zone.
  - A new MTF/HTF candle reaches the filters one LTF candle after it closes,
    because Base's `request.security` reads the latest closed candle.
    The same goes for the market's direction: an order placed at the
    previous close can still fill on the candle where the market turned.
    That setup is traded rather than cancelled.
  - Each platform starts its EMAs from its own history, so the EMA values can
    differ slightly where little HTF history is loaded.
  - The Hurst exponent on the MTF or LTF takes more calculation than on the
    HTF.

### Deriv synthetic indices

Both versions are set up for Deriv's synthetic indices: Volatility (including
the 1s versions), Crash / Boom, Jump, Step, Range Break, DEX and Drift Switch.

- **No volume needed.** The strategy uses no volume. The Optimal
  Conditions, whose Market Volume requirement measured nothing on synthetic
  indices, are gone, along with the Symbol Profile that switched it off.
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
  generated markets of 120 days each, with the default settings. Every
  trade was rechecked with independent code, including:
  - A is a swing of the LTF candles, and the setup was known only after A
    was confirmed;
  - the break level is a swing before A, and a candle closed beyond it
    before the setup was armed;
  - B is the extreme since A, following price at each close until it was
    confirmed, and the level is the 83% retracement of that leg;
  - the heavy-pressure rule;
  - A lies within the processed candles;
  - the setup was not missed;
  - the entry is at the first touch, with no new HH/LL beyond a confirmed B
    first;
  - Market Tradability read Tradable in the trade direction: the HTF EMA
    order, the MTF swings and the Hurst exponent (see below);
  - the take profit, stop and 1:2 / 1:3 choice;
  - the lot size, including the risk cuts;
  - the day and trade limits;
  - breakeven.

  All 114 trades passed. Every one of the 259 touches of an armed setup was
  either traded or rejected because Market Tradability was not Tradable
  (145).

  Three more runs of 10 markets each also passed:
  - the EMA order required on the last 3 HTF candles (51 trades);
  - the Hurst exponent on the MTF (52 trades);
  - short EMAs (5/10/20), whose order flips often (87 trades).
- **Only setups in the market's direction.** The market's direction was
  recomputed independently from the HTF candles.
  - At every tick of the 20 markets (7.8 million checks), any armed setup
    pointed the market's direction.
  - Each of the 1,038 setups that ended was audited over its whole life
    (13,831 candles): the market pointed its direction at every candle, and
    the 4 that were cancelled ended on the first candle where it did not.
  - At each entry, the market had pointed the trade direction since the
    setup's candle.

  The generated markets are random, so they say nothing about profitability.
- **The Tradable rule.** Market Tradability was computed for every
  combination (900 cases) of:
  - the HTF EMAs: unavailable, bullish order, bearish order, in order on the
    latest candle only, or not in order;
  - MTF swing availability, and the latest swing against the previous one
    (above, below, equal) for highs and lows;
  - the Hurst exponent: too few candles, flat prices, or above, equal to or
    below the minimum.

  It read Tradable exactly as the rule says. Every reason named each
  failing condition.
- **The trend at each entry.** Every trade was rechecked with independent
  code:
  - the three HTF EMAs, recomputed from the HTF candles, matched the EA's
    and were in the trade direction's order;
  - the MTF made an HH and an HL for buys, or an LL and an LH for sells;
  - the Hurst exponent, recomputed by a separately written estimator,
    matched the EA's and was above 0.55.
- **The Hurst estimator.** The EA's estimator was compared on 1,500 random
  series with one written separately (one pass, long double, the slope from
  the normal equations). The largest difference was below 1e-14.
  - On those series, random walks read 0.47 on average, steady trends 0.98
    and mean-reverting prices about 0.
  - Flat prices and a zero price give no value.
- **EA and Pine read the same trend.** Across 19 generated markets:
  - the EA's latest and previous swing highs and lows matched the Pine
    engine's on 21,865 readings;
  - the EA's Hurst exponent matched a line-by-line Python copy of the Pine
    calculation on 21,388 readings, with windows of 50, 100 and 250 closes.
    A deliberate off-by-one in the copy made every reading differ, so the
    comparison catches indexing mistakes;
  - the EA's market direction at each M30 candle matched the one the Pine
    request returns on 109,421 candles, including weekend gaps and 1, 2 or 3
    candles of EMA consistency. Reading the HTF candle one step too late in
    the copy made 3,209 comparisons differ.
- **Deriv tests.** Separate tests cover:
  - sizing at the minimum, maximum and total volume limits;
  - the Journal reason while history is missing.

  Half of the 20 backtest markets ran as `Volatility 75 Index`.
- **Unit tests.** Separate tests cover:
  - the daily risk bookkeeping (losses, breakeven exits, cuts and the daily
    reset);
  - the daily trade limit and excluded days;
  - the LTF drawings.
- **The EA and the Pine strategy agree.** The EA's setup scan was compared,
  setup by setup, with a Python mirror of the Pine strategy's setup logic.
  - **Markets:** 19 generated markets, plus 4 whose market direction flipped
    at random every 2 to 30 candles.
  - **Settings:** several swing levels, windows (20 to 60 candles) and
    pressure settings, at both forex and gold price scales.
  - **Result:** all 1,960 setups matched: A, B (where it ended up), the
    level, the outcome, when the setup was armed and ended, and why it
    ended.
  - **Outcomes:** 171 were cancelled when the market turned, and 38 were
    missed (price reached 83% before the setup was known).
  - **Sensitivity:** without the direction rule, the copy differed on 2,185
    setups.
- **The drawing limit.** In a 60-day visual run, the chart was checked at
  every M30 candle. It always showed exactly the latest 2 setups plus any
  live one. In 213 of those checks, older setups were hidden.

## 83% Strategy 2.0 (`83% Strategy 2.0.mq5` and `83% Strategy 2.0.pine`)

83% Strategy 2.0 follows the updated strategy guide. It is Base (v2.44) with
the 83% Strategy built in, keeping the existing Fibonacci and execution logic
but with much less around it.

- **Fewer inputs.** 50 inputs in each file, against 107 in the first version
  and 63 in Base itself.
- **Removed:**
  - Base's MA, session, ADX and ATR filters;
  - Optimal Conditions and Tradable (Early);
  - the Use HTF / MTF / LTF switches;
  - the trade recommendations;
  - the structure alerts;
  - the six optional Fibonacci levels and their settings;
  - the HTF EMA filter of the first version;
  - `Setups_To_Show`;
  - the risk cut after losses.
- **Kept:**
  - Base's structure engine and drawings, unchanged;
  - Market Tradability, the internal structure and the Hurst exponent.
- **Drawing settings:** colours, line styles and widths are fixed.

The first version (`83% Strategy.mq5` / `.pine`) has since been removed from
the repository; 2.0 replaces it.

### The rules

**Market direction.** The direction is the HTF Market Trend (H4 by
default).
- In a bullish market (Bullish or Bullish Transition), only buy setups are
  scanned, shown and traded.
- In a bearish market, only sell setups.
- In Consolidation / Undefined, none.
- When the direction changes, the live setup is cancelled and the drawn
  setups are cleared.
- The direction at each LTF candle is the HTF trend as a build at that
  candle's open saw it.

**Market filters.** An entry needs both, in the setup's direction:
1. **Market Tradability reads Tradable.** This is Base's rule with only the
   HTF selected:
   - the HTF trend is Bullish (Bearish) by a BOS;
   - its latest swings are an HH and an HL (an LL and an LH);
   - its internal structure is bullish (bearish) by a BOS;
   - the Hurst exponent is above `Hurst_Minimum` (0.50).

   The reasons are word for word Base's.
2. **The MTF's most recent structure is a BOS that formed an HH** (an LL
   for sells). The MTF Market Trend (H1 by default) must read Bullish or
   Bearish, not a Transition.

**LTF setup.** The LTF is M30, with LTF Swing Detection level 3, and the
setup must be found within the last `LTF_Bars_To_Process` (25) closed
candles.
- **A** is the most recent HL from which there was heavy buying pressure.
- **Break of structure.** A candle closes above the swing high before A.
- **B** is the highest high since A. It follows price until it is a
  confirmed swing.
- **Fibonacci.** It runs from B (0%) to A (100%).
- **Entry.** Price touches the entry level. With the engulfing confirmation
  (off by default), an engulfing candle must then confirm it; see
  [Engulfing confirmation](#engulfing-confirmation).
- **Invalid.** A new HH beyond a confirmed B before the entry level. The HL
  is then used up.

Sells mirror this with an LH, a close below the swing low before it, the
lowest low since then as B, and a new LL as the invalidation. Heavy pressure,
missed setups and how B moves are as in the first version.

**Entry Fibonacci Level.** `Entry_Fib_Level` (Entry Fibonacci Level on
TradingView) is a dropdown with one level: 70.5%, 78.6%, **83%** (the
default) or 88.6%.
- **Levels below two thirds are not offered.** With the take profit just
  before B, a 1:2 stop at 61.8% or 50% could never stay behind A, so those
  levels could never trade.
- **At 70.5% some trades are skipped.** The 1:2 stop often only just fits
  behind A. In the backtests below, 41 of 558 touches were skipped because
  the stop would not have been behind A.

**Only setups found within the processed bars are shown.** The chart shows
the setups whose A lies within the last 25 LTF candles, created since the
market last changed direction, so all of them are in the market's
direction. A live setup expires when its A leaves the processed bars.

### Engulfing confirmation

`Engulfing_Confirmation` ("Engulfing Confirmation After The Touch" on
TradingView) is off by default. Switched on, touching the entry level does
not enter the trade by itself. The setup is **touched** and waits for an
engulfing candle in its direction on the LTF.

It makes trades much rarer: in the backtests below most 120-day runs had no
trade at all with it on (see
[Why a backtest shows no trades](#why-a-backtest-shows-no-trades)).

- **The engulfing.** For a buy, a bearish candle followed by a bullish
  candle that:
  - opens at or below the bearish candle's close; and
  - closes above the bearish candle's open.

  A sell mirrors this. Wicks are not compared; the bodies decide.
- **At or just after the touch.** The engulfing candle can be the touching
  candle itself or a later one, within `Engulfing_Window_Candles` (2) LTF
  candles, the touching candle included. With 2, that is the touching candle
  or the next one.
- **The wait fails** if, before the engulfing:
  - a candle closes through A (below the HL, above the LH);
  - price makes a new HH beyond B (a new LL for a sell); or
  - the window runs out.

  The setup also expires when A leaves the processed bars: the touch and the
  engulfing must both come while A is within them. It is cancelled when the
  market changes direction. A failed setup's A is used up, like an
  invalidated one.
- **The entry.** The trade is entered at the market once the engulfing
  candle has closed: on the first tick of the next candle in the EA, and by
  a market order at the engulfing candle's close on TradingView (filled at
  the next open). After a weekend or session break the next candle is the
  first one after the break. The market filters, the day's limits and the
  risk management then apply as usual.
- **The stop.** For an engulfing entry, the stop goes behind the engulfing
  candle instead of A:
  - the ATR stop is `SL_Buffer_ATR` (0.5) LTF ATR below the engulfing
    candle's low (above its high for a sell);
  - the take profit stays just before B;
  - the closer of 1:2 and 1:3 is used, moving the stop to match, as long as
    the stop stays behind the engulfing candle. If a 1:2 stop would sit
    inside the engulfing candle, the trade is skipped with that reason.
- **Off (the default).** The strategy enters at the first touch of the
  level, with the stop behind A.

### Risk management (all adjustable)

- **Trading days.** Monday to Saturday (`Trade_Monday` ... `Trade_Sunday`).
- **Trades per day.** At most `Max_Trades_Per_Day` (3) a day, one position
  at a time.
- **Losses end the day.** After `Losses_To_End_Day` (2) consecutive losses,
  trading ends for that day.
  - A loss closes more than half its initial risk beyond the entry.
  - A breakeven exit is not a loss, and it ends a run of losses.
  - The EA reads the day back from the deal history, so a restart keeps it.
  - 0 switches this rule off.
- **Risk per trade.** `Risk_Percent` (5%) of the balance is lost at the
  stop. Lot size = balance x risk % / the loss of one lot at the stop.
- **Take profit.** `TP_Buffer_ATR` (0.1) LTF ATR before B.
- **Stop loss and reward-to-risk.**
  - A stop `SL_Buffer_ATR` (0.5) LTF ATR behind A gives the natural ratio.
    An engulfing entry uses the engulfing candle instead of A (see
    [Engulfing confirmation](#engulfing-confirmation)).
  - The closer of 1:2 and 1:3 is used, moving the stop to match (1:2.4 uses
    1:2).
  - The stop always stays behind A (or the engulfing candle).
- **Breakeven.** The stop moves to the entry at `Breakeven_At_Percent` (60%)
  of the way to the take profit.
- **Deriv sizing.** `Minimum_Lot_Max_Risk_Multiple` (EA) and the minimum
  quantity settings (TradingView) work as in the first version.

### Defaults and inputs

- **Timeframes.** HTF H4, MTF H1, LTF M30.
  - The guide sets the LTF to 30 minutes, and the MTF must sit between the
    LTF and the HTF.
  - Both files check that the HTF is longer than the MTF and the MTF longer
    than the LTF.
  - Base's own default HTF (H1) would leave no room for an H1 MTF.
- **Swing Detection.** HTF 3, MTF 5, LTF 3.
- **Internal Structure.** One `Internal_Structure_Level` (4) for every
  timeframe. Its chart drawing (`Show_Internal_Structure`) is off by
  default.
- **Hurst exponent.** `Hurst_Timeframe` (HTF), `Hurst_Candles` (100) and
  `Hurst_Minimum` (0.50, as in Base; the first version used 0.55).
- **Alerts.** Popup and push alerts announce armed setups and entries only.
- **Magic number.** `Magic_Number` is 20261002, so the two versions keep
  separate trades and daily counts on one account.

### The dashboard

**Market rows:**
- HTF Market Trend, with its Swing Structure and Internal Structure below
  it;
- MTF Market Trend;
- Hurst Exponent;
- Market Tradability and its Tradability Reason.

**Strategy rows:**
- **83% Strategy.** The state: a setup armed, a setup touched and waiting for
  its engulfing (with the candles waited so far), a position open, or
  waiting for a buy or sell setup.
- **Setup.** A, B and the entry price. B reads `(forming)` while it still
  follows price.
- **Entry Filters.** PASS, or BLOCKED with the reason:
  - Market Tradability is Not Tradable;
  - the MTF is a Transition or the other way;
  - the market has no direction.
- **Risk Today.** Trades out of the maximum and losses in a row, with
  "(done for today)" once the losses have ended the day.
- **Last Setup.** What happened to the latest setup that reached its level.
- **This Run.** Since the EA started (on TradingView, since the start of the
  chart's history): the setups found, how many reached the entry level (and
  with the confirmation, how many an engulfing confirmed), the trades, and
  the most frequent reason a setup that reached its entry was not traded.

On the LTF chart each shown setup has its Fibonacci (0%, the entry level
with its price, 100%), A / B / C and the target and stop zones. Failed
setups are dotted with their reason.
- With the engulfing confirmation, `touch` marks where price reached the
  level. C sits at the engulfing candle's close, labelled with the engulfing
  (for example `C (bullish M30 engulfing)`).
- A setup waiting for its engulfing reads `waiting for a bullish M30
  engulfing`.

### MetaTrader 5 and TradingView

- **MetaTrader 5.** Install `83% Strategy 2.0.mq5` in `MQL5/Experts`, compile
  it, and backtest it with **Every tick** modelling.
  - `Trade_Mode` is **Strategy Tester only** by default.
  - Entries are market orders: on the first tick at the level, or with the
    confirmation on the first tick after the engulfing candle closes.
  - At the end of a test run, a run summary is printed in the Journal (see
    [Why a backtest shows no trades](#why-a-backtest-shows-no-trades)).
- **TradingView.** Add `83% Strategy 2.0.pine` to an M30 chart (the LTF).
  On any other timeframe it places no orders, and the dashboard reads "Open a
  30m chart to trade". Entries are limit orders at the level, placed at a
  candle's close, or with the confirmation market orders at the engulfing
  candle's close. For a market order the stop and target are planned from
  that close; the EA plans them from its actual entry price.
- **Differences on TradingView:**
  - breakeven is checked at candle closes;
  - Pine has no spread;
  - days follow the exchange time zone;
  - a new HTF or MTF candle reaches the filters, and the market's direction,
    one LTF candle after it closes.
  - The structure is calculated on all loaded history. The EA replays three
    times Bars To Process, the same as for its direction. On the test
    markets the two directions always agreed (see below).

### Why a backtest shows no trades

The strategy trades rarely by design. Every entry needs all of these at
once:
- a market direction (the HTF Market Trend);
- Market Tradability reading Tradable: the HTF trend Bullish (Bearish) by a
  BOS with HH + HL (LL + LH), a BOS internal structure, and a Hurst exponent
  above 0.50;
- the MTF's latest break a BOS in the same direction;
- an LTF setup (an HL with heavy pressure and a break of structure) whose
  entry level is touched while A is within the last 25 LTF candles;
- with the engulfing confirmation, an engulfing within 2 candles of the
  touch.

**How often it trades.** Backtests with the default settings on 30
generated markets of 120 days each:

| Generated markets | Confirmation off (the default) | Confirmation on |
|---|---|---|
| Trending | 120 trades; 2 of the 30 markets had none | 11 trades; 20 had none |
| Mildly trending | 96 trades; 2 had none | 10 trades; 22 had none |
| Random walk (like Deriv's Volatility indices) | 80 trades; 7 had none | 5 trades; 25 had none |

With the confirmation on, most 120-day backtests make no trade at all, which
is why it is now off by default. Even with it off, expect roughly one trade
a month on one market, and none in some months. Real markets may differ from
these generated ones.

**What blocks most.** On the random-walk markets, 532 of the 612 touches were
not traded, 518 of them (97%) because Market Tradability was Not Tradable.
In those 518:
- the Hurst exponent was not above 0.50 in 58%;
- the internal structure was not a BOS in the direction in 37%;
- the swings were not HH + HL (LL + LH) in 37%;
- the HTF was only in a Transition in 20%.

One touch can fail several of these.

**When a backtest shows no trades:**
- **TradingView.** The strategy must be on an M30 chart (the LTF). On any
  other timeframe it places no orders and the dashboard reads "Open a 30m
  chart to trade". The test covers only the history the chart has loaded,
  which depends on the TradingView plan; a few months may well have no
  trade.
- **MetaTrader 5.** Test a long period (a year or more) with Every tick or
  1 minute OHLC modelling. `Trade_Mode` Off makes no trades.
- **Read the run summary.** The EA prints one in the Journal at the end of
  every test run, and the dashboard's This Run row shows the same in short.
  For example:

  ```
  83% Strategy 2.0 run summary (<symbol>, M30 setups):
    67 setups found, 15 reached the 83% level, 2 traded.
    Other endings: 32 invalidated (a new HH/LL first), 16 expired,
    4 cancelled (the market turned), 0 missed, 0 replaced.
    Not traded: Market Tradability is Not Tradable (12)
    Not traded: the H1 Market Trend was not a BOS in the setup's direction (1)
  ```

  With the confirmation it also gives the setups confirmed and the failed
  waits by cause. A run with no trades ends with why: no setup formed, none
  reached the level, none was confirmed, or the ones that reached it were
  skipped for the reasons listed.

**Trading more often.** Each of these changes the strategy, so test it:
- leave the engulfing confirmation off;
- lower `Hurst_Minimum`. At 0.30 the random-walk markets gave 164 trades
  instead of 80, and every market traded, but those trades lost 15.1R in
  total (the 80 at 0.50 made +1.9R). On the trending markets 0.30 gave 135
  trades instead of 120;
- with the confirmation, a longer `Engulfing_Window_Candles`: 4 candles gave
  39 trades against 22 with 2 (Hurst minimum 0.30, 60 trending markets).

### How it was checked

Nothing here has been compiled in MetaEditor or run in TradingView. The
checks used the test harness (MQL5 compiled as C++ against a mock terminal)
and Python mirrors:

- **Base's behaviour is unchanged.** Base's whole test suite passes against
  the 2.0 EA.
- **Every trade follows the rules.** Tick-level backtests ran on 30
  generated markets of 120 days each, with the default settings (the
  engulfing confirmation off). Every trade was rechecked with independent
  code:
  - A, the break of structure, B, the heavy pressure and the processed
    bars;
  - the entry level at the selected Fibonacci ratio, and the first touch;
  - Market Tradability recomputed: the HTF trend, its swings, an
    independently written internal structure, and a separately written
    Hurst estimator;
  - the MTF's latest break a BOS in the trade's direction;
  - the market's direction from the setup's candle to the entry;
  - the take profit, stop, 1:2 / 1:3 choice and lot size;
  - 3 trades a day, the end of the day after 2 consecutive losses, the
    trading days, and breakeven.

  All 120 trades passed. Every one of the 428 touches of a live setup was
  traded or rejected for a genuine reason. Most rejections (285 of 308) were
  Not Tradable; 22 were for the MTF not being a BOS in the setup's
  direction. The 120 trades are the same as before the engulfing
  confirmation was added.
- **The engulfing confirmation.** The same 30 markets with the
  confirmation on:
  - 57 setups were confirmed by an engulfing;
  - 11 were traded, 2 of them on an engulfing that was the touching candle
    itself;
  - 36 were rejected as Not Tradable and 2 for the MTF, and 8 because a 1:2
    stop would not be behind the engulfing candle.

  Every engulfing trade was rechecked with independent code, as well as the
  checks above:
  - the touch of the level;
  - the engulfing, found by separately written code within the window;
  - no close through A and no new HH (LL) before it;
  - the entry on the first tick after the engulfing candle closed;
  - the stop behind the engulfing candle.

  All 11 passed, and every confirmed setup was traded or rejected for a
  genuine reason. A separate test checked the engulfing rule on all 625
  combinations of two candle bodies (15 bullish and 15 bearish engulfings).
- **After a weekend.** A unit test confirms a setup on Friday's last M30
  candle and checks that the EA enters on Monday's first tick, once, and not
  on a later candle. Before this fix the EA dropped such a setup without
  entering or recording it; on the mildly trending markets one was dropped.
- **Random-walk and mildly trending markets.** The same checks passed on 30
  of each, with the confirmation off and on (the trade counts are in the
  table above).
- **The run summary.** In every backtest its trades equalled the positions
  opened, and its skipped setups the touches (or confirmations) the checks
  saw rejected. Every setup that reached its entry was either traded or
  skipped.
- **Engulfing confirmation with other settings, all passing.** These runs
  used 60 markets and a Hurst minimum of 0.30:
  - 83%: 22 trades;
  - 70.5%: 12 trades;
  - 78.6%: 18 trades;
  - 88.6%: 18 trades;
  - a window of 4 candles: 39 trades.
- **Other settings, all passing.** Most runs used a Hurst minimum of 0.30, so
  that there were more trades:
  - Hurst minimum 0.30 at 83% (135 trades);
  - entry at 70.5% (136 trades), 78.6% (149 trades) and 88.6% (120 trades);
  - HTF H2 / MTF H1 (117 trades);
  - the Hurst exponent on the MTF (88 trades).
- **Market direction.** Across these backtests and the limit tests, every
  live setup was checked against the market's direction at every candle
  (30,134 checks). Each of the 2,143 setups that ended was audited over its
  life; 113 of them were cancelled when the market turned, on the right
  candle.
- **Market Tradability.** The 2.0 EA's state and reason equal Base's (only
  the HTF selected) word for word on all 1,715 rule cases. A line-by-line
  Python copy of the 2.0 Pine rule gave the same on every case.
- **The EA and the Pine strategy agree.** The EA's setups after every closed
  candle were compared with a line-by-line Python copy of the 2.0 Pine setup
  logic:
  - **Coverage:** 23 generated markets, 4 of them with market directions
    flipping every 2 to 30 candles; several swing levels, windows (10 to 60),
    pressure settings and all four entry levels.
  - **Setups:** all 2,115 setups and 132,265 candle snapshots matched.
  - **Engulfing confirmation:** it was on in 17 of the markets, with windows
    of 2 to 4 candles. The touches, the waits (648 candle snapshots of a
    setup waiting), the 127 confirmations (with their close and stop) and
    the 360 failed waits all matched.
  - **Expiry with the confirmation:** the Pine now expires a setup before
    the candle on which its A leaves the processed candles, as the EA does.
    Before, the Pine could confirm (and trade) a setup on that candle that
    the EA never saw: 6 of 133 confirmations on these markets.
  - **Run counts:** the EA's run summary equalled the Pine's This Run
    counters on all 23 markets: 2,115 setups found, 629 reached the level,
    127 confirmed.
  - **Drawn setups:** the set the Pine draws matched the EA's on every
    candle, 40,086 setup-candles in all.
  - **Market direction:** the EA's (its replay window) and the Pine's (all
    history) matched on all 109,421 candles.
- **The tests catch mistakes.** Planting a mistake made them fail:
  - no cancellation when the market turns: 2,528 differences;
  - a fixed 83% level: 27,780 differences;
  - a Pine copy without the clear on a change of direction: 3,402
    differences;
  - an EA without the MTF filter: rule violations in 8 markets;
  - an EA that never ends the day: caught by the unit test and the
    backtests;
  - no engulfing allowed on the touching candle: 180 differences;
  - an engulfing window one candle too long: 3,068 differences;
  - an engulfing that ignores the open: caught by the 625-combination test
    (the generated markets always open at the previous close, so the
    backtests alone could not catch it);
  - the Pine without the expiry before the candle A leaves on: the run
    counts differed on 13 of the 17 markets with the confirmation;
  - the EA's old entry window, which ran by the clock: the weekend test
    fails.
- **Drawing.** Five visual runs of 120 days checked the chart at every M30
  candle (28,800 checks). Two of them had the engulfing confirmation on:
  - the live setup showed its three levels, A and B (3,294 checks);
  - the traded setups showed C and their zones (22 trades);
  - the drawn setups followed the display rule exactly, including 85 clears
    by a change of direction on the forming candle;
  - structure stayed within the processed candles.
- **The Pine file parses** with pynescript (a syntax check only).

## ORB Strategy (`ORB Strategy.mq5` and `ORB Strategy.pine`)

An Opening Range Breakout EA, with a TradingView strategy that follows the
same rules. It was built after comparing ORB with CRT (Candle Range Theory)
on the data available here. ORB was the only one of the two with an edge
beyond chance, so it is the one built. Its default exit has the highest win
rate that still kept an edge.

Nothing here has been compiled in MetaEditor, run in the MT5 Strategy Tester
or run in TradingView. The EA was checked in the test harness (MQL5 compiled
as C++ against a mock terminal), and the Pine strategy against the EA through
a line-by-line Python copy (see [How it was
checked](#how-the-orb-strategy-was-checked)). The strategy research used
Python backtests.

### ORB against CRT: the study

**What was compared.**
- **ORB**, from published work and existing EAs:
  - Zarattini and Aziz (2023), the 5-minute ORB on QQQ: enter in the
    direction of the first 5-minute candle, stop at its other end, target
    10R or the close. They report a 24% win rate and +0.13R a trade, without
    spread or slippage. An independent replication found it breaks even at
    about 2.2 cents a share of slippage.
  - Zarattini, Barbon and Aziz (2024): the plain 5-minute ORB on US stocks
    had a Sharpe ratio of 0.48. Restricted to the day's 20 "stocks in play"
    it reached 2.81. That filter needs a scan of thousands of stocks, which
    a single-symbol EA cannot do.
  - Crabel (1990): narrow opening ranges tend to come before trend days.
    This was tested as a range-width filter.
  - MQL5 ORB EAs: a London 07:00-08:00 GMT range, a breakout buffer, a fixed
    reward-to-risk and one trade per session.
- **CRT**, from the ICT-derived guides and the MQL5 CRT articles:
  - candle 1 sets the range;
  - candle 2 sweeps its high (low) and closes back inside;
  - the trade aims for the other side during candle 3.
  - Entries tested: candle 3's open, 50% of candle 2, or a retest of the
    swept level.
  - Targets tested: the other side of candle 1, its middle, or 0.5 to 1.5R,
    with the stop beyond the sweep.
  - Filters tested: the 1, 5 and 9 New York key times on H4, the sweep
    depth, where candle 2 closed, the trend and the range size.
  - CRT has no published, audited results. Guides quote 45-65% win rates.

**Data.** All of it was local; nothing was downloaded.
- EURUSD H1, April 2017 to February 2018 (5,000 candles).
- Euro Stoxx 50 futures M1, January and February 2006 (41 days).
- Daily candles:
  - GOOG, INTC, NVDA, ORCL and YHOO (1995-2015);
  - the Euro Stoxx 50 (2006).

**Method.**
- **Combinations:** every combination of the variants, 2,160 to 4,704 per
  family.
- **Costs:**
  - 1 pip round trip on EURUSD;
  - 1 point on the futures;
  - 0.10% on stocks.
- **Pessimistic fills:**
  - a stop is never closer than 4 times the cost;
  - when a candle touches both the stop and the target, the stop counts
    first.
- **Train and test:** the first 60% of each data set chose the settings;
  the last 40% tested them.
- **Shuffled control:** the same search ran on 8 copies of the data, with
  the candles shuffled within each hour of the day. That keeps the daily
  pattern of volatility but removes any real structure, so whatever the
  search finds there is luck. A real edge has to beat it.

**Results.** The share of combinations that were profitable on both the
training and the test part:

| Family | Real data | Shuffled (median) |
|---|---|---|
| EURUSD ORB | 22.3% | 8.2% |
| EURUSD CRT, H1 | 0.0% | 0.0% |
| EURUSD CRT, H4 | 0.6% | 1.4% |
| EURUSD CRT, D1 (about 40 trades) | 14.0% | 12.8% |
| Daily CRT, 5 stocks and the index | 0.1% | 0.0% |
| Futures ORB (41 days) | 8.7% | 16.4% |
| Futures CRT, H1 (41 days) | 1.0% | 2.2% |

- **ORB:** ORB on EURUSD is the only family clearly above chance. Its best
  test result was 66 trades, 39% won, +0.35R a trade and a profit factor of
  1.59. That was the London-open range, held to the close.
- **CRT:** it never beat its shuffled control where there were enough
  trades. The best H4 CRT settings from the training part lost 0.09 to 0.19R
  a trade on the test part.
- **Futures:** the futures sample (41 days, about 12 test trades a setting)
  is too small to decide anything.
- **Win rate is mostly geometry.** A small target wins often on any market.
  Choosing the highest training win rate found ORB settings that won 69-86%
  of their test trades but made only +0.03 to +0.06R a trade. The same search
  on shuffled data also found 70-80% winners. A win rate alone says little;
  what counts is how far it beats the shuffled data at the same target.

### Exits: win rate against profit

These rows use a London 08:00-09:00 range, entries until 12:00 and a close
at 16:00 London time, entering on the break with the stop on the other side.
The data is EURUSD, April 2017 to February 2018: 180 trades.

| Take profit | Win rate | Average | Profit factor | Shuffled: win rate / average |
|---|---|---|---|---|
| 0.5R | 68% | 0.00R | 0.99 | 67% / -0.04R |
| 0.75R | 61% | +0.05R | 1.15 | 60% / 0.00R |
| **1R (default)** | **57%** | **+0.09R** | **1.23** | 53% / 0.00R |
| 1.5R | 53% | +0.14R | 1.33 | 45% / +0.01R |
| None: close at 16:00 | 50% | +0.38R | 1.83 | 39% / +0.07R |

- **1R, the default.** This is the highest win rate that still beat the
  shuffled data on both win rate and average, on both parts:
  - 58% and +0.09R on the training part;
  - 55% and +0.09R on the test part.

  The edge is small, though. On the shuffled data, the 90th-percentile
  average was +0.08R.
- **Holding to the close** (`Take_Profit_R` = 0) is the stronger result:
  - it wins 11 points more often than on shuffled data;
  - it averages five times as much as on shuffled data.

  Choose it if profit matters more to you than the win rate.
- **0.75R and below** win more often, but no more often than on shuffled
  data. That is not an edge.
- **A partial close at 0.75R with the stop moved to breakeven** won 61%.
  Hourly data could not settle its average: depending on the order of
  prices inside a candle, it fell between -0.05R and +0.18R. Test it on tick
  data before relying on it.
- **Futures cross-check.** The same rules on the 2006 futures, with a
  60-minute range:
  - 1R: 59% won, +0.23R a trade;
  - held to the close: 48% won, +0.31R a trade.

  That is only 27 trades. A 15-minute range lost on the same data.

### The rules

- **Session clock.** The session times are in London time by default; New
  York time or the broker's server time can be chosen instead. See [Time
  zones](#orb-time-zones).
- **The opening range.** It is the high and low of the M1 candles from
  `Range_Start` to `Range_End` (08:00-09:00). The day is skipped when:
  - the range has fewer M1 candles than half its minutes (a holiday or a
    late open);
  - it is wider than `Max_Range_ADR_Percent` of the 10-day average daily
    range (off by default).
- **The entry.** From `Range_End` until `Last_Entry` (12:00), the first
  break decides:
  - **Break** (default): the chart price (bid) reaches the range high plus
    the buffer, and the EA buys at the ask. At the range low minus the
    buffer, it sells.
  - **Close**: a `Close_Timeframe` candle closes beyond the range. Only a
    candle that opened at or after the range end counts. The order is sent
    on the next candle's first tick.
- **One attempt a day.** The first break decides, even when it cannot be
  traded, for example because the stop is too close.
- **The stop.** It goes on the other side of the range, or at its middle.
  A sell's stop carries the spread, because sells close on the ask.
- **No trade** when the stop is closer than `Min_Stop_Spreads` (4) times the
  spread, or than the broker allows.
- **The target.** It is `Take_Profit_R` times the risk, and the risk is
  measured from the actual entry. A setting of 0 means no target.
- **The partial close** (optional). At `Partial_Close_R`, the EA closes
  `Partial_Close_Percent` of the position and moves the stop to the entry.
- **The time exit.** A position still open at `Close_Time` (16:00) on the
  day it opened is closed.
- **The size.** It is `Risk_Percent` of the balance, lost at the stop.
- **Attached late.** When the EA is attached after the range has ended:
  - if price already broke the range, there is no trade that day;
  - after `Last_Entry`, there is none either.

### ORB time zones

The EA turns server time into the Session Clock using
`Server_GMT_Offset` (the winter offset) and `Server_DST`.
- **Most MT5 brokers** run GMT+2 in winter and GMT+3 in summer on the US
  rule, so New York 17:00 is 00:00 server time. These are the defaults.
- **The London open** is then 10:00 server time for most of the year. It
  is 11:00 for two to three weeks in March and in October/November, while
  the US is on summer time and the UK is not.
- **Check your broker.** Compare the server time in Market Watch with GMT
  in winter. Set `Server_DST` to EU or None if the broker follows those.
- **Other sessions.** New York 09:30-09:45 (or 09:30-10:30) is the usual
  range for US indices. Set `Session_Clock` to New York.
- **Server time.** With `Session_Clock` on server time, nothing is
  converted: the times are the chart's.

### Inputs

- **Session:**
  - `Session_Clock`, `Range_Start`, `Range_End`, `Last_Entry`, `Close_Time`;
  - `Server_GMT_Offset`, `Server_DST`.
- **Entry:**
  - `Entry_Mode` (break or candle close), `Close_Timeframe` (close entries);
  - `Breakout_Buffer_Percent` (% of the range);
  - `Max_Range_ADR_Percent` (0 = off), `Min_Stop_Spreads`.
- **Exits:**
  - `Stop_Loss_At` (other side or middle);
  - `Take_Profit_R` (0 = hold to the Close Time);
  - `Partial_Close_R` (0 = off), `Partial_Close_Percent`.
- **Risk:** `Trade_Mode` (Strategy Tester only by default), `Risk_Percent`
  (1%), `Magic_Number`.
- **Optimization:** `Optimization_Criterion`, `Minimum_Trades`.
- **Chart:** `Show_Ranges`, `Show_Panel`, `Enable_Alerts`.

### Optimizing in the Strategy Tester

- Choose **Custom max** as the optimization criterion. The EA then
  returns `Optimization_Criterion`:
  - **Win rate** (default). It counts only with at least `Minimum_Trades`
    trades and a positive average R; otherwise it is 0. That keeps the
    optimizer from buying a high win rate with a losing system.
  - **Average R a trade.**
  - **Profit factor.**
- Use **Every tick based on real ticks**.
- Optimize on one period and confirm on a later one: the Forward setting.
  With 30 trades or fewer, no result means much.
- As the study above shows, a higher win rate from a closer target is
  usually not an edge. Compare win rates at the same `Take_Profit_R`.

### The panel and the chart

- Each day's range is a blue box, with green and red dashed break levels
  that run to the Close Time. The last 30 days stay on the chart.
- **The panel:**
  - the session times;
  - today's range (its size in points and as a % of the average daily
    range);
  - what happened today: waiting, armed, the trade, or why there was no
    trade;
  - the open position;
  - the results since the EA started: trades, win rate, average R and
    profit factor.
- At the end of a test run, the same results are printed in the Journal.

### MetaTrader 5

Install `ORB Strategy.mq5` in `MQL5/Experts` and compile it. It runs on any
chart period; the range is always built from M1 candles. `Trade_Mode` is
**Strategy Tester only** by default.

### TradingView (`ORB Strategy.pine`)

Add `ORB Strategy.pine` to a chart of 1 to 15 minutes.
- **The candles must fit the range.** The range is built from the chart's
  candles, so its start and length must be multiples of the chart's minutes.
  Otherwise each day reads "the chart's candles do not fit the opening range".
  For the default 60-minute range, any chart from 1 to 15 minutes works (30
  and 60 do too).
- **Time zones.** `Session Clock` is London, New York or the symbol's
  exchange time. TradingView applies the daylight saving itself, so there are
  no broker-offset inputs.
- **Entries:**
  - **Break:** stop orders at the range high and low, on the first tick
    beyond them. The first to fill cancels the other (an OCA group).
  - **Candle close:** the chart's own candles are used (there is no Candle
    Timeframe input). The order fills at the next candle's open.
- **The same inputs otherwise,** plus `Quantity Step`. There is no Trade
  Mode, Magic Number, minimum stop in spreads or optimization criterion: they
  have no TradingView equivalent.
- **The panel** shows the same rows as the EA's. The `Results` row gives the
  closed positions, with partial closes joined to their position: the win
  rate, average R and profit factor.
- **Alerts.** With `Alerts (entries)` on, an `alert()` call fires when a
  position opens. Create an alert on the strategy with "Any alert() function
  call" to receive it.
- **Differences from the EA:**
  - **Spread:** Pine has none. The EA's entries pay it, and its sell stops
    carry it.
  - **The range** comes from the chart's candles, not from M1 candles.
  - **Candle-close sizing:** the size of a candle-close entry is worked out
    from the signal candle's close; the EA uses the actual fill.
  - **Breakeven after a partial close:** the stop moves to the entry from
    the next candle; the EA moves it on the same tick.
  - **A gap through the break level** fills at the open. On that candle the
    target is still planned from the level; from the next candle it is
    measured from the fill.

### How the ORB Strategy was checked

- **Every trade follows the rules.** The harness ran tick-level backtests
  covering:
  - the 2006 futures M1 data with 10 settings;
  - 4 generated EURUSD-like markets of 120 days with 4 settings each;
  - 20 runs that attach the EA mid-morning.

  The settings included:
  - break and close entries, including a range end inside a candle;
  - the middle stop, buffers and the range-width filter;
  - holding to the close and partial closes;
  - New York and London clocks, and US and EU server DST.

  Every one of the 2,151 trades matched an independently written model of
  the rules. That model has its own range, filters, time zones, stop, target
  and size arithmetic. Each trade's entry time, side, price, volume and
  stored risk matched, and so did every close (price, volume and time).
- **Time zones.** 250,344 server-to-clock conversions matched a table of
  published DST dates (2016-2027), and the DST functions were checked at the
  40 changes. Four readable anchors were checked too, for example London
  08:00 = 11:00 server time on 18 March 2024.
- **The results, OnTester and the panel** matched the deal history, also
  while a position was open.
- **Inputs.** 8 invalid input combinations were rejected.
- **The EA matches the research model.** On the futures data it took the
  same trades as the Python model in the same direction (29 of 29 days), with
  the same win rate. The average R differed only by the cost model (-0.60
  against -0.65R).
- **The Pine strategy matches the EA.** A line-by-line Python copy of the Pine
  script ran with TradingView's order handling:
  - orders placed at a candle's close work from the next candle;
  - stop and limit orders fill at their price, or at the open when a candle
    opens beyond them;
  - each candle runs open, the nearer extreme, the other extreme, close;
  - the first entry to fill cancels the other.

  The EA ran on the same 1-minute candles, along the same price path one tick
  at a time, without spread. There were 22 runs: the futures data with 10
  settings, and 3 generated markets with 4 settings each (London and New York
  clocks, partial closes, close entries).
  - **Trade for trade:** 21 runs matched, 1,752 positions in all. The entry
    candle, side, price and size matched, and so did every close (candle,
    price and size).
  - **Candle-close entries on the futures:** they matched on timing and
    prices, but 25 of 39 sizes differed, because Pine sizes from the signal
    candle's close.
  - **Other chart periods:** on 5- and 15-minute charts, the Pine copy traded
    the same 39 days, in the same direction, as on 1-minute candles. A range
    that does not fit the candles (09:00-09:10 on 15 minutes) was skipped
    every day.
  - **An EA bug found and fixed.** A price exactly on the partial-close level
    could miss it through floating-point rounding, so the EA closed a tick
    later. It now allows a thousandth of a point of slack, and the harness
    model was corrected the same way.
  - **Planted mistakes in the Pine copy:** 9 of 10 made the comparison fail.
    Among them were the wrong last-entry or close time, no breakeven, no OCA
    group, the range without its first candle, an unrounded break level and a
    London clock without DST. The tenth allowed close entries on the range's
    last candle, which cannot change a trade, because that candle closes
    inside the range.
- **The Pine file parses** with pynescript (a syntax check only).
- **The tests catch mistakes.** Each of 20 planted mistakes made them fail.
  Among them:
  - triggering buys on the ask;
  - a sell stop without the spread;
  - a close one minute late;
  - the range including its end candle;
  - DST on the wrong Sunday or an hour late;
  - a target or size 10% off;
  - no breakeven, or no last-entry time;
  - close entries from a candle that began inside the range;
  - a win rate that ignores the average;
  - open trades counted in the results;
  - no check for a range already broken when attaching late;
  - a London clock without DST;
  - a panel that never refreshes.
- **Limits:**
  - the backtest figures come from a Python model of the rules on hourly
    EURUSD data, not from the EA itself;
  - the data is one currency pair over 10 months, a strongly trending
    period (1.07 to 1.25);
  - with hourly candles, the order of prices inside an hour is unknown, so
    the stop was counted first.

  Results on other symbols and years will differ, and past results do not
  promise future ones.

**Sources:**
- Zarattini and Aziz, "Can Day Trading Really Be Profitable?" (SSRN
  4416622);
- an independent replication
  (https://github.com/giovannibrusco/zarattini-2023-orb-qqq);
- Zarattini, Barbon and Aziz, "A Profitable Day Trading Strategy For The
  U.S. Equity Market" (SSRN 4729284);
- Crabel, "Day Trading with Short Term Price Patterns and Opening Range
  Breakout" (1990);
- MQL5 articles 20339 (session ORB) and 20323 (CRT).
