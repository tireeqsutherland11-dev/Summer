#property copyright "83% Strategy on Base (v2.43) and Fib Base"
#property version   "1.00"
#property strict
#property description "83% Strategy: buys the 83% retracement of a heavy LTF HL-to-HH leg (sells mirror it) when Market Tradability reads Tradable in that direction."
#property description "Base's market structure and dashboard, Fib Base's Fibonacci levels; trades only in the Strategy Tester by default."

#include <Trade\Trade.mqh>

enum BASE_SESSION { BASE_NEW_YORK=0, BASE_LONDON=1, BASE_TOKYO=2, BASE_SYDNEY=3, BASE_CUSTOM=4, BASE_24X7=5 };
enum BASE_ADX_SCOPE { BASE_BOS_ONLY=0, BASE_BOS_AND_CHOCH=1 };
enum BASE_ATR_MODE { BASE_ATR_MINIMUM=0, BASE_ATR_MAXIMUM=1, BASE_ATR_RANGE=2 };
enum BASE_LABEL_SIZE { BASE_TINY=7, BASE_SMALL=9, BASE_NORMAL=11, BASE_LARGE=14 };
// Market Tradability (see EvaluateTradability).
enum BASE_TRADABILITY { BASE_NOT_TRADABLE=0, BASE_TRADABLE_EARLY=1, BASE_TRADABLE=2 };

// 83% Strategy (see the 83% Strategy section below).
enum S83_TRADE_MODE
  {
   S83_TRADING_OFF=0,       // Off (analysis only)
   S83_TRADING_TESTER=1,    // Strategy Tester only
   S83_TRADING_LIVE=2       // Strategy Tester and live charts
  };
enum S83_FIB_LABEL
  {
   S83_LABEL_PERCENT=0,     // Percent (83.00%)
   S83_LABEL_RATIO=1,       // Ratio (0.83)
   S83_LABEL_PRICE=2,       // Price
   S83_LABEL_PERCENT_PRICE=3 // Percent and price
  };
enum S83_HURST_TF
  {
   S83_HURST_HTF=0,         // HTF
   S83_HURST_MTF=1,         // MTF
   S83_HURST_LTF=2          // LTF
  };

input group "Timeframes"
input ENUM_TIMEFRAMES Structure_Timeframe=PERIOD_H4; // HTF
input ENUM_TIMEFRAMES Setup_Entry_Timeframe=PERIOD_H1; // MTF
input ENUM_TIMEFRAMES LTF_Timeframe=PERIOD_M30; // LTF

// Base's Trend Analysis Timeframes are fixed: the 83% Strategy's trend is the
// HTF EMAs and the MTF swings (see EvaluateTradability).
const bool Use_HTF=true;
const bool Use_MTF=true;
const bool Use_LTF=false;

input group "Structure Bar Processing"
input int Bars_To_Process=100;

input group "Swing Detection"
input int HTF_Swing_Level=3; // HTF Swing Detection Length (1-10)
input int MTF_Swing_Level=5; // MTF Swing Detection Length (1-10)
input int LTF_Swing_Level=3; // LTF Swing Detection Length (1-10)
input bool Show_Swing_Points=true;
input bool Show_Strong_Weak_High_Low=true; // Show Strong/Weak High/Low

input group "Internal Structure"
input bool Show_Internal_Structure=false; // Show Internal Structure (on the chart only)
const bool Show_Internal_On_Dashboard=false;   // the Internal Structure is not on the dashboard
input int HTF_Internal_Level=4; // HTF Internal Structure Length (1-10)
input int MTF_Internal_Level=4; // MTF Internal Structure Length (1-10)
input int LTF_Internal_Level=4; // LTF Internal Structure Length (1-10)
input color Internal_Bullish_Color=C'8,153,129'; // Internal Bullish Color
input color Internal_Bearish_Color=C'242,54,69'; // Internal Bearish Color

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
input ENUM_LINE_STYLE Line_Style=STYLE_SOLID;
input int Line_Width=2;

input group "EQH/EQL"
input bool Show_Equal_Highs_Lows=true; // Show EQH/EQL
input double Equal_Highs_Lows_Threshold=0.2; // EQH/EQL Threshold (ATR, 0 = off)

input group "HTF EMA Trend Filter"
input int HTF_EMA_Fast=20; // HTF Fast EMA
input int HTF_EMA_Middle=50; // HTF Middle EMA
input int HTF_EMA_Slow=200; // HTF Slow EMA (bullish 20 > 50 > 200, bearish 20 < 50 < 200)
input int HTF_EMA_Candles=1; // Closed HTF Candles The EMA Order Must Hold On (1 = the latest)
input bool Show_HTF_EMA_Lines=false; // Show HTF EMA Lines
input color HTF_EMA_Fast_Color=clrDodgerBlue; // HTF Fast EMA Color
input color HTF_EMA_Middle_Color=clrDarkOrange; // HTF Middle EMA Color
input color HTF_EMA_Slow_Color=clrPurple; // HTF Slow EMA Color

input group "Hurst Exponent (Trend Persistence)"
input S83_HURST_TF Hurst_Timeframe=S83_HURST_HTF; // Hurst Timeframe
input int Hurst_Candles=100; // Hurst Window (closed candles, 50-400)
input double Hurst_Minimum=0.55; // Tradable When H Is Above (0.5 = random walk)

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

input group "Alerts"
input bool Enable_Popup_Alerts=false;
input bool Enable_Push_Notifications=false;

input group "83% Strategy - Symbol (Deriv Synthetic Indices)"
input double Minimum_Lot_Max_Risk_Multiple=0.0;   // Trade The Minimum Lot If It Risks At Most N x The Planned Risk (0 = skip)

input group "83% Strategy - Setup (LTF)"
input int    LTF_Bars_To_Process=40;              // LTF Independent Processed Bars
input double Entry_Level=0.83;                    // Entry Fibonacci Level (0.83 = 83%)
input int    Impulse_Candles=3;                   // Heavy Pressure: Candles After The HL/LH
input double Impulse_Min_ATR=2.0;                 // Heavy Pressure: Minimum Move (LTF ATR)

input group "83% Strategy - Risk Management"
input S83_TRADE_MODE Trade_Mode=S83_TRADING_TESTER;
input double Risk_Percent=5.0;                    // Risk (%) Per Trade
input int    Max_Trades_Per_Day=5;                // Number Of Trades Per Day (Max)
input int    Losses_Before_Risk_Cut=2;            // Consecutive Losses Before Cutting The Risk (0 = never)
input double Risk_Cut_Factor=0.5;                 // Risk Multiplier After Each Run Of Losses
input bool   Trade_Monday=true;
input bool   Trade_Tuesday=true;
input bool   Trade_Wednesday=true;
input bool   Trade_Thursday=true;
input bool   Trade_Friday=true;
input bool   Trade_Saturday=true;
input bool   Trade_Sunday=false;
input ulong  Magic_Number=20261001;

input group "83% Strategy - Stop Loss, Take Profit and Breakeven"
input double SL_Buffer_ATR=0.5;                   // Stop Loss Behind The HL/LH (LTF ATR)
input double TP_Buffer_ATR=0.1;                   // Take Profit Before The HH/LL (LTF ATR)
input double Reward_Risk_Low=2.0;                 // Standard R:R (1:2)
input double Reward_Risk_High=3.0;                // Standard R:R (1:3)
input double Breakeven_At_Percent=60.0;           // Breakeven At % Of The Take Profit (0 = off)

input group "83% Strategy - Fibonacci (Fib Base)"
input bool   Show_Fibonacci=true;
input bool   Fib_Level_1_Show=true;               // Level 1 Show
input double Fib_Level_1=0.0;                     // Level 1 (B)
input color  Fib_Level_1_Color=clrGray;           // Level 1 Color
input bool   Fib_Level_2_Show=false;              // Level 2 Show
input double Fib_Level_2=0.5;                     // Level 2
input color  Fib_Level_2_Color=clrMediumSeaGreen; // Level 2 Color
input bool   Fib_Level_3_Show=false;              // Level 3 Show
input double Fib_Level_3=0.618;                   // Level 3
input color  Fib_Level_3_Color=clrTeal;           // Level 3 Color
input bool   Fib_Level_4_Show=false;              // Level 4 Show
input double Fib_Level_4=0.705;                   // Level 4
input color  Fib_Level_4_Color=clrDarkTurquoise;  // Level 4 Color
input bool   Fib_Level_5_Show=false;              // Level 5 Show
input double Fib_Level_5=0.886;                   // Level 5
input color  Fib_Level_5_Color=clrPurple;         // Level 5 Color
input bool   Fib_Level_6_Show=true;               // Level 6 Show
input double Fib_Level_6=1.0;                     // Level 6 (A)
input color  Fib_Level_6_Color=clrGray;           // Level 6 Color
input color  Entry_Level_Color=clrOrange;         // Entry Level (83%) Color
input ENUM_LINE_STYLE Fib_Line_Style=STYLE_SOLID;
input int    Fib_Line_Width=1;
input S83_FIB_LABEL Fib_Label_Text=S83_LABEL_PERCENT;
input int    Fib_Right_Offset=10;                 // Fibonacci Candles Right Of The Latest Candle

input group "83% Strategy - Visuals (LTF)"
input int    Setups_To_Show=2;                    // Setups Shown On The LTF Chart (the latest; live ones always)
input bool   Show_Setup_Points=true;              // Show A / B / C
input color  Bullish_Setup_Color=clrRed;          // Buy Setup A / B / C Color
input color  Bearish_Setup_Color=clrRoyalBlue;    // Sell Setup A / B / C Color
input bool   Show_Position_Boxes=true;            // Show Target And Stop Zones
input color  Target_Zone_Color=C'214,226,250';
input color  Stop_Zone_Color=C'248,215,218';
input int    Position_Box_Candles=20;             // Zone Width (LTF Candles)

// Internal tuning values are deliberately kept out of the Inputs dialog. The
// streamlined UI exposes only settings that are useful during normal use.
const double ADX_Minimum=25.0;
const BASE_ADX_SCOPE Apply_ADX_Filter_To=BASE_BOS_ONLY;
const BASE_ATR_MODE ATR_Filter_Mode=BASE_ATR_MINIMUM;
const double ATR_Minimum=1.0;
const double ATR_Maximum=10.0;

// Swing detection (Smart Money Engine): a swing high is a pivot of N candles
// on each side (see PivotHigh), which is also how many candles it takes to
// confirm.  A smaller N finds more, faster swings; a larger N fewer, cleaner
// ones.  The internal structure uses the same pivots with its own, shorter N.
// The 14-candle ATR sizes the EQH/EQL threshold and the CHoCH trap area.
//
// Swing Detection and Internal Structure Lengths are a 1-10 scale, not N
// itself: swings found with N candles are mostly the same swings found with
// N+1, so at N=10 one more candle changed only 11% of the drawn labels.  Each
// level is the N that changes about a third of the drawn swing labels from
// the level before (27-42% on real data, 23-43% on generated markets):
//   level      1   2   3   4   5   6   7   8   9  10
//   N          1   2   3   5   7  10  14  19  26  36
const int MIN_DETECTION_LEVEL=1;
const int MAX_DETECTION_LEVEL=10;
const int SWING_ATR_LENGTH=14;

// Candles on each side of a pivot (N) for a Swing Detection or Internal
// Structure level.
int DetectionCandles(const int level)
  {
   switch(MathMax(MIN_DETECTION_LEVEL,MathMin(MAX_DETECTION_LEVEL,level)))
     {
      case 1: return 1;
      case 2: return 2;
      case 3: return 3;
      case 4: return 5;
      case 5: return 7;
      case 6: return 10;
      case 7: return 14;
      case 8: return 19;
      case 9: return 26;
     }
   return 36;
  }

int HTFSwingLength() { return DetectionCandles(HTF_Swing_Level); }
int MTFSwingLength() { return DetectionCandles(MTF_Swing_Level); }
int LTFSwingLength() { return DetectionCandles(LTF_Swing_Level); }
int HTFInternalLength() { return DetectionCandles(HTF_Internal_Level); }
int MTFInternalLength() { return DetectionCandles(MTF_Internal_Level); }
int LTFInternalLength() { return DetectionCandles(LTF_Internal_Level); }

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
datetime g_last_ltf_bar=0;
datetime g_last_structure_bar=0;
datetime g_last_setup_bar=0;
int g_adx_handle=INVALID_HANDLE;
int g_atr_handle=INVALID_HANDLE;

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
   // Strong/Weak High/Low (Smart Money Engine, see ReplayStructure): the swing
   // protected by the latest break and the trend's trailing extreme.
   bool have_trail_high;
   bool have_trail_low;
   double trail_high;
   double trail_low;
   datetime trail_high_time;
   datetime trail_low_time;
  };

// One accepted structure point.  A point is superseded when a more extreme
// pivot is confirmed before the opposite leg begins (see AcceptStructureHigh).
// An equal high or low (EQH/EQL, see MarkEqualSwing) keeps the role of the
// swing it equals, and its break level is the outer edge of the pair.
struct BASE_STRUCTURE_POINT
  {
   int pivot;               // bar index of the swing candle
   int confirmed;           // bar index on which the swing was accepted
   datetime time;
   double price;
   int side;                // 1 high, -1 low
   int kind;                // 1 HH/LL, -1 LH/HL, 0 untyped
   bool superseded;
   int equal;               // points index of the swing it equals (EQH/EQL), -1 if none
   double level;            // break level: the price, or the outer edge of an EQH/EQL pair
   datetime level_time;     // the swing that holds the level
   int level_pivot;
  };

// One close-confirmed structure break.
struct BASE_STRUCTURE_EVENT
  {
   int bar;                 // candle on which the event became known
   int break_bar;           // candle that closed through the level
   int direction;           // 1 bullish, -1 bearish
   bool bos;                // true BOS (continuation), false CHoCH
   datetime swing_time;     // pivot time of the broken level
   int swing_bar;           // bar index of that swing
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

// The chart draws its own timeframe with the swing and internal lengths of
// the matching HTF, MTF or LTF inputs; any other chart period uses the HTF
// lengths.
int ChartSwingLength(const ENUM_TIMEFRAMES timeframe)
  {
   if(timeframe==BASETimeframe()) return HTFSwingLength();
   if(timeframe==SetupTimeframe()) return MTFSwingLength();
   if(timeframe==LTFTimeframe()) return LTFSwingLength();
   return HTFSwingLength();
  }

int ChartInternalLength(const ENUM_TIMEFRAMES timeframe)
  {
   if(timeframe==BASETimeframe()) return HTFInternalLength();
   if(timeframe==SetupTimeframe()) return MTFInternalLength();
   if(timeframe==LTFTimeframe()) return LTFInternalLength();
   return HTFInternalLength();
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
   int longest=MathMax(HTFSwingLength(),MathMax(MTFSwingLength(),LTFSwingLength()));
   return MathMax(2*longest+2,MathMin(wanted,100000));
  }

int ReplayBars(const int displayed)
  {
   return MathMin(100000,displayed*STRUCTURE_WARMUP_FACTOR);
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

// A structure line never clips through a candle: it ends on the first
// candle after the swing whose wick or body reaches the level (high at or
// above a level broken upwards, low at or below one broken downwards).  That
// is the candle that closed through the level unless an earlier wick swept
// it.
int FirstTouchBar(const MqlRates &rates[],const int swing_bar,const int break_bar,
                  const int direction,const double level)
  {
   for(int b=swing_bar+1;b<break_bar;b++)
      if(direction>0?rates[b].high>=level:rates[b].low<=level) return b;
   return break_bar;
  }

// Structure must alternate between a high leg and a low leg.  When several
// same-side pivots are confirmed before the opposite leg appears, they are one
// swing rather than several contrasting structure points: retain only the
// highest high or lowest low.  The reference is the extreme from the previous
// same-side leg, so replacing a candidate does not change what it is compared
// against when deciding HH/LH or LL/HL.
bool AcceptStructureHigh(const double value,bool &have_high,double &last_high,
                         int &last_side,bool &have_reference,double &reference,int &kind)
  {
   if(last_side==1)
     {
      if(value<=last_high) return false;
      last_high=value;
      kind=have_reference?(value>reference?1:-1):0;
      return true;
     }
   have_reference=have_high;
   reference=last_high;
   kind=have_high?(value>last_high?1:-1):0;
   have_high=true;
   last_high=value;
   last_side=1;
   return true;
  }

bool AcceptStructureLow(const double value,bool &have_low,double &last_low,
                        int &last_side,bool &have_reference,double &reference,int &kind)
  {
   if(last_side==-1)
     {
      if(value>=last_low) return false;
      last_low=value;
      kind=have_reference?(value<reference?1:-1):0;
      return true;
     }
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
   points[index].equal=-1;
   points[index].level=points[index].price;
   points[index].level_time=bar.time;
   points[index].level_pivot=pivot;
   return index;
  }

// EQH / EQL: a swing within Equal_Highs_Lows_Threshold ATR of the previous
// swing on its side (the swing its HH/LH or LL/HL label is judged against)
// is an equal high or low.  The two swings are one liquidity pool, so the
// new swing keeps the role of the swing it equals instead of being called
// higher or lower by a hair, and the pool's outer edge is the level a close
// must break.  An untyped first swing has no role to pass on.
void MarkEqualSwing(BASE_STRUCTURE_POINT &points[],const int index,const int reference,
                    const double atr)
  {
   if(reference<0 || points[reference].kind==0 || Equal_Highs_Lows_Threshold<=0.0) return;
   if(MathAbs(points[index].price-points[reference].price)>=Equal_Highs_Lows_Threshold*atr) return;
   points[index].kind=points[reference].kind;
   points[index].equal=reference;
   bool outer=points[index].side>0?points[reference].level>points[index].level:
                                   points[reference].level<points[index].level;
   if(!outer) return;
   points[index].level=points[reference].level;
   points[index].level_time=points[reference].level_time;
   points[index].level_pivot=points[reference].level_pivot;
  }

void AddStructureEvent(BASE_STRUCTURE_EVENT &events[],BASE_STRUCTURE_STATE &state,
                       const int bar,const int break_bar,const int direction,const bool bos,
                       const datetime swing_time,const int swing_bar,const double level)
  {
   int index=ArraySize(events);
   ArrayResize(events,index+1,64);
   events[index].bar=bar;
   events[index].break_bar=break_bar;
   events[index].direction=direction;
   events[index].bos=bos;
   events[index].swing_time=swing_time;
   events[index].swing_bar=swing_bar;
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
   int bar;                 // bar index of the swing that holds the level
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
   int level_bar;
   int level_point;
  };

void SetLevel(BASE_LEVEL &level,const BASE_STRUCTURE_POINT &points[],const int index)
  {
   level.active=true;
   level.price=points[index].level;
   level.time=points[index].level_time;
   level.bar=points[index].level_pivot;
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
   choch.level_bar=level.bar;
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
   restored.bar=choch.level_bar;
   restored.point=choch.level_point;
   if(choch.direction>0 && high_point==choch.level_point) lh=restored;
   if(choch.direction<0 && low_point==choch.level_point) hl=restored;
   choch.direction=0;
  }

// The swings after the broken LH have made an HH (bullish), or after the
// broken HL an LL (bearish), and no LL (HH) has formed after it since.  An
// equal high or low (EQH/EQL) is neither: it did not go beyond the swing it
// equals, so it neither confirms nor cancels a CHoCH.
bool CHoCHComplete(const BASE_CHOCH_CANDIDATE &choch,const BASE_STRUCTURE_POINT &points[],
                   const int high_point,const int low_point)
  {
   int extreme=choch.direction>0?high_point:low_point;
   int opposite=choch.direction>0?low_point:high_point;
   return extreme>choch.level_point && points[extreme].kind>0 && points[extreme].equal<0 &&
          (opposite<extreme || points[opposite].kind<0 || points[opposite].equal>=0);
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
                     choch.level_time,choch.level_bar,choch.level);
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

// Strong/Weak High/Low after one candle (see ReplayStructure): a break on
// this candle (new events, or an LS confirmed on it) protects the latest
// swing on the other side of the resulting trend, then the trailing extreme
// on the trend's side follows the candle.
void TrailExtremes(BASE_STRUCTURE_STATE &state,const BASE_STRUCTURE_POINT &points[],
                   const BASE_STRUCTURE_EVENT &events[],const int before,const int bar,
                   const MqlRates &candle,const int high_point,const int low_point)
  {
   int count=ArraySize(events);
   bool broke=count>before;
   for(int k=count-1;k>=0 && k>=count-3 && !broke;k--)
      if(events[k].ls && events[k].ls_bar==bar) broke=true;
   if(broke && state.direction>0 && low_point>=0)
     {
      state.have_trail_low=true;
      state.trail_low=points[low_point].price;
      state.trail_low_time=points[low_point].time;
     }
   if(broke && state.direction<0 && high_point>=0)
     {
      state.have_trail_high=true;
      state.trail_high=points[high_point].price;
      state.trail_high_time=points[high_point].time;
     }
   if(state.direction>0 && (!state.have_trail_high || candle.high>state.trail_high))
     {
      state.have_trail_high=true;
      state.trail_high=candle.high;
      state.trail_high_time=candle.time;
     }
   if(state.direction<0 && (!state.have_trail_low || candle.low<state.trail_low))
     {
      state.have_trail_low=true;
      state.trail_low=candle.low;
      state.trail_low_time=candle.time;
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
// Swings: a pivot of `length` candles on each side (see PivotHigh), accepted
// by the alternating-leg rules and labelled HH/LH or LL/HL against the previous
// leg's extreme, or EQH/EQL when within Equal_Highs_Lows_Threshold ATR of it
// (see MarkEqualSwing): an equal swing keeps that swing's role, breaks at the
// pool's outer edge, and neither confirms nor cancels a CHoCH.
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
//
// Strong/Weak High/Low (Smart Money Engine): every break (a BOS, a confirmed
// CHoCH or an LS restoring the old trend) protects the latest swing on the
// other side: a bullish one the latest swing low, a bearish one the latest
// swing high.  While the trend is bullish the trailing high follows every
// higher high (bearish: the trailing low every lower low).  The protected
// swing is Strong, the trailing extreme Weak: Strong Low / Weak High in a
// bullish trend, Strong High / Weak Low in a bearish one.
bool ReplayStructure(const MqlRates &rates[],const int total,const int length,
                     BASE_STRUCTURE_STATE &state,BASE_STRUCTURE_POINT &points[],
                     BASE_STRUCTURE_EVENT &events[])
  {
   ZeroMemory(state);
   state.labels_from=-1;
   state.trap_from=-1;
   ArrayResize(points,0);
   ArrayResize(events,0);
   if(total<2*length+2) return false;
   double atr[];
   SwingATR(rates,total,atr);
   int last_side=0;
   bool have_high_reference=false,have_low_reference=false;
   double high_reference=0.0,low_reference=0.0;
   int high_point=-1,low_point=-1;
   // The previous leg's swing on each side: the one a new swing is labelled
   // against, and the one it may equal (EQH/EQL).
   int high_reference_point=-1,low_reference_point=-1;
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
      int before=ArraySize(events);
      int pivot=i-length;
      bool pivot_high=PivotHigh(rates,total,pivot,length);
      bool pivot_low=PivotLow(rates,total,pivot,length);
      // A candle that is both a swing high and a swing low (an outside candle,
      // about 4% of swing candles at 1 candle a side) is taken in the order
      // its price most likely went: a bullish candle made its low first, a
      // bearish or flat one its high first.
      bool low_first=pivot_high && pivot_low && rates[pivot].close>rates[pivot].open;
      for(int pass=0;pass<2;pass++)
        {
         bool high_pass=(pass==0)!=low_first;
         if(high_pass && pivot_high)
           {
            int kind=0;
            bool same_leg=last_side==1;
            if(AcceptStructureHigh(rates[pivot].high,state.have_high,state.last_high,last_side,
                                   have_high_reference,high_reference,kind))
              {
               // A higher pivot in the same leg replaces the leg's high; the
               // first high of a new leg ends the low leg, identifying its low.
               if(same_leg) points[high_point].superseded=true;
               else
                 {
                  IdentifySwing(ll,hl,points,low_point);
                  high_reference_point=high_point;
                 }
               high_point=AddStructurePoint(points,pivot,i,rates[pivot],1,kind);
               MarkEqualSwing(points,high_point,high_reference_point,atr[pivot]);
               kind=points[high_point].kind;
               bool equal=points[high_point].equal>=0;
               state.last_high_kind=kind;
               state.last_high_time=rates[pivot].time;
               // An HH beyond the old uptrend's extreme after a failed bearish
               // CHoCH confirms the LS; a pending CHoCH attempt ends with it.
               if(LSSwing(watch,events,1,rates[pivot].high))
                 {
                  ConfirmLS(events,state,watch,i);
                  choch.direction=0;
                 }
               // Only swings formed after the breaking close can cancel a CHoCH,
               // and an equal high never does.
               else if(choch.direction>0 && kind<0 && pivot>choch.break_bar && !equal)
                  CancelCHoCH(choch,lh,hl,high_point,low_point);   // the break made only an LH
               else if(choch.direction<0 && kind>0 && pivot>choch.break_bar && !equal)
                  CancelCHoCH(choch,lh,hl,high_point,low_point);   // an HH before the LL
               else if(choch.direction!=0 && CHoCHComplete(choch,points,high_point,low_point))
                  ConfirmCHoCH(events,state,i,choch,watch,points,high_point,low_point,hh,ll);             // LH broken, then an HH
              }
           }
         if(!high_pass && pivot_low)
           {
            int kind=0;
            bool same_leg=last_side==-1;
            if(AcceptStructureLow(rates[pivot].low,state.have_low,state.last_low,last_side,
                                  have_low_reference,low_reference,kind))
              {
               if(same_leg) points[low_point].superseded=true;
               else
                 {
                  IdentifySwing(hh,lh,points,high_point);
                  low_reference_point=low_point;
                 }
               low_point=AddStructurePoint(points,pivot,i,rates[pivot],-1,kind);
               MarkEqualSwing(points,low_point,low_reference_point,atr[pivot]);
               kind=points[low_point].kind;
               bool equal=points[low_point].equal>=0;
               state.last_low_kind=kind;
               state.last_low_time=rates[pivot].time;
               if(LSSwing(watch,events,-1,rates[pivot].low))
                 {
                  ConfirmLS(events,state,watch,i);
                  choch.direction=0;
                 }
               else if(choch.direction<0 && kind<0 && pivot>choch.break_bar && !equal)
                  CancelCHoCH(choch,lh,hl,high_point,low_point);   // the break made only an HL
               else if(choch.direction>0 && kind>0 && pivot>choch.break_bar && !equal)
                  CancelCHoCH(choch,lh,hl,high_point,low_point);   // an LL before the HH
               else if(choch.direction!=0 && CHoCHComplete(choch,points,high_point,low_point))
                  ConfirmCHoCH(events,state,i,choch,watch,points,high_point,low_point,hh,ll);             // HL broken, then an LL
              }
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
            AddStructureEvent(events,state,i,i,1,true,hh.time,hh.bar,hh.price);
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
            AddStructureEvent(events,state,i,i,-1,true,ll.time,ll.bar,ll.price);
           }
        }
      TrailExtremes(state,points,events,before,i,rates[i],high_point,low_point);
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
bool AnalyseStructure(const ENUM_TIMEFRAMES timeframe,const int wanted,const int length,
                      BASE_STRUCTURE_STATE &state,MqlRates &rates[],
                      BASE_STRUCTURE_POINT &points[],BASE_STRUCTURE_EVENT &events[])
  {
   ArraySetAsSeries(rates,false);
   int total=CopyRates(_Symbol,timeframe,1,wanted,rates);
   return total>0 && ReplayStructure(rates,total,length,state,points,events);
  }

// Internal Structure (Smart Money Engine): minor structure inside the swings,
// from pivots of the timeframe's Internal Structure Length candles (default
// 5, shorter than the Swing Detection Length).  It gives more insight into
// the moves between swings without changing the Market Trend or alerts; its
// only effect elsewhere is Tradable (Early), which requires it to agree (see
// EvaluateTradability).
//  * Each internal pivot high (low) becomes the internal high (low) level.
//  * The first close above the internal high is an internal bullish BOS, or
//    an internal bullish CHoCH when the internal trend was bearish; bearish
//    mirrors this.  Each level is broken once, and the break sets the
//    internal trend.
//  * On the chart its breaks are drawn as dashed width-1 lines with faded
//    captions, except where the internal pivot is also a swing of the main
//    structure, which draws that level itself.
// As everywhere in Base, only closed candles are used.
struct BASE_INTERNAL_STRUCTURE
  {
   int trend;               // 1 bullish, -1 bearish, 0 no break yet
   bool last_choch;         // the latest break was a CHoCH
   double break_level;      // the level the latest break closed through
   bool have_high;
   bool have_low;
   double high;             // the latest internal pivot high and low
   double low;
   int high_bar;
   int low_bar;
   bool high_broken;
   bool low_broken;
  };

// One internal break: the pivot it closed through, the candle that did, the
// first candle that touched the level (where its line ends, see
// FirstTouchBar), and the candle midway between the pivot and that one where
// its caption is centred.
struct BASE_BREAK_MARK
  {
   int direction;           // 1 bullish, -1 bearish
   bool choch;              // a CHoCH (against the internal trend) or a BOS
   double level;
   datetime swing_time;
   datetime break_time;
   datetime end_time;
   datetime label_time;
  };

void AddBreakMark(BASE_BREAK_MARK &breaks[],const int direction,const bool choch,const double level,
                  const MqlRates &rates[],const int swing_bar,const int break_bar)
  {
   int index=ArraySize(breaks);
   ArrayResize(breaks,index+1,64);
   breaks[index].direction=direction;
   breaks[index].choch=choch;
   breaks[index].level=level;
   breaks[index].swing_time=rates[swing_bar].time;
   breaks[index].break_time=rates[break_bar].time;
   int end=FirstTouchBar(rates,swing_bar,break_bar,direction,level);
   breaks[index].end_time=rates[end].time;
   breaks[index].label_time=rates[(int)MathRound(0.5*(swing_bar+end))].time;
  }

void ReplayInternalStructure(const MqlRates &rates[],const int total,const int length,
                             BASE_INTERNAL_STRUCTURE &internal,BASE_BREAK_MARK &breaks[])
  {
   ZeroMemory(internal);
   ArrayResize(breaks,0);
   for(int t=length;t<total;t++)
     {
      int pivot=t-length;
      if(PivotHigh(rates,total,pivot,length))
        {
         internal.have_high=true;
         internal.high=rates[pivot].high;
         internal.high_bar=pivot;
         internal.high_broken=false;
        }
      if(PivotLow(rates,total,pivot,length))
        {
         internal.have_low=true;
         internal.low=rates[pivot].low;
         internal.low_bar=pivot;
         internal.low_broken=false;
        }
      double close=rates[t].close;
      if(internal.have_high && !internal.high_broken && close>internal.high)
        {
         internal.high_broken=true;
         internal.last_choch=internal.trend<0;
         internal.trend=1;
         internal.break_level=internal.high;
         AddBreakMark(breaks,1,internal.last_choch,internal.high,rates,internal.high_bar,t);
        }
      if(internal.have_low && !internal.low_broken && close<internal.low)
        {
         internal.low_broken=true;
         internal.last_choch=internal.trend>0;
         internal.trend=-1;
         internal.break_level=internal.low;
         AddBreakMark(breaks,-1,internal.last_choch,internal.low,rates,internal.low_bar,t);
        }
     }
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

// A swing's label: HH/LH/LL/HL, or EQH/EQL for an equal high or low (which
// keeps the role of the swing it equals).
string LabelText(const BASE_STRUCTURE_POINT &point)
  {
   if(Show_Equal_Highs_Lows && point.equal>=0) return point.side>0?"EQH":"EQL";
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

// Tradable (Early): early entries in the trend's direction while the
// transition holds, and the BOS that would confirm it.
string EarlyRecommendationText(const BASE_STRUCTURE_STATE &htf,const BASE_STRUCTURE_STATE &ltf)
  {
   int direction=BiasDirection(htf);
   string action=direction>0?"buys":"sells";
   if(DefiniteBias(htf))
      return HTFName()+" is "+TrendWord(direction)+" and the internal structure agrees: early "+action+
             " are possible before "+LTFName()+" confirms with a "+TrendWord(direction)+" BOS.";
   string text="Early "+action+" only";
   if(direction>0 && htf.have_hl) text+=", while price holds above HL "+PriceText(htf.hl);
   if(direction<0 && htf.have_lh) text+=", while price holds below LH "+PriceText(htf.lh);
   if(direction>0 && htf.have_hh) text+="; a close above HH "+PriceText(htf.hh)+" (bullish BOS) confirms the trend";
   if(direction<0 && htf.have_ll) text+="; a close below LL "+PriceText(htf.ll)+" (bearish BOS) confirms the trend";
   return text+".";
  }

// The dashboard's recommendation: the HTF's, unless an established HTF trend
// is held back by a selected lower timeframe, which it then names, or the
// market is only Tradable (Early).
string TradeRecommendation(const BASE_STRUCTURE_STATE &htf,const BASE_STRUCTURE_POINT &points[],
                           const BASE_STRUCTURE_STATE &mtf,const BASE_STRUCTURE_STATE &ltf,
                           const BASE_TRADABILITY tradability)
  {
   int direction=BiasDirection(htf);
   if(tradability==BASE_TRADABLE_EARLY) return EarlyRecommendationText(htf,ltf);
   bool tradable=tradability==BASE_TRADABLE;
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

// The internal structure's dashboard output: its trend and latest break.
string InternalTrendText(const BASE_INTERNAL_STRUCTURE &internal)
  {
   if(internal.trend==0) return "Undefined";
   return (internal.trend>0?"Bullish":"Bearish")+(internal.last_choch?" (CHoCH)":" (BOS)");
  }

// How the internal structure relates to the timeframe's Market Trend.
string InternalAgreementText(const BASE_INTERNAL_STRUCTURE &internal,const BASE_STRUCTURE_STATE &state,
                             const string name)
  {
   int trend=BiasDirection(state);
   if(internal.trend==0) return "No internal break yet to compare with the "+name+" Market Trend.";
   if(trend==0)
      return "The "+name+" Market Trend is ranging; the internal structure is "+TrendWord(internal.trend)+".";
   if(trend==internal.trend) return "Agrees with the "+name+" Market Trend.";
   return "Opposes the "+name+" Market Trend: a "+TrendWord(internal.trend)+" move inside the "+
          TrendWord(trend)+" trend (a pullback until the swing structure breaks).";
  }

string InternalStructureTooltip(const BASE_INTERNAL_STRUCTURE &internal,const BASE_STRUCTURE_STATE &state,
                                const string name,const int level)
  {
   string text="Internal structure (level "+(string)level+": "+(string)DetectionCandles(level)+
               "-candle swings)\nInternal trend: ";
   if(internal.trend==0) text+="no internal level broken yet";
   else text+=(internal.trend>0?"Bullish":"Bearish")+" since a "+TrendWord(internal.trend)+" "+
              (internal.last_choch?"CHoCH":"BOS")+" through "+PriceText(internal.break_level);
   return text+"\n"+InternalAgreementText(internal,state,name);
  }

// Strong/Weak High/Low of a timeframe: the swing protected by the latest
// break is Strong, the trailing extreme on the trend's side Weak.
string StrongWeakText(const BASE_STRUCTURE_STATE &state)
  {
   string high=state.have_trail_high?(state.direction<0?"Strong High ":"Weak High ")+PriceText(state.trail_high):
               "no swing high yet";
   string low=state.have_trail_low?(state.direction>0?"Strong Low ":"Weak Low ")+PriceText(state.trail_low):
              "no swing low yet";
   return high+" | "+low;
  }

// The four-line breakdown, joined for a tooltip.
string BreakdownText(const BASE_STRUCTURE_STATE &state,const BASE_STRUCTURE_POINT &points[],
                     const BASE_STRUCTURE_EVENT &events[])
  {
   return "Current Trend Classification: "+BiasText(state)+
          "\nTrigger Condition Met: "+TriggerText(state)+
          "\nStructural Evidence: "+EvidenceText(state,points,events)+
          "\nStrong/Weak: "+StrongWeakText(state)+
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

// "H4", "H4 and M15": timeframes joined for a sentence.
string JoinNames(const string &names[],const int count)
  {
   string result="";
   for(int i=0;i<count;i++)
      result+=(i==0?"":(i==count-1?" and ":", "))+names[i];
   return result;
  }

// Market Tradability (83% Strategy): trend identification from three
// conditions, which must all line up.
//  * Bullish:
//     1. HTF EMA trend filter: the HTF EMAs are in order, fast > middle > slow
//        (HTF_EMA_Fast 20 > HTF_EMA_Middle 50 > HTF_EMA_Slow 200), on each of
//        the last HTF_EMA_Candles closed HTF candles (1: the latest one).
//     2. MTF structural progression, upward expansion: a Higher High (the
//        latest swing high above the previous one) and a Higher Low (the
//        latest swing low above the previous one).
//     3. The Hurst exponent H of the last Hurst_Candles closed candles of the
//        Hurst timeframe (the HTF by default) is above Hurst_Minimum (0.55).
//  * Bearish: fast < middle < slow; a Lower Low and a Lower High; H above
//    Hurst_Minimum.
//  * Not Tradable otherwise; the reason names what is missing.
// The MTF swings are its structure swings (MTF Swing Detection Length): the
// latest swing high and the one before it (the previous leg's high; a
// higher high within the same leg replaces it), and the same for lows.  The
// Internal Structure plays no part (it is only drawn on the chart).
const int S83_HURST_MIN_LAG=2;    // the Hurst exponent's lags (see S83HurstOf)
const int S83_HURST_MAX_LAG=20;

struct S83_TREND
  {
   bool have_ema;
   double ema_fast;         // the HTF EMAs on the latest closed HTF candle
   double ema_middle;
   double ema_slow;
   int ema_stack;           // that candle's order: 1 fast > middle > slow, -1 fast < middle < slow, 0 neither
   int ema_direction;       // the order that held on each of the last HTF_EMA_Candles candles, else 0
   bool have_highs;
   double high;             // the MTF's latest swing high
   double prev_high;        // the swing high before it
   bool have_lows;
   double low;
   double prev_low;
   bool have_hurst;
   double hurst;            // the Hurst exponent H
   int hurst_candles;       // closed candles available for it
  };

// The latest swing on one side (1 highs, -1 lows) and the one before it,
// skipping swings a later one in the same leg replaced.
bool S83LastTwoSwings(const BASE_STRUCTURE_POINT &points[],const int side,double &current,double &previous)
  {
   int found=0;
   for(int k=ArraySize(points)-1;k>=0 && found<2;k--)
     {
      if(points[k].side!=side || points[k].superseded) continue;
      if(found==0) current=points[k].price;
      else previous=points[k].price;
      found++;
     }
   return found==2;
  }

// "HH", "LH" or "EQH" for highs; "LL", "HL" or "EQL" for lows.
string S83SwingTag(const int side,const double current,const double previous)
  {
   if(side>0) return current>previous?"HH":current<previous?"LH":"EQH";
   return current<previous?"LL":current>previous?"HL":"EQL";
  }

string S83EmaText()
  {
   return HTFName()+" "+(string)HTF_EMA_Fast+"/"+(string)HTF_EMA_Middle+"/"+(string)HTF_EMA_Slow+" EMA";
  }

// "20 > 50 > 200" (bullish) or "20 < 50 < 200" (bearish).
string S83EmaOrder(const int direction)
  {
   string op=direction>0?" > ":" < ";
   return (string)HTF_EMA_Fast+op+(string)HTF_EMA_Middle+op+(string)HTF_EMA_Slow;
  }

string S83HurstName()
  {
   return Hurst_Timeframe==S83_HURST_MTF?MTFName():Hurst_Timeframe==S83_HURST_LTF?LTFName():HTFName();
  }

// About 0.5 is a random walk; above it a trending (persistent) market, below
// it a mean-reverting one.
string S83HurstWord(const double h)
  {
   return h>0.55?"trending":h>=0.45?"random walk":"mean-reverting";
  }

// The MTF swings for a direction: "" when they show its expansion (an HH and
// an HL for buys, an LL and an LH for sells), else what is missing.
string S83SwingProblem(const S83_TREND &trend,const int d)
  {
   if(!trend.have_highs || !trend.have_lows)
      return "the "+MTFName()+" has no two swing "+(!trend.have_highs?"highs":"lows")+" yet";
   bool ok=d>0?trend.high>trend.prev_high && trend.low>trend.prev_low:
               trend.low<trend.prev_low && trend.high<trend.prev_high;
   if(ok) return "";
   return "the "+MTFName()+" swings are "+S83SwingTag(1,trend.high,trend.prev_high)+" + "+
          S83SwingTag(-1,trend.low,trend.prev_low)+", not "+(d>0?"HH + HL":"LL + LH")+" ("+
          (d>0?"upward":"downward")+" expansion)";
  }

// The Hurst exponent: "" when it is above Hurst_Minimum, else why not.
string S83HurstProblem(const S83_TREND &trend)
  {
   if(!trend.have_hurst)
      return trend.hurst_candles<Hurst_Candles?
             "the Hurst exponent needs "+(string)Hurst_Candles+" closed "+S83HurstName()+" candles ("+
             (string)trend.hurst_candles+" so far)":"the Hurst exponent is not available (the "+S83HurstName()+" closes do not move)";
   if(trend.hurst>Hurst_Minimum) return "";
   return "the Hurst exponent "+DoubleToString(trend.hurst,2)+" is not above "+DoubleToString(Hurst_Minimum,2)+
          " ("+S83HurstWord(trend.hurst)+")";
  }

BASE_TRADABILITY EvaluateTradability(const S83_TREND &trend,string &reason)
  {
   if(!trend.have_ema)
     {
      reason="The "+S83EmaText()+"s are not available yet (not enough "+HTFName()+" history).";
      return BASE_NOT_TRADABLE;
     }
   int d=trend.ema_direction;
   if(d==0)
     {
      if(trend.ema_stack!=0)
         reason="The "+HTFName()+" EMAs are "+S83EmaOrder(trend.ema_stack)+" on the latest closed candle, but not on each of the last "+
                (string)HTF_EMA_Candles+".";
      else
         reason="The "+HTFName()+" EMAs are not in order ("+(string)HTF_EMA_Fast+" EMA "+PriceText(trend.ema_fast)+", "+
                (string)HTF_EMA_Middle+" EMA "+PriceText(trend.ema_middle)+", "+(string)HTF_EMA_Slow+" EMA "+
                PriceText(trend.ema_slow)+"): bullish needs "+S83EmaOrder(1)+", bearish "+S83EmaOrder(-1)+".";
      return BASE_NOT_TRADABLE;
     }
   string ema=HTFName()+" EMAs "+S83EmaOrder(d)+(HTF_EMA_Candles>1?" on the last "+(string)HTF_EMA_Candles+" closed candles":"");
   string swings=S83SwingProblem(trend,d),hurst=S83HurstProblem(trend);
   if(swings!="" || hurst!="")
     {
      reason=ema+", but "+swings+(swings!="" && hurst!=""?", and ":"")+hurst+".";
      return BASE_NOT_TRADABLE;
     }
   reason=ema+", the "+MTFName()+" made "+(d>0?"an HH and an HL":"an LL and an LH")+", and the Hurst exponent "+
          DoubleToString(trend.hurst,2)+" is above "+DoubleToString(Hurst_Minimum,2)+".";
   return BASE_TRADABLE;
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

string PassText(const bool pass)
  {
   return pass?"PASS":"BLOCKED";
  }

// Qualifies the latest closed structure candle with the session, ADX and ATR
// filters.  The filters never gate structure, trend, alerts or the 83%
// Strategy's entries; the result is shown as the tooltip of the dashboard's
// tradability row.
string EntryFilterTooltip(const MqlRates &bar,const double &adx[],const double &atr[])
  {
   bool session=InSession(bar.time);
   bool adx_pass=!Use_ADX_Filter || (adx[0]!=EMPTY_VALUE && adx[0]>=ADX_Minimum);
   bool atr_pass=!Use_ATR_Filter || (atr[0]!=EMPTY_VALUE &&
                 (ATR_Filter_Mode==BASE_ATR_MINIMUM?atr[0]>=ATR_Minimum:
                  ATR_Filter_Mode==BASE_ATR_MAXIMUM?atr[0]<=ATR_Maximum:
                  atr[0]>=ATR_Minimum && atr[0]<=ATR_Maximum));
   bool choch_adx=!Use_ADX_Filter || Apply_ADX_Filter_To==BASE_BOS_ONLY || adx_pass;
   string text="Entry filters, latest closed "+TimeframeName(BASETimeframe())+" candle";
   text+="\nBOS "+PassText(session && adx_pass && atr_pass)+" | CHoCH "+PassText(session && choch_adx && atr_pass);
   text+="\nSession "+(Use_Session_Filter?(session?"in":"out"):"off")+
         " | ADX "+(Use_ADX_Filter?DoubleToString(adx[0],1)+" "+PassText(adx_pass):"off")+
         " | ATR "+(Use_ATR_Filter?DoubleToString(atr[0],_Digits)+" "+PassText(atr_pass):"off");
   return text;
  }

void DrawTextAnchored(const string id,const datetime time,const double price,const string text,
                      const color clr,const ENUM_ANCHOR_POINT anchor,const int font_size)
  {
   string name=g_prefix+id;
   if(ObjectFind(0,name)>=0 || !ObjectCreate(0,name,OBJ_TEXT,0,time,price)) return;
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,font_size);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,anchor);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
  }

// Text centred above the point, or below it when `below`.
void DrawText(const string id,const datetime time,const double price,const string text,
              const color clr,const bool below,const int font_size)
  {
   DrawTextAnchored(id,time,price,text,clr,below?ANCHOR_UPPER:ANCHOR_LOWER,font_size);
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

// BOS, CHoCH and LS share one drawing: a line from the broken swing to the
// first candle that touches its level (see FirstTouchBar), and the caption
// centred on that line (the candle midway between the two), above a line
// broken upwards and below one broken downwards.  An LS keeps the place of
// the CHoCH it replaced, in its own colour.  Object names use the candle that
// closed through the level.
void DrawSignal(const string kind,const int direction,const datetime swing_time,
                const double level,const datetime break_time,const datetime end_time,
                const datetime label_time)
  {
   bool bos=kind=="BOS",ls=kind=="LS";
   if((bos && !Show_BOS_Labels) || (ls && !Show_LS_Labels) || (!bos && !ls && !Show_CHoCH_Labels))
      return;
   color clr=ls?(direction>0?Bullish_LS_Color:Bearish_LS_Color):
             direction>0?(bos?Bullish_BOS_Color:Bullish_CHoCH_Color)
                        :(bos?Bearish_BOS_Color:Bearish_CHoCH_Color);
   string key=kind+(direction>0?"_UP_":"_DOWN_")+(string)break_time;
   DrawText(key,label_time,level,kind,clr,direction<0,(int)Label_Size);
   if(Show_Structure_Lines)
      DrawSegment(key+"_LINE",swing_time,level,end_time,level,
                  ls?clr:(bos?clrBlue:clrRed),Line_Style,Line_Width);
  }

string StructureLabel(const BASE_STRUCTURE_POINT &point)
  {
   return LabelText(point);
  }

void DrawStructurePoint(const string kind,const int side,const datetime time,const double price)
  {
   if(!Show_Swing_Points) return;
   bool low=side<0;
   color clr=low?clrTeal:clrIndianRed;
   DrawText("STRUCTURE_"+kind+"_"+(string)time,time,price,kind,clr,low,(int)Label_Size);
  }

// Draws one replay from candle `first` onwards (earlier candles are warm-up):
// HH/HL/LH/LL/EQH/EQL labels (superseded and untyped points are skipped), a
// dotted line joining each equal high or low to the swing it equals,
// BOS/CHoCH/LS signals and the dotted current swing levels.  A CHoCH may be
// confirmed several candles after its break; its line still ends no later
// than the candle that closed through the level.
void DrawStructure(const MqlRates &rates[],const int total,const int first,
                   const BASE_STRUCTURE_STATE &state,const BASE_STRUCTURE_POINT &points[],
                   const BASE_STRUCTURE_EVENT &events[])
  {
   int point_count=ArraySize(points);
   for(int i=0;i<point_count;i++)
     {
      if(points[i].superseded || points[i].kind==0 || points[i].pivot<first) continue;
      DrawStructurePoint(StructureLabel(points[i]),points[i].side,points[i].time,points[i].price);
      int equal=points[i].equal;
      if(Show_Swing_Points && Show_Equal_Highs_Lows && equal>=0 && points[equal].pivot>=first)
         DrawSegment("EQUAL_"+(string)points[i].time,points[equal].time,points[equal].price,
                     points[i].time,points[i].price,points[i].side>0?clrIndianRed:clrTeal,STYLE_DOT,1);
     }
   // A break is drawn only with its broken swing, so every BOS, CHoCH and LS
   // starts from a marked swing.
   int event_count=ArraySize(events);
   for(int i=0;i<event_count;i++)
      if(events[i].break_bar>=first && events[i].swing_time>=rates[first].time)
        {
         int end=FirstTouchBar(rates,events[i].swing_bar,events[i].break_bar,events[i].direction,
                               events[i].level);
         int middle=(int)MathRound(0.5*(events[i].swing_bar+end));
         DrawSignal(events[i].ls?"LS":(events[i].bos?"BOS":"CHoCH"),events[i].direction,
                    events[i].swing_time,events[i].level,rates[events[i].break_bar].time,
                    rates[end].time,rates[middle].time);
        }
   if(Show_Swing_Points && state.have_high)
      DrawSegment("LAST_HIGH",state.last_high_time,state.last_high,rates[total-1].time,
                  state.last_high,clrIndianRed,STYLE_DOT,1);
   if(Show_Swing_Points && state.have_low)
      DrawSegment("LAST_LOW",state.last_low_time,state.last_low,rates[total-1].time,
                  state.last_low,clrTeal,STYLE_DOT,1);
  }

// A caption faded towards the chart background (Smart Money Engine draws
// internal captions at 70% strength).
color FadeColor(const color clr,const double amount)
  {
   color background=(color)ChartGetInteger(0,CHART_COLOR_BACKGROUND);
   int r=(int)MathRound((clr&0xFF)*(1.0-amount)+(background&0xFF)*amount);
   int g=(int)MathRound(((clr>>8)&0xFF)*(1.0-amount)+((background>>8)&0xFF)*amount);
   int b=(int)MathRound(((clr>>16)&0xFF)*(1.0-amount)+((background>>16)&0xFF)*amount);
   return (color)((b<<16)|(g<<8)|r);
  }

// The internal structure's BOS/CHoCH (Smart Money Engine): a dashed width-1
// line from the internal pivot to the candle that closed through it and a
// faded caption centred on it, above a line broken upwards and below one
// broken downwards.  A pivot that is also a swing of the main structure is
// skipped, since the main structure draws that level.  A break is drawn when
// its closing candle is in the drawn window.
void DrawInternalBreaks(const BASE_BREAK_MARK &breaks[],const BASE_STRUCTURE_POINT &points[],
                        const datetime first_time)
  {
   if(!Show_Internal_Structure) return;
   int count=ArraySize(points);
   for(int i=0;i<ArraySize(breaks);i++)
     {
      if(breaks[i].break_time<first_time) continue;
      bool swing=false;
      for(int k=count-1;k>=0 && !swing;k--)
         if(points[k].side==breaks[i].direction && points[k].time==breaks[i].swing_time) swing=true;
      if(swing) continue;
      color clr=breaks[i].direction>0?Internal_Bullish_Color:Internal_Bearish_Color;
      string key="INTERNAL_"+(breaks[i].direction>0?"BULL_":"BEAR_")+(string)breaks[i].break_time;
      DrawSegment(key+"_SEGMENT",breaks[i].swing_time,breaks[i].level,breaks[i].end_time,
                  breaks[i].level,clr,STYLE_DASH,1);
      DrawText(key,breaks[i].label_time,breaks[i].level,breaks[i].choch?"CHoCH":"BOS",FadeColor(clr,0.3),
               breaks[i].direction<0,(int)Label_Size);
     }
  }

// Strong/Weak High/Low (Smart Money Engine): dashed lines from the trailing
// high and low to 20 candles right of the latest closed candle, with their
// names just right of the line ends.
void DrawStrongWeak(const BASE_STRUCTURE_STATE &state,const datetime last_time,
                    const ENUM_TIMEFRAMES timeframe)
  {
   if(!Show_Strong_Weak_High_Low) return;
   datetime right=last_time+20*PeriodSeconds(timeframe);
   if(state.have_trail_high)
     {
      DrawSegment("STRONG_WEAK_HIGH",state.trail_high_time,state.trail_high,right,state.trail_high,
                  clrIndianRed,STYLE_DASH,1);
      DrawTextAnchored("STRONG_WEAK_HIGH_TEXT",right,state.trail_high,
                       state.direction<0?"Strong High":"Weak High",clrIndianRed,ANCHOR_LEFT,(int)Label_Size);
     }
   if(state.have_trail_low)
     {
      DrawSegment("STRONG_WEAK_LOW",state.trail_low_time,state.trail_low,right,state.trail_low,
                  clrTeal,STYLE_DASH,1);
      DrawTextAnchored("STRONG_WEAK_LOW_TEXT",right,state.trail_low,
                       state.direction>0?"Strong Low":"Weak Low",clrTeal,ANCHOR_LEFT,(int)Label_Size);
     }
  }

// One chart replay drawn: its structure, its internal structure and its
// Strong/Weak High/Low.
void DrawChart(const MqlRates &rates[],const int total,const int first,const BASE_STRUCTURE_STATE &state,
               const BASE_STRUCTURE_POINT &points[],const BASE_STRUCTURE_EVENT &events[],
               const int internal_length,const ENUM_TIMEFRAMES timeframe)
  {
   DrawStructure(rates,total,first,state,points,events);
   if(Show_Internal_Structure)
     {
      BASE_INTERNAL_STRUCTURE internal;
      BASE_BREAK_MARK breaks[];
      ReplayInternalStructure(rates,total,internal_length,internal,breaks);
      DrawInternalBreaks(breaks,points,rates[first].time);
     }
   DrawStrongWeak(state,rates[total-1].time,timeframe);
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
// when they do not, and Tradable (Early) is amber.  There is no background
// or border.
const int DASHBOARD_FONT_SIZE=10;
const int DASHBOARD_ROW_HEIGHT=18;
const int DASHBOARD_INDENT=12;
const color DASHBOARD_TEXT_COLOR=clrBlack;
const color DASHBOARD_POSITIVE_COLOR=clrGreen;
const color DASHBOARD_NEGATIVE_COLOR=clrRed;
const color DASHBOARD_NEUTRAL_COLOR=clrGray;
const color DASHBOARD_EARLY_COLOR=clrDarkOrange;   // Tradable (Early)

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

// Long outputs (the Tradability Reason and Trade Recommendations) wrap onto
// continuation rows of at most DASHBOARD_WRAP_CHARS characters, broken
// between words; the continuation rows have no component name.
const int DASHBOARD_WRAP_CHARS=48;

void AddWrappedDashboardRow(BASE_DASHBOARD_ROW &rows[],const string label,const string value,
                            const color value_color,const string tooltip="")
  {
   string words[];
   int count=StringSplit(value,' ',words);
   string line="";
   bool first=true;
   for(int i=0;i<count;i++)
     {
      if(words[i]=="") continue;
      if(line!="" && StringLen(line)+1+StringLen(words[i])>DASHBOARD_WRAP_CHARS)
        {
         AddDashboardRow(rows,first?label:"",line,value_color,tooltip);
         first=false;
         line="";
        }
      line+=(line==""?"":" ")+words[i];
     }
   if(line!="" || first) AddDashboardRow(rows,first?label:"",line,value_color,tooltip);
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
   // A spacer row (no name, no value) draws nothing; a continuation row
   // (no name) draws only its value.
   for(int i=0;i<count;i++)
     {
      if(rows[i].label=="" && rows[i].value=="") continue;
      int y=10+i*DASHBOARD_ROW_HEIGHT;
      string name=g_prefix+"DASHBOARD_"+(string)i;
      if(rows[i].label!="")
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

// The internal structure under its timeframe's Market Trend, indented; the
// tooltip gives its latest break and how it relates to the Market Trend.
void AddInternalStructureRow(BASE_DASHBOARD_ROW &rows[],const BASE_INTERNAL_STRUCTURE &internal,
                             const BASE_STRUCTURE_STATE &state,const string name,const int level)
  {
   if(!Show_Internal_On_Dashboard) return;
   color clr=internal.trend>0?DASHBOARD_POSITIVE_COLOR:internal.trend<0?DASHBOARD_NEGATIVE_COLOR:
             DASHBOARD_NEUTRAL_COLOR;
   AddDashboardRow(rows,"Internal Structure:",InternalTrendText(internal),clr,
                   InternalStructureTooltip(internal,state,name,level),true,DASHBOARD_INDENT);
  }

// Each selected timeframe's Market Trend (its breakdown is the tooltip),
// Market Tradability (the entry filters are its tooltip), the reason and the
// HTF trade recommendation, then the 83% Strategy rows.
void DrawDashboard(const S83_TREND &trend,const BASE_TRADABILITY tradability,
                   const string tradability_reason,const string filter_tooltip)
  {
   Comment("");
   BASE_DASHBOARD_ROW rows[];
   // 1. The HTF EMA order.
   int d=trend.have_ema?trend.ema_direction:0;
   int stack=trend.have_ema?trend.ema_stack:0;
   string ema_tip=trend.have_ema?(string)HTF_EMA_Fast+" EMA "+PriceText(trend.ema_fast)+", "+(string)HTF_EMA_Middle+
                  " EMA "+PriceText(trend.ema_middle)+", "+(string)HTF_EMA_Slow+" EMA "+PriceText(trend.ema_slow)+
                  " (latest closed "+HTFName()+" candle)":"Not enough "+HTFName()+" history yet";
   string ema_text=!trend.have_ema?"Not available":d>0?"Bullish ("+S83EmaOrder(1)+")":d<0?"Bearish ("+S83EmaOrder(-1)+")":
                   stack!=0?S83EmaOrder(stack)+", not on each of the last "+(string)HTF_EMA_Candles:"Not in order";
   AddDashboardRow(rows,"HTF Trend ("+S83EmaText()+"):",ema_text,
                   d>0?DASHBOARD_POSITIVE_COLOR:d<0?DASHBOARD_NEGATIVE_COLOR:DASHBOARD_NEUTRAL_COLOR,ema_tip);
   // 2. The MTF swings: green for an HH and an HL, red for an LL and an LH.
   string highs=trend.have_highs?S83SwingTag(1,trend.high,trend.prev_high):"no two swing highs yet";
   string lows=trend.have_lows?S83SwingTag(-1,trend.low,trend.prev_low):"no two swing lows yet";
   bool both=trend.have_highs && trend.have_lows;
   bool up=both && trend.high>trend.prev_high && trend.low>trend.prev_low;
   bool down=both && trend.low<trend.prev_low && trend.high<trend.prev_high;
   string swing_tip="Latest swing high "+(trend.have_highs?PriceText(trend.high)+" vs previous "+PriceText(trend.prev_high):"-")+
                    "; latest swing low "+(trend.have_lows?PriceText(trend.low)+" vs previous "+PriceText(trend.prev_low):"-");
   AddDashboardRow(rows,"MTF Swings ("+MTFName()+"):",highs+" + "+lows,
                   up?DASHBOARD_POSITIVE_COLOR:down?DASHBOARD_NEGATIVE_COLOR:DASHBOARD_NEUTRAL_COLOR,swing_tip);
   // 3. The Hurst exponent.
   AddDashboardRow(rows,"Hurst Exponent ("+S83HurstName()+"):",
                   trend.have_hurst?"H "+DoubleToString(trend.hurst,2)+" ("+S83HurstWord(trend.hurst)+")":"Not available",
                   trend.have_hurst?PassColor(trend.hurst>Hurst_Minimum):DASHBOARD_NEUTRAL_COLOR,
                   "The last "+(string)Hurst_Candles+" closed "+S83HurstName()+" candles. Tradable needs H above "+
                   DoubleToString(Hurst_Minimum,2)+"; about 0.5 is a random walk, above it a trending market, below it a mean-reverting one.");
   AddDashboardRow(rows,"Market Tradability:",
                   tradability==BASE_TRADABLE?"Tradable ("+TrendWord(d)+")":"Not Tradable",
                   PassColor(tradability==BASE_TRADABLE),filter_tooltip);
   AddWrappedDashboardRow(rows,"Tradability Reason:",tradability_reason,DASHBOARD_TEXT_COLOR);
   S83DashboardRows(rows);
   DrawDashboardRows(rows);
  }

// ===========================================================================
// 83% Strategy
// ===========================================================================
// Trades the 83% retracement of a heavy LTF impulse in the direction of an
// established MTF trend, using Base's structure (above) for the swings and
// the market filters, and Fib Base's Fibonacci engine for the levels.
//
// Bullish (buys only):
//  * Market Tradability reads Tradable (bullish): all three conditions line
//    up: the HTF EMAs are in order, 20 > 50 > 200, on the latest closed HTF
//    candle; the MTF shows upward expansion, an HH and an HL; and the Hurst
//    exponent is above 0.55 (a trending market).  Bearish: 20 < 50 < 200, an
//    MTF LL and LH, and the same Hurst exponent.  See EvaluateTradability.
//    It is the only market filter.
//  * Only setups in the market's direction are identified: buys while the
//    HTF EMAs are in bullish order (the dashboard's HTF Trend), sells while
//    they are in bearish order, none while they are in neither.  A setup
//    still armed when the market stops pointing its direction is cancelled.
//    See S83ScanSetups.
//  * LTF setup (M30, Swing Detection level 3 by default), searched in the last
//    LTF_Bars_To_Process (40) closed LTF candles:
//      A: the most recent HL from which there was heavy buying pressure;
//      the break of structure: a candle after A closes above the swing high
//      before A (its break level, as Base's BOS);
//      B: the highest high since A.  It follows price until it is a
//      confirmed swing high (Swing Detection Length candles close without
//      reaching it), so a pullback while B is forming counts.
//    The Fibonacci runs from B (0%) to A (100%); the entry level is 83%.
//  * Entry: price touches the 83% level.
//  * Invalid: price makes a new HH (trades above a confirmed B) before
//    touching 83%.  The HL is then used up; a new setup needs a new HL.
// Bearish mirrors this: an LH with heavy selling pressure, a close below the
// swing low before it, the lowest low since then as B, a sell at the 83%
// retracement, invalid on a new LL.
//
// Heavy pressure: within Impulse_Candles candles of A (A's candle included),
// a candle closes at least Impulse_Min_ATR LTF ATR beyond A, the 14-candle
// ATR taken at A.  On real data (an index M15/M30, EURUSD H1, five stocks D1)
// 2.0 ATR selected the strongest 43% of HL-to-HH legs.
//
// Setups are found candle by candle on closed LTF candles; the entry and the
// invalidation are checked on every tick against the level of the latest
// closed candle (B moves only at candle closes).  A setup is known once A is
// a confirmed swing, the break has closed and the pressure is measured; if
// price already reached the entry level after B before that, the setup is
// missed, not traded late.
//
// Risk: Risk_Percent of the balance per trade at the stop, cut by
// Risk_Cut_Factor after every Losses_Before_Risk_Cut consecutive losses in a
// day and restored at the end of the day; at most Max_Trades_Per_Day entries
// a day, on the selected days, one position at a time.  Lots = balance x
// risk / the loss of one lot at the stop (MT5's tick value), which is the
// "(Balance x Risk %) / Stop Loss in points" rule for any symbol.
//
// Stop loss and take profit: the take profit is TP_Buffer_ATR LTF ATR before
// B.  The stop loss SL_Buffer_ATR LTF ATR behind A gives the position's
// natural reward-to-risk; the trade uses whichever of Reward_Risk_Low (1:2)
// and Reward_Risk_High (1:3) is closer and moves the stop to match (1:2.4
// becomes 1:2).  With 0.5 ATR the natural ratio fell between 1:2.2 and 1:3.0
// for 80% of the real-data setups, as the strategy describes.  The stop moves
// to the entry price once price has covered Breakeven_At_Percent of the way
// to the take profit.

int LTFBarsToProcess() { return MathMax(5,MathMin(LTF_Bars_To_Process,400)); }

// The drawn history of a chart period: LTF_Bars_To_Process candles on the
// LTF, as for Base elsewhere.
int ChartDisplayBars(const ENUM_TIMEFRAMES timeframe)
  {
   if(timeframe==LTFTimeframe()) return LTFBarsToProcess();
   return ChartStructureBars(timeframe);
  }

// Drawing is skipped in non-visual Strategy Tester runs and optimisation.
bool DrawingEnabled()
  {
   return MQLInfoInteger(MQL_TESTER)==0 || MQLInfoInteger(MQL_VISUAL_MODE)!=0;
  }

// A build waiting for data says why in the Journal, once per reason.
string g_s83_waiting="";

// A build waiting for data says why in the Journal, once per reason (a
// symbol with too little history otherwise just never trades).
bool S83Wait(const string reason)
  {
   if(reason!=g_s83_waiting && MQLInfoInteger(MQL_OPTIMIZATION)==0)
      Print("83% Strategy: waiting - ",reason);
   g_s83_waiting=reason;
   return false;
  }

// ------------------------------------------------------------ Fib Base
// Fib Base's fibLevelCalc: the price of a ratio along the leg, measured from
// the high (from_high) or from the low.
double FibLevel(const double ratio,const bool from_high,const double hi,const double lo)
  {
   return from_high?hi-(hi-lo)*ratio:lo+(hi-lo)*ratio;
  }

string FibRatioText(const double ratio)
  {
   string text=DoubleToString(ratio,3);
   // "0.830" -> "0.83", "1.000" -> "1"
   while(StringLen(text)>1 && StringSubstr(text,StringLen(text)-1,1)=="0") text=StringSubstr(text,0,StringLen(text)-1);
   if(StringSubstr(text,StringLen(text)-1,1)==".") text=StringSubstr(text,0,StringLen(text)-1);
   return text;
  }

string FibLabelText(const double ratio,const double price)
  {
   string percent=DoubleToString(ratio*100.0,2)+"%";
   if(Fib_Label_Text==S83_LABEL_RATIO) return FibRatioText(ratio);
   if(Fib_Label_Text==S83_LABEL_PRICE) return DoubleToString(price,_Digits);
   if(Fib_Label_Text==S83_LABEL_PERCENT_PRICE) return percent+" ("+DoubleToString(price,_Digits)+")";
   return percent;
  }

// ------------------------------------------------------------- setups
enum S83_STATE
  {
   S83_ARMED=0,       // waiting for the entry level
   S83_TOUCHED=1,     // price reached the entry level
   S83_INVALID=2,     // a new HH (LL) came first
   S83_EXPIRED=3,     // A left the LTF processed bars
   S83_MISSED=4,      // the entry level was reached before the setup was known
   S83_REPLACED=5,    // a newer setup in the same direction took over
   S83_CANCELLED=6    // the market no longer points its direction
  };

// One setup: A (the HL/LH the heavy move started from), B (the extreme
// since A, the HH/LL the move formed) and the entry level between them.
// Bars are indices into the LTF replay that found it; times stay valid after
// it.
struct S83_SETUP
  {
   int direction;           // 1 buy (HL -> HH), -1 sell (LH -> LL)
   double a_price;
   datetime a_time;
   int a_bar;
   double b_price;
   datetime b_time;
   int b_bar;
   int b_fixed;             // 1 once B is a confirmed swing (or the level was touched)
   double break_level;      // the swing before A whose break armed the setup
   datetime break_time;     // the candle that closed beyond it
   double level;            // the entry level (83%)
   double impulse;          // the heavy-pressure move, in LTF ATR
   double atr;              // LTF ATR at A
   datetime created_time;   // the candle on whose close the setup became known
   int state;               // S83_STATE
   datetime end_time;       // the candle of the touch, invalidation, expiry or miss
   int why;                 // why it ended (S83_WHY)
  };

enum S83_WHY
  {
   S83_WHY_NONE=0,
   S83_WHY_NEW_B=1,         // a new HH (LL) before the touch
   S83_WHY_EXPIRED=2,       // A left the processed candles
   S83_WHY_MISSED=3,        // the level was reached before the setup was known
   S83_WHY_REPLACED=4,      // a newer setup in the same direction
   S83_WHY_MARKET=5         // the market no longer points its direction
  };

string S83WhyText(const S83_SETUP &setup)
  {
   string b=S83BLabel(setup.direction);
   switch(setup.why)
     {
      case S83_WHY_NEW_B: return "invalidated: a new "+b+" first";
      case S83_WHY_EXPIRED: return "expired: A left the "+(string)LTFBarsToProcess()+" processed candles";
      case S83_WHY_MISSED: return "missed: "+S83LevelText()+" reached before the setup was known";
      case S83_WHY_REPLACED: return "replaced by a newer setup";
      case S83_WHY_MARKET: return "cancelled: the market is no longer "+(setup.direction>0?"bullish":"bearish");
     }
   return "";
  }

// What happened live when an armed setup was touched or invalidated.
struct S83_OUTCOME
  {
   int direction;
   datetime a_time;
   bool traded;
   string text;
   datetime time;           // the tick
   double entry;
   double sl;
   double tp;
   double rr;
   double lots;
  };

// Trades and risk of the current server day (see S83LoadDay).
struct S83_DAY
  {
   datetime day;
   int trades;              // entries opened today
   int losses;              // consecutive losses in the latest run today
   int cuts;                // how many times the risk was cut today
  };

CTrade g_trade;
bool g_s83_ready=false;
// Published by Rebuild for the tick handler and the dashboard.
BASE_TRADABILITY g_s83_tradability=BASE_NOT_TRADABLE;
int g_s83_market_direction=0;      // the market's direction now: the HTF EMA order (1, -1 or 0)
string g_s83_tradability_reason="";
double g_s83_atr=0.0;              // LTF ATR of the latest closed LTF candle
datetime g_s83_last_time=0;        // the latest closed LTF candle
S83_SETUP g_s83_setups[];          // every setup found in the processed bars
S83_SETUP g_s83_armed[2];          // [0] buy, [1] sell: the armed setups
int g_s83_armed_valid[2];          // 1 when that slot holds an armed setup
S83_OUTCOME g_s83_outcomes[];
S83_DAY g_s83_day;
ulong g_s83_breakeven_failed=0;
string g_s83_journaled="";

int S83Slot(const int direction) { return direction>0?0:1; }
string S83Side(const int direction) { return direction>0?"buy":"sell"; }
string S83LevelText() { return DoubleToString(Entry_Level*100.0,0)+"%"; }
string S83ALabel(const int direction) { return direction>0?"HL":"LH"; }
string S83BLabel(const int direction) { return direction>0?"HH":"LL"; }

// Heavy pressure (see above): the furthest close beyond A within
// Impulse_Candles candles of it, in LTF ATR at A.
double S83Impulse(const MqlRates &rates[],const double &atr[],const int a_bar,const int b_bar,
                  const int direction,const double a_price)
  {
   if(atr[a_bar]<=0.0) return 0.0;
   int last=MathMin(a_bar+Impulse_Candles,b_bar);
   double best=0.0;
   for(int k=a_bar;k<=last;k++)
      best=MathMax(best,direction>0?rates[k].close-a_price:a_price-rates[k].close);
   return best/atr[a_bar];
  }

bool S83Touched(const S83_SETUP &setup,const MqlRates &bar)
  {
   return setup.direction>0?bar.low<=setup.level:bar.high>=setup.level;
  }

bool S83Beyond(const S83_SETUP &setup,const MqlRates &bar)
  {
   return setup.direction>0?bar.high>setup.b_price:bar.low<setup.b_price;
  }

bool S83Live(const S83_SETUP &setup)
  {
   return setup.state==S83_ARMED;
  }

void S83End(S83_SETUP &setup,const int state,const datetime time,const int why)
  {
   setup.state=state;
   setup.end_time=time;
   setup.why=why;
  }

// One closed LTF candle of an armed setup: a touch of the entry level makes
// it touched (the entry); otherwise going beyond a confirmed B invalidates
// it (beyond a forming B, B follows at the close: S83FollowB).
void S83Step(S83_SETUP &setup,const MqlRates &candle)
  {
   if(setup.state!=S83_ARMED) return;
   if(S83Touched(setup,candle)) S83End(setup,S83_TOUCHED,candle.time,S83_WHY_NONE);
   else if(setup.b_fixed!=0 && S83Beyond(setup,candle)) S83End(setup,S83_INVALID,candle.time,S83_WHY_NEW_B);
  }

// The entry level of a setup's leg (Fib Base: 0% at B, 100% at A).
double S83EntryLevel(const S83_SETUP &setup)
  {
   return setup.direction>0?FibLevel(Entry_Level,true,setup.b_price,setup.a_price)
                           :FibLevel(Entry_Level,false,setup.a_price,setup.b_price);
  }

// At the close of LTF candle i, the B of an armed setup follows price until
// it is a confirmed swing: a candle at or beyond B becomes B (the latest of
// equal extremes, as Base finds a swing), and B is fixed once Swing
// Detection Length candles have closed without reaching it.  The entry
// level moves with B.
void S83FollowB(S83_SETUP &setup,const MqlRates &rates[],const int i)
  {
   if(setup.state!=S83_ARMED || setup.b_fixed!=0) return;
   int d=setup.direction;
   if(d>0?rates[i].high>=setup.b_price:rates[i].low<=setup.b_price)
     {
      setup.b_price=d>0?rates[i].high:rates[i].low;
      setup.b_time=rates[i].time;
      setup.b_bar=i;
      setup.level=S83EntryLevel(setup);
     }
   if(i-setup.b_bar>=LTFSwingLength()) setup.b_fixed=1;
  }

// The setups of one LTF replay, candle by candle over its last
// LTF_Bars_To_Process closed candles.  Only setups in the market's direction
// are identified: market[i] is the market direction at the open of candle i
// (see S83MarketHistory), buys only in a bullish market and sells only in a
// bearish one.  On each candle:
//  0. an armed setup whose direction the market no longer points is
//     cancelled, before the candle can touch it;
//  1. each armed setup steps through the candle (see S83Step): touched or
//     invalidated.  If still armed, its B follows price (S83FollowB), and it
//     expires once its A is no longer within the processed candles.
//  2. for buys in a bullish market, or sells in a bearish one: the latest
//     swing low (high) confirmed so far, A,
//     starts a setup when it is an HL (LH), has not been used, lies within
//     the processed candles, a candle from A on has closed beyond the swing
//     before it (the break of structure) and it shows heavy pressure.  B is
//     the extreme since A.  If the entry level was reached after B (and
//     after the break) before the setup was known, it is missed; otherwise
//     it is armed and replaces any live setup in its direction.
// A starting a setup is used up.
// Only the setups live now or ended within the processed candles are kept.
// They were all created at most two windows back, and whether their A was
// used up depends only on that A's earlier setups, all created after A within
// one more window; so scanning from three windows back gives the same result
// as scanning all of history.
void S83ScanSetups(const MqlRates &rates[],const int total,const BASE_STRUCTURE_POINT &points[],
                   const double &atr[],const int &market[],S83_SETUP &setups[],int &live_buy,int &live_sell)
  {
   ArrayResize(setups,0);
   live_buy=-1;
   live_sell=-1;
   int window=LTFBarsToProcess();
   int first=MathMax(0,total-window);
   int start=MathMax(0,total-3*window);
   int count=ArraySize(points);
   int next=0;
   while(next<count && points[next].confirmed<start) next++;
   datetime used_buy[],used_sell[];
   for(int i=start;i<total;i++)
     {
      for(int slot=0;slot<2;slot++)
        {
         int index=slot==0?live_buy:live_sell;
         if(index<0) continue;
         if(market[i]!=setups[index].direction)
            S83End(setups[index],S83_CANCELLED,rates[i].time,S83_WHY_MARKET);
         S83Step(setups[index],rates[i]);
         S83FollowB(setups[index],rates,i);
         if(S83Live(setups[index]) && setups[index].a_bar<i-window+1)
            S83End(setups[index],S83_EXPIRED,rates[i].time,S83_WHY_EXPIRED);
         if(S83Live(setups[index])) continue;
         if(slot==0) live_buy=-1;
         else live_sell=-1;
        }
      while(next<count && points[next].confirmed<=i) next++;
      for(int slot=0;slot<2;slot++)
        {
         int direction=slot==0?1:-1;
         if(market[i]!=direction) continue;
         // A: the latest swing on its side; the swing before it on the other
         // side holds the level whose break arms the setup.
         int a=-1,p=-1;
         for(int k=next-1;k>=0 && a<0;k--)
            if(points[k].side==-direction) a=k;
         if(a<0 || points[a].kind>=0 || points[a].pivot<i-window+1) continue;
         if(direction>0?S83Used(used_buy,points[a].time):S83Used(used_sell,points[a].time)) continue;
         for(int k=a-1;k>=0 && p<0;k--)
            if(points[k].side==direction) p=k;
         if(p<0) continue;
         int broke=-1;
         for(int k=points[a].pivot;k<=i && broke<0;k++)
            if(direction>0?rates[k].close>points[p].level:rates[k].close<points[p].level) broke=k;
         if(broke<0) continue;
         double impulse=S83Impulse(rates,atr,points[a].pivot,i,direction,points[a].price);
         if(impulse<Impulse_Min_ATR) continue;
         int b=points[a].pivot;
         for(int k=points[a].pivot;k<=i;k++)
            if(direction>0?rates[k].high>=rates[b].high:rates[k].low<=rates[b].low) b=k;
         int index=ArraySize(setups);
         ArrayResize(setups,index+1,16);
         setups[index].direction=direction;
         setups[index].a_price=points[a].price;
         setups[index].a_time=points[a].time;
         setups[index].a_bar=points[a].pivot;
         setups[index].b_price=direction>0?rates[b].high:rates[b].low;
         setups[index].b_time=rates[b].time;
         setups[index].b_bar=b;
         setups[index].b_fixed=i-b>=LTFSwingLength()?1:0;
         setups[index].break_level=points[p].level;
         setups[index].break_time=rates[broke].time;
         setups[index].level=S83EntryLevel(setups[index]);
         setups[index].impulse=impulse;
         setups[index].atr=atr[points[a].pivot];
         setups[index].created_time=rates[i].time;
         setups[index].state=S83_ARMED;
         setups[index].end_time=0;
         setups[index].why=S83_WHY_NONE;
         if(direction>0) S83Use(used_buy,points[a].time);
         else S83Use(used_sell,points[a].time);
         bool missed=false;
         for(int k=MathMax(b,broke)+1;k<=i && !missed;k++)
            if(S83Touched(setups[index],rates[k])) missed=true;
         if(missed)
           {
            S83End(setups[index],S83_MISSED,rates[i].time,S83_WHY_MISSED);
            continue;
           }
         int previous_live=direction>0?live_buy:live_sell;
         if(previous_live>=0) S83End(setups[previous_live],S83_REPLACED,rates[i].time,S83_WHY_REPLACED);
         if(direction>0) live_buy=index; else live_sell=index;
        }
     }
   // Keep the setups live now or ended within the processed candles.
   live_buy=-1;
   live_sell=-1;
   int kept=0;
   for(int k=0;k<ArraySize(setups);k++)
     {
      if(!S83Live(setups[k]) && setups[k].end_time<rates[first].time) continue;
      if(kept!=k) setups[kept]=setups[k];
      if(S83Live(setups[kept]))
        {
         if(setups[kept].direction>0) live_buy=kept; else live_sell=kept;
        }
      kept++;
     }
   ArrayResize(setups,kept);
  }

void S83Use(datetime &used[],const datetime time)
  {
   int n=ArraySize(used);
   ArrayResize(used,n+1,16);
   used[n]=time;
  }

bool S83Used(const datetime &used[],const datetime time)
  {
   for(int i=ArraySize(used)-1;i>=0;i--)
      if(used[i]==time) return true;
   return false;
  }

// --------------------------------------------------------------- trend
// The HTF EMAs (on the latest closed HTF candles), the MTF's last two swing
// highs and lows, and the Hurst exponent, for Market Tradability (see
// EvaluateTradability).
int g_s83_ema_fast_handle=INVALID_HANDLE;
int g_s83_ema_middle_handle=INVALID_HANDLE;
int g_s83_ema_slow_handle=INVALID_HANDLE;
S83_TREND g_s83_trend;

ENUM_TIMEFRAMES S83HurstTimeframe()
  {
   if(Hurst_Timeframe==S83_HURST_MTF) return SetupTimeframe();
   if(Hurst_Timeframe==S83_HURST_LTF) return LTFTimeframe();
   return BASETimeframe();
  }

// The Hurst exponent of n closes (oldest first) by the lagged-difference
// method (the generalized Hurst exponent with q = 2): x = ln(close); for each
// lag tau from S83_HURST_MIN_LAG to S83_HURST_MAX_LAG, sigma(tau) is the root
// mean square of x[t+tau] - x[t] over the window; H is the least-squares
// slope of ln sigma(tau) against ln tau.  A random walk gives about 0.5; a
// trending market more (a steady drift, which is not subtracted, or momentum
// in the moves), a mean-reverting one less.  False when a close is not
// positive or the prices do not move.  83% Strategy.pine computes it in the
// same order.
bool S83HurstOf(const double &close[],const int n,double &h)
  {
   h=0.0;
   if(n<=S83_HURST_MAX_LAG) return false;
   double x[];
   ArrayResize(x,n);
   for(int i=0;i<n;i++)
     {
      if(close[i]<=0.0) return false;
      x[i]=MathLog(close[i]);
     }
   int lags=S83_HURST_MAX_LAG-S83_HURST_MIN_LAG+1;
   double lt[],ls[];
   ArrayResize(lt,lags);
   ArrayResize(ls,lags);
   for(int k=0;k<lags;k++)
     {
      int tau=S83_HURST_MIN_LAG+k;
      int m=n-tau;
      double square=0.0;
      for(int t=0;t<m;t++)
        {
         double move=x[t+tau]-x[t];
         square+=move*move;
        }
      square/=m;
      if(square<=0.0) return false;
      lt[k]=MathLog((double)tau);
      ls[k]=MathLog(MathSqrt(square));
     }
   double mt=0.0,ms=0.0;
   for(int k=0;k<lags;k++)
     {
      mt+=lt[k];
      ms+=ls[k];
     }
   mt/=lags;
   ms/=lags;
   double sxy=0.0,sxx=0.0;
   for(int k=0;k<lags;k++)
     {
      sxy+=(lt[k]-mt)*(ls[k]-ms);
      sxx+=(lt[k]-mt)*(lt[k]-mt);
     }
   h=sxy/sxx;
   return true;
  }

// The EMA order on one candle: 1 fast > middle > slow, -1 fast < middle <
// slow, 0 neither.
int S83EmaStack(const double fast,const double middle,const double slow)
  {
   if(fast>middle && middle>slow) return 1;
   if(fast<middle && middle<slow) return -1;
   return 0;
  }

void S83ReadTrend(const BASE_STRUCTURE_POINT &mtf_points[],S83_TREND &trend)
  {
   ZeroMemory(trend);
   // The EMAs on the last HTF_EMA_Candles closed HTF candles (oldest first).
   int n=HTF_EMA_Candles;
   double fast[],middle[],slow[];
   ArraySetAsSeries(fast,false);
   ArraySetAsSeries(middle,false);
   ArraySetAsSeries(slow,false);
   trend.have_ema=g_s83_ema_fast_handle!=INVALID_HANDLE && g_s83_ema_middle_handle!=INVALID_HANDLE &&
                  g_s83_ema_slow_handle!=INVALID_HANDLE && iBars(_Symbol,BASETimeframe())>HTF_EMA_Slow+n &&
                  CopyBuffer(g_s83_ema_fast_handle,0,1,n,fast)==n && CopyBuffer(g_s83_ema_middle_handle,0,1,n,middle)==n &&
                  CopyBuffer(g_s83_ema_slow_handle,0,1,n,slow)==n;
   for(int i=0;i<n && trend.have_ema;i++)
      if(fast[i]==EMPTY_VALUE || middle[i]==EMPTY_VALUE || slow[i]==EMPTY_VALUE) trend.have_ema=false;
   if(trend.have_ema)
     {
      trend.ema_fast=fast[n-1];
      trend.ema_middle=middle[n-1];
      trend.ema_slow=slow[n-1];
      trend.ema_stack=S83EmaStack(fast[n-1],middle[n-1],slow[n-1]);
      trend.ema_direction=trend.ema_stack;
      for(int i=0;i<n-1;i++)
         if(S83EmaStack(fast[i],middle[i],slow[i])!=trend.ema_stack) trend.ema_direction=0;
     }
   trend.have_highs=S83LastTwoSwings(mtf_points,1,trend.high,trend.prev_high);
   trend.have_lows=S83LastTwoSwings(mtf_points,-1,trend.low,trend.prev_low);
   // The Hurst exponent of the last Hurst_Candles closed candles.
   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   int got=CopyRates(_Symbol,S83HurstTimeframe(),1,Hurst_Candles,rates);
   trend.hurst_candles=MathMax(got,0);
   if(got==Hurst_Candles)
     {
      double close[];
      ArrayResize(close,got);
      for(int i=0;i<got;i++) close[i]=rates[i].close;
      trend.have_hurst=S83HurstOf(close,got,trend.hurst);
     }
   g_s83_trend=trend;
  }

// The market direction at the open of each LTF candle from `from` on, for the
// setup scan: the HTF EMA order (as g_s83_trend.ema_direction) of the latest
// HTF candles closed by then: 1 bullish (fast > middle > slow on each of the
// last HTF_EMA_Candles), -1 bearish, 0 neither.  The HTF candle that closes
// as an LTF candle opens counts for that candle, as it does live.  False
// while the EMAs cannot be read yet (the build then waits).
bool S83MarketHistory(const MqlRates &rates[],const int total,const int from,int &market[])
  {
   ArrayResize(market,MathMax(total,0));
   if(total<=0) return true;
   ArrayInitialize(market,0);
   ENUM_TIMEFRAMES htf=BASETimeframe();
   int period=PeriodSeconds(htf);
   int n=HTF_EMA_Candles;
   int start=MathMax(0,MathMin(from,total-1));
   if(g_s83_ema_fast_handle==INVALID_HANDLE || g_s83_ema_middle_handle==INVALID_HANDLE ||
      g_s83_ema_slow_handle==INVALID_HANDLE) return false;
   if(iBars(_Symbol,htf)<=HTF_EMA_Slow+n) return true;   // not enough HTF history: no direction
   // The closed HTF candles from n before the first LTF candle's open to now.
   int count=(int)((TimeCurrent()-rates[start].time)/period)+n+3;
   MqlRates htf_rates[];
   double fast[],middle[],slow[];
   ArraySetAsSeries(htf_rates,false);
   ArraySetAsSeries(fast,false);
   ArraySetAsSeries(middle,false);
   ArraySetAsSeries(slow,false);
   int got=CopyRates(_Symbol,htf,1,count,htf_rates);
   if(got<=0 || CopyBuffer(g_s83_ema_fast_handle,0,1,got,fast)!=got ||
      CopyBuffer(g_s83_ema_middle_handle,0,1,got,middle)!=got || CopyBuffer(g_s83_ema_slow_handle,0,1,got,slow)!=got)
      return false;
   // The EMA direction after each closed HTF candle.
   int direction[];
   ArrayResize(direction,got);
   int run=0,last=0;
   for(int k=0;k<got;k++)
     {
      int stack=fast[k]==EMPTY_VALUE || middle[k]==EMPTY_VALUE || slow[k]==EMPTY_VALUE?0:
                S83EmaStack(fast[k],middle[k],slow[k]);
      run=stack!=0 && stack==last?run+1:(stack!=0?1:0);
      last=stack;
      // Only runs that lie wholly within the copied candles count.
      direction[k]=run>=n && k>=n-1?stack:0;
     }
   int j=-1;
   for(int i=start;i<total;i++)
     {
      while(j+1<got && htf_rates[j+1].time+period<=rates[i].time) j++;
      market[i]=j>=0?direction[j]:0;
     }
   return true;
  }

// The HTF EMA lines over the drawn HTF candles (at most 500 segments each).
void S83DrawEmaLine(const int handle,const string id,const color clr,const MqlRates &rates[],
                    const int total,const int displayed)
  {
   int first=MathMax(1,total-MathMin(500,displayed));
   int count=total-first+1;
   double values[];
   if(total<2 || !CopyIndicator(handle,0,count,values)) return;
   // values[j] belongs to rates[first-1+j] (both end at the latest closed candle).
   for(int i=first;i<total;i++)
      DrawSegment("EMA_"+id+"_"+(string)rates[i].time,rates[i-1].time,values[i-first],rates[i].time,
                  values[i-first+1],clr,STYLE_SOLID,2);
  }

void S83DrawEmaLines(const MqlRates &rates[],const int total,const int displayed)
  {
   if(!Show_HTF_EMA_Lines) return;
   S83DrawEmaLine(g_s83_ema_fast_handle,"FAST",HTF_EMA_Fast_Color,rates,total,displayed);
   S83DrawEmaLine(g_s83_ema_middle_handle,"MIDDLE",HTF_EMA_Middle_Color,rates,total,displayed);
   S83DrawEmaLine(g_s83_ema_slow_handle,"SLOW",HTF_EMA_Slow_Color,rates,total,displayed);
  }

// ------------------------------------------------------------ outcomes
int S83OutcomeIndex(const int direction,const datetime a_time)
  {
   for(int i=ArraySize(g_s83_outcomes)-1;i>=0;i--)
      if(g_s83_outcomes[i].direction==direction && g_s83_outcomes[i].a_time==a_time) return i;
   return -1;
  }

void S83Record(const S83_SETUP &setup,const bool traded,const string text,const double entry,
               const double sl,const double tp,const double rr,const double lots)
  {
   int n=ArraySize(g_s83_outcomes);
   // Only the latest outcomes can belong to setups still in the processed
   // candles; the oldest is dropped (field by field: the text is a string).
   if(n>=50)
     {
      for(int i=1;i<n;i++)
        {
         g_s83_outcomes[i-1].direction=g_s83_outcomes[i].direction;
         g_s83_outcomes[i-1].a_time=g_s83_outcomes[i].a_time;
         g_s83_outcomes[i-1].traded=g_s83_outcomes[i].traded;
         g_s83_outcomes[i-1].text=g_s83_outcomes[i].text;
         g_s83_outcomes[i-1].time=g_s83_outcomes[i].time;
         g_s83_outcomes[i-1].entry=g_s83_outcomes[i].entry;
         g_s83_outcomes[i-1].sl=g_s83_outcomes[i].sl;
         g_s83_outcomes[i-1].tp=g_s83_outcomes[i].tp;
         g_s83_outcomes[i-1].rr=g_s83_outcomes[i].rr;
         g_s83_outcomes[i-1].lots=g_s83_outcomes[i].lots;
        }
      n--;
     }
   ArrayResize(g_s83_outcomes,n+1);
   g_s83_outcomes[n].direction=setup.direction;
   g_s83_outcomes[n].a_time=setup.a_time;
   g_s83_outcomes[n].traded=traded;
   g_s83_outcomes[n].text=text;
   g_s83_outcomes[n].time=TimeCurrent();
   g_s83_outcomes[n].entry=entry;
   g_s83_outcomes[n].sl=sl;
   g_s83_outcomes[n].tp=tp;
   g_s83_outcomes[n].rr=rr;
   g_s83_outcomes[n].lots=lots;
  }

string S83SetupText(const S83_SETUP &setup)
  {
   return (setup.direction>0?"Buy":"Sell")+": A "+S83ALabel(setup.direction)+" "+PriceText(setup.a_price)+
          " -> B "+S83BLabel(setup.direction)+" "+PriceText(setup.b_price)+
          (S83Live(setup) && setup.b_fixed==0?" (forming)":"")+"; "+S83LevelText()+" at "+PriceText(setup.level);
  }

void S83Journal(const string text)
  {
   if(text==g_s83_journaled) return;
   g_s83_journaled=text;
   if(MQLInfoInteger(MQL_OPTIMIZATION)==0) Print("83% Strategy: ",text);
  }

void S83Alert(const string text)
  {
   if(MQLInfoInteger(MQL_TESTER)!=0) return;
   string message=_Symbol+" "+LTFName()+" 83% Strategy: "+text;
   if(Enable_Popup_Alerts) Alert(message);
   if(Enable_Push_Notifications) SendNotification(message);
  }

// -------------------------------------------------------------- trading
bool TradingActive()
  {
   if(Trade_Mode==S83_TRADING_OFF) return false;
   if(MQLInfoInteger(MQL_TESTER)!=0) return true;
   return Trade_Mode==S83_TRADING_LIVE;
  }

bool S83FindPosition(ulong &ticket)
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong candidate=PositionGetTicket(i);
      if(candidate==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC)==Magic_Number)
        {
         ticket=candidate;
         return true;
        }
     }
   return false;
  }

// Aligns a price to the symbol's tick size: direction 1 rounds up, -1 rounds
// down and 0 rounds to the nearest tick.
double AlignPrice(const double price,const int direction)
  {
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tick<=0.0) tick=_Point;
   double steps=price/tick;
   if(direction>0) steps=MathCeil(steps-1e-8);
   else if(direction<0) steps=MathFloor(steps+1e-8);
   else steps=MathRound(steps);
   return NormalizeDouble(steps*tick,_Digits);
  }

// The broker's minimum distance between the market and a stop.
double MinimumStopDistance()
  {
   long level=MathMax(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),
                      SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL));
   return (double)(level+1)*_Point;
  }

bool S83TradingDay(const int day_of_week)
  {
   switch(day_of_week)
     {
      case 0: return Trade_Sunday;
      case 1: return Trade_Monday;
      case 2: return Trade_Tuesday;
      case 3: return Trade_Wednesday;
      case 4: return Trade_Thursday;
      case 5: return Trade_Friday;
     }
   return Trade_Saturday;
  }

string S83DayName(const int day_of_week)
  {
   switch(day_of_week)
     {
      case 0: return "Sunday";
      case 1: return "Monday";
      case 2: return "Tuesday";
      case 3: return "Wednesday";
      case 4: return "Thursday";
      case 5: return "Friday";
     }
   return "Saturday";
  }

// The risk of the risk distance stored in an entry's comment ("83% buy
// r=123", in points), 0 when absent.
double S83CommentRisk(const string comment)
  {
   int at=StringFind(comment,"r=");
   if(at<0) return 0.0;
   return (double)StringToInteger(StringSubstr(comment,at+2))*_Point;
  }

// Today's trades and losses, from the deal history (so a restart keeps them).
// A day is the server's calendar day.  A trade is a loss when it closed more
// than half its initial risk beyond its entry (a breakeven exit is not); the
// initial risk comes from its entry's comment, or the profit's sign without
// one.  A win or breakeven ends a run of losses; every Losses_Before_Risk_Cut
// consecutive losses cut the risk once more.
void S83LoadDay(S83_DAY &day)
  {
   datetime now=TimeCurrent();
   day.day=now-(now%86400);
   day.trades=0;
   day.losses=0;
   day.cuts=0;
   if(!HistorySelect(day.day-7*86400,now+86400)) return;
   int total=HistoryDealsTotal();
   long ids[];
   double opens[],risks[];
   int buys[];
   for(int i=0;i<total;i++)
     {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0 || HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol ||
         (ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=Magic_Number) continue;
      long entry=HistoryDealGetInteger(deal,DEAL_ENTRY);
      datetime time=(datetime)HistoryDealGetInteger(deal,DEAL_TIME);
      long position=HistoryDealGetInteger(deal,DEAL_POSITION_ID);
      if(entry==DEAL_ENTRY_IN)
        {
         int n=ArraySize(ids);
         ArrayResize(ids,n+1,16);
         ArrayResize(opens,n+1,16);
         ArrayResize(risks,n+1,16);
         ArrayResize(buys,n+1,16);
         ids[n]=position;
         opens[n]=HistoryDealGetDouble(deal,DEAL_PRICE);
         risks[n]=S83CommentRisk(HistoryDealGetString(deal,DEAL_COMMENT));
         buys[n]=HistoryDealGetInteger(deal,DEAL_TYPE)==DEAL_TYPE_BUY?1:0;
         if(time>=day.day) day.trades++;
         continue;
        }
      if((entry!=DEAL_ENTRY_OUT && entry!=DEAL_ENTRY_OUT_BY) || time<day.day) continue;
      double profit=HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_SWAP)+
                    HistoryDealGetDouble(deal,DEAL_COMMISSION);
      bool loss=profit<0.0;
      for(int k=ArraySize(ids)-1;k>=0;k--)
         if(ids[k]==position)
           {
            if(risks[k]>0.0)
              {
               double price=HistoryDealGetDouble(deal,DEAL_PRICE);
               loss=(buys[k]!=0?opens[k]-price:price-opens[k])>0.5*risks[k];
              }
            break;
           }
      if(loss)
        {
         day.losses++;
         if(Losses_Before_Risk_Cut>0 && day.losses%Losses_Before_Risk_Cut==0) day.cuts++;
        }
      else day.losses=0;
     }
  }

// Today's risk per trade, in percent of the balance.
double S83RiskPercent(const S83_DAY &day)
  {
   return Risk_Percent*MathPow(Risk_Cut_Factor,day.cuts);
  }

// Volume that loses `risk_money` at the stop, rounded down to the symbol's
// volume step.  Below the symbol's minimum it is 0 (no trade), or the minimum
// when that risks at most Minimum_Lot_Max_Risk_Multiple times `risk_money`;
// above the maximum per order (or the symbol's total volume limit) it is
// capped, which risks less.  `note` says which applied.
string g_s83_size_note="";
double S83Volume(const bool sell,const double entry,const double sl,const double risk_money)
  {
   g_s83_size_note="";
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double minimum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maximum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double limit=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_LIMIT);
   if(limit>0.0) maximum=MathMin(maximum,limit);
   double loss=0.0;
   if(!OrderCalcProfit(sell?ORDER_TYPE_SELL:ORDER_TYPE_BUY,_Symbol,1.0,entry,sl,loss) || loss>=0.0)
      return 0.0;
   double lots=risk_money/(-loss);
   if(step>0.0)
     {
      lots=MathFloor(lots/step+1e-8)*step;
      lots=NormalizeDouble(lots,(int)MathMax(0.0,MathCeil(-MathLog10(step)-1e-8)));
     }
   if(lots<minimum)
     {
      if(Minimum_Lot_Max_Risk_Multiple<=0.0 || minimum*(-loss)>Minimum_Lot_Max_Risk_Multiple*risk_money)
         return 0.0;
      g_s83_size_note="minimum lot "+DoubleToString(minimum,2)+", risking "+
                      DoubleToString(minimum*(-loss)/risk_money,2)+"x the planned risk";
      return minimum;
     }
   if(lots>maximum && maximum>0.0)
     {
      g_s83_size_note="capped at the symbol's maximum of "+DoubleToString(maximum,2)+" lots";
      return maximum;
     }
   return lots;
  }

// Why a touched setup cannot be traded now, or "".
string S83Blocker(const int direction)
  {
   ulong ticket=0;
   if(S83FindPosition(ticket)) return "a position is already open";
   MqlDateTime now;
   TimeToStruct(TimeCurrent(),now);
   if(!S83TradingDay(now.day_of_week)) return S83DayName(now.day_of_week)+" is not a trading day";
   if(g_s83_day.trades>=Max_Trades_Per_Day)
      return "the maximum of "+(string)Max_Trades_Per_Day+" trades today is reached";
   return S83FilterText(direction);
  }

// Stop loss, take profit, reward-to-risk and volume for an entry at `entry`.
// Returns "" or why the trade cannot be planned.  A sell's take profit and
// stop are hit on the ask, so the spread is added to both.
string S83Plan(const S83_SETUP &setup,const double entry,const double spread,const double atr,
               double &sl,double &tp,double &rr,double &lots,double &risk_money)
  {
   int d=setup.direction;
   if(atr<=0.0) return "the LTF ATR is unavailable";
   tp=d>0?AlignPrice(setup.b_price-TP_Buffer_ATR*atr,-1):AlignPrice(setup.b_price+TP_Buffer_ATR*atr+spread,1);
   double reward=d>0?tp-entry:entry-tp;
   if(reward<=0.0) return "the take profit is not beyond the entry";
   double atr_stop=d>0?setup.a_price-SL_Buffer_ATR*atr:setup.a_price+SL_Buffer_ATR*atr+spread;
   double atr_risk=d>0?entry-atr_stop:atr_stop-entry;
   if(atr_risk<=0.0) return "the entry is beyond the stop loss";
   double natural=reward/atr_risk;
   rr=natural<0.5*(Reward_Risk_Low+Reward_Risk_High)?Reward_Risk_Low:Reward_Risk_High;
   double risk=reward/rr;
   sl=d>0?AlignPrice(entry-risk,-1):AlignPrice(entry+risk,1);
   double minimum=MinimumStopDistance();
   if((d>0?entry-sl:sl-entry)<minimum || reward<minimum) return "the stop or target is too close to the price";
   // An entry well past the entry level (a gap through it) can leave a 1:2 /
   // 1:3 stop in front of A; the stop must stay behind the HL (LH).
   if(d>0?sl>=setup.a_price:sl<=setup.a_price)
      return "the price is too far from the "+S83LevelText()+" level: a 1:"+DoubleToString(rr,0)+
             " stop would not be behind the "+S83ALabel(d);
   risk_money=AccountInfoDouble(ACCOUNT_BALANCE)*S83RiskPercent(g_s83_day)/100.0;
   lots=S83Volume(d<0,entry,sl,risk_money);
   if(lots<=0.0)
      return "the position size is below the symbol's minimum of "+
             DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),2)+" lots";
   double margin=0.0;
   if(OrderCalcMargin(d<0?ORDER_TYPE_SELL:ORDER_TYPE_BUY,_Symbol,lots,entry,margin) &&
      margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE))
      return "insufficient free margin";
   return "";
  }

// The entry moment of a setup: price touched the entry level.
void S83Enter(const S83_SETUP &setup,const MqlTick &tick)
  {
   string what=S83Side(setup.direction)+" setup ("+S83SetupText(setup)+")";
   string event=S83LevelText()+" touched";
   if(!TradingActive())
     {
      S83Record(setup,false,event+"; not traded (Trade Mode)",0.0,0.0,0.0,0.0,0.0);
      S83Alert(event+" on the "+what);
      return;
     }
   S83LoadDay(g_s83_day);
   string reason=S83Blocker(setup.direction);
   bool buy=setup.direction>0;
   double entry=buy?tick.ask:tick.bid;
   double sl=0.0,tp=0.0,rr=0.0,lots=0.0,risk_money=0.0;
   if(reason=="") reason=S83Plan(setup,entry,tick.ask-tick.bid,g_s83_atr,sl,tp,rr,lots,risk_money);
   if(reason=="" && MQLInfoInteger(MQL_TESTER)==0 &&
      (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)==0 || MQLInfoInteger(MQL_TRADE_ALLOWED)==0))
      reason="Algo Trading is disabled";
   if(reason!="")
     {
      S83Record(setup,false,event+"; not traded: "+reason,0.0,0.0,0.0,0.0,0.0);
      S83Journal(what+" not traded: "+reason);
      return;
     }
   // Synthetic indices move many points a tick; a fixed 20-point deviation
   // would requote on instant execution, so allow a tenth of the LTF ATR.
   g_trade.SetDeviationInPoints((ulong)MathMax(20.0,MathRound(0.1*g_s83_atr/_Point)));
   string comment="83% "+S83Side(setup.direction)+" r="+
                  (string)(long)MathRound(MathAbs(entry-sl)/_Point);
   bool sent=buy?g_trade.Buy(lots,_Symbol,0.0,sl,tp,comment):g_trade.Sell(lots,_Symbol,0.0,sl,tp,comment);
   uint retcode=g_trade.ResultRetcode();
   if(sent && (retcode==TRADE_RETCODE_DONE || retcode==TRADE_RETCODE_PLACED))
     {
      g_s83_day.trades++;
      S83Record(setup,true,S83Side(setup.direction)+" "+DoubleToString(lots,2)+" lots at "+PriceText(entry)+
                ", SL "+PriceText(sl)+", TP "+PriceText(tp)+" (1:"+DoubleToString(rr,0)+")"+
                (g_s83_size_note==""?"":"; "+g_s83_size_note),entry,sl,tp,rr,lots);
      S83Journal(S83Side(setup.direction)+" "+DoubleToString(lots,2)+" lots at "+PriceText(entry)+" SL "+
                 PriceText(sl)+" TP "+PriceText(tp)+" 1:"+DoubleToString(rr,0)+", risk "+
                 DoubleToString(S83RiskPercent(g_s83_day),2)+"% ("+what+")"+
                 (g_s83_size_note==""?"":"; "+g_s83_size_note));
      S83Alert(S83Side(setup.direction)+" at "+PriceText(entry)+", SL "+PriceText(sl)+", TP "+PriceText(tp));
     }
   else
     {
      // A setup is used up even when the request fails, so a rejected order
      // is not resent on every tick.
      S83Record(setup,false,event+"; the order failed ("+g_trade.ResultRetcodeDescription()+")",
                0.0,0.0,0.0,0.0,0.0);
      Print("83% Strategy: the order for the ",what," failed - ",g_trade.ResultRetcodeDescription());
     }
  }

// Every tick: an armed setup is entered when the chart price (bid) touches
// its entry level and invalidated when it goes beyond B first.
void S83CheckEntry()
  {
   if(!g_s83_ready) return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0.0 || tick.ask<=0.0) return;
   bool changed=false;
   for(int slot=0;slot<2;slot++)
     {
      if(g_s83_armed_valid[slot]==0) continue;
      S83_SETUP setup=g_s83_armed[slot];
      if(S83OutcomeIndex(setup.direction,setup.a_time)>=0) continue;
      bool buy=setup.direction>0;
      bool touched=buy?tick.bid<=setup.level:tick.bid>=setup.level;
      // Beyond a forming B, B follows price at the candle's close instead.
      bool beyond=setup.b_fixed!=0 && (buy?tick.bid>setup.b_price:tick.bid<setup.b_price);
      if(touched)
        {
         S83Enter(setup,tick);
         changed=true;
        }
      else if(beyond)
        {
         S83Record(setup,false,"invalidated: a new "+S83BLabel(setup.direction)+" before the "+S83LevelText()+
                   " retracement",0.0,0.0,0.0,0.0,0.0);
         changed=true;
        }
     }
   if(changed && DrawingEnabled()) S83Redraw();
  }

// Moves the stop to the entry price once price (bid) has covered
// Breakeven_At_Percent of the way to the take profit.
void S83ManagePosition()
  {
   if(Breakeven_At_Percent<=0.0) return;
   ulong ticket=0;
   if(!S83FindPosition(ticket)) return;
   double open=PositionGetDouble(POSITION_PRICE_OPEN);
   double sl=PositionGetDouble(POSITION_SL);
   double tp=PositionGetDouble(POSITION_TP);
   if(tp<=0.0) return;
   bool buy=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
   bool at_breakeven=sl>0.0 && (buy?sl>=open:sl<=open);
   if(at_breakeven || ticket==g_s83_breakeven_failed) return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick)) return;
   double progress=buy?tick.bid-open:open-tick.bid;
   double room=buy?tick.bid-open:open-tick.ask;
   if(progress<Breakeven_At_Percent/100.0*MathAbs(tp-open) || room<MinimumStopDistance()) return;
   if(!g_trade.PositionModify(ticket,open,tp))
     {
      g_s83_breakeven_failed=ticket;
      Print("83% Strategy: moving the stop to breakeven failed - ",g_trade.ResultRetcodeDescription());
     }
   else S83Journal("stop moved to breakeven at "+PriceText(open));
  }

void S83OnTick()
  {
   if(TradingActive()) S83ManagePosition();
   S83CheckEntry();
  }

// --------------------------------------------------------------- update
// Called by Rebuild after every closed candle of any of the three
// timeframes: publishes the market filters and finds the LTF setups.
void S83Update(const BASE_STRUCTURE_STATE &htf,const BASE_STRUCTURE_STATE &mtf,
               const BASE_STRUCTURE_STATE &ltf,const MqlRates &ltf_rates[],const int ltf_total,
               const BASE_STRUCTURE_POINT &ltf_points[],const int &market[],
               const BASE_TRADABILITY tradability,const string tradability_reason)
  {
   g_s83_tradability=tradability;
   g_s83_tradability_reason=tradability_reason;
   g_s83_market_direction=g_s83_trend.have_ema?g_s83_trend.ema_direction:0;
   double atr[];
   SwingATR(ltf_rates,ltf_total,atr);
   g_s83_atr=atr[ltf_total-1];
   g_s83_last_time=ltf_rates[ltf_total-1].time;
   int armed_buy=-1,armed_sell=-1;
   int was_armed[2];
   datetime was_time[2];
   for(int slot=0;slot<2;slot++)
     {
      was_armed[slot]=g_s83_ready && g_s83_armed_valid[slot]!=0?1:0;
      was_time[slot]=g_s83_armed[slot].a_time;
     }
   // Only setups in the market's direction (see S83ScanSetups).
   S83ScanSetups(ltf_rates,ltf_total,ltf_points,atr,market,g_s83_setups,armed_buy,armed_sell);
   // The forming candle: a live setup the market no longer points to is
   // cancelled now (the next scan ends it on this candle too).
   datetime forming=iTime(_Symbol,LTFTimeframe(),0);
   if(armed_buy>=0 && g_s83_market_direction!=1)
     {
      S83End(g_s83_setups[armed_buy],S83_CANCELLED,forming,S83_WHY_MARKET);
      armed_buy=-1;
     }
   if(armed_sell>=0 && g_s83_market_direction!=-1)
     {
      S83End(g_s83_setups[armed_sell],S83_CANCELLED,forming,S83_WHY_MARKET);
      armed_sell=-1;
     }
   g_s83_armed_valid[0]=armed_buy>=0?1:0;
   g_s83_armed_valid[1]=armed_sell>=0?1:0;
   if(armed_buy>=0) g_s83_armed[0]=g_s83_setups[armed_buy];
   if(armed_sell>=0) g_s83_armed[1]=g_s83_setups[armed_sell];
   S83LoadDay(g_s83_day);
   // A newly armed setup is announced once.
   for(int slot=0;slot<2;slot++)
      if(g_s83_armed_valid[slot]!=0 && (was_armed[slot]==0 || was_time[slot]!=g_s83_armed[slot].a_time) && g_s83_ready)
         S83Alert("setup armed - "+S83SetupText(g_s83_armed[slot]));
   g_s83_ready=true;
  }

// ------------------------------------------------------------ dashboard
// The 83% Strategy rows under Base's dashboard: the setup state, the entry
// filters for the armed (or MTF) direction, today's risk and the latest
// outcome.
void S83DashboardRows(BASE_DASHBOARD_ROW &rows[])
  {
   if(!g_s83_ready) return;
   AddDashboardRow(rows,"","",DASHBOARD_TEXT_COLOR);
   ulong ticket=0;
   bool position=S83FindPosition(ticket);
   string state=g_s83_market_direction>0?"Waiting for a buy setup":g_s83_market_direction<0?"Waiting for a sell setup":
                "No setups ("+HTFName()+" EMAs not in order)";
   color state_color=DASHBOARD_NEUTRAL_COLOR;
   if(position)
     {
      bool buy=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
      state=(buy?"Buy":"Sell")+" position open";
      state_color=buy?DASHBOARD_POSITIVE_COLOR:DASHBOARD_NEGATIVE_COLOR;
     }
   else if(g_s83_armed_valid[0]!=0 && g_s83_armed_valid[1]!=0) state="Buy and sell setups live";
   else if(g_s83_armed_valid[0]!=0)
     {
      state="Buy setup armed";
      state_color=DASHBOARD_POSITIVE_COLOR;
     }
   else if(g_s83_armed_valid[1]!=0)
     {
      state="Sell setup armed";
      state_color=DASHBOARD_NEGATIVE_COLOR;
     }
   AddDashboardRow(rows,"83% Strategy ("+LTFName()+"):",state,state_color,
                   "Buys (sells) at the "+S83LevelText()+" retracement of the latest "+LTFName()+
                   " HL-to-HH (LH-to-LL) leg with heavy pressure, within the last "+(string)LTFBarsToProcess()+
                   " "+LTFName()+" candles. Only buy setups are identified in a bullish market and only sell setups "+
                   "in a bearish one (the "+HTFName()+" EMA order).");
   for(int slot=0;slot<2;slot++)
      if(g_s83_armed_valid[slot]!=0)
         AddWrappedDashboardRow(rows,"Setup:",S83SetupText(g_s83_armed[slot]),DASHBOARD_TEXT_COLOR,
                                "Heavy pressure "+DoubleToString(g_s83_armed[slot].impulse,1)+" "+LTFName()+" ATR");
   int direction=g_s83_armed_valid[0]!=0?1:(g_s83_armed_valid[1]!=0?-1:g_s83_market_direction);
   string blocker=S83FilterText(direction);
   AddWrappedDashboardRow(rows,"Entry Filters:",blocker==""?"PASS ("+TrendWord(direction)+")":"BLOCKED: "+blocker,
                          PassColor(blocker==""));
   string risk=(string)g_s83_day.trades+"/"+(string)Max_Trades_Per_Day+" trades, risk "+
               DoubleToString(S83RiskPercent(g_s83_day),2)+"%";
   if(g_s83_day.losses>0) risk+=", "+(string)g_s83_day.losses+" loss"+(g_s83_day.losses==1?"":"es")+" in a row";
   MqlDateTime now;
   TimeToStruct(TimeCurrent(),now);
   if(!S83TradingDay(now.day_of_week)) risk+=" (no trading on "+S83DayName(now.day_of_week)+")";
   AddDashboardRow(rows,"Risk Today:",risk,DASHBOARD_TEXT_COLOR,
                   "Risk "+DoubleToString(Risk_Percent,2)+"% per trade, x"+DoubleToString(Risk_Cut_Factor,2)+
                   " after every "+(string)Losses_Before_Risk_Cut+" consecutive losses, reset each day.");
   int last=ArraySize(g_s83_outcomes)-1;
   if(last>=0)
      AddWrappedDashboardRow(rows,"Last Setup:",g_s83_outcomes[last].text,
                             g_s83_outcomes[last].traded?DASHBOARD_POSITIVE_COLOR:DASHBOARD_TEXT_COLOR);
   if(!TradingActive())
      AddDashboardRow(rows,"Trading:","Off on this chart (Trade Mode)",DASHBOARD_NEUTRAL_COLOR);
  }

// The market filters alone (no position, day or trade-count checks), for the
// dashboard.
// The market filter of an entry: Market Tradability reads Tradable in its
// direction: the HTF EMA order, the MTF swings and the Hurst exponent line up
// (see EvaluateTradability).
string S83FilterText(const int direction)
  {
   if(g_s83_tradability!=BASE_TRADABLE)
      return "Market Tradability is not Tradable ("+g_s83_tradability_reason+")";
   if(g_s83_market_direction!=direction)
      return "Market Tradability is "+TrendWord(g_s83_market_direction)+", not "+TrendWord(direction);
   return "";
  }

// ------------------------------------------------------------- drawing
// On the LTF chart: each setup of the processed candles with Fib Base's
// levels (B 0%, the entry level, A 100% and the optional levels), A / B / C,
// and the position as in the strategy's examples: the target zone (entry to
// take profit) and the stop zone (entry to stop loss) from C.  An armed
// setup shows its planned position from the latest candle; a setup that
// failed is drawn dotted with the reason.
void S83Text(const string id,const datetime time,const double price,const string text,const color clr,
             const ENUM_ANCHOR_POINT anchor,const int size)
  {
   DrawTextAnchored("S83_"+id,time,price,text,clr,anchor,size);
  }

void S83Line(const string id,const datetime from,const datetime to,const double price,const color clr,
             const ENUM_LINE_STYLE style,const int width)
  {
   DrawSegment("S83_"+id,from,price,to,price,clr,style,width);
  }

void S83Box(const string id,const datetime from,const datetime to,const double top,const double bottom,
            const color clr)
  {
   string name=g_prefix+"S83_"+id;
   if(ObjectFind(0,name)>=0 || !ObjectCreate(0,name,OBJ_RECTANGLE,0,from,top,to,bottom)) return;
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FILL,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
  }

void S83DrawLevel(const string id,const S83_SETUP &setup,const double ratio,const color clr,
                  const datetime from,const datetime to,const ENUM_LINE_STYLE style)
  {
   bool from_high=setup.direction>0;
   double hi=setup.direction>0?setup.b_price:setup.a_price;
   double lo=setup.direction>0?setup.a_price:setup.b_price;
   double price=FibLevel(ratio,from_high,hi,lo);
   S83Line(id,from,to,price,clr,style,Fib_Line_Width);
   S83Text(id+"_TEXT",to,price," "+FibLabelText(ratio,price),clr,ANCHOR_LEFT,(int)Label_Size);
  }

void S83DrawSetup(const S83_SETUP &setup,const int index,const datetime right)
  {
   string key=(setup.direction>0?"BUY_":"SELL_")+(string)setup.a_time;
   bool armed=S83Live(setup);
   int outcome=S83OutcomeIndex(setup.direction,setup.a_time);
   bool touched=setup.state==S83_TOUCHED ||
                (outcome>=0 && StringFind(g_s83_outcomes[outcome].text,"invalidated")<0);
   bool failed=!armed && !touched;
   int period=PeriodSeconds(LTFTimeframe());
   datetime end=right;
   if(!armed && setup.end_time+Fib_Right_Offset*period<right) end=setup.end_time+Fib_Right_Offset*period;
   color point_color=setup.direction>0?Bullish_Setup_Color:Bearish_Setup_Color;
   ENUM_LINE_STYLE style=failed?STYLE_DOT:Fib_Line_Style;
   if(Show_Fibonacci)
     {
      if(Fib_Level_1_Show) S83DrawLevel(key+"_L1",setup,Fib_Level_1,Fib_Level_1_Color,setup.a_time,end,style);
      if(Fib_Level_2_Show) S83DrawLevel(key+"_L2",setup,Fib_Level_2,Fib_Level_2_Color,setup.a_time,end,style);
      if(Fib_Level_3_Show) S83DrawLevel(key+"_L3",setup,Fib_Level_3,Fib_Level_3_Color,setup.a_time,end,style);
      if(Fib_Level_4_Show) S83DrawLevel(key+"_L4",setup,Fib_Level_4,Fib_Level_4_Color,setup.a_time,end,style);
      if(Fib_Level_5_Show) S83DrawLevel(key+"_L5",setup,Fib_Level_5,Fib_Level_5_Color,setup.a_time,end,style);
      if(Fib_Level_6_Show) S83DrawLevel(key+"_L6",setup,Fib_Level_6,Fib_Level_6_Color,setup.a_time,end,style);
      S83DrawLevel(key+"_ENTRY",setup,Entry_Level,Entry_Level_Color,setup.a_time,end,style);
     }
   if(Show_Setup_Points)
     {
      S83Text(key+"_A",setup.a_time,setup.a_price,"A",point_color,setup.direction>0?ANCHOR_UPPER:ANCHOR_LOWER,
              (int)Label_Size+1);
      S83Text(key+"_B",setup.b_time,setup.b_price,"B",point_color,setup.direction>0?ANCHOR_LOWER:ANCHOR_UPPER,
              (int)Label_Size+1);
     }
   string why=S83WhyText(setup);
   if(outcome>=0 && !g_s83_outcomes[outcome].traded) why=g_s83_outcomes[outcome].text;
   if(touched && Show_Setup_Points)
     {
      datetime c_time=setup.state!=S83_TOUCHED && outcome>=0?g_s83_outcomes[outcome].time:setup.end_time;
      S83Text(key+"_C",c_time,setup.level,"C",point_color,setup.direction>0?ANCHOR_UPPER:ANCHOR_LOWER,
              (int)Label_Size+1);
     }
   if(why!="")
      S83Text(key+"_WHY",setup.end_time>0?setup.end_time:right,setup.level,why,clrGray,
              setup.direction>0?ANCHOR_RIGHT_UPPER:ANCHOR_RIGHT_LOWER,(int)Label_Size);
   if(!Show_Position_Boxes) return;
   // The position: the traded one from C, or the plan at the entry level.
   double entry=setup.level,sl=0.0,tp=0.0,rr=0.0;
   datetime from=0;
   if(outcome>=0 && g_s83_outcomes[outcome].traded)
     {
      entry=g_s83_outcomes[outcome].entry;
      sl=g_s83_outcomes[outcome].sl;
      tp=g_s83_outcomes[outcome].tp;
      rr=g_s83_outcomes[outcome].rr;
      from=g_s83_outcomes[outcome].time;
     }
   else if(setup.state==S83_ARMED)
     {
      double lots=0.0,risk_money=0.0;
      if(S83Plan(setup,entry,0.0,g_s83_atr,sl,tp,rr,lots,risk_money)=="" || (sl>0.0 && tp>0.0))
         from=g_s83_last_time;
     }
   if(from==0 || sl<=0.0 || tp<=0.0) return;
   datetime to=from+Position_Box_Candles*period;
   S83Box(key+"_TARGET",from,to,MathMax(entry,tp),MathMin(entry,tp),Target_Zone_Color);
   S83Box(key+"_STOP",from,to,MathMax(entry,sl),MathMin(entry,sl),Stop_Zone_Color);
   string plan=(armed?"Planned ":"")+"1:"+DoubleToString(rr,0)+"  TP "+PriceText(tp)+"  SL "+PriceText(sl);
   S83Text(key+"_PLAN",to,tp,plan,DASHBOARD_TEXT_COLOR,ANCHOR_LEFT,(int)Label_Size);
  }

// Only the latest Setups_To_Show setups are drawn (newest first), and every
// live one, so the chart stays clean.
void S83DrawAll()
  {
   if(!g_s83_ready || PeriodSeconds((ENUM_TIMEFRAMES)_Period)!=PeriodSeconds(LTFTimeframe())) return;
   datetime right=g_s83_last_time+Fib_Right_Offset*PeriodSeconds(LTFTimeframe());
   int shown=0;
   for(int i=ArraySize(g_s83_setups)-1;i>=0;i--)
     {
      if(!S83Live(g_s83_setups[i]) && shown>=Setups_To_Show) continue;
      S83DrawSetup(g_s83_setups[i],i,right);
      shown++;
     }
  }

// Redraws the setups after a live outcome, between candles.
void S83Redraw()
  {
   ObjectsDeleteAll(0,g_prefix+"S83_");
   S83DrawAll();
   ChartRedraw();
  }

string S83InputProblem()
  {
   if(LTF_Bars_To_Process<5) return "LTF_Bars_To_Process must be at least 5";
   if(Setups_To_Show<0) return "Setups_To_Show cannot be negative";
   if(HTF_EMA_Fast<1 || HTF_EMA_Middle<=HTF_EMA_Fast || HTF_EMA_Slow<=HTF_EMA_Middle)
      return "the HTF EMAs need 1 <= HTF_EMA_Fast < HTF_EMA_Middle < HTF_EMA_Slow";
   if(HTF_EMA_Candles<1 || HTF_EMA_Candles>50) return "HTF_EMA_Candles must be 1 to 50";
   if(Hurst_Candles<50 || Hurst_Candles>400) return "Hurst_Candles must be 50 to 400";
   if(Hurst_Minimum<0.0 || Hurst_Minimum>=1.0) return "Hurst_Minimum must be 0 to below 1";
   if(Entry_Level<=0.0 || Entry_Level>=1.0) return "the Entry Level must be between 0 and 1 (0.83 = 83%)";
   if(Impulse_Candles<0 || Impulse_Min_ATR<0.0) return "the heavy-pressure inputs cannot be negative";
   if(Risk_Percent<=0.0 || Risk_Percent>100.0) return "Risk_Percent must be above 0 and at most 100";
   if(Max_Trades_Per_Day<1) return "Max_Trades_Per_Day must be at least 1";
   if(Losses_Before_Risk_Cut<0 || Risk_Cut_Factor<=0.0 || Risk_Cut_Factor>1.0)
      return "the risk cut needs Losses_Before_Risk_Cut >= 0 and a factor above 0 and at most 1";
   if(SL_Buffer_ATR<0.0 || TP_Buffer_ATR<0.0) return "the stop and target buffers cannot be negative";
   if(Reward_Risk_Low<=0.0 || Reward_Risk_High<Reward_Risk_Low)
      return "the standard reward-to-risk ratios must be positive, the second at least the first";
   if(Breakeven_At_Percent<0.0 || Breakeven_At_Percent>=100.0) return "Breakeven_At_Percent must be 0 to 99";
   if(Minimum_Lot_Max_Risk_Multiple<0.0) return "Minimum_Lot_Max_Risk_Multiple cannot be negative";
   return "";
  }

void S83Init()
  {
   g_s83_ready=false;
   g_s83_armed_valid[0]=0;
   g_s83_armed_valid[1]=0;
   ArrayResize(g_s83_setups,0);
   g_s83_breakeven_failed=0;
   g_s83_journaled="";
   g_s83_waiting="";
   ZeroMemory(g_s83_trend);
   g_s83_ema_fast_handle=iMA(_Symbol,BASETimeframe(),HTF_EMA_Fast,0,MODE_EMA,PRICE_CLOSE);
   g_s83_ema_middle_handle=iMA(_Symbol,BASETimeframe(),HTF_EMA_Middle,0,MODE_EMA,PRICE_CLOSE);
   g_s83_ema_slow_handle=iMA(_Symbol,BASETimeframe(),HTF_EMA_Slow,0,MODE_EMA,PRICE_CLOSE);
   g_trade.SetExpertMagicNumber(Magic_Number);
   g_trade.SetDeviationInPoints(20);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.LogLevel(LOG_LEVEL_ERRORS);
  }

void S83Deinit()
  {
   if(g_s83_ema_fast_handle!=INVALID_HANDLE) IndicatorRelease(g_s83_ema_fast_handle);
   if(g_s83_ema_middle_handle!=INVALID_HANDLE) IndicatorRelease(g_s83_ema_middle_handle);
   if(g_s83_ema_slow_handle!=INVALID_HANDLE) IndicatorRelease(g_s83_ema_slow_handle);
   g_s83_ema_fast_handle=INVALID_HANDLE;
   g_s83_ema_middle_handle=INVALID_HANDLE;
   g_s83_ema_slow_handle=INVALID_HANDLE;
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
   int length=HTFSwingLength();
   int displayed=StructureBars();
   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   int total=CopyRates(_Symbol,timeframe,1,ReplayBars(displayed),rates);
   if(total<2*length+2)
      return S83Wait("not enough "+TimeframeName(timeframe)+" history yet ("+(string)MathMax(total,0)+" candles)");

   // The ADX and ATR filters use the latest closed bar.
   double adx[],atr[];
   if(Use_ADX_Filter && !CopyIndicator(g_adx_handle,0,1,adx)) return S83Wait("the HTF ADX is still calculating");
   if(Use_ATR_Filter && !CopyIndicator(g_atr_handle,0,1,atr)) return S83Wait("the HTF ATR is still calculating");

   // The MTF and LTF biases are replayed over the same elapsed time as the
   // structure timeframe (plus the same warm-up), so every bias has comparable
   // context instead of a few hours of lower-timeframe candles.
   BASE_STRUCTURE_STATE setup_state,ltf_state;
   MqlRates setup_rates[],ltf_rates[];
   BASE_STRUCTURE_POINT setup_points[],ltf_points[];
   BASE_STRUCTURE_EVENT setup_events[],ltf_events[];
   if(!AnalyseStructure(SetupTimeframe(),ReplayBars(ChartStructureBars(SetupTimeframe())),
                        MTFSwingLength(),setup_state,setup_rates,setup_points,setup_events))
      return S83Wait("not enough "+MTFName()+" history yet");
   if(!AnalyseStructure(LTFTimeframe(),ReplayBars(ChartStructureBars(LTFTimeframe())),
                        LTFSwingLength(),ltf_state,ltf_rates,ltf_points,ltf_events))
      return S83Wait("not enough "+LTFName()+" history yet");
   int ltf_total=ArraySize(ltf_rates);

   // Labels follow the chart period, while the dashboard state stays on
   // Structure_Timeframe.
   bool anchored=chart_timeframe==timeframe;
   MqlRates chart_rates[];
   ArraySetAsSeries(chart_rates,false);
   int chart_total=0;
   if(!anchored && DrawingEnabled())
     {
      chart_total=CopyRates(_Symbol,chart_timeframe,1,
                            ReplayBars(ChartStructureBars(chart_timeframe)),chart_rates);
      if(chart_total<=0) return S83Wait("the chart's history is not loaded yet");
     }

   BASE_STRUCTURE_STATE structure_state;
   BASE_STRUCTURE_POINT points[];
   BASE_STRUCTURE_EVENT events[];
   ReplayStructure(rates,total,length,structure_state,points,events);


   if(DrawingEnabled())
     {
      ObjectsDeleteAll(0,g_prefix);
      if(anchored)
         DrawChart(rates,total,MathMax(0,total-displayed),structure_state,points,events,
                   HTFInternalLength(),timeframe);
      else
        {
         BASE_STRUCTURE_STATE chart_state;
         BASE_STRUCTURE_POINT chart_points[];
         BASE_STRUCTURE_EVENT chart_events[];
         if(ReplayStructure(chart_rates,chart_total,ChartSwingLength(chart_timeframe),
                            chart_state,chart_points,chart_events))
            DrawChart(chart_rates,chart_total,MathMax(0,chart_total-ChartDisplayBars(chart_timeframe)),
                      chart_state,chart_points,chart_events,ChartInternalLength(chart_timeframe),
                      chart_timeframe);
        }
      S83DrawEmaLines(rates,total,displayed);
     }

   // Trend: the HTF EMAs on the latest closed HTF candle and the MTF swings,
   // and the market direction at each LTF candle's open (the setups follow it).
   S83_TREND trend;
   S83ReadTrend(setup_points,trend);
   int market[];
   if(!S83MarketHistory(ltf_rates,ltf_total,ltf_total-3*LTFBarsToProcess(),market) ||
      (!trend.have_ema && iBars(_Symbol,BASETimeframe())>HTF_EMA_Slow+HTF_EMA_Candles))
      return S83Wait("the HTF EMAs are still calculating");
   string tradability_reason="";
   BASE_TRADABILITY tradability=EvaluateTradability(trend,tradability_reason);
   S83Update(structure_state,setup_state,ltf_state,ltf_rates,ltf_total,ltf_points,market,
             tradability,tradability_reason);

   if(DrawingEnabled()) DrawDashboard(trend,tradability,tradability_reason,EntryFilterTooltip(rates[total-1],adx,atr));
   if(DrawingEnabled()) S83DrawAll();
   g_s83_waiting="";
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
   return true;
  }

bool ValidInputs()
  {
   string problem="";
   if(HTF_Swing_Level<MIN_DETECTION_LEVEL || HTF_Swing_Level>MAX_DETECTION_LEVEL ||
      MTF_Swing_Level<MIN_DETECTION_LEVEL || MTF_Swing_Level>MAX_DETECTION_LEVEL ||
      LTF_Swing_Level<MIN_DETECTION_LEVEL || LTF_Swing_Level>MAX_DETECTION_LEVEL)
      problem="each Swing Detection Length must be between "+(string)MIN_DETECTION_LEVEL+" and "+
              (string)MAX_DETECTION_LEVEL;
   else if(HTF_Internal_Level<MIN_DETECTION_LEVEL || HTF_Internal_Level>MAX_DETECTION_LEVEL ||
           MTF_Internal_Level<MIN_DETECTION_LEVEL || MTF_Internal_Level>MAX_DETECTION_LEVEL ||
           LTF_Internal_Level<MIN_DETECTION_LEVEL || LTF_Internal_Level>MAX_DETECTION_LEVEL)
      problem="each Internal Structure Length must be between "+(string)MIN_DETECTION_LEVEL+" and "+
              (string)MAX_DETECTION_LEVEL;
   else if(Bars_To_Process<100)
      problem="Bars_To_Process must be at least 100";
   else if(ADX_Length<1 || ATR_Length<1)
      problem="ADX and ATR lengths must be positive";
   else if(Equal_Highs_Lows_Threshold<0.0 || Equal_Highs_Lows_Threshold>0.5)
      problem="the EQH/EQL Threshold must be between 0 and 0.5";
   else if(!Use_HTF && !Use_MTF && !Use_LTF)
      problem="enable at least one trend analysis timeframe";
   if(problem=="") problem=S83InputProblem();
   if(problem=="") return true;
   Print("83% Strategy: invalid input - ",problem,".");
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
   if(Use_ADX_Filter && (g_adx_handle=iADX(_Symbol,timeframe,ADX_Length))==INVALID_HANDLE) return INIT_FAILED;
   if(Use_ATR_Filter && (g_atr_handle=iATR(_Symbol,timeframe,ATR_Length))==INVALID_HANDLE) return INIT_FAILED;
   S83Init();
   if(!EventSetTimer(2)) return INIT_FAILED;
   CheckForBar();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(g_adx_handle!=INVALID_HANDLE) IndicatorRelease(g_adx_handle);
   if(g_atr_handle!=INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   g_adx_handle=INVALID_HANDLE;
   g_atr_handle=INVALID_HANDLE;
   S83Deinit();
   ObjectsDeleteAll(0,g_prefix);
   Comment("");
  }

void CheckForBar()
  {
   datetime current=iTime(_Symbol,LTFTimeframe(),0);
   datetime structure_current=iTime(_Symbol,BASETimeframe(),0);
   datetime setup_current=iTime(_Symbol,SetupTimeframe(),0);
   if(current==0 || structure_current==0 || setup_current==0)
     {
      S83Wait("no "+(structure_current==0?HTFName():setup_current==0?MTFName():LTFName())+" candles yet");
      return;
     }
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

void OnTick()
  {
   CheckForBar();
   S83OnTick();
  }
void OnTimer() { CheckForBar(); }
