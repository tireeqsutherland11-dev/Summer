# MetaTrader 5 Indicators and Tools

## Liquidity Sweep Strategy

`Liquidity Sweep Strategy.mq5` contains the complete Base market-structure EA
and the complete Model Base liquidity-swing EA in one Expert Advisor. Each
engine retains its own settings, calculations, objects, and object-name prefix.
The Base analysis, filters, dashboard, boundaries, alerts, and structure logic
continue to run independently from Model Base's pivot, overlap-count, volume,
qualification, zone, and level logic.

The active chart period decides which engine may draw. Model Base draws its
liquidity objects only when the chart period equals `Setup_Entry_Timeframe`
(MTF). Base draws its full overlays on `Structure_Timeframe` or
`Boundary_Timeframe` (HTF), and also draws its chart-timeframe HH/HL/LH/LL
points on the MTF. This preserves the standalone Base swing detection on the
setup chart instead of substituting Model Base's separate, typically longer
liquidity-pivot lookback. On all other chart periods both engines remain
visually hidden; Base's analytical processing and optional alerts remain active.

On the MTF chart, Base identifies structure points as `HH`, `LH`, `HL`, or
`LL` using `Swing_Detection_Length`; numeric volume labels are not drawn.
Model Base independently uses `Pivot_Lookback` to select liquidity areas, which
are filtered by the current HTF/Structure market bias: a bearish bias draws
areas only from MTF lower highs (`LH`), while a bullish bias draws areas only
from MTF higher lows (`HL`). A consolidating HTF bias draws no liquidity area.

### Manual structure and liquidity feedback

The `Enable_Manual_Feedback` input is enabled by default and displays a review
panel in the chart's top-right corner. Disable it when the annotation controls
are not needed. To review an identified `HH`, `HL`, `LH`, `LL`, or liquidity
swing, first select **Correct point** or **Incorrect point**, then click its
label or liquidity object. The EA places an `OK` or `X` beside the point and
appends the review to a CSV file.

To report a point the EA missed, select **Missed HH**, **Missed HL**,
**Missed LH**, **Missed LL**, **Missed liquidity H**, or **Missed liquidity L**,
then click the precise chart time and price where the point belongs. A gold
marker confirms the annotation and the one-shot missed-point mode clears after
the click. **Cancel** clears any active mode without recording feedback.

`Feedback_CSV_File` controls the append-only file name. The CSV includes the
recording time, symbol, chart timeframe, category, verdict, point time, price,
and source object name. It is written with MQL5's `FILE_COMMON` flag, so it
survives EA restarts and can be shared by terminal instances. Chart markers are
session aids; the CSV is the durable feedback record.

Install the EA in `MQL5/Experts`, compile it in MetaEditor, and attach
**Liquidity Sweep Strategy** to one chart. Changing chart timeframe is handled
immediately by `OnChartEvent`, while the shared two-second timer retries builds
until MT5 finishes synchronizing all requested histories. A chart restart is
therefore not required. Model Base always calculates from
`Setup_Entry_Timeframe`, including pivot detection, sweep/cross detection,
overlap counts, volume, and projection. Its liquidity pivots are reconstructed
from a fixed window of the latest 400 MTF candles, so changing the visible
range or resizing the chart does not change the identified points. When
enabled, `Intrabar_Timeframe` must be lower than `Setup_Entry_Timeframe`. The
merged EA remains analysis and visualisation software and does not place trades.

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
the latest 400 candles, independently of the visible chart range. It does not
start a history-download retry timer, and rebuilds on each new chart bar and
when the chart changes. MetaTrader tick volume is used because
broker-independent centralized volume is not universally available.

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
visible chart does not yet contain a complete pivot window. If the chart
reports zero swings with strong-departure qualification enabled, disable that
option first and then tune its thresholds for the symbol and timeframe.

## Road

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
- **Tradable** always requires an established Bullish or Bearish HTF bias: its
  latest break must be a continuation BOS that creates a new HH or LL, rather
  than a transitional CHoCH. The enabled tradeability timeframe directions
  must also agree, and when LTF participation is enabled its latest break must
  be BOS. It is an analytical state, not an instruction to place a trade.
- **Optimal Conditions** applies only the requirements enabled in the
  **Optimal Conditions** input group. By default it checks timeframe
  correlation, boundary clearance, extension, relative tick volume, and
  relative true-range momentum.
- BOS/CHoCH alerts describe confirmed structure events and are intentionally
  independent of the qualification filters.

All calculations use closed candles. A wick beyond a swing is not considered a
break; a candle must close beyond it.

## Configuration notes

- `Bars_To_Process` controls replay depth and therefore startup/rebuild cost.
  Start with the default 100 and raise it only when more context is needed.
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
