#property copyright "Market Trend Analyser conversion"
#property version   "2.34"
#property strict
#property description "BASE: MT5 port of the Market Trend Analyser Pine Script."
#property description "Signal/visualisation EA only; the source indicator contains no trading rules."

enum BASE_MA_TYPE { BASE_SMA=0, BASE_EMA=1 };
enum BASE_MA_FILTER_MODE { BASE_PRICE_ABOVE_BELOW=0, BASE_FULL_BODY_CLOSE=1 };
enum BASE_SESSION { BASE_NEW_YORK=0, BASE_LONDON=1, BASE_TOKYO=2, BASE_SYDNEY=3, BASE_CUSTOM=4, BASE_24X7=5 };
enum BASE_ADX_SCOPE { BASE_BOS_ONLY=0, BASE_BOS_AND_CHOCH=1 };
enum BASE_ATR_MODE { BASE_ATR_MINIMUM=0, BASE_ATR_MAXIMUM=1, BASE_ATR_RANGE=2 };
enum BASE_LABEL_SIZE { BASE_TINY=7, BASE_SMALL=9, BASE_NORMAL=11, BASE_LARGE=14 };

input group "Timeframes"
input ENUM_TIMEFRAMES Structure_Timeframe=PERIOD_H4; // HTF
input ENUM_TIMEFRAMES Setup_Entry_Timeframe=PERIOD_H1; // MTF
input ENUM_TIMEFRAMES LTF_Timeframe=PERIOD_M15; // LTF

input group "Trend Analysis Timeframes"
input bool Use_HTF=true; // Use HTF
input bool Use_MTF=true; // Use MTF
input bool Use_LTF=false; // Use LTF

input group "Structure Bar Processing"
input int Bars_To_Process=100;

input group "Swing Detection Sensitivity"
input int HTF_Swing_Sensitivity=50; // HTF Swing Sensitivity 
input int MTF_Swing_Sensitivity=50; // MTF Swing Sensitivity 
input int LTF_Swing_Sensitivity=50; // LTF Swing Sensitivity 
input bool Show_Swing_Points=true;

input group "BOS Display"
input bool Show_BOS_Labels=true;
input color Bullish_BOS_Color=clrBlue;
input color Bearish_BOS_Color=clrBlue;

input group "CHoCH Display"
input bool Show_CHoCH_Labels=true;
input color Bullish_CHoCH_Color=clrRed;
input color Bearish_CHoCH_Color=clrRed;

input group "LS Display"
input bool Show_LS_Labels=true;
input color Bullish_LS_Color=C'229,184,0'; // Bullish LS Color (a failed bullish CHoCH)
input color Bearish_LS_Color=C'229,184,0'; // Bearish LS Color (a failed bearish CHoCH)

input group "Labels and Lines"
input BASE_LABEL_SIZE Label_Size=BASE_SMALL;
input bool Show_Structure_Lines=true;
input ENUM_LINE_STYLE Line_Style=STYLE_DASH;
input int Line_Width=1;

input group "MA Filter (HTF)"
input bool Use_HTF_MA_Filter=true;
input int HTF_MA_Length=50;
input BASE_MA_TYPE HTF_MA_Type=BASE_EMA; // MA Type
input bool Show_HTF_MA_Line=false;
input color HTF_MA_Color=clrBlue;

input group "MA Filter (MTF)"
input bool Use_MTF_MA_Filter=true;
input int MTF_MA_Length=100;
input BASE_MA_TYPE MTF_MA_Type=BASE_EMA; // MA Type
input bool Show_MTF_MA_Line=false;
input color MTF_MA_Color=clrOrange;

input group "Session Filter"
input bool Use_Session_Filter=false;
input BASE_SESSION Session_Preset=BASE_NEW_YORK;
input string Custom_Session="0930-1600";
input int Custom_UTC_Offset_Minutes=0;
input int Server_UTC_Offset_Minutes=0;

input group "ADX Filter"
input bool Use_ADX_Filter=true;
input int ADX_Length=14;

input group "ATR Filter"
input bool Use_ATR_Filter=true;
input int ATR_Length=14;

input group "Optimal Conditions"
input bool Use_Timeframe_Correlation_For_Optimal=true;
input bool Use_Healthy_Extension_For_Optimal=false;
input bool Use_Market_Volume_For_Optimal=true;
input bool Use_Price_Momentum_For_Optimal=false;

input group "Alerts"
input bool Enable_Popup_Alerts=false;
input bool Enable_Push_Notifications=false;

// Internal tuning values are deliberately kept out of the Inputs dialog. The
// streamlined UI exposes only settings that are useful during normal use.
const BASE_MA_FILTER_MODE HTF_MA_Filter_Mode=BASE_PRICE_ABOVE_BELOW;
const BASE_MA_FILTER_MODE MTF_MA_Filter_Mode=BASE_PRICE_ABOVE_BELOW;
const double ADX_Minimum=25.0;
const BASE_ADX_SCOPE Apply_ADX_Filter_To=BASE_BOS_ONLY;
const BASE_ATR_MODE ATR_Filter_Mode=BASE_ATR_MINIMUM;
const double ATR_Minimum=1.0;
const double ATR_Maximum=10.0;
const bool Use_Optimal_Conditions_Meter=true;
const double Maximum_Extension_ATR=3.0;
const int Volume_Average_Length=20;
const double Volume_Minimum_Ratio=0.50;
const double Volume_Maximum_Ratio=2.00;
const int Momentum_Average_Length=20;
const double Momentum_Minimum_Ratio=0.50;
const double Momentum_Maximum_Ratio=2.00;

// HH/HL/LH/LL identification uses two sets of the same two filters:
//  * swing strength: the candles on each side that a swing high (low) must
//    beat, which is also how many candles it takes to confirm;
//  * swing size: how far a new swing must travel from the previous opposite
//    swing, in ATR of the swing candle.  It removes small pullbacks (minor
//    LH/HL swings); a swing beyond the previous high/low always counts.
// The Sensitive set finds quick, detailed swings; the Smooth set keeps only
// major ones.  Each timeframe's Swing Sensitivity blends the two: 0 uses the
// Smooth set, 100 the Sensitive set and 50 the exact average of both.
const int SENSITIVE_SWING_STRENGTH=2;
const double SENSITIVE_SWING_SIZE_ATR=1.0;
const int SMOOTH_SWING_STRENGTH=4;
const double SMOOTH_SWING_SIZE_ATR=3.0;
const int SWING_ATR_LENGTH=14;

// The bias is Consolidation / Undefined when either condition holds:
//  * sporadic structure: the BOS/CHoCH breaks since the oldest of the last
//    SPORADIC_LABELS HH/HL/LH/LL labels change direction at least
//    SPORADIC_FLIPS times (for example bullish, bearish, bullish);
//  * CHoCH trap: at least two CHoCHs since the last BOS that confirmed its
//    direction, the latest within CHOCH_TRAP_AREA_ATR ATR of an earlier one.
const int SPORADIC_LABELS=5;
const int SPORADIC_FLIPS=2;
const double CHOCH_TRAP_AREA_ATR=4.0;

string g_prefix="";
bool g_built=false;
long g_foreground=-1;       // the chart's own "chart on foreground" setting

// Label layout (see PlaceBreakLabel): the chart area each drawing covers, in
// candles and prices, and the chart's current scale.
struct BASE_BOX
  {
   int from;
   int to;
   double low;
   double high;
  };
BASE_BOX g_boxes[];
double g_bar_px=8.0;        // pixels per candle
double g_price_px=0.0;      // price per pixel
long g_layout_scale=-1;
datetime g_last_ltf_bar=0;
datetime g_last_structure_bar=0;
datetime g_last_setup_bar=0;
int g_htf_ma_handle=INVALID_HANDLE;
int g_mtf_ma_handle=INVALID_HANDLE;
int g_adx_handle=INVALID_HANDLE;
int g_atr_handle=INVALID_HANDLE;
int g_ltf_atr_handle=INVALID_HANDLE;

// Every replay covers this many times the displayed history.  The extra,
// undrawn candles let the trend and the HH/HL/LH/LL labels settle before the
// first displayed candle, so the left edge of the chart and the bias are not
// based on a cold start.
const int STRUCTURE_WARMUP_FACTOR=3;

struct BASE_STRUCTURE_STATE
  {
   int direction;           // trend: 1 bullish, -1 bearish, 0 not yet established
   bool last_break_was_bos;  // false after a CHoCH until the next BOS
   int last_high_kind;       // 1 HH, -1 LH, 0 untyped first high
   int last_low_kind;        // 1 LL, -1 HL, 0 untyped first low
   bool have_high;
   bool have_low;
   double last_high;
   double last_low;
   datetime last_high_time;
   datetime last_low_time;
   // The unbroken levels whose next close-through is a BOS (hh/ll) or starts
   // a CHoCH (lh/hl).
   bool have_hh;
   bool have_lh;
   bool have_ll;
   bool have_hl;
   double hh;
   double lh;
   double ll;
   double hl;
   // Consolidation / Undefined (see ClassifyConsolidation).
   int consolidation;       // bit 1: sporadic 5-label sequence, bit 2: CHoCHs without a BoS
   int labels_from;         // points index of the oldest of the last five labels, -1 if fewer
   int trap_from;           // events index of the first CHoCH of the trap, -1 if none
  };

// One accepted structure point.  A point is superseded when a more extreme
// pivot is confirmed before the opposite leg begins (see AcceptStructureHigh).
struct BASE_STRUCTURE_POINT
  {
   int pivot;               // bar index of the swing candle
   int confirmed;           // bar index on which the swing was accepted
   datetime time;
   double price;
   int side;                // 1 high, -1 low
   int kind;                // 1 HH/LL, -1 LH/HL, 0 untyped
   bool superseded;
  };

// One close-confirmed structure break.
struct BASE_STRUCTURE_EVENT
  {
   int bar;                 // candle on which the event became known
   int break_bar;           // candle that closed through the level
   int direction;           // 1 bullish, -1 bearish
   bool bos;                // true BOS (continuation), false CHoCH
   datetime swing_time;     // pivot time of the broken level
   double level;
   bool ls;                 // a CHoCH reclassified as a liquidity sweep (LS)
   int ls_bar;              // candle on which the LS became known, -1 if none
   double origin;           // CHoCH: its protected swing (0 when not watched)
   double extreme;          // CHoCH: the old trend's most recent identified LL/HH
  };

ENUM_TIMEFRAMES SetupTimeframe()
  {
   return Setup_Entry_Timeframe==PERIOD_CURRENT?(ENUM_TIMEFRAMES)_Period:Setup_Entry_Timeframe;
  }

ENUM_TIMEFRAMES LTFTimeframe()
  {
   return LTF_Timeframe==PERIOD_CURRENT?(ENUM_TIMEFRAMES)_Period:LTF_Timeframe;
  }

ENUM_TIMEFRAMES BASETimeframe()
  {
   return Structure_Timeframe==PERIOD_CURRENT?(ENUM_TIMEFRAMES)_Period:Structure_Timeframe;
  }

string TimeframeName(const ENUM_TIMEFRAMES timeframe)
  {
   // EnumToString returns "PERIOD_H1"; alerts and tooltips only need "H1".
   return StringSubstr(EnumToString(timeframe),7);
  }

struct BASE_SWING_FILTER
  {
   int strength;            // candles on each side a swing must beat
   double size_atr;         // minimum move from the previous opposite swing, in ATR
  };

// The working filters: the Smooth and Sensitive sets blended by a timeframe's
// Swing Sensitivity (50 = the average of the two sets).
BASE_SWING_FILTER SwingFilter(const int sensitivity)
  {
   double weight=MathMax(0,MathMin(100,sensitivity))/100.0;
   BASE_SWING_FILTER filter;
   filter.strength=(int)MathRound(SMOOTH_SWING_STRENGTH+
                                  (SENSITIVE_SWING_STRENGTH-SMOOTH_SWING_STRENGTH)*weight);
   filter.size_atr=SMOOTH_SWING_SIZE_ATR+(SENSITIVE_SWING_SIZE_ATR-SMOOTH_SWING_SIZE_ATR)*weight;
   return filter;
  }

// The chart draws its own timeframe with the sensitivity of the matching
// HTF, MTF or LTF input; any other chart period uses the HTF sensitivity.
int ChartSensitivity(const ENUM_TIMEFRAMES timeframe)
  {
   if(timeframe==BASETimeframe()) return HTF_Swing_Sensitivity;
   if(timeframe==SetupTimeframe()) return MTF_Swing_Sensitivity;
   if(timeframe==LTFTimeframe()) return LTF_Swing_Sensitivity;
   return HTF_Swing_Sensitivity;
  }

int StructureBars()
  {
   return MathMax(100,MathMin(Bars_To_Process,100000));
  }

// Displayed history on another timeframe covers the same elapsed time as
// Bars_To_Process on the structure timeframe (100 H1 bars become 400 M15).
int ChartStructureBars(const ENUM_TIMEFRAMES timeframe)
  {
   int structure_seconds=PeriodSeconds(BASETimeframe());
   int chart_seconds=PeriodSeconds(timeframe);
   int wanted=StructureBars();
   if(structure_seconds>0 && chart_seconds>0)
      wanted=(int)MathCeil((double)StructureBars()*structure_seconds/chart_seconds);
   return MathMax(2*MathMax(SMOOTH_SWING_STRENGTH,SENSITIVE_SWING_STRENGTH)+2,MathMin(wanted,100000));
  }

int ReplayBars(const int displayed)
  {
   return MathMin(100000,displayed*STRUCTURE_WARMUP_FACTOR);
  }

ENUM_MA_METHOD BASEMAMethod(const BASE_MA_TYPE value)
  {
   return value==BASE_EMA?MODE_EMA:MODE_SMA;
  }

// A swing high must exceed the N candles on its left and stay above the N
// candles on its right.  Equal highs (a double top) therefore form one swing
// owned by the latest candle of the plateau instead of cancelling each other
// out and leaving the swing unidentified.  Swing lows mirror this rule.
bool PivotHigh(const MqlRates &rates[],const int total,const int index,const int length)
  {
   if(index-length<0 || index+length>=total) return false;
   double value=rates[index].high;
   for(int i=index-length;i<index;i++)
      if(rates[i].high>value) return false;
   for(int i=index+1;i<=index+length;i++)
      if(rates[i].high>=value) return false;
   return true;
  }

bool PivotLow(const MqlRates &rates[],const int total,const int index,const int length)
  {
   if(index-length<0 || index+length>=total) return false;
   double value=rates[index].low;
   for(int i=index-length;i<index;i++)
      if(rates[i].low<value) return false;
   for(int i=index+1;i<=index+length;i++)
      if(rates[i].low<=value) return false;
   return true;
  }

// Structure must alternate between a high leg and a low leg.  When several
// same-side pivots are confirmed before the opposite leg appears, they are one
// swing rather than several contrasting structure points: retain only the
// highest high or lowest low.  The reference is the extreme from the previous
// same-side leg, so replacing a candidate does not change what it is compared
// against when deciding HH/LH or LL/HL.  A new leg must also travel at least
// min_size from the previous opposite swing, unless it takes out the previous
// swing on its side: a small LH/HL is a pullback inside the current leg, not
// a swing, while every HH/LL counts because it breaks a structure level.
bool AcceptStructureHigh(const double value,bool &have_high,double &last_high,
                         int &last_side,bool &have_reference,double &reference,
                         int &kind,const bool have_low,const double last_low,
                         const double min_size)
  {
   if(last_side==1)
     {
      if(value<=last_high) return false;
      last_high=value;
      kind=have_reference?(value>reference?1:-1):0;
      return true;
     }
   if(have_low && value-last_low<min_size && !(have_high && value>last_high)) return false;
   have_reference=have_high;
   reference=last_high;
   kind=have_high?(value>last_high?1:-1):0;
   have_high=true;
   last_high=value;
   last_side=1;
   return true;
  }

bool AcceptStructureLow(const double value,bool &have_low,double &last_low,
                        int &last_side,bool &have_reference,double &reference,
                        int &kind,const bool have_high,const double last_high,
                        const double min_size)
  {
   if(last_side==-1)
     {
      if(value>=last_low) return false;
      last_low=value;
      kind=have_reference?(value<reference?1:-1):0;
      return true;
     }
   if(have_high && last_high-value<min_size && !(have_low && value<last_low)) return false;
   have_reference=have_low;
   reference=last_low;
   kind=have_low?(value<last_low?1:-1):0;
   have_low=true;
   last_low=value;
   last_side=-1;
   return true;
  }

int AddStructurePoint(BASE_STRUCTURE_POINT &points[],const int pivot,const int confirmed,
                      const MqlRates &bar,const int side,const int kind)
  {
   int index=ArraySize(points);
   ArrayResize(points,index+1,64);
   points[index].pivot=pivot;
   points[index].confirmed=confirmed;
   points[index].time=bar.time;
   points[index].price=side>0?bar.high:bar.low;
   points[index].side=side;
   points[index].kind=kind;
   points[index].superseded=false;
   return index;
  }

void AddStructureEvent(BASE_STRUCTURE_EVENT &events[],BASE_STRUCTURE_STATE &state,
                       const int bar,const int break_bar,const int direction,const bool bos,
                       const datetime swing_time,const double level)
  {
   int index=ArraySize(events);
   ArrayResize(events,index+1,64);
   events[index].bar=bar;
   events[index].break_bar=break_bar;
   events[index].direction=direction;
   events[index].bos=bos;
   events[index].swing_time=swing_time;
   events[index].level=level;
   events[index].ls=false;
   events[index].ls_bar=-1;
   events[index].origin=0.0;
   events[index].extreme=0.0;
   state.direction=direction;
   state.last_break_was_bos=bos;
  }

// The direction of the latest event before `index` that is not an LS.
int PreviousDirection(const BASE_STRUCTURE_EVENT &events[],const int index)
  {
   for(int i=index-1;i>=0;i--)
      if(!events[i].ls) return events[i].direction;
   return 0;
  }

// One identified swing that a candle close can break.  `point` is the swing's
// index in the structure points.
struct BASE_LEVEL
  {
   bool active;
   double price;
   datetime time;
   int point;
  };

// A CHoCH whose LH (bullish) or HL (bearish) has been broken and which waits
// for the swing that confirms it: an HH (bullish) or LL (bearish) after the
// broken swing.
struct BASE_CHOCH_CANDIDATE
  {
   int direction;           // 1 bullish, -1 bearish, 0 none
   int break_bar;           // candle that closed through the LH/HL
   double level;            // the broken LH/HL
   datetime level_time;
   int level_point;
  };

void SetLevel(BASE_LEVEL &level,const BASE_STRUCTURE_POINT &points[],const int index)
  {
   level.active=true;
   level.price=points[index].price;
   level.time=points[index].time;
   level.point=index;
  }

// A swing is identified once the opposite leg after it has begun: no later
// pivot can replace it, so it stays marked on the chart.  Only then does it
// become the HH/LH (or LL/HL) whose close-through is a break.
void IdentifySwing(BASE_LEVEL &extreme,BASE_LEVEL &correction,
                   const BASE_STRUCTURE_POINT &points[],const int index)
  {
   if(index<0) return;
   if(points[index].kind>0) SetLevel(extreme,points,index);
   if(points[index].kind<0) SetLevel(correction,points,index);
  }

void StartCHoCH(BASE_CHOCH_CANDIDATE &choch,const int direction,const int bar,
                const BASE_LEVEL &level)
  {
   choch.direction=direction;
   choch.break_bar=bar;
   choch.level=level.price;
   choch.level_time=level.time;
   choch.level_point=level.point;
  }

// Drops a candidate.  While the broken LH/HL is still the latest swing on its
// side, it stays the most recent LH/HL and a later close through it is a
// fresh break.
void CancelCHoCH(BASE_CHOCH_CANDIDATE &choch,BASE_LEVEL &lh,BASE_LEVEL &hl,
                 const int high_point,const int low_point)
  {
   BASE_LEVEL restored;
   restored.active=true;
   restored.price=choch.level;
   restored.time=choch.level_time;
   restored.point=choch.level_point;
   if(choch.direction>0 && high_point==choch.level_point) lh=restored;
   if(choch.direction<0 && low_point==choch.level_point) hl=restored;
   choch.direction=0;
  }

// The swings after the broken LH have made an HH (bullish), or after the
// broken HL an LL (bearish), and no LL (HH) has formed after it since.
bool CHoCHComplete(const BASE_CHOCH_CANDIDATE &choch,const BASE_STRUCTURE_POINT &points[],
                   const int high_point,const int low_point)
  {
   int extreme=choch.direction>0?high_point:low_point;
   int opposite=choch.direction>0?low_point:high_point;
   return extreme>choch.level_point && points[extreme].kind>0 &&
          (opposite<extreme || points[opposite].kind<0);
  }

// A CHoCH that reversed a trend is watched while it is the latest event: if
// the old trend carries on instead, it was a liquidity sweep (LS).
//  * Protected swing (origin): the swing the breaking move started from, the
//    last low before the HH of a bullish CHoCH (the last high before the LL
//    of a bearish one).
//  * Extreme: the old trend's most recent identified LL (bullish CHoCH) or
//    HH (bearish CHoCH).
//  * Trigger: a close through the protected swing.
//  * Confirmation: the old trend carries on beyond its extreme, by a close
//    (which is also the old trend's BOS) or by a swing, before anything else
//    prints.  A BOS in the CHoCH's direction or an opposite CHoCH ends the
//    watch, and the CHoCH stands.
struct BASE_LS_WATCH
  {
   int event;               // events index of the watched CHoCH, -1 if none
   int direction;           // the CHoCH's direction
   double origin;
   double extreme;
   int prior_direction;     // the trend before the CHoCH
   bool prior_bos;
   bool triggered;          // a close has broken the protected swing
   bool beyond;             // a swing beyond the extreme has formed since
  };

bool LSWatching(const BASE_LS_WATCH &watch,const BASE_STRUCTURE_EVENT &events[])
  {
   return watch.event>=0 && watch.event==ArraySize(events)-1;
  }

// A swing on the old trend's side (side -1 low, 1 high) accepted while
// watching: beyond the extreme it shows the old trend carrying on.  Returns
// true when that confirms the LS.
bool LSSwing(BASE_LS_WATCH &watch,const BASE_STRUCTURE_EVENT &events[],const int side,
             const double price)
  {
   if(!LSWatching(watch,events) || watch.direction!=-side) return false;
   if(side<0?price<watch.extreme:price>watch.extreme) watch.beyond=true;
   return watch.triggered && watch.beyond;
  }

// A close while watching.  Returns true when it confirms the LS.
bool LSClose(BASE_LS_WATCH &watch,const BASE_STRUCTURE_EVENT &events[],const double close)
  {
   if(!LSWatching(watch,events)) return false;
   bool bullish=watch.direction>0;
   if(bullish?close<watch.origin:close>watch.origin) watch.triggered=true;
   return watch.triggered && (watch.beyond || (bullish?close<watch.extreme:close>watch.extreme));
  }

// The CHoCH was a liquidity sweep: it is relabelled LS and the trend it
// changed is restored, as if it had never printed.
void ConfirmLS(BASE_STRUCTURE_EVENT &events[],BASE_STRUCTURE_STATE &state,
               BASE_LS_WATCH &watch,const int bar)
  {
   events[watch.event].ls=true;
   events[watch.event].ls_bar=bar;
   state.direction=watch.prior_direction;
   state.last_break_was_bos=watch.prior_bos;
   watch.event=-1;
  }

void ConfirmCHoCH(BASE_STRUCTURE_EVENT &events[],BASE_STRUCTURE_STATE &state,
                  const int bar,BASE_CHOCH_CANDIDATE &choch,BASE_LS_WATCH &watch,
                  const BASE_STRUCTURE_POINT &points[],const int high_point,const int low_point,
                  const BASE_LEVEL &hh,const BASE_LEVEL &ll)
  {
   int prior_direction=state.direction;
   bool prior_bos=state.last_break_was_bos;
   int direction=choch.direction;
   AddStructureEvent(events,state,bar,choch.break_bar,direction,false,
                     choch.level_time,choch.level);
   choch.direction=0;
   watch.event=-1;
   int origin=direction>0?low_point:high_point;
   bool have_extreme=direction>0?ll.time>0:hh.time>0;
   if(prior_direction==0 || origin<0 || !have_extreme) return;
   int index=ArraySize(events)-1;
   events[index].origin=points[origin].price;
   events[index].extreme=direction>0?ll.price:hh.price;
   watch.event=index;
   watch.direction=direction;
   watch.origin=events[index].origin;
   watch.extreme=events[index].extreme;
   watch.prior_direction=prior_direction;
   watch.prior_bos=prior_bos;
   watch.triggered=false;
   watch.beyond=false;
  }

// Consolidation / Undefined: flags the replay's current state when either
//  1. sporadic structure: the breaks since the oldest of the last five
//     HH/HL/LH/LL labels change direction at least twice, or
//  2. CHoCH trap: two or more CHoCHs since the last BOS that confirmed its
//     direction (a BOS following an event in the same direction), the latest
//     within CHOCH_TRAP_AREA_ATR ATR of an earlier one.
// Events are in time order and a CHoCH's break candle is never before an
// earlier event, so break candles can be compared with label candles.
void ClassifyConsolidation(const BASE_STRUCTURE_POINT &points[],const BASE_STRUCTURE_EVENT &events[],
                           const double atr,BASE_STRUCTURE_STATE &state)
  {
   state.consolidation=0;
   state.labels_from=-1;
   state.trap_from=-1;
   int labels=0;
   for(int k=ArraySize(points)-1;k>=0 && labels<SPORADIC_LABELS;k--)
      if(!points[k].superseded && points[k].kind!=0)
        {
         labels++;
         state.labels_from=k;
        }
   if(labels<SPORADIC_LABELS) state.labels_from=-1;
   int event_count=ArraySize(events);
   if(state.labels_from>=0)
     {
      int flips=0,previous=0;
      for(int i=0;i<event_count;i++)
        {
         if(events[i].ls || events[i].break_bar<points[state.labels_from].pivot) continue;
         if(previous!=0 && events[i].direction!=previous) flips++;
         previous=events[i].direction;
        }
      if(flips>=SPORADIC_FLIPS) state.consolidation|=1;
     }
   // An LS is not a break: it neither flips nor joins the trap.
   int start=0;
   for(int i=event_count-1;i>0;i--)
      if(!events[i].ls && events[i].bos && PreviousDirection(events,i)==events[i].direction)
        {
         start=i+1;
         break;
        }
   int latest=-1;
   for(int i=event_count-1;i>=start && latest<0;i--)
      if(!events[i].bos && !events[i].ls) latest=i;
   if(latest<0) return;
   for(int i=start;i<latest;i++)
      if(!events[i].bos && !events[i].ls &&
         MathAbs(events[i].level-events[latest].level)<=CHOCH_TRAP_AREA_ATR*atr)
        {
         state.consolidation|=2;
         state.trap_from=i;
         return;
        }
  }

// Average true range over SWING_ATR_LENGTH candles (fewer at the start) at
// every candle.  It sizes the minimum swing from the swing candle and the
// candles before it only, so it never looks ahead.
void SwingATR(const MqlRates &rates[],const int total,double &atr[])
  {
   ArrayResize(atr,total);
   double ranges[];
   ArrayResize(ranges,total);
   double sum=0.0;
   for(int i=0;i<total;i++)
     {
      double range=rates[i].high-rates[i].low;
      if(i>0)
         range=MathMax(range,MathMax(MathAbs(rates[i].high-rates[i-1].close),
                                     MathAbs(rates[i].low-rates[i-1].close)));
      ranges[i]=range;
      sum+=range;
      if(i>=SWING_ATR_LENGTH) sum-=ranges[i-SWING_ATR_LENGTH];
      atr[i]=sum/MathMin(i+1,SWING_ATR_LENGTH);
     }
  }

// Replays confirmed swings and close-confirmed breaks over closed candles.
// Market bias, chart labels and BOS/CHoCH drawings all come from this single
// routine, so they can never disagree about structure.
//
// Swings: a pivot of filter.strength candles (see PivotHigh) that has moved
// at least filter.size_atr ATR from the previous opposite swing, accepted by
// the alternating-leg rules and labelled HH/LH or LL/HL against the previous
// leg's extreme.
//
// Only an identified swing can be broken: one whose leg has ended because
// the opposite leg after it has begun.  Until then a more extreme pivot can
// still replace it, so a close through it breaks nothing; the last
// identified swing stays the level.  This way every BOS and CHoCH starts
// from a swing that stays marked on the chart.
//
// Only a candle close through a swing is a break; a wick is a liquidity
// sweep.  The label of the broken swing decides the event:
//  * BOS (bullish): the most recent identified HH is broken, creating a new
//    HH.
//  * BOS (bearish): the most recent identified LL is broken, creating a new
//    LL.
//  * CHoCH (becoming bullish): while the trend is not already bullish, the
//    most recent identified LH is broken and the next swing high is an HH.
//    The CHoCH is confirmed when that HH is confirmed, or by the breaking
//    close itself when a wick through the LH already made the HH.  An LH
//    made by the break, or an LL before the HH, cancels it; swings printed
//    before the breaking close never do.
//  * CHoCH (becoming bearish): the mirror image; the most recent identified
//    HL is broken and the next swing low is an LL.
//  * A broken LH in a bullish trend (or HL in a bearish trend) is a pullback
//    inside that trend and prints nothing.
//  * LS (liquidity sweep): a CHoCH that reversed a trend fails when, before
//    anything else prints, a close breaks its protected swing and the old
//    trend carries on beyond its extreme (see BASE_LS_WATCH).  The CHoCH is
//    relabelled LS and the trend before it is restored.
// Trend: bullish after a bullish BOS, bullish transitional after a bullish
// CHoCH until the next bullish BOS or until it fails as an LS; bearish
// mirrors this.
bool ReplayStructure(const MqlRates &rates[],const int total,const BASE_SWING_FILTER &filter,
                     BASE_STRUCTURE_STATE &state,BASE_STRUCTURE_POINT &points[],
                     BASE_STRUCTURE_EVENT &events[])
  {
   ZeroMemory(state);
   state.labels_from=-1;
   state.trap_from=-1;
   ArrayResize(points,0);
   ArrayResize(events,0);
   int length=filter.strength;
   if(total<2*length+2) return false;
   double atr[];
   SwingATR(rates,total,atr);
   int last_side=0;
   bool have_high_reference=false,have_low_reference=false;
   double high_reference=0.0,low_reference=0.0;
   int high_point=-1,low_point=-1;
   // The most recent identified and unbroken HH, LH, LL and HL.
   BASE_LEVEL hh,lh,ll,hl;
   ZeroMemory(hh);
   ZeroMemory(lh);
   ZeroMemory(ll);
   ZeroMemory(hl);
   BASE_CHOCH_CANDIDATE choch;
   ZeroMemory(choch);
   BASE_LS_WATCH watch;
   ZeroMemory(watch);
   watch.event=-1;
   for(int i=length;i<total;i++)
     {
      int pivot=i-length;
      if(PivotHigh(rates,total,pivot,length))
        {
         int kind=0;
         bool same_leg=last_side==1;
         if(AcceptStructureHigh(rates[pivot].high,state.have_high,state.last_high,last_side,
                                have_high_reference,high_reference,kind,state.have_low,
                                state.last_low,filter.size_atr*atr[pivot]))
           {
            // A higher pivot in the same leg replaces the leg's high; the
            // first high of a new leg ends the low leg, identifying its low.
            if(same_leg) points[high_point].superseded=true;
            else IdentifySwing(ll,hl,points,low_point);
            high_point=AddStructurePoint(points,pivot,i,rates[pivot],1,kind);
            state.last_high_kind=kind;
            state.last_high_time=rates[pivot].time;
            // An HH beyond the old uptrend's extreme after a failed bearish
            // CHoCH confirms the LS; a pending CHoCH attempt ends with it.
            if(LSSwing(watch,events,1,rates[pivot].high))
              {
               ConfirmLS(events,state,watch,i);
               choch.direction=0;
              }
            // Only swings formed after the breaking close can cancel a CHoCH.
            else if(choch.direction>0 && kind<0 && pivot>choch.break_bar)
               CancelCHoCH(choch,lh,hl,high_point,low_point);   // the break made only an LH
            else if(choch.direction<0 && kind>0 && pivot>choch.break_bar)
               CancelCHoCH(choch,lh,hl,high_point,low_point);   // an HH before the LL
            else if(choch.direction!=0 && CHoCHComplete(choch,points,high_point,low_point))
               ConfirmCHoCH(events,state,i,choch,watch,points,high_point,low_point,hh,ll);             // LH broken, then an HH
           }
        }
      if(PivotLow(rates,total,pivot,length))
        {
         int kind=0;
         bool same_leg=last_side==-1;
         if(AcceptStructureLow(rates[pivot].low,state.have_low,state.last_low,last_side,
                               have_low_reference,low_reference,kind,state.have_high,
                               state.last_high,filter.size_atr*atr[pivot]))
           {
            if(same_leg) points[low_point].superseded=true;
            else IdentifySwing(hh,lh,points,high_point);
            low_point=AddStructurePoint(points,pivot,i,rates[pivot],-1,kind);
            state.last_low_kind=kind;
            state.last_low_time=rates[pivot].time;
            if(LSSwing(watch,events,-1,rates[pivot].low))
              {
               ConfirmLS(events,state,watch,i);
               choch.direction=0;
              }
            else if(choch.direction<0 && kind<0 && pivot>choch.break_bar)
               CancelCHoCH(choch,lh,hl,high_point,low_point);   // the break made only an HL
            else if(choch.direction>0 && kind>0 && pivot>choch.break_bar)
               CancelCHoCH(choch,lh,hl,high_point,low_point);   // an LL before the HH
            else if(choch.direction!=0 && CHoCHComplete(choch,points,high_point,low_point))
               ConfirmCHoCH(events,state,i,choch,watch,points,high_point,low_point,hh,ll);             // HL broken, then an LL
           }
        }

      double close=rates[i].close;
      // LS first: the restored trend then decides the breaks below, so the
      // protected swing's break is a pullback and a close beyond the old
      // extreme is that trend's BOS.
      if(LSClose(watch,events,close))
        {
         ConfirmLS(events,state,watch,i);
         choch.direction=0;
        }
      // A broken LH is a bullish CHoCH candidate unless the trend is already
      // bullish, in which case it is a pullback high.  An LH broken together
      // with an HH is the CHoCH, not a BOS.
      if(lh.active && close>lh.price)
        {
         lh.active=false;
         if(state.direction<=0 && choch.direction<=0)
           {
            CancelCHoCH(choch,lh,hl,high_point,low_point);
            StartCHoCH(choch,1,i,lh);
            // A wick may already have made the HH.
            if(CHoCHComplete(choch,points,high_point,low_point)) ConfirmCHoCH(events,state,i,choch,watch,points,high_point,low_point,hh,ll);
           }
        }
      if(hh.active && close>hh.price)
        {
         hh.active=false;
         if(choch.direction<=0)
           {
            CancelCHoCH(choch,lh,hl,high_point,low_point);
            AddStructureEvent(events,state,i,i,1,true,hh.time,hh.price);
           }
        }
      if(hl.active && close<hl.price)
        {
         hl.active=false;
         if(state.direction>=0 && choch.direction>=0)
           {
            CancelCHoCH(choch,lh,hl,high_point,low_point);
            StartCHoCH(choch,-1,i,hl);
            if(CHoCHComplete(choch,points,high_point,low_point)) ConfirmCHoCH(events,state,i,choch,watch,points,high_point,low_point,hh,ll);
           }
        }
      if(ll.active && close<ll.price)
        {
         ll.active=false;
         if(choch.direction>=0)
           {
            CancelCHoCH(choch,lh,hl,high_point,low_point);
            AddStructureEvent(events,state,i,i,-1,true,ll.time,ll.price);
           }
        }
     }
   state.have_hh=hh.active;
   state.hh=hh.price;
   state.have_lh=lh.active;
   state.lh=lh.price;
   state.have_ll=ll.active;
   state.ll=ll.price;
   state.have_hl=hl.active;
   state.hl=hl.price;
   ClassifyConsolidation(points,events,atr[total-1],state);
   return true;
  }

// Replays structure on any timeframe without drawing it.  This keeps the
// structure, setup and LTF biases independent of each other.
bool AnalyseStructure(const ENUM_TIMEFRAMES timeframe,const int wanted,const int sensitivity,
                      BASE_STRUCTURE_STATE &state,MqlRates &rates[],
                      BASE_STRUCTURE_POINT &points[],BASE_STRUCTURE_EVENT &events[])
  {
   ArraySetAsSeries(rates,false);
   int total=CopyRates(_Symbol,timeframe,1,wanted,rates);
   return total>0 && ReplayStructure(rates,total,SwingFilter(sensitivity),state,points,events);
  }

// The bias direction used for trading: none while Consolidation / Undefined.
int BiasDirection(const BASE_STRUCTURE_STATE &state)
  {
   return state.consolidation!=0?0:state.direction;
  }

bool DefiniteBias(const BASE_STRUCTURE_STATE &state)
  {
   // A trend is established once its latest break is a BOS.  A CHoCH starts
   // a transition that the next BOS completes; pullback swings that break
   // nothing cannot put an established trend back into transition.
   return BiasDirection(state)!=0 && state.last_break_was_bos;
  }

string BiasText(const BASE_STRUCTURE_STATE &state)
  {
   if(BiasDirection(state)==0) return "Consolidation / Undefined";
   bool definite=DefiniteBias(state);
   if(state.direction>0) return definite?"Bullish":"Bullish Transition";
   return definite?"Bearish":"Bearish Transition";
  }

string TriggerText(const BASE_STRUCTURE_STATE &state)
  {
   if(state.direction==0) return "No structure break yet";
   string text="";
   if((state.consolidation&1)!=0) text="Sporadic 5-label sequence";
   if((state.consolidation&2)!=0) text+=(text==""?"":" + ")+"Multiple CHoCHs without BoS";
   if(text!="") return text;
   return state.last_break_was_bos?"Clear trending structure":"Clear structure (CHoCH awaiting BoS)";
  }

string PriceText(const double price)
  {
   return DoubleToString(price,_Digits);
  }

string BreakText(const BASE_STRUCTURE_EVENT &event)
  {
   return (event.direction>0?"bull ":"bear ")+(event.bos?"BoS":"CHoCH");
  }

string LabelText(const BASE_STRUCTURE_POINT &point)
  {
   if(point.side>0) return point.kind>0?"HH":"LH";
   return point.kind>0?"LL":"HL";
  }

// The last five labels and every break since the oldest of them, the CHoCHs
// of a trap, or the latest break of a clear structure.
string EvidenceText(const BASE_STRUCTURE_STATE &state,const BASE_STRUCTURE_POINT &points[],
                    const BASE_STRUCTURE_EVENT &events[])
  {
   int event_count=ArraySize(events);
   string labels="";
   if(state.labels_from>=0)
      for(int k=state.labels_from;k<ArraySize(points);k++)
         if(!points[k].superseded && points[k].kind!=0)
            labels+=(labels==""?"":" ")+LabelText(points[k]);
   string text=labels==""?"":"Labels "+labels;
   if((state.consolidation&1)!=0)
     {
      string breaks="";
      for(int i=0;i<event_count;i++)
         if(!events[i].ls && events[i].break_bar>=points[state.labels_from].pivot)
            breaks+=(breaks==""?"":", ")+BreakText(events[i]);
      text+="; breaks "+breaks;
     }
   if((state.consolidation&2)!=0)
     {
      string chochs="";
      for(int i=state.trap_from;i<event_count;i++)
         if(!events[i].bos && !events[i].ls) chochs+=(chochs==""?"":", ")+BreakText(events[i])+" "+PriceText(events[i].level);
      text+=(text==""?"":" | ")+chochs+"; no confirming BoS since";
     }
   int latest=event_count-1;
   while(latest>=0 && events[latest].ls) latest--;
   if(state.consolidation==0 && latest>=0)
      text+=(text==""?"":"; ")+"latest "+BreakText(events[latest])+" "+
            PriceText(events[latest].level);
   return text==""?"No labels yet":text;
  }

string TrendWord(const int direction)
  {
   return direction>0?"bullish":"bearish";
  }

string HTFName() { return TimeframeName(BASETimeframe()); }
string MTFName() { return TimeframeName(SetupTimeframe()); }
string LTFName() { return TimeframeName(LTFTimeframe()); }

// What to do on one timeframe's trend: one action and the level that
// decides it.
string RecommendationText(const BASE_STRUCTURE_STATE &state,const BASE_STRUCTURE_POINT &points[])
  {
   int direction=BiasDirection(state);
   if(state.direction==0)
      return "Stand aside until a BOS sets the trend.";
   if(direction==0)
     {
      // Range edges: the extremes of the last five labels.
      double top=0.0,bottom=0.0;
      bool have=false;
      if(state.labels_from>=0)
         for(int k=state.labels_from;k<ArraySize(points);k++)
            if(!points[k].superseded && points[k].kind!=0)
              {
               if(!have || points[k].price>top) top=points[k].price;
               if(!have || points[k].price<bottom) bottom=points[k].price;
               have=true;
              }
      string text="Stand aside";
      if(have) text+=" or trade only the range edges ("+PriceText(bottom)+" to "+PriceText(top)+")";
      if(state.have_hh && state.have_ll)
         text+="; a close above HH "+PriceText(state.hh)+" or below LL "+PriceText(state.ll)+
               " starts a new trend";
      else
         text+=" until a BOS starts a new trend";
      return text+".";
     }
   if(direction>0)
     {
      if(!state.last_break_was_bos)
         return state.have_hh?"Wait for a close above HH "+PriceText(state.hh)+" (bullish BOS) before buying.":
                "Wait for a bullish BOS before buying.";
      return state.have_hl?"Look for buys on pullbacks while price holds above HL "+PriceText(state.hl)+".":
             "Look for buys on pullbacks.";
     }
   if(!state.last_break_was_bos)
      return state.have_ll?"Wait for a close below LL "+PriceText(state.ll)+" (bearish BOS) before selling.":
             "Wait for a bearish BOS before selling.";
   return state.have_lh?"Look for sells on pullbacks while price holds below LH "+PriceText(state.lh)+".":
          "Look for sells on pullbacks.";
  }

// The dashboard's recommendation: the HTF's, unless an established HTF trend
// is held back by a selected lower timeframe, which it then names.
string TradeRecommendation(const BASE_STRUCTURE_STATE &htf,const BASE_STRUCTURE_POINT &points[],
                           const BASE_STRUCTURE_STATE &mtf,const BASE_STRUCTURE_STATE &ltf,
                           const bool tradable)
  {
   int direction=BiasDirection(htf);
   if(!tradable && direction!=0 && htf.last_break_was_bos)
     {
      string action=direction>0?"buying":"selling";
      string lead=HTFName()+" is "+TrendWord(direction)+", but wait for ";
      if(Use_MTF && BiasDirection(mtf)!=direction)
         return lead+MTFName()+" to turn "+TrendWord(direction)+" before "+action+".";
      if(Use_LTF && (BiasDirection(ltf)!=direction || !DefiniteBias(ltf)))
         return lead+LTFName()+" to confirm with a "+TrendWord(direction)+" BOS before "+action+".";
     }
   return RecommendationText(htf,points);
  }

// The four-line breakdown, joined for a tooltip.
string BreakdownText(const BASE_STRUCTURE_STATE &state,const BASE_STRUCTURE_POINT &points[],
                     const BASE_STRUCTURE_EVENT &events[])
  {
   return "Current Trend Classification: "+BiasText(state)+
          "\nTrigger Condition Met: "+TriggerText(state)+
          "\nStructural Evidence: "+EvidenceText(state,points,events)+
          "\nTrade Recommendations: "+RecommendationText(state,points);
  }

// "H4", "H4 and H1" or "H4, H1 and M15": the selected trend timeframes.
string TrendTimeframesText()
  {
   string names[3];
   int count=0;
   if(Use_HTF) names[count++]=HTFName();
   if(Use_MTF) names[count++]=MTFName();
   if(Use_LTF) names[count++]=LTFName();
   string result="";
   for(int i=0;i<count;i++)
      result+=(i==0?"":(i==count-1?" and ":", "))+names[i];
   return result;
  }

// Why a timeframe has no trend direction.
string NoTrendText(const string name,const BASE_STRUCTURE_STATE &state)
  {
   if(state.direction==0) return name+" has no structure break yet.";
   string why="";
   if((state.consolidation&1)!=0) why="breaks in both directions over its last 5 swings";
   if((state.consolidation&2)!=0) why+=(why==""?"":"; ")+"repeated CHoCHs in one area with no BOS";
   return name+" is ranging ("+why+").";
  }

string TransitionText(const string name,const BASE_STRUCTURE_STATE &state)
  {
   return name+" is only in a "+TrendWord(state.direction)+
          " transition (a CHoCH not yet confirmed by a BOS).";
  }

// Market Tradability: the HTF trend must be established (latest break a
// BOS); every selected trend timeframe must have a direction and they must
// all agree; a selected LTF must itself be established.  The MTF may be
// transitional.  A Consolidation / Undefined trend has no direction.  The
// reason says why in one sentence, naming the timeframes.
bool EvaluateTradability(const BASE_STRUCTURE_STATE &htf,const BASE_STRUCTURE_STATE &mtf,
                          const BASE_STRUCTURE_STATE &ltf,string &reason)
  {
   bool htf_definite=DefiniteBias(htf);
   bool ltf_definite=DefiniteBias(ltf);
   int htf_direction=BiasDirection(htf);
   int mtf_direction=BiasDirection(mtf);
   int ltf_direction=BiasDirection(ltf);
   bool available=(!Use_HTF || htf_direction!=0) &&
                  (!Use_MTF || mtf_direction!=0) &&
                  (!Use_LTF || ltf_direction!=0);
   bool match=(!Use_HTF || !Use_MTF ||
               htf_direction==mtf_direction) &&
              (!Use_HTF || !Use_LTF ||
               htf_direction==ltf_direction) &&
              (!Use_MTF || !Use_LTF ||
               mtf_direction==ltf_direction);
   bool tradable=htf_definite && available && match && (!Use_LTF || ltf_definite);
   if(tradable)
     {
      int selected=(Use_HTF?1:0)+(Use_MTF?1:0)+(Use_LTF?1:0);
      int direction=Use_HTF?htf_direction:(Use_MTF?mtf_direction:ltf_direction);
      reason=TrendTimeframesText()+(selected==1?" is ":selected==2?" are both ":" are all ")+
             TrendWord(direction)+", and the "+HTFName()+" trend is confirmed by a BOS";
      if(Use_LTF) reason+=", as is the "+LTFName()+" trend";
      reason+=".";
     }
   else if(htf_direction==0) reason=NoTrendText(HTFName(),htf);
   else if(!htf_definite) reason=TransitionText(HTFName(),htf);
   else if(Use_MTF && mtf_direction==0) reason=NoTrendText(MTFName(),mtf);
   else if(Use_LTF && ltf_direction==0) reason=NoTrendText(LTFName(),ltf);
   else if(!match)
     {
      string first=Use_HTF?HTFName():MTFName();
      int first_direction=Use_HTF?htf_direction:mtf_direction;
      bool mtf_conflict=Use_HTF && Use_MTF && mtf_direction!=htf_direction;
      string other=mtf_conflict?MTFName():LTFName();
      int other_direction=mtf_conflict?mtf_direction:ltf_direction;
      reason=first+" is "+TrendWord(first_direction)+" but "+other+" is "+TrendWord(other_direction)+".";
     }
   else reason=TransitionText(LTFName(),ltf);
   return tradable;
  }

// Healthy Extension: measured in the HTF bias direction (the trading
// direction) from the newest corrective LTF swing, which must be an HL for a
// bullish bias or an LH for a bearish bias, to the latest LTF close.
bool HealthyExtension(const BASE_STRUCTURE_STATE &htf,const BASE_STRUCTURE_STATE &ltf,
                      const double close,const double atr)
  {
   if(atr==EMPTY_VALUE || atr<=0.0) return false;
   double extension=-1.0;
   int direction=BiasDirection(htf);
   if(direction>0 && ltf.have_low && ltf.last_low_kind<0)
      extension=(close-ltf.last_low)/atr;
   else if(direction<0 && ltf.have_high && ltf.last_high_kind<0)
      extension=(ltf.last_high-close)/atr;
   return extension>=0.0 && extension<=Maximum_Extension_ATR;
  }

// Optimal Conditions: every enabled requirement must pass.  Returns the
// result and the reason listing each failed requirement.
bool EvaluateOptimal(const bool bias_ready,const bool healthy_extension,
                     const bool good_volume,const double volume_ratio,
                     const bool good_momentum,const double momentum_ratio,string &reason)
  {
   bool optimal=(!Use_Timeframe_Correlation_For_Optimal || bias_ready) &&
                (!Use_Healthy_Extension_For_Optimal || healthy_extension) &&
                (!Use_Market_Volume_For_Optimal || good_volume) &&
                (!Use_Price_Momentum_For_Optimal || good_momentum);
   if(optimal)
     {
      reason="All selected requirements are met";
      return true;
     }
   reason="";
   if(Use_Timeframe_Correlation_For_Optimal && !bias_ready)
      reason="the selected timeframes do not correlate (see Tradability Reason)";
   if(Use_Healthy_Extension_For_Optimal && !healthy_extension)
      reason+=(reason==""?"":"; ")+"price is overextended or lacks a valid corrective anchor";
   if(Use_Market_Volume_For_Optimal && !good_volume)
      reason+=(reason==""?"":"; ")+(volume_ratio<Volume_Minimum_Ratio?"volume is too low":"volume is too high");
   if(Use_Price_Momentum_For_Optimal && !good_momentum)
      reason+=(reason==""?"":"; ")+(momentum_ratio<Momentum_Minimum_Ratio?
                                    "momentum is too low (price is sluggish)":
                                    "momentum is too high (price would need to be chased)");
   return false;
  }

// True range captures both the candle's travel and any gap from the preceding
// close.  Relative true range is used as a direction-neutral momentum measure:
// quiet/sluggish bars and unusually fast chase bars are both undesirable.
double BarTrueRange(const MqlRates &rates[],const int index)
  {
   double range=rates[index].high-rates[index].low;
   if(index<=0) return range;
   return MathMax(range,MathMax(MathAbs(rates[index].high-rates[index-1].close),
                                MathAbs(rates[index].low-rates[index-1].close)));
  }

bool ParseSession(const string source,int &start_minutes,int &end_minutes)
  {
   string pieces[];
   if(StringSplit(source,'-',pieces)!=2 || StringLen(pieces[0])!=4 || StringLen(pieces[1])!=4)
      return false;
   // StringToInteger silently converts malformed text (for example "AB00")
   // to zero.  Reject anything other than the documented HHMM-HHMM format so
   // a typo cannot unexpectedly enable a midnight session.
   for(int part=0;part<2;part++)
      for(int character=0;character<4;character++)
        {
         ushort digit=StringGetCharacter(pieces[part],character);
         if(digit<'0' || digit>'9') return false;
        }
   int sh=(int)StringToInteger(StringSubstr(pieces[0],0,2));
   int sm=(int)StringToInteger(StringSubstr(pieces[0],2,2));
   int eh=(int)StringToInteger(StringSubstr(pieces[1],0,2));
   int em=(int)StringToInteger(StringSubstr(pieces[1],2,2));
   if(sh>23 || eh>23 || sm>59 || em>59) return false;
   start_minutes=sh*60+sm; end_minutes=eh*60+em;
   return true;
  }

bool InSession(const datetime server_time)
  {
   if(!Use_Session_Filter || Session_Preset==BASE_24X7) return true;
   string session="0000-2359";
   int zone_offset=0;
   if(Session_Preset==BASE_NEW_YORK) { session="0930-1600"; zone_offset=-300; }
   else if(Session_Preset==BASE_LONDON) { session="0800-1700"; zone_offset=0; }
   else if(Session_Preset==BASE_TOKYO) { session="0900-1500"; zone_offset=540; }
   else if(Session_Preset==BASE_SYDNEY) { session="0800-1700"; zone_offset=600; }
   else { session=Custom_Session; zone_offset=Custom_UTC_Offset_Minutes; }
   int begin=0,end=0;
   if(!ParseSession(session,begin,end)) return false;
   datetime local_time=server_time+(zone_offset-Server_UTC_Offset_Minutes)*60;
   MqlDateTime stamp; TimeToStruct(local_time,stamp);
   int minute=stamp.hour*60+stamp.min;
   if(begin==end) return true;
   return begin<end?(minute>=begin && minute<end):(minute>=begin || minute<end);
  }

// Copies the newest `count` closed-bar values.  Fails while the indicator is
// still calculating so the caller can retry instead of using partial data.
bool CopyIndicator(const int handle,const int buffer,const int count,double &values[])
  {
   ArraySetAsSeries(values,false);
   if(handle==INVALID_HANDLE || BarsCalculated(handle)<count+1) return false;
   return CopyBuffer(handle,buffer,1,count,values)==count;
  }

// The latest closed MTF candle and its MTF MA.
bool MTFValues(double &ma,double &open,double &close)
  {
   double value[1];
   if(g_mtf_ma_handle==INVALID_HANDLE || CopyBuffer(g_mtf_ma_handle,0,1,1,value)!=1) return false;
   ma=value[0];
   open=iOpen(_Symbol,SetupTimeframe(),1);
   close=iClose(_Symbol,SetupTimeframe(),1);
   return open!=0.0 && close!=0.0;
  }

string PassText(const bool pass)
  {
   return pass?"PASS":"BLOCKED";
  }

// Qualifies the latest closed structure candle with the HTF MA, MTF MA,
// session, ADX and ATR filters.  The HTF MA filter compares the latest closed
// HTF candle with the HTF MA, the MTF MA filter the latest closed MTF candle
// with the MTF MA.  The filters never gate structure, trend or alerts; the
// result is shown as the tooltip of the dashboard's tradability row.
string EntryFilterTooltip(const MqlRates &bar,const double &ma[],const double &adx[],
                          const double &atr[])
  {
   bool htf_long=true,htf_short=true;
   string htf_text="off";
   if(Use_HTF_MA_Filter)
     {
      double value=ma[ArraySize(ma)-1];
      htf_long=HTF_MA_Filter_Mode==BASE_PRICE_ABOVE_BELOW?bar.close>value
               :bar.close>value && bar.open>value && bar.close>bar.open;
      htf_short=HTF_MA_Filter_Mode==BASE_PRICE_ABOVE_BELOW?bar.close<value
                :bar.close<value && bar.open<value && bar.close<bar.open;
      htf_text=htf_long?"long":(htf_short?"short":"neutral");
     }
   bool mtf_long=!Use_MTF_MA_Filter,mtf_short=!Use_MTF_MA_Filter;
   string mtf_text="off";
   double mtf_ma=0.0,mtf_open=0.0,mtf_close=0.0;
   if(Use_MTF_MA_Filter)
     {
      mtf_text="unavailable";
      if(MTFValues(mtf_ma,mtf_open,mtf_close))
        {
         mtf_long=MTF_MA_Filter_Mode==BASE_PRICE_ABOVE_BELOW?mtf_close>mtf_ma
                  :mtf_close>mtf_ma && mtf_open>mtf_ma && mtf_close>mtf_open;
         mtf_short=MTF_MA_Filter_Mode==BASE_PRICE_ABOVE_BELOW?mtf_close<mtf_ma
                   :mtf_close<mtf_ma && mtf_open<mtf_ma && mtf_close<mtf_open;
         mtf_text=mtf_long?"long":(mtf_short?"short":"neutral");
        }
     }
   bool session=InSession(bar.time);
   bool adx_pass=!Use_ADX_Filter || (adx[0]!=EMPTY_VALUE && adx[0]>=ADX_Minimum);
   bool atr_pass=!Use_ATR_Filter || (atr[0]!=EMPTY_VALUE &&
                 (ATR_Filter_Mode==BASE_ATR_MINIMUM?atr[0]>=ATR_Minimum:
                  ATR_Filter_Mode==BASE_ATR_MAXIMUM?atr[0]<=ATR_Maximum:
                  atr[0]>=ATR_Minimum && atr[0]<=ATR_Maximum));
   bool long_direction=htf_long && mtf_long && session;
   bool short_direction=htf_short && mtf_short && session;
   bool choch_adx=!Use_ADX_Filter || Apply_ADX_Filter_To==BASE_BOS_ONLY || adx_pass;
   string text="Entry filters, latest closed "+TimeframeName(BASETimeframe())+" candle";
   text+="\nBOS: long "+PassText(long_direction && adx_pass && atr_pass)+
         ", short "+PassText(short_direction && adx_pass && atr_pass);
   text+="\nCHoCH: long "+PassText(long_direction && choch_adx && atr_pass)+
         ", short "+PassText(short_direction && choch_adx && atr_pass);
   text+="\nHTF MA "+htf_text+" | MTF MA "+mtf_text+" | Session "+
         (Use_Session_Filter?(session?"in":"out"):"off");
   text+="\nADX "+(Use_ADX_Filter?DoubleToString(adx[0],1)+" "+PassText(adx_pass):"off")+
         " | ATR "+(Use_ATR_Filter?DoubleToString(atr[0],_Digits)+" "+PassText(atr_pass):"off");
   return text;
  }

void DrawText(const string id,const datetime time,const double price,const string text,
              const color clr,const ENUM_ANCHOR_POINT anchor,const int font_size)
  {
   string name=g_prefix+id;
   if(ObjectFind(0,name)>=0 || !ObjectCreate(0,name,OBJ_TEXT,0,time,price)) return;
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,font_size);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,anchor);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
  }

void DrawSegment(const string id,const datetime from,const double from_price,
                 const datetime to,const double to_price,const color clr,
                 const ENUM_LINE_STYLE style,const int width)
  {
   string name=g_prefix+id;
   if(ObjectFind(0,name)>=0 || !ObjectCreate(0,name,OBJ_TREND,0,from,from_price,to,to_price)) return;
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,MathMax(1,MathMin(4,width)));
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
  }

bool SignalShown(const string kind)
  {
   if(kind=="BOS") return Show_BOS_Labels;
   if(kind=="LS") return Show_LS_Labels;
   return Show_CHoCH_Labels;
  }

// BOS, CHoCH and LS share one drawing: a line from the broken swing to the
// candle that closed through it, and the caption placed by PlaceBreakLabel.
// An LS keeps the place of the CHoCH it replaced, in its own colour.
void DrawSignal(const string kind,const int direction,const datetime swing_time,
                const double level,const datetime break_time,const datetime label_time,
                const double label_price)
  {
   if(!SignalShown(kind)) return;
   bool bos=kind=="BOS",ls=kind=="LS";
   color clr=ls?(direction>0?Bullish_LS_Color:Bearish_LS_Color):
             direction>0?(bos?Bullish_BOS_Color:Bullish_CHoCH_Color)
                        :(bos?Bearish_BOS_Color:Bearish_CHoCH_Color);
   string key=kind+(direction>0?"_UP_":"_DOWN_")+(string)break_time;
   // A bullish caption stands on its anchor, above the line; a bearish one
   // hangs below it.
   DrawText(key,label_time,label_price,kind,clr,direction>0?ANCHOR_LOWER:ANCHOR_UPPER,
            (int)Label_Size);
   if(Show_Structure_Lines)
      DrawSegment(key+"_LINE",swing_time,level,break_time,level,
                  ls?clr:(bos?clrBlue:clrRed),Line_Style,Line_Width);
  }

string StructureLabel(const BASE_STRUCTURE_POINT &point)
  {
   if(point.side>0) return point.kind>0?"HH":"LH";
   return point.kind>0?"LL":"HL";
  }

void DrawStructurePoint(const string kind,const datetime time,const double price)
  {
   if(!Show_Swing_Points) return;
   bool low=kind=="HL" || kind=="LL";
   color clr=low?clrTeal:clrIndianRed;
   DrawText("STRUCTURE_"+kind+"_"+(string)time,time,price,kind,clr,low?ANCHOR_UPPER:ANCHOR_LOWER,
            (int)Label_Size);
  }

// The index of the candle opening at `time` (or the last one before it).
int BarOfTime(const MqlRates &rates[],const int total,const datetime time)
  {
   int low=0,high=total-1;
   while(low<high)
     {
      int middle=(low+high+1)/2;
      if(rates[middle].time<=time) low=middle;
      else high=middle-1;
     }
   return low;
  }

// Label layout.  A BOS, CHoCH or LS label sits near the middle of its line,
// on the side the price did not come from: above a line broken upwards,
// below one broken downwards.  It then moves away from the line only as far
// as it must to clear every candle, swing label, dotted level line, MA line,
// structure line and earlier break label it covers, so it never overlaps a
// candle or another drawing.  Sizes follow the chart's zoom and height, and
// a zoom lays the chart out again (see OnChartEvent).
void StartLayout(const MqlRates &rates[],const int total,const int first)
  {
   ArrayResize(g_boxes,0);
   g_layout_scale=ChartGetInteger(0,CHART_SCALE);
   g_bar_px=MathPow(2.0,(double)MathMax(0,MathMin(5,(int)g_layout_scale)));
   long height=ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
   if(height<=0) height=600;
   // The larger of the drawn and the visible price range, so a label is never
   // sized smaller than it can appear.
   double high=rates[first].high,low=rates[first].low;
   for(int i=first;i<total;i++)
     {
      high=MathMax(high,rates[i].high);
      low=MathMin(low,rates[i].low);
     }
   double visible=ChartGetDouble(0,CHART_PRICE_MAX)-ChartGetDouble(0,CHART_PRICE_MIN);
   g_price_px=MathMax(high-low,visible)/(double)height;
  }

void TextSize(const string text,int &width,int &height)
  {
   uint w=0,h=0;
   if(TextSetFont("Arial",-(int)Label_Size*10) && TextGetSize(text,w,h) && w>0)
     {
      width=(int)w;
      height=(int)h;
      return;
     }
   width=StringLen(text)*(int)Label_Size;
   height=2*(int)Label_Size;
  }

// Candles a centred label of this width reaches on each side, plus one.
int HalfBars(const int width_px)
  {
   return (int)MathCeil(width_px/g_bar_px/2.0)+1;
  }

void AddBox(const int from,const int to,const double low,const double high)
  {
   int n=ArraySize(g_boxes);
   ArrayResize(g_boxes,n+1,64);
   g_boxes[n].from=from;
   g_boxes[n].to=to;
   g_boxes[n].low=low;
   g_boxes[n].high=high;
  }

double Beyond(const double edge,const double obstacle,const bool above,const double gap)
  {
   return above?MathMax(edge,obstacle+gap):MathMin(edge,obstacle-gap);
  }

// The label edge nearest the level (its bottom above the line, its top below
// it) at which a label centred on candle x covers nothing.
double ClearEdge(const MqlRates &rates[],const int total,const double &line_a[],
                 const double &line_b[],const int x,const int half,const double level,
                 const bool above,const double height)
  {
   int from=MathMax(0,x-half),to=MathMin(total-1,x+half);
   double gap=3.0*g_price_px;
   double edge=above?level+gap:level-gap;
   bool have_a=ArraySize(line_a)==total,have_b=ArraySize(line_b)==total;
   for(int pass=0;pass<100;pass++)
     {
      double low=above?edge:edge-height,high=above?edge+height:edge;
      double moved=edge;
      for(int i=from;i<=to;i++)
        {
         if(rates[i].high>=low && rates[i].low<=high)
            moved=Beyond(moved,above?rates[i].high:rates[i].low,above,gap);
         if(have_a && line_a[i]!=EMPTY_VALUE && line_a[i]>=low && line_a[i]<=high)
            moved=Beyond(moved,line_a[i],above,gap);
         if(have_b && line_b[i]!=EMPTY_VALUE && line_b[i]>=low && line_b[i]<=high)
            moved=Beyond(moved,line_b[i],above,gap);
        }
      for(int b=ArraySize(g_boxes)-1;b>=0;b--)
         if(g_boxes[b].to>=from && g_boxes[b].from<=to && g_boxes[b].high>=low && g_boxes[b].low<=high)
            moved=Beyond(moved,above?g_boxes[b].high:g_boxes[b].low,above,gap);
      if(moved==edge) break;
      edge=moved;
     }
   return edge;
  }

// Where a break label goes: the candle it is centred on and the price of its
// bottom (above the line) or top (below it).  Of the candles near the middle
// of the line, the one that lets the label sit closest to the line wins.
void PlaceBreakLabel(const MqlRates &rates[],const int total,const double &line_a[],
                     const double &line_b[],const int swing_bar,const int break_bar,
                     const double level,const bool above,const int width_px,const int height_px,
                     int &x,double &edge)
  {
   int half=HalfBars(width_px);
   double height=height_px*g_price_px;
   int middle=(swing_bar+break_bar)/2;
   x=middle;
   edge=ClearEdge(rates,total,line_a,line_b,middle,half,level,above,height);
   for(int k=1;k<=6;k++)
      for(int sign=1;sign>=-1;sign-=2)
        {
         int candidate=middle+sign*k*half;
         if(candidate<=swing_bar || candidate>=break_bar) continue;
         double candidate_edge=ClearEdge(rates,total,line_a,line_b,candidate,half,level,above,height);
         if(MathAbs(candidate_edge-level)<MathAbs(edge-level))
           {
            x=candidate;
            edge=candidate_edge;
           }
        }
   AddBox(x-half,x+half,above?edge:edge-height,above?edge+height:edge);
  }

string EventKind(const BASE_STRUCTURE_EVENT &event)
  {
   return event.ls?"LS":(event.bos?"BOS":"CHoCH");
  }

bool EventDrawn(const BASE_STRUCTURE_EVENT &event,const MqlRates &rates[],const int first)
  {
   return event.break_bar>=first && event.swing_time>=rates[first].time && SignalShown(EventKind(event));
  }

// Draws one replay from candle `first` onwards (earlier candles are warm-up):
// HH/HL/LH/LL labels (superseded and untyped points are skipped), the dotted
// current swing levels and the BOS/CHoCH/LS signals, whose labels are laid
// out last so they keep clear of everything else.  A CHoCH may be confirmed
// several candles after its break; its line ends on the candle that
// actually closed through the level.  line_a/line_b are the MA lines at each
// candle (EMPTY_VALUE where not drawn).
void DrawStructure(const MqlRates &rates[],const int total,const int first,
                   const BASE_STRUCTURE_STATE &state,const BASE_STRUCTURE_POINT &points[],
                   const BASE_STRUCTURE_EVENT &events[],const double &line_a[],
                   const double &line_b[])
  {
   StartLayout(rates,total,first);
   int width=0,height=0;
   int point_count=ArraySize(points);
   for(int i=0;i<point_count;i++)
      if(!points[i].superseded && points[i].kind!=0 && points[i].pivot>=first)
        {
         string kind=StructureLabel(points[i]);
         DrawStructurePoint(kind,points[i].time,points[i].price);
         if(!Show_Swing_Points) continue;
         TextSize(kind,width,height);
         int half=HalfBars(width);
         double h=height*g_price_px,price=points[i].price;
         if(points[i].side>0) AddBox(points[i].pivot-half,points[i].pivot+half,price,price+h);
         else AddBox(points[i].pivot-half,points[i].pivot+half,price-h,price);
        }
   if(Show_Swing_Points && state.have_high)
     {
      DrawSegment("LAST_HIGH",state.last_high_time,state.last_high,rates[total-1].time,
                  state.last_high,clrIndianRed,STYLE_DOT,1);
      AddBox(BarOfTime(rates,total,state.last_high_time),total-1,state.last_high,state.last_high);
     }
   if(Show_Swing_Points && state.have_low)
     {
      DrawSegment("LAST_LOW",state.last_low_time,state.last_low,rates[total-1].time,
                  state.last_low,clrTeal,STYLE_DOT,1);
      AddBox(BarOfTime(rates,total,state.last_low_time),total-1,state.last_low,state.last_low);
     }
   // A break is drawn only with its broken swing, so every BOS, CHoCH and LS
   // starts from a marked swing.  All structure lines are placed before any
   // label, so no label crosses another break's line.
   int event_count=ArraySize(events);
   for(int i=0;i<event_count;i++)
      if(EventDrawn(events[i],rates,first) && Show_Structure_Lines)
         AddBox(BarOfTime(rates,total,events[i].swing_time),events[i].break_bar,events[i].level,
                events[i].level);
   for(int i=0;i<event_count;i++)
     {
      if(!EventDrawn(events[i],rates,first)) continue;
      string kind=EventKind(events[i]);
      TextSize(kind,width,height);
      int x=0;
      double edge=0.0;
      PlaceBreakLabel(rates,total,line_a,line_b,BarOfTime(rates,total,events[i].swing_time),
                      events[i].break_bar,events[i].level,events[i].direction>0,width,height,x,edge);
      DrawSignal(kind,events[i].direction,events[i].swing_time,events[i].level,
                 rates[events[i].break_bar].time,rates[x].time,edge);
     }
  }

// A polyline (the times of line_rates[from..count-1], values) at each candle
// of rates: linear between its points, EMPTY_VALUE outside them.
void SampleLine(const MqlRates &line_rates[],const double &values[],const int from,
                const int count,const MqlRates &rates[],const int total,double &out[])
  {
   ArrayResize(out,total);
   ArrayInitialize(out,EMPTY_VALUE);
   if(from<0 || count-from<2) return;
   int j=from+1;
   for(int i=0;i<total;i++)
     {
      datetime t=rates[i].time;
      if(t<line_rates[from].time || t>line_rates[count-1].time) continue;
      while(j<count-1 && line_rates[j].time<t) j++;
      datetime t0=line_rates[j-1].time,t1=line_rates[j].time;
      out[i]=t1>t0?values[j-1]+(values[j]-values[j-1])*(double)(t-t0)/(double)(t1-t0):values[j];
     }
  }

int FirstMABar(const int total,const int displayed)
  {
   return MathMax(1,total-MathMin(500,displayed));
  }

// The HTF MA over the drawn HTF candles and the MTF MA over the drawn MTF
// candles (at most 500 segments each).
void DrawAverageLines(const MqlRates &rates[],const int total,const int displayed,
                      const double &ma[],const MqlRates &mtf[],const double &mtf_ma[],
                      const int mtf_count)
  {
   if(Show_HTF_MA_Line && Use_HTF_MA_Filter && ArraySize(ma)==total)
      for(int i=FirstMABar(total,displayed);i<total;i++)
         DrawSegment("HTF_MA_"+(string)rates[i].time,rates[i-1].time,ma[i-1],rates[i].time,ma[i],
                     HTF_MA_Color,STYLE_SOLID,2);
   for(int i=1;i<mtf_count;i++)
      DrawSegment("MTF_MA_"+(string)mtf[i].time,mtf[i-1].time,mtf_ma[i-1],mtf[i].time,mtf_ma[i],
                  MTF_MA_Color,STYLE_SOLID,2);
  }

void SendBASEAlert(const string signal,const datetime bar_time)
  {
   static datetime last_alert=0;
   if(bar_time<=last_alert) return;
   last_alert=bar_time;
   string message=_Symbol+" "+TimeframeName(BASETimeframe())+" "+signal;
   if(Enable_Popup_Alerts) Alert(message);
   if(Enable_Push_Notifications) SendNotification(message);
  }

// Dashboard styling: component names are black and bold, and only the
// outputs are coloured.  Trends are green (Bullish, Bullish
// Transition), red (Bearish, Bearish Transition) or grey (Consolidation /
// Undefined); tradability and conditions are green when they pass and red
// when they do not.  There is no background or border.
const int DASHBOARD_FONT_SIZE=10;
const int DASHBOARD_ROW_HEIGHT=18;
const int DASHBOARD_INDENT=12;
const color DASHBOARD_TEXT_COLOR=clrBlack;
const color DASHBOARD_POSITIVE_COLOR=clrGreen;
const color DASHBOARD_NEGATIVE_COLOR=clrRed;
const color DASHBOARD_NEUTRAL_COLOR=clrGray;

struct BASE_DASHBOARD_ROW
  {
   string label;            // component name; empty for a spacer row
   string value;            // output
   color value_color;
   string tooltip;
   bool bold;
   int indent;
  };

void AddDashboardRow(BASE_DASHBOARD_ROW &rows[],const string label,const string value,
                     const color value_color,const string tooltip="",const bool bold=true,
                     const int indent=0)
  {
   int index=ArraySize(rows);
   ArrayResize(rows,index+1);
   rows[index].label=label;
   rows[index].value=value;
   rows[index].value_color=value_color;
   rows[index].tooltip=tooltip;
   rows[index].bold=bold;
   rows[index].indent=indent;
  }

string DashboardFont(const bool bold)
  {
   return bold?"Arial Bold":"Arial";
  }

int DashboardTextWidth(const string text,const bool bold)
  {
   uint width=0,height=0;
   // A negative size is in tenths of a point, as OBJPROP_FONTSIZE is drawn.
   if(!TextSetFont(DashboardFont(bold),-DASHBOARD_FONT_SIZE*10) || !TextGetSize(text,width,height))
      return StringLen(text)*DASHBOARD_FONT_SIZE;
   return (int)width;
  }

void DrawDashboardText(const string name,const int x,const int y,const string text,
                       const color clr,const bool bold,const string tooltip)
  {
   if(!ObjectCreate(0,name,OBJ_LABEL,0,0,0)) return;
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,DASHBOARD_FONT_SIZE);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetString(0,name,OBJPROP_FONT,DashboardFont(bold));
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   // "\n" suppresses MT5's default tooltip, which would show the object name.
   ObjectSetString(0,name,OBJPROP_TOOLTIP,tooltip==""?"\n":tooltip);
  }

// Two aligned columns: the component names, then their outputs.
void DrawDashboardRows(const BASE_DASHBOARD_ROW &rows[])
  {
   int count=ArraySize(rows);
   int column=0;
   for(int i=0;i<count;i++)
      if(rows[i].label!="")
         column=MathMax(column,rows[i].indent+DashboardTextWidth(rows[i].label,rows[i].bold));
   column+=10+8;
   for(int i=0;i<count;i++)
     {
      if(rows[i].label=="") continue;
      int y=10+i*DASHBOARD_ROW_HEIGHT;
      string name=g_prefix+"DASHBOARD_"+(string)i;
      DrawDashboardText(name,10+rows[i].indent,y,rows[i].label,DASHBOARD_TEXT_COLOR,rows[i].bold,
                        rows[i].tooltip);
      DrawDashboardText(name+"_VALUE",column,y,rows[i].value,rows[i].value_color,false,
                        rows[i].tooltip);
     }
  }

color TrendColor(const BASE_STRUCTURE_STATE &state)
  {
   int direction=BiasDirection(state);
   if(direction>0) return DASHBOARD_POSITIVE_COLOR;
   if(direction<0) return DASHBOARD_NEGATIVE_COLOR;
   return DASHBOARD_NEUTRAL_COLOR;
  }

color PassColor(const bool pass)
  {
   return pass?DASHBOARD_POSITIVE_COLOR:DASHBOARD_NEGATIVE_COLOR;
  }

// Each selected timeframe's Market Trend (its breakdown is the tooltip),
// Market Tradability (the entry filters are its tooltip), the reason, the
// HTF trade recommendation, and Optimal Conditions with each selected
// condition (the reason is the tooltip).
void DrawDashboard(const BASE_STRUCTURE_STATE &htf,const string htf_breakdown,
                   const string recommendation,const BASE_STRUCTURE_STATE &mtf,
                   const string mtf_breakdown,const BASE_STRUCTURE_STATE &ltf,
                   const string ltf_breakdown,const bool tradable,
                   const string tradability_reason,const string filter_tooltip,
                   const bool optimal,const string optimal_reason,const bool correlated,
                   const bool healthy_extension,const bool good_volume,const double volume_ratio,
                   const bool good_momentum,const double momentum_ratio)
  {
   Comment("");
   BASE_DASHBOARD_ROW rows[];
   if(Use_HTF)
      AddDashboardRow(rows,"HTF Market Trend ("+TimeframeName(BASETimeframe())+"):",BiasText(htf),
                      TrendColor(htf),htf_breakdown);
   if(Use_MTF)
      AddDashboardRow(rows,"MTF Market Trend ("+TimeframeName(SetupTimeframe())+"):",BiasText(mtf),
                      TrendColor(mtf),mtf_breakdown);
   if(Use_LTF)
      AddDashboardRow(rows,"LTF Market Trend ("+TimeframeName(LTFTimeframe())+"):",BiasText(ltf),
                      TrendColor(ltf),ltf_breakdown);
   AddDashboardRow(rows,"Market Tradability:",tradable?"Tradable":"Not Tradable",
                   PassColor(tradable),filter_tooltip);
   AddDashboardRow(rows,"Tradability Reason:",tradability_reason,DASHBOARD_TEXT_COLOR);
   AddDashboardRow(rows,"Trade Recommendations:",recommendation,DASHBOARD_TEXT_COLOR);
   AddDashboardRow(rows,"","",DASHBOARD_TEXT_COLOR);
   AddDashboardRow(rows,"Optimal Conditions:",optimal?"OPTIMAL":"NOT OPTIMAL",PassColor(optimal),
                   optimal_reason);
   if(Use_Timeframe_Correlation_For_Optimal)
      AddDashboardRow(rows,"Timeframe Correlation:",PassText(correlated),PassColor(correlated),
                      optimal_reason,true,DASHBOARD_INDENT);
   if(Use_Healthy_Extension_For_Optimal)
      AddDashboardRow(rows,"Healthy Extension:",PassText(healthy_extension),
                      PassColor(healthy_extension),optimal_reason,true,DASHBOARD_INDENT);
   if(Use_Market_Volume_For_Optimal)
      AddDashboardRow(rows,"Market Volume:",PassText(good_volume)+" ("+DoubleToString(volume_ratio,2)+
                      "x average)",PassColor(good_volume),optimal_reason,true,DASHBOARD_INDENT);
   if(Use_Price_Momentum_For_Optimal)
      AddDashboardRow(rows,"Price Momentum:",PassText(good_momentum)+" ("+
                      DoubleToString(momentum_ratio,2)+"x average range)",PassColor(good_momentum),
                      optimal_reason,true,DASHBOARD_INDENT);
   DrawDashboardRows(rows);
  }

// Returns false while history or an indicator is still being synchronized.
// Every series is gathered before any chart object is touched, so an early
// retry (common straight after attaching or a timeframe change) keeps the
// previous drawing instead of blanking the chart.  The timer then retries the
// same bar every two seconds until the build completes.
bool Rebuild(const bool permit_alert)
  {
   ENUM_TIMEFRAMES timeframe=BASETimeframe();
   ENUM_TIMEFRAMES chart_timeframe=(ENUM_TIMEFRAMES)_Period;
   BASE_SWING_FILTER filter=SwingFilter(HTF_Swing_Sensitivity);
   int length=filter.strength;
   int displayed=StructureBars();
   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   int total=CopyRates(_Symbol,timeframe,1,ReplayBars(displayed),rates);
   if(total<2*length+2) return false;

   // Only the MA line needs history; the filters use the latest closed bar.
   double ma[],adx[],atr[];
   if(Use_HTF_MA_Filter && !CopyIndicator(g_htf_ma_handle,0,Show_HTF_MA_Line?total:1,ma)) return false;
   if(Use_ADX_Filter && !CopyIndicator(g_adx_handle,0,1,adx)) return false;
   if(Use_ATR_Filter && !CopyIndicator(g_atr_handle,0,1,atr)) return false;

   // The MTF and LTF biases are replayed over the same elapsed time as the
   // structure timeframe (plus the same warm-up), so every bias has comparable
   // context instead of a few hours of lower-timeframe candles.
   BASE_STRUCTURE_STATE setup_state,ltf_state;
   MqlRates setup_rates[],ltf_rates[];
   BASE_STRUCTURE_POINT setup_points[],ltf_points[];
   BASE_STRUCTURE_EVENT setup_events[],ltf_events[];
   if(!AnalyseStructure(SetupTimeframe(),ReplayBars(ChartStructureBars(SetupTimeframe())),
                        MTF_Swing_Sensitivity,setup_state,setup_rates,setup_points,setup_events))
      return false;
   if(!AnalyseStructure(LTFTimeframe(),ReplayBars(ChartStructureBars(LTFTimeframe())),
                        LTF_Swing_Sensitivity,ltf_state,ltf_rates,ltf_points,ltf_events))
      return false;
   int ltf_total=ArraySize(ltf_rates);
   double ltf_atr[];
   if(!CopyIndicator(g_ltf_atr_handle,0,1,ltf_atr)) return false;

   // Labels follow the chart period, while the dashboard state stays on
   // Structure_Timeframe.
   bool anchored=chart_timeframe==timeframe;
   MqlRates chart_rates[];
   ArraySetAsSeries(chart_rates,false);
   int chart_total=0;
   if(!anchored)
     {
      chart_total=CopyRates(_Symbol,chart_timeframe,1,
                            ReplayBars(ChartStructureBars(chart_timeframe)),chart_rates);
      if(chart_total<=0) return false;
     }

   BASE_STRUCTURE_STATE structure_state;
   BASE_STRUCTURE_POINT points[];
   BASE_STRUCTURE_EVENT events[];
   ReplayStructure(rates,total,filter,structure_state,points,events);

   // The MTF MA line, if shown, over the drawn MTF candles.
   MqlRates mtf_rates[];
   double mtf_ma[];
   int mtf_count=0;
   ArraySetAsSeries(mtf_rates,false);
   if(Show_MTF_MA_Line && Use_MTF_MA_Filter)
     {
      mtf_count=MathMin(501,ChartStructureBars(SetupTimeframe()));
      if(CopyRates(_Symbol,SetupTimeframe(),1,mtf_count,mtf_rates)!=mtf_count ||
         !CopyIndicator(g_mtf_ma_handle,0,mtf_count,mtf_ma))
         mtf_count=0;
     }
   bool htf_line=Show_HTF_MA_Line && Use_HTF_MA_Filter && ArraySize(ma)==total;

   // The MA lines at each drawn candle, so labels keep clear of them.
   double line_a[],line_b[];
   ObjectsDeleteAll(0,g_prefix);
   if(anchored)
     {
      if(htf_line) SampleLine(rates,ma,FirstMABar(total,displayed)-1,total,rates,total,line_a);
      if(mtf_count>1) SampleLine(mtf_rates,mtf_ma,0,mtf_count,rates,total,line_b);
      DrawStructure(rates,total,MathMax(0,total-displayed),structure_state,points,events,line_a,line_b);
     }
   else
     {
      BASE_STRUCTURE_STATE chart_state;
      BASE_STRUCTURE_POINT chart_points[];
      BASE_STRUCTURE_EVENT chart_events[];
      if(htf_line) SampleLine(rates,ma,FirstMABar(total,displayed)-1,total,chart_rates,chart_total,line_a);
      if(mtf_count>1) SampleLine(mtf_rates,mtf_ma,0,mtf_count,chart_rates,chart_total,line_b);
      if(ReplayStructure(chart_rates,chart_total,SwingFilter(ChartSensitivity(chart_timeframe)),
                         chart_state,chart_points,chart_events))
         DrawStructure(chart_rates,chart_total,
                       MathMax(0,chart_total-ChartStructureBars(chart_timeframe)),
                       chart_state,chart_points,chart_events,line_a,line_b);
     }
   DrawAverageLines(rates,total,displayed,ma,mtf_rates,mtf_ma,mtf_count);

   string tradability_reason="";
   bool bias_ready=EvaluateTradability(structure_state,setup_state,ltf_state,tradability_reason);
   bool tradable=bias_ready;
   bool healthy_extension=HealthyExtension(structure_state,ltf_state,
                                           ltf_rates[ltf_total-1].close,ltf_atr[0]);

   int volume_length=MathMin(Volume_Average_Length,ltf_total-1);
   double average_volume=0.0;
   for(int i=ltf_total-1-volume_length;i<ltf_total-1;i++) average_volume+=(double)ltf_rates[i].tick_volume;
   if(volume_length>0) average_volume/=volume_length;
   double volume_ratio=average_volume>0.0?(double)ltf_rates[ltf_total-1].tick_volume/average_volume:0.0;
   bool good_volume=average_volume>0.0 && volume_ratio>=Volume_Minimum_Ratio &&
                    volume_ratio<=Volume_Maximum_Ratio;
   int momentum_length=MathMin(Momentum_Average_Length,ltf_total-2);
   double average_true_range=0.0;
   for(int i=ltf_total-1-momentum_length;i<ltf_total-1;i++)
      average_true_range+=BarTrueRange(ltf_rates,i);
   if(momentum_length>0) average_true_range/=momentum_length;
   double momentum_ratio=average_true_range>0.0?
                         BarTrueRange(ltf_rates,ltf_total-1)/average_true_range:0.0;
   bool good_momentum=average_true_range>0.0 &&
                      momentum_ratio>=Momentum_Minimum_Ratio &&
                      momentum_ratio<=Momentum_Maximum_Ratio;
   string optimal_reason="";
   bool optimal=EvaluateOptimal(bias_ready,healthy_extension,good_volume,volume_ratio,
                                good_momentum,momentum_ratio,optimal_reason);

   DrawDashboard(structure_state,BreakdownText(structure_state,points,events),
                 TradeRecommendation(structure_state,points,setup_state,ltf_state,tradable),
                 setup_state,BreakdownText(setup_state,setup_points,setup_events),
                 ltf_state,BreakdownText(ltf_state,ltf_points,ltf_events),
                 tradable,tradability_reason,EntryFilterTooltip(rates[total-1],ma,adx,atr),
                 optimal,optimal_reason,bias_ready,healthy_extension,good_volume,volume_ratio,
                 good_momentum,momentum_ratio);
   // Alert every event that became known on the newest closed candle (a CHoCH
   // confirmed by a second break arrives together with its BOS).  An LS
   // comes first: it is known before the old trend's BOS on the same candle.
   string signal="";
   for(int i=ArraySize(events)-1;i>=0 && events[i].bar==total-1;i--)
      signal=(events[i].bos?"BOS ":"CHoCH ")+(events[i].direction>0?"bullish":"bearish")+
             (signal==""?"":" + ")+signal;
   for(int i=ArraySize(events)-1;i>=0;i--)
      if(events[i].ls && events[i].ls_bar==total-1)
        {
         signal="LS ("+(events[i].direction>0?"bullish":"bearish")+" CHoCH failed)"+
                (signal==""?"":" + ")+signal;
         break;
        }
   if(permit_alert && signal!="") SendBASEAlert(signal,rates[total-1].time);
   ChartRedraw();
   g_built=true;
   return true;
  }

bool ValidInputs()
  {
   string problem="";
   if(HTF_Swing_Sensitivity<0 || HTF_Swing_Sensitivity>100 ||
      MTF_Swing_Sensitivity<0 || MTF_Swing_Sensitivity>100 ||
      LTF_Swing_Sensitivity<0 || LTF_Swing_Sensitivity>100)
      problem="each Swing Sensitivity must be between 0 and 100";
   else if(Bars_To_Process<100)
      problem="Bars_To_Process must be at least 100";
   else if(HTF_MA_Length<1 || MTF_MA_Length<1 || ADX_Length<1 || ATR_Length<1)
      problem="HTF MA, MTF MA, ADX and ATR lengths must be positive";
   else if(!Use_Timeframe_Correlation_For_Optimal && !Use_Healthy_Extension_For_Optimal &&
           !Use_Market_Volume_For_Optimal && !Use_Price_Momentum_For_Optimal)
      problem="enable at least one Optimal Conditions requirement";
   else if(!Use_HTF && !Use_MTF && !Use_LTF)
      problem="enable at least one trend analysis timeframe";
   if(problem=="") return true;
   Print("BASE: invalid input - ",problem,".");
   return false;
  }

int OnInit()
  {
   if(!ValidInputs()) return INIT_PARAMETERS_INCORRECT;
   // MT5 keeps an EA's global variables across a chart timeframe change, so
   // explicitly forget the previous chart's bars.  Otherwise a first build that
   // waits for data would never be retried until the next LTF candle.
   g_last_ltf_bar=0;
   g_last_structure_bar=0;
   g_last_setup_bar=0;
   ENUM_TIMEFRAMES timeframe=BASETimeframe();
   g_prefix="BASE_"+(string)ChartID()+"_";
   g_built=false;
   // Draw objects in front of the candles so no label is hidden behind one;
   // the chart's own setting is restored when Base is removed.
   if(g_foreground<0) g_foreground=ChartGetInteger(0,CHART_FOREGROUND);
   ChartSetInteger(0,CHART_FOREGROUND,false);
   if(Use_HTF_MA_Filter && (g_htf_ma_handle=iMA(_Symbol,timeframe,HTF_MA_Length,0,BASEMAMethod(HTF_MA_Type),PRICE_CLOSE))==INVALID_HANDLE) return INIT_FAILED;
   if(Use_MTF_MA_Filter && (g_mtf_ma_handle=iMA(_Symbol,SetupTimeframe(),MTF_MA_Length,0,BASEMAMethod(MTF_MA_Type),PRICE_CLOSE))==INVALID_HANDLE) return INIT_FAILED;
   if(Use_ADX_Filter && (g_adx_handle=iADX(_Symbol,timeframe,ADX_Length))==INVALID_HANDLE) return INIT_FAILED;
   if(Use_ATR_Filter && (g_atr_handle=iATR(_Symbol,timeframe,ATR_Length))==INVALID_HANDLE) return INIT_FAILED;
   if((g_ltf_atr_handle=iATR(_Symbol,LTFTimeframe(),ATR_Length))==INVALID_HANDLE) return INIT_FAILED;
   if(!EventSetTimer(2)) return INIT_FAILED;
   CheckForBar();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(g_htf_ma_handle!=INVALID_HANDLE) IndicatorRelease(g_htf_ma_handle);
   if(g_mtf_ma_handle!=INVALID_HANDLE) IndicatorRelease(g_mtf_ma_handle);
   if(g_adx_handle!=INVALID_HANDLE) IndicatorRelease(g_adx_handle);
   if(g_atr_handle!=INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   if(g_ltf_atr_handle!=INVALID_HANDLE) IndicatorRelease(g_ltf_atr_handle);
   g_htf_ma_handle=INVALID_HANDLE;
   g_mtf_ma_handle=INVALID_HANDLE;
   g_adx_handle=INVALID_HANDLE;
   g_atr_handle=INVALID_HANDLE;
   g_ltf_atr_handle=INVALID_HANDLE;
   ObjectsDeleteAll(0,g_prefix);
   Comment("");
   if(g_foreground>=0 && reason!=REASON_CHARTCHANGE && reason!=REASON_PARAMETERS)
     {
      ChartSetInteger(0,CHART_FOREGROUND,g_foreground!=0);
      g_foreground=-1;
     }
  }

// A zoom changes how many candles each label covers: lay the chart out
// again.  Scrolling alone changes nothing.
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   if(id==CHARTEVENT_CHART_CHANGE && g_built && ChartGetInteger(0,CHART_SCALE)!=g_layout_scale)
      Rebuild(false);
  }

void CheckForBar()
  {
   datetime current=iTime(_Symbol,LTFTimeframe(),0);
   datetime structure_current=iTime(_Symbol,BASETimeframe(),0);
   datetime setup_current=iTime(_Symbol,SetupTimeframe(),0);
   if(current==0 || structure_current==0 || setup_current==0) return;
   bool changed=current!=g_last_ltf_bar || structure_current!=g_last_structure_bar ||
                setup_current!=g_last_setup_bar;
   if(changed)
     {
      // The first build after attaching never alerts.
      bool alert=g_last_ltf_bar!=0 && g_last_structure_bar!=0 && g_last_setup_bar!=0;
      // Do not consume the bar until every required series has loaded.  When
      // Rebuild reports temporary unavailability, OnTimer will retry in two
      // seconds even if no tick arrives on the newly selected timeframe.
      if(Rebuild(alert))
        {
         g_last_ltf_bar=current;
         g_last_structure_bar=structure_current;
         g_last_setup_bar=setup_current;
        }
     }
  }

void OnTick() { CheckForBar(); }
void OnTimer() { CheckForBar(); }
