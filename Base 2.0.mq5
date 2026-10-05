#property copyright "Market Trend Analyser conversion"
#property version   "3.00"
#property strict
#property description "BASE 2.0: market structure from ATR-sized swings and a three-state trend (Bullish, Bearish, Range) held by one protected level."
#property description "Signal/visualisation EA only; it contains no trading rules."

enum BASE_MA_TYPE { BASE_SMA=0, BASE_EMA=1 };
enum BASE_MA_FILTER_MODE { BASE_PRICE_ABOVE_BELOW=0, BASE_FULL_BODY_CLOSE=1 };
enum BASE_SESSION { BASE_NEW_YORK=0, BASE_LONDON=1, BASE_TOKYO=2, BASE_SYDNEY=3, BASE_CUSTOM=4, BASE_24X7=5 };
enum BASE_ADX_SCOPE { BASE_BOS_ONLY=0, BASE_BOS_AND_CHOCH=1 };
enum BASE_ATR_MODE { BASE_ATR_MINIMUM=0, BASE_ATR_MAXIMUM=1, BASE_ATR_RANGE=2 };
enum BASE_LABEL_SIZE { BASE_TINY=7, BASE_SMALL=9, BASE_NORMAL=11, BASE_LARGE=14 };
// Market Tradability (see EvaluateTradability).
enum BASE_TRADABILITY { BASE_NOT_TRADABLE=0, BASE_TRADABLE=2 };
// The timeframe the Hurst exponent is measured on (see HurstOf).
enum BASE_HURST_TF { BASE_HURST_HTF=0, BASE_HURST_MTF=1, BASE_HURST_LTF=2 };

input group "Timeframes"
input ENUM_TIMEFRAMES Structure_Timeframe=PERIOD_H1; // HTF
input ENUM_TIMEFRAMES Setup_Entry_Timeframe=PERIOD_M30; // MTF
input ENUM_TIMEFRAMES LTF_Timeframe=PERIOD_M15; // LTF

input group "Trend Analysis Timeframes"
input bool Use_HTF=true; // Use HTF
input bool Use_MTF=false; // Use MTF
input bool Use_LTF=false; // Use LTF

input group "Trend Quality (Market Tradability)"
input int Trend_Quality_Candles=30; // Trend Quality Window (closed HTF candles, 5-200)
input double Trend_Quality_Minimum=0.30; // Tradable When The HTF Efficiency Is At Least (0-1)

input group "Market Tradability Extras (off by default)"
input bool Require_Progressive_Swings=false; // Also Require HH + HL (LL + LH)
input bool Require_Internal_Agreement=false; // Also Require The HTF Internal Structure To Agree
input bool Use_Hurst_Filter=false; // Also Require The Hurst Exponent Above Its Minimum

input group "Hurst Exponent (Trend Persistence)"
input BASE_HURST_TF Hurst_Timeframe=BASE_HURST_HTF; // Hurst Timeframe (HTF, MTF or LTF)
input int Hurst_Candles=100; // Hurst Window (closed candles, 50-400)
input double Hurst_Minimum=0.50; // Hurst Minimum (0.5 = random walk)

input group "Structure Bar Processing"
input int Bars_To_Process=100;

input group "Swing Detection (ATR swing size)"
input int HTF_Swing_Level=3; // HTF Swing Size (1-10: 0.5 to 5 ATR, 3 = 1 ATR)
input int MTF_Swing_Level=5; // MTF Swing Size (1-10: 0.5 to 5 ATR, 5 = 1.5 ATR)
input int LTF_Swing_Level=7; // LTF Swing Size (1-10: 0.5 to 5 ATR, 7 = 2.5 ATR)
input bool Show_Swing_Points=true;
input bool Show_Strong_Weak_High_Low=true; // Show Strong/Weak High/Low (Range High/Low in a range)

input group "Internal Structure"
input bool Show_Internal_Structure=true; // Show Internal Structure
input bool Show_Internal_On_Dashboard=true; // Show Internal Structure On Dashboard
input double Internal_Swing_Ratio=0.5; // Internal Swing Size (fraction of the swing size, 0.2-0.9)
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
input bool Use_Timeframe_Correlation_For_Optimal=false;
input bool Use_Healthy_Extension_For_Optimal=false;
input bool Use_Market_Volume_For_Optimal=false;
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
const double Maximum_Extension_ATR=10.0;   // MTF ATR beyond the latest MTF swing (see TrendExtension)
const int Volume_Average_Length=20;
const double Volume_Minimum_Ratio=0.50;
const double Volume_Maximum_Ratio=2.00;
const int Momentum_Average_Length=20;
const double Momentum_Minimum_Ratio=0.50;
const double Momentum_Maximum_Ratio=2.00;

// Swing detection (ATR zigzag, see ReplayStructure): a swing is confirmed
// once price closes a set distance back from it, measured in ATR, so swings
// grow and shrink with volatility instead of counting candles.  The Swing
// Detection levels (1-10) are that distance:
//   level      1     2     3     4     5     6     7     8     9    10
//   ATR      0.5  0.75   1.0  1.25   1.5   2.0   2.5   3.0   4.0   5.0
// Level 3 (1 ATR) marks about as many swings as Base's 2-candle pivots
// (level 2) did.  The internal structure is the same engine with a fraction
// (Internal_Swing_Ratio) of its timeframe's swing size.  The 14-candle ATR
// sizes the swings, the break buffer and the EQH/EQL threshold.
const int MIN_DETECTION_LEVEL=1;
const int MAX_DETECTION_LEVEL=10;
const int SWING_ATR_LENGTH=14;

// The swing size, in ATR, of a Swing Detection level.
double SwingSize(const int level)
  {
   switch(MathMax(MIN_DETECTION_LEVEL,MathMin(MAX_DETECTION_LEVEL,level)))
     {
      case 1: return 0.5;
      case 2: return 0.75;
      case 3: return 1.0;
      case 4: return 1.25;
      case 5: return 1.5;
      case 6: return 2.0;
      case 7: return 2.5;
      case 8: return 3.0;
      case 9: return 4.0;
     }
   return 5.0;
  }

double HTFSwingSize() { return SwingSize(HTF_Swing_Level); }
double MTFSwingSize() { return SwingSize(MTF_Swing_Level); }
double LTFSwingSize() { return SwingSize(LTF_Swing_Level); }
double InternalSize(const double swing_size) { return swing_size*Internal_Swing_Ratio; }

// A break is a close beyond a level by this much of the latest candle's ATR,
// so a close that only grazes a level breaks nothing.
const double BREAK_BUFFER_ATR=0.1;

string g_prefix="";
datetime g_last_ltf_bar=0;
datetime g_last_structure_bar=0;
datetime g_last_setup_bar=0;
int g_htf_ma_handle=INVALID_HANDLE;
int g_mtf_ma_handle=INVALID_HANDLE;
int g_adx_handle=INVALID_HANDLE;
int g_atr_handle=INVALID_HANDLE;

// Every replay covers this many times the displayed history.  The extra,
// undrawn candles let the trend and the swings settle before the first
// displayed candle, so the left edge of the chart and the trend are not
// based on a cold start.
const int STRUCTURE_WARMUP_FACTOR=3;

// The trend of one timeframe (see ReplayStructure).
struct BASE_STRUCTURE_STATE
  {
   int trend;               // 1 Bullish, -1 Bearish, 0 Range
   int prev_trend;          // Range: the trend its CHoCH broke (0 before the first trend)
   int choch_event;         // Range: events index of that CHoCH, -1 if none
   // The latest swing on each side, and its HH/LH (LL/HL) kind.
   bool have_high;
   double last_high;
   datetime last_high_time;
   int last_high_kind;
   int last_high_point;
   bool have_low;
   double last_low;
   datetime last_low_time;
   int last_low_kind;
   int last_low_point;
   // Bullish (Bearish): the protected low (high), the weak high (low) a BOS
   // must close beyond, and the trend's running high (low) since its BOS.
   bool have_protected;
   double protected_level;
   datetime protected_time;
   int protected_bar;
   bool have_target;
   double target;
   datetime target_time;
   int target_bar;
   bool have_trail;
   double trail;
   datetime trail_time;
   int bos_bar;             // the candle of the latest BOS, -1 before the first
   // Range: its high and low.
   bool have_range_high;
   double range_high;
   datetime range_high_time;
   int range_high_bar;
   bool have_range_low;
   double range_low;
   datetime range_low_time;
   int range_low_bar;
  };

// One confirmed swing.  Swings never change once confirmed.
struct BASE_STRUCTURE_POINT
  {
   int pivot;               // bar index of the swing candle
   int confirmed;           // bar index of the close that confirmed it
   datetime time;
   double price;
   int side;                // 1 high, -1 low
   int kind;                // 1 HH/LL, -1 LH/HL, 0 the first swing on its side
   int equal;               // points index of the swing it equals (EQH/EQL), -1 if none
  };

// One close-confirmed break.
struct BASE_STRUCTURE_EVENT
  {
   int bar;                 // the candle that closed through the level
   int direction;           // 1 bullish, -1 bearish
   bool bos;                // a BOS, or a CHoCH (a protected level broken)
   datetime swing_time;     // the swing that held the level
   int swing_bar;
   double level;
   bool ls;                 // a CHoCH after which the old trend resumed (liquidity sweep)
   int ls_bar;              // the candle that resumed it, -1 if none
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

// The chart draws its own timeframe with the swing size of the matching
// HTF, MTF or LTF input; any other chart period uses the HTF size.
double ChartSwingSize(const ENUM_TIMEFRAMES timeframe)
  {
   if(timeframe==BASETimeframe()) return HTFSwingSize();
   if(timeframe==SetupTimeframe()) return MTFSwingSize();
   if(timeframe==LTFTimeframe()) return LTFSwingSize();
   return HTFSwingSize();
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
   return MathMax(50,MathMin(wanted,100000));
  }

int ReplayBars(const int displayed)
  {
   return MathMin(100000,displayed*STRUCTURE_WARMUP_FACTOR);
  }

ENUM_MA_METHOD BASEMAMethod(const BASE_MA_TYPE value)
  {
   return value==BASE_EMA?MODE_EMA:MODE_SMA;
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

// Average true range over SWING_ATR_LENGTH candles (fewer at the start) at
// every candle, from that candle and the ones before it only.
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

// The candle of the highest high (side 1) or lowest low (-1) after candle
// `from` up to candle `to` (candle `to` itself when from==to); the latest of
// equal ones.
int ExtremeAfter(const MqlRates &rates[],const int side,const int from,const int to)
  {
   int best=-1;
   for(int j=MathMin(from+1,to);j<=to;j++)
      if(best<0 || (side>0?rates[j].high>=rates[best].high:rates[j].low<=rates[best].low)) best=j;
   return best;
  }

// A swing confirmed on candle `at`: labelled against the previous swing on
// its side (HH/LH, LL/HL; EQH/EQL within Equal_Highs_Lows_Threshold ATR of
// it, which is only a label), and offered to the trend: in a trend, a swing
// on the trend's side since its BOS can become the weak high (low) the next
// BOS must break; in a range, it widens the range.
void AddSwing(BASE_STRUCTURE_STATE &state,BASE_STRUCTURE_POINT &points[],const MqlRates &rates[],
              const double &atr[],const int side,const int bar,const int at)
  {
   double price=side>0?rates[bar].high:rates[bar].low;
   bool have_prev=side>0?state.have_high:state.have_low;
   double prev=side>0?state.last_high:state.last_low;
   int prev_point=side>0?state.last_high_point:state.last_low_point;
   int index=ArraySize(points);
   ArrayResize(points,index+1,64);
   points[index].pivot=bar;
   points[index].confirmed=at;
   points[index].time=rates[bar].time;
   points[index].price=price;
   points[index].side=side;
   points[index].kind=!have_prev?0:((side>0?price>prev:price<prev)?1:-1);
   points[index].equal=have_prev && Equal_Highs_Lows_Threshold>0.0 &&
                       MathAbs(price-prev)<Equal_Highs_Lows_Threshold*atr[bar]?prev_point:-1;
   if(side>0)
     {
      state.have_high=true;
      state.last_high=price;
      state.last_high_time=rates[bar].time;
      state.last_high_kind=points[index].kind;
      state.last_high_point=index;
     }
   else
     {
      state.have_low=true;
      state.last_low=price;
      state.last_low_time=rates[bar].time;
      state.last_low_kind=points[index].kind;
      state.last_low_point=index;
     }
   if(state.trend==side && bar>=state.bos_bar &&
      (!state.have_target || (side>0?price>state.target:price<state.target)))
     {
      state.have_target=true;
      state.target=price;
      state.target_time=rates[bar].time;
      state.target_bar=bar;
     }
   if(state.trend==0 && side>0 && (!state.have_range_high || price>state.range_high))
     {
      state.have_range_high=true;
      state.range_high=price;
      state.range_high_time=rates[bar].time;
      state.range_high_bar=bar;
     }
   if(state.trend==0 && side<0 && (!state.have_range_low || price<state.range_low))
     {
      state.have_range_low=true;
      state.range_low=price;
      state.range_low_time=rates[bar].time;
      state.range_low_bar=bar;
     }
  }

void AddStructureEvent(BASE_STRUCTURE_EVENT &events[],const int bar,const int direction,const bool bos,
                       const datetime swing_time,const int swing_bar,const double level)
  {
   int index=ArraySize(events);
   ArrayResize(events,index+1,64);
   events[index].bar=bar;
   events[index].direction=direction;
   events[index].bos=bos;
   events[index].swing_time=swing_time;
   events[index].swing_bar=swing_bar;
   events[index].level=level;
   events[index].ls=false;
   events[index].ls_bar=-1;
  }

// A BOS on candle `bar` through the swing on candle `level_bar` starts (or
// continues) a trend: the protected level becomes the latest confirmed swing
// on the other side (with none yet, the deepest point since the broken
// swing), and the next BOS needs a new swing on the trend's side.
void StartTrend(BASE_STRUCTURE_STATE &state,const BASE_STRUCTURE_POINT &points[],const MqlRates &rates[],
                const int direction,const int level_bar,const int bar)
  {
   int found=-1;
   for(int k=ArraySize(points)-1;k>=0 && found<0;k--)
      if(points[k].side==-direction) found=k;
   if(found>=0)
     {
      state.protected_level=points[found].price;
      state.protected_time=points[found].time;
      state.protected_bar=points[found].pivot;
     }
   else
     {
      int deepest=ExtremeAfter(rates,-direction,level_bar,bar);
      state.protected_level=direction>0?rates[deepest].low:rates[deepest].high;
      state.protected_time=rates[deepest].time;
      state.protected_bar=deepest;
     }
   state.have_protected=true;
   state.trend=direction;
   state.have_target=false;
   state.have_trail=false;
   state.bos_bar=bar;
   state.have_range_high=false;
   state.have_range_low=false;
  }

// A CHoCH on candle `bar`: the trend `old` lost its protected level and the
// market is a range.  Its far edge is the old trend's extreme since the
// protected level; the near edge waits for the next swing.
void EnterRange(BASE_STRUCTURE_STATE &state,const BASE_STRUCTURE_EVENT &events[],const MqlRates &rates[],
                const int old,const int bar)
  {
   int far=ExtremeAfter(rates,old,state.protected_bar,bar);
   state.trend=0;
   state.prev_trend=old;
   state.choch_event=ArraySize(events)-1;
   state.have_range_high=old>0;
   state.have_range_low=old<0;
   if(old>0)
     {
      state.range_high=rates[far].high;
      state.range_high_time=rates[far].time;
      state.range_high_bar=far;
     }
   else
     {
      state.range_low=rates[far].low;
      state.range_low_time=rates[far].time;
      state.range_low_bar=far;
     }
   state.have_protected=false;
   state.have_target=false;
   state.have_trail=false;
  }

// A close beyond the range on candle `bar`: a BOS that way.  When it resumes
// the trend the range's CHoCH broke, that CHoCH was a liquidity sweep (LS).
void LeaveRange(BASE_STRUCTURE_STATE &state,const BASE_STRUCTURE_POINT &points[],
                BASE_STRUCTURE_EVENT &events[],const MqlRates &rates[],const int direction,const int bar)
  {
   double level=direction>0?state.range_high:state.range_low;
   datetime level_time=direction>0?state.range_high_time:state.range_low_time;
   int level_bar=direction>0?state.range_high_bar:state.range_low_bar;
   if(state.prev_trend==direction && state.choch_event>=0 && state.choch_event==ArraySize(events)-1)
     {
      events[state.choch_event].ls=true;
      events[state.choch_event].ls_bar=bar;
     }
   AddStructureEvent(events,bar,direction,true,level_time,level_bar,level);
   state.prev_trend=0;
   state.choch_event=-1;
   StartTrend(state,points,rates,direction,level_bar,bar);
  }

// Replays swings and the trend over closed candles.  The trend, the chart
// labels and every BOS/CHoCH/LS come from this single routine, so they can
// never disagree.  `size` is the swing size in ATR (see SwingSize).
//
// Swings (ATR zigzag): the leg in progress tracks its extreme (a later equal
// high or low takes over).  A swing high is confirmed by the first close at
// least `size` ATR below the leg's high, the ATR being the 14-candle ATR at
// the high's candle; the falling leg then starts from the lowest low after
// the high.  Swing lows mirror this.  Before the first swing both extremes
// are tracked and whichever is confirmed first starts the legs.  Highs and
// lows always alternate, and a swing never changes once confirmed.
//
// Trend: Bullish, Bearish or Range.  A break is a close beyond a level by
// BREAK_BUFFER_ATR of the latest candle's ATR.
//  * Bullish: a close above the weak high (the highest swing high confirmed
//    since the last BOS) is a bullish BOS, and the protected low becomes the
//    latest confirmed swing low.  A close below the protected low is a
//    bearish CHoCH, and the market becomes a Range.  Pullbacks that hold the
//    protected low change nothing.
//  * Bearish mirrors Bullish.
//  * Range: its high is the old trend's extreme since its protected level
//    (or the first swing high) and any higher swing high confirmed since; its
//    low mirrors this.  A close above the range high is a bullish BOS
//    (Bullish), below the range low a bearish BOS (Bearish).  When that
//    resumes the trend the CHoCH broke, the CHoCH was a liquidity sweep and
//    is relabelled LS.
// Strong/Weak High/Low: in a bullish trend the protected low is the Strong
// Low and the trend's running high since its BOS the Weak High (bearish
// mirrors this); a range shows its high and low.
bool ReplayStructure(const MqlRates &rates[],const int total,const double size,
                     BASE_STRUCTURE_STATE &state,BASE_STRUCTURE_POINT &points[],
                     BASE_STRUCTURE_EVENT &events[])
  {
   ZeroMemory(state);
   state.choch_event=-1;
   state.bos_bar=-1;
   state.last_high_point=-1;
   state.last_low_point=-1;
   ArrayResize(points,0);
   ArrayResize(events,0);
   if(total<2) return false;
   double atr[];
   SwingATR(rates,total,atr);
   int leg=0;                  // 1 rising (tracking a high), -1 falling, 0 before the first swing
   int high_bar=0,low_bar=0;   // before the first swing: the highest high and lowest low so far
   int extreme_bar=-1;         // the leg's extreme
   for(int i=0;i<total;i++)
     {
      // 1. Swings.
      if(leg==0)
        {
         if(rates[i].high>=rates[high_bar].high) high_bar=i;
         if(rates[i].low<=rates[low_bar].low) low_bar=i;
         bool up=rates[i].close>=rates[low_bar].low+size*atr[low_bar];
         bool down=rates[i].close<=rates[high_bar].high-size*atr[high_bar];
         // Both at once: the earlier extreme is the older swing.
         if(up && (!down || low_bar<high_bar))
           {
            AddSwing(state,points,rates,atr,-1,low_bar,i);
            leg=1;
            extreme_bar=ExtremeAfter(rates,1,low_bar,i);
            if(down)
              {
               AddSwing(state,points,rates,atr,1,high_bar,i);
               leg=-1;
               extreme_bar=ExtremeAfter(rates,-1,high_bar,i);
              }
           }
         else if(down)
           {
            AddSwing(state,points,rates,atr,1,high_bar,i);
            leg=-1;
            extreme_bar=ExtremeAfter(rates,-1,high_bar,i);
            if(up)
              {
               AddSwing(state,points,rates,atr,-1,low_bar,i);
               leg=1;
               extreme_bar=ExtremeAfter(rates,1,low_bar,i);
              }
           }
        }
      else
        {
         if(leg>0 && rates[i].high>=rates[extreme_bar].high) extreme_bar=i;
         if(leg<0 && rates[i].low<=rates[extreme_bar].low) extreme_bar=i;
         // A big candle can confirm a swing and the next one at once, but a
         // leg that starts on this candle waits for a later close: the order
         // of the candle's own high and low is unknown.
         for(int pass=0;pass<4;pass++)
           {
            int pivot=extreme_bar;
            if(leg>0 && rates[i].close<=rates[pivot].high-size*atr[pivot])
              {
               AddSwing(state,points,rates,atr,1,pivot,i);
               leg=-1;
               extreme_bar=ExtremeAfter(rates,-1,pivot,i);
              }
            else if(leg<0 && rates[i].close>=rates[pivot].low+size*atr[pivot])
              {
               AddSwing(state,points,rates,atr,-1,pivot,i);
               leg=1;
               extreme_bar=ExtremeAfter(rates,1,pivot,i);
              }
            else break;
            if(pivot==i) break;
           }
        }

      // 2. The trend.
      double close=rates[i].close,buffer=BREAK_BUFFER_ATR*atr[i];
      if(state.trend>0)
        {
         if(close<state.protected_level-buffer)
           {
            AddStructureEvent(events,i,-1,false,state.protected_time,state.protected_bar,state.protected_level);
            EnterRange(state,events,rates,1,i);
           }
         else if(state.have_target && close>state.target+buffer)
           {
            AddStructureEvent(events,i,1,true,state.target_time,state.target_bar,state.target);
            StartTrend(state,points,rates,1,state.target_bar,i);
           }
        }
      else if(state.trend<0)
        {
         if(close>state.protected_level+buffer)
           {
            AddStructureEvent(events,i,1,false,state.protected_time,state.protected_bar,state.protected_level);
            EnterRange(state,events,rates,-1,i);
           }
         else if(state.have_target && close<state.target-buffer)
           {
            AddStructureEvent(events,i,-1,true,state.target_time,state.target_bar,state.target);
            StartTrend(state,points,rates,-1,state.target_bar,i);
           }
        }
      else
        {
         if(state.have_range_high && close>state.range_high+buffer)
            LeaveRange(state,points,events,rates,1,i);
         else if(state.have_range_low && close<state.range_low-buffer)
            LeaveRange(state,points,events,rates,-1,i);
        }

      // 3. The trend's running extreme since its BOS (the Weak High / Low).
      if(state.trend!=0 && (!state.have_trail || (state.trend>0?rates[i].high>=state.trail:
                                                                  rates[i].low<=state.trail)))
        {
         state.have_trail=true;
         state.trail=state.trend>0?rates[i].high:rates[i].low;
         state.trail_time=rates[i].time;
        }
     }
   return true;
  }

// Replays structure on any timeframe without drawing it.
bool AnalyseStructure(const ENUM_TIMEFRAMES timeframe,const int wanted,const double size,
                      BASE_STRUCTURE_STATE &state,MqlRates &rates[],
                      BASE_STRUCTURE_POINT &points[],BASE_STRUCTURE_EVENT &events[])
  {
   ArraySetAsSeries(rates,false);
   int total=CopyRates(_Symbol,timeframe,1,wanted,rates);
   return total>0 && ReplayStructure(rates,total,size,state,points,events);
  }

// The trend direction: 1 Bullish, -1 Bearish, 0 Range.
int BiasDirection(const BASE_STRUCTURE_STATE &state)
  {
   return state.trend;
  }

// Trend quality: the efficiency of the last `candles` closes (Kaufman): the
// net move divided by the distance travelled close to close, from 0 (pure
// chop) to 1 (a straight line), with the net move's direction.  On generated
// markets with known trends, requiring 0.30 over 30 candles in the trend's
// direction made Market Tradability right more often, and earlier, than
// Base's progressive-swing, internal-structure and Hurst requirements (see
// the README).
bool TrendQuality(const MqlRates &rates[],const int total,const int candles,double &value,int &direction)
  {
   value=0.0;
   direction=0;
   if(candles<1 || total<=candles) return false;
   double path=0.0;
   for(int i=total-candles;i<total;i++) path+=MathAbs(rates[i].close-rates[i-1].close);
   double net=rates[total-1].close-rates[total-1-candles].close;
   value=path>0.0?MathAbs(net)/path:0.0;
   direction=net>0.0?1:net<0.0?-1:0;
   return true;
  }
string BiasText(const BASE_STRUCTURE_STATE &state)
  {
   if(state.trend>0) return "Bullish";
   if(state.trend<0) return "Bearish";
   return "Range";
  }

string PriceText(const double price)
  {
   return DoubleToString(price,_Digits);
  }

string BreakText(const BASE_STRUCTURE_EVENT &event)
  {
   return (event.direction>0?"bull ":"bear ")+(event.ls?"LS":event.bos?"BOS":"CHoCH");
  }

// A swing's label: HH/LH/LL/HL, or EQH/EQL when it is within the EQH/EQL
// threshold of the previous swing on its side.
string LabelText(const BASE_STRUCTURE_POINT &point)
  {
   if(Show_Equal_Highs_Lows && point.equal>=0) return point.side>0?"EQH":"EQL";
   if(point.side>0) return point.kind>0?"HH":"LH";
   return point.kind>0?"LL":"HL";
  }

string TrendWord(const int direction)
  {
   return direction>0?"bullish":"bearish";
  }

string HTFName() { return TimeframeName(BASETimeframe()); }
string MTFName() { return TimeframeName(SetupTimeframe()); }
string LTFName() { return TimeframeName(LTFTimeframe()); }

// What to do on one timeframe's trend: one action and the levels that
// decide it.
string RecommendationText(const BASE_STRUCTURE_STATE &state)
  {
   if(state.trend!=0)
     {
      bool up=state.trend>0;
      string text=up?"Look for buys on pullbacks while price holds above the protected low "+PriceText(state.protected_level):
                     "Look for sells on pullbacks while price holds below the protected high "+PriceText(state.protected_level);
      if(state.have_target)
         text+="; a close "+(up?"above the weak high ":"below the weak low ")+PriceText(state.target)+
               " continues the trend";
      return text+".";
     }
   if(!state.have_range_high && !state.have_range_low)
      return "Stand aside until the first swings form and price closes beyond one.";
   string text="Stand aside";
   if(state.have_range_high && state.have_range_low)
      text+=" or trade only the range edges ("+PriceText(state.range_low)+" to "+PriceText(state.range_high)+")";
   if(state.have_range_high)
      text+="; a close above "+PriceText(state.range_high)+(state.prev_trend>0?" resumes the uptrend":" starts an uptrend");
   if(state.have_range_low)
      text+="; a close below "+PriceText(state.range_low)+(state.prev_trend<0?" resumes the downtrend":" starts a downtrend");
   if(!state.have_range_low)
      text+="; a downtrend needs a swing low first, then a close below it";
   if(!state.have_range_high)
      text+="; an uptrend needs a swing high first, then a close above it";
   return text+".";
  }

// The dashboard's recommendation: the HTF's, unless the HTF trend is held
// back by a selected lower timeframe or by Market Tradability, which it then
// names.
string TradeRecommendation(const BASE_STRUCTURE_STATE &htf,const BASE_STRUCTURE_STATE &mtf,
                           const BASE_STRUCTURE_STATE &ltf,const BASE_TRADABILITY tradability)
  {
   int direction=htf.trend;
   if(tradability!=BASE_TRADABLE && direction!=0)
     {
      string action=direction>0?"buying":"selling";
      string lead=HTFName()+" is "+TrendWord(direction)+", but wait for ";
      if(Use_MTF && mtf.trend!=direction)
         return lead+MTFName()+" to turn "+TrendWord(direction)+" before "+action+".";
      if(Use_LTF && ltf.trend!=direction)
         return lead+LTFName()+" to turn "+TrendWord(direction)+" before "+action+".";
      return lead+"Market Tradability (see Tradability Reason) before "+action+".";
     }
   return RecommendationText(htf);
  }

// The internal structure's dashboard output: its trend and latest break.
string InternalTrendText(const BASE_STRUCTURE_STATE &internal,const BASE_STRUCTURE_EVENT &events[])
  {
   int last=ArraySize(events)-1;
   if(last<0) return BiasText(internal);
   return BiasText(internal)+" ("+(events[last].ls?"LS":events[last].bos?"BOS":"CHoCH")+")";
  }

// How the internal structure relates to the timeframe's Market Trend.
string InternalAgreementText(const BASE_STRUCTURE_STATE &internal,const BASE_STRUCTURE_STATE &state,
                             const string name)
  {
   if(state.trend==0)
      return "The "+name+" Market Trend is a range; the internal structure is "+
             (internal.trend==0?"a range too.":TrendWord(internal.trend)+".");
   if(internal.trend==state.trend) return "Agrees with the "+name+" Market Trend.";
   if(internal.trend==0)
      return "A range inside the "+TrendWord(state.trend)+" "+name+" trend (a pause while the protected level holds).";
   return "Opposes the "+name+" Market Trend: a "+TrendWord(internal.trend)+" move inside the "+
          TrendWord(state.trend)+" trend (a pullback while the protected level holds).";
  }

string InternalStructureTooltip(const BASE_STRUCTURE_STATE &internal,const BASE_STRUCTURE_EVENT &events[],
                                const BASE_STRUCTURE_STATE &state,const string name,const double size)
  {
   string text="Internal structure ("+DoubleToString(InternalSize(size),2)+" ATR swings, "+
               DoubleToString(Internal_Swing_Ratio,2)+" of the "+name+" swing size)\nInternal trend: "+
               BiasText(internal);
   int last=ArraySize(events)-1;
   if(last>=0) text+=" since a "+BreakText(events[last])+" through "+PriceText(events[last].level);
   return text+"\n"+InternalAgreementText(internal,state,name);
  }

// Strong/Weak High/Low of a timeframe: in a trend the protected level is
// Strong and the trend's running extreme since its BOS Weak; a range has its
// high and low.
string StrongWeakText(const BASE_STRUCTURE_STATE &state)
  {
   if(state.trend>0)
      return "Strong Low "+PriceText(state.protected_level)+
             (state.have_trail?" | Weak High "+PriceText(state.trail):"");
   if(state.trend<0)
      return "Strong High "+PriceText(state.protected_level)+
             (state.have_trail?" | Weak Low "+PriceText(state.trail):"");
   string high=state.have_range_high?"Range High "+PriceText(state.range_high):"no range high yet";
   string low=state.have_range_low?"Range Low "+PriceText(state.range_low):"no range low yet";
   return high+" | "+low;
  }

// Why a timeframe reads its trend: the break that set it.
string TrendWhyText(const BASE_STRUCTURE_STATE &state,const BASE_STRUCTURE_EVENT &events[])
  {
   int last=ArraySize(events)-1;
   if(state.trend!=0 && last>=0)
      return "a "+TrendWord(state.trend)+" BOS through "+PriceText(events[last].level)+"; the protected "+
             (state.trend>0?"low ":"high ")+PriceText(state.protected_level)+" holds";
   if(state.prev_trend!=0 && last>=0)
      return "the "+TrendWord(state.prev_trend)+" trend's protected "+(state.prev_trend>0?"low ":"high ")+
             PriceText(events[last].level)+" broke (a "+TrendWord(-state.prev_trend)+" CHoCH)";
   return "no trend yet: a close beyond the first swings sets it";
  }

// The latest swing on each side: "HH 1.2345 | HL 1.2300".
string LatestSwingsText(const BASE_STRUCTURE_STATE &state)
  {
   string high=!state.have_high?"no swing high yet":
               (state.last_high_kind==0?"first high ":state.last_high_kind>0?"HH ":"LH ")+PriceText(state.last_high);
   string low=!state.have_low?"no swing low yet":
              (state.last_low_kind==0?"first low ":state.last_low_kind>0?"LL ":"HL ")+PriceText(state.last_low);
   return high+" | "+low;
  }

// The trend breakdown, joined for a tooltip.
string BreakdownText(const BASE_STRUCTURE_STATE &state,const BASE_STRUCTURE_EVENT &events[])
  {
   return "Current Trend: "+BiasText(state)+
          "\nWhy: "+TrendWhyText(state,events)+
          "\nLatest Swings: "+LatestSwingsText(state)+
          "\nStrong/Weak: "+StrongWeakText(state)+
          "\nTrade Recommendations: "+RecommendationText(state);
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

// Why a timeframe has no trend: a range, and how it came about.
string RangeText(const string name,const BASE_STRUCTURE_STATE &state)
  {
   if(state.prev_trend==0) return name+" has no trend yet (no close beyond its first swings).";
   return name+" is in a range: its "+TrendWord(state.prev_trend)+" trend's protected "+
          (state.prev_trend>0?"low":"high")+" broke (a "+TrendWord(-state.prev_trend)+" CHoCH).";
  }

// "H4", "H4 and M15": timeframes joined for a sentence.
string JoinNames(const string &names[],const int count)
  {
   string result="";
   for(int i=0;i<count;i++)
      result+=(i==0?"":(i==count-1?" and ":", "))+names[i];
   return result;
  }

// The latest two swings on each side of a timeframe, for the progressive
// structure Market Tradability can require: the latest swing high and the
// one before it, and the same for lows.
struct BASE_SWINGS
  {
   bool have_highs;
   double high;             // the latest swing high
   double prev_high;        // the swing high before it
   bool have_lows;
   double low;
   double prev_low;
  };

bool LastTwoSwings(const BASE_STRUCTURE_POINT &points[],const int side,double &current,double &previous)
  {
   int found=0;
   for(int k=ArraySize(points)-1;k>=0 && found<2;k--)
     {
      if(points[k].side!=side) continue;
      if(found==0) current=points[k].price;
      else previous=points[k].price;
      found++;
     }
   return found==2;
  }

void ReadSwings(const BASE_STRUCTURE_POINT &points[],BASE_SWINGS &swings)
  {
   ZeroMemory(swings);
   swings.have_highs=LastTwoSwings(points,1,swings.high,swings.prev_high);
   swings.have_lows=LastTwoSwings(points,-1,swings.low,swings.prev_low);
  }

// "HH", "LH" or "EQH" for highs; "LL", "HL" or "EQL" for lows.
string SwingTag(const int side,const double current,const double previous)
  {
   if(side>0) return current>previous?"HH":current<previous?"LH":"EQH";
   return current<previous?"LL":current>previous?"HL":"EQL";
  }

// 1 for a bullish progression (an HH and an HL), -1 for a bearish one (an LL
// and an LH), 0 otherwise.
int SwingProgression(const BASE_SWINGS &swings)
  {
   if(!swings.have_highs || !swings.have_lows) return 0;
   if(swings.high>swings.prev_high && swings.low>swings.prev_low) return 1;
   if(swings.low<swings.prev_low && swings.high<swings.prev_high) return -1;
   return 0;
  }

// "HH + HL", or what is missing.
string SwingStructureText(const BASE_SWINGS &swings)
  {
   return (swings.have_highs?SwingTag(1,swings.high,swings.prev_high):"no two swing highs yet")+" + "+
          (swings.have_lows?SwingTag(-1,swings.low,swings.prev_low):"no two swing lows yet");
  }

// The structure of a timeframe for a direction: "" when it is progressive
// (an HH and an HL for bullish, an LL and an LH for bearish), else what is
// missing.
string SwingProblem(const BASE_SWINGS &swings,const int direction,const string name)
  {
   if(!swings.have_highs || !swings.have_lows)
      return "the "+name+" has no two swing "+(!swings.have_highs?"highs":"lows")+" yet";
   if(SwingProgression(swings)==direction) return "";
   return "the "+name+" swings are "+SwingStructureText(swings)+" ("+TrendWord(direction)+" needs "+
          (direction>0?"HH + HL":"LL + LH")+")";
  }

// --------------------------------------------------------- Hurst exponent
// The Hurst exponent H of the last Hurst_Candles closed candles of the Hurst
// timeframe (the HTF by default), as in the 83% Strategy: a random walk
// gives about 0.5, a trending (persistent) market more, a mean-reverting one
// less.
const int HURST_MIN_LAG=2;
const int HURST_MAX_LAG=20;

struct BASE_HURST
  {
   bool have;
   double value;            // H
   int candles;             // closed candles available for it
  };

ENUM_TIMEFRAMES HurstTimeframe()
  {
   if(Hurst_Timeframe==BASE_HURST_MTF) return SetupTimeframe();
   if(Hurst_Timeframe==BASE_HURST_LTF) return LTFTimeframe();
   return BASETimeframe();
  }

string HurstName() { return TimeframeName(HurstTimeframe()); }

// The lagged-difference method (the generalized Hurst exponent with q = 2):
// x = ln(close) of n closes (oldest first); for each lag tau from
// HURST_MIN_LAG to HURST_MAX_LAG, sigma(tau) is the root mean square of
// x[t+tau] - x[t] over the window; H is the least-squares slope of
// ln sigma(tau) against ln tau.  The drift is not subtracted, so a steady
// trend raises H as momentum does (with the standard deviation instead, a
// steady trend read about 0.41, like a random walk).  False when a close is
// not positive or the prices do not move.  Base.pine computes it in the same
// order.
bool HurstOf(const double &close[],const int n,double &h)
  {
   h=0.0;
   if(n<=HURST_MAX_LAG) return false;
   double x[];
   ArrayResize(x,n);
   for(int i=0;i<n;i++)
     {
      if(close[i]<=0.0) return false;
      x[i]=MathLog(close[i]);
     }
   int lags=HURST_MAX_LAG-HURST_MIN_LAG+1;
   double lt[],ls[];
   ArrayResize(lt,lags);
   ArrayResize(ls,lags);
   for(int k=0;k<lags;k++)
     {
      int tau=HURST_MIN_LAG+k;
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

void ReadHurst(BASE_HURST &hurst)
  {
   ZeroMemory(hurst);
   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   int got=CopyRates(_Symbol,HurstTimeframe(),1,Hurst_Candles,rates);
   hurst.candles=MathMax(got,0);
   if(got!=Hurst_Candles) return;
   double close[];
   ArrayResize(close,got);
   for(int i=0;i<got;i++) close[i]=rates[i].close;
   hurst.have=HurstOf(close,got,hurst.value);
  }

// About 0.5 is a random walk; above it a trending (persistent) market, below
// it a mean-reverting one.  "trending" is above Hurst_Minimum, so the reading
// agrees with Market Tradability.
string HurstWord(const double h)
  {
   return h>Hurst_Minimum?"trending":h>=0.45?"random walk":"mean-reverting";
  }

// The Hurst exponent: "" when it is above Hurst_Minimum, else why not.
string HurstProblem(const BASE_HURST &hurst)
  {
   if(!hurst.have)
      return hurst.candles<Hurst_Candles?
             "the Hurst exponent needs "+(string)Hurst_Candles+" closed "+HurstName()+" candles ("+
             (string)hurst.candles+" so far)":"the Hurst exponent is not available (the "+HurstName()+" closes do not move)";
   if(hurst.value>Hurst_Minimum) return "";
   return "the Hurst exponent "+DoubleToString(hurst.value,2)+" is not above "+DoubleToString(Hurst_Minimum,2)+
          " ("+HurstWord(hurst.value)+")";
  }

// The HTF internal structure for a direction: "" when it is in that
// direction, else what it is.
string InternalProblem(const BASE_STRUCTURE_STATE &internal,const int direction,const string name)
  {
   if(internal.trend==direction) return "";
   return "the "+name+" internal structure is "+(internal.trend==0?"a range":TrendWord(internal.trend))+
          ", not "+TrendWord(direction);
  }

// "a; b; c" for the reasons.
string JoinProblems(const string &problems[],const int count)
  {
   string result="";
   for(int i=0;i<count;i++) result+=(i==0?"":"; ")+problems[i];
   return result;
  }

// Trend Quality on the dashboard: "0.42 up".
string QualityText(const bool have,const double value,const int direction)
  {
   if(!have) return "Not available";
   return DoubleToString(value,2)+(direction>0?" up":direction<0?" down":" flat");
  }

// The HTF trend quality for a direction: "" when it is at least
// Trend_Quality_Minimum and its net move is in that direction, else why not.
string QualityProblem(const bool have,const double value,const int quality_direction,const int direction)
  {
   if(!have)
      return "the "+HTFName()+" trend quality needs "+(string)(Trend_Quality_Candles+1)+" closed candles";
   if(quality_direction!=direction)
      return "the last "+(string)Trend_Quality_Candles+" "+HTFName()+" candles moved against the trend";
   if(value<Trend_Quality_Minimum)
      return "the "+HTFName()+" trend quality "+DoubleToString(value,2)+" is below "+
             DoubleToString(Trend_Quality_Minimum,2)+" (too choppy)";
   return "";
  }

// Market Tradability:
//  * Tradable: the HTF trend and the trend of every selected trend timeframe
//    are all Bullish (or all Bearish), and the HTF trend quality (see
//    TrendQuality) is at least Trend_Quality_Minimum (0.30), its net move in
//    the trend's direction.  Optionally, also (all off by default):
//    progressive swings, HH + HL (LL + LH), on each of them
//    (Require_Progressive_Swings); the HTF internal structure in the trend's
//    direction (Require_Internal_Agreement); the Hurst exponent above
//    Hurst_Minimum (Use_Hurst_Filter).
//  * Not Tradable otherwise.
// The reason names the timeframes and every condition that fails.
BASE_TRADABILITY EvaluateTradability(const BASE_STRUCTURE_STATE &htf,const BASE_STRUCTURE_STATE &mtf,
                                     const BASE_STRUCTURE_STATE &ltf,const BASE_STRUCTURE_STATE &htf_internal,
                                     const BASE_SWINGS &htf_swings,const BASE_SWINGS &mtf_swings,
                                     const BASE_SWINGS &ltf_swings,const bool have_quality,
                                     const double quality,const int quality_direction,
                                     const BASE_HURST &hurst,string &reason)
  {
   int d=htf.trend;
   int selected=(Use_HTF?1:0)+(Use_MTF?1:0)+(Use_LTF?1:0);
   // The HTF and the selected timeframes, for the reasons.
   int named=selected+(Use_HTF?0:1);
   string names=Use_HTF?TrendTimeframesText():HTFName()+(selected==1?" and ":", ")+TrendTimeframesText();
   if(d==0)
     {
      reason=RangeText(HTFName(),htf);
      return BASE_NOT_TRADABLE;
     }
   if(Use_MTF && mtf.trend!=d)
     {
      reason=mtf.trend==0?RangeText(MTFName(),mtf):
             HTFName()+" is "+TrendWord(d)+" but "+MTFName()+" is "+TrendWord(mtf.trend)+".";
      return BASE_NOT_TRADABLE;
     }
   if(Use_LTF && ltf.trend!=d)
     {
      reason=ltf.trend==0?RangeText(LTFName(),ltf):
             HTFName()+" is "+TrendWord(d)+" but "+LTFName()+" is "+TrendWord(ltf.trend)+".";
      return BASE_NOT_TRADABLE;
     }
   string checks[6];
   checks[0]=QualityProblem(have_quality,quality,quality_direction,d);
   checks[1]=Require_Progressive_Swings?SwingProblem(htf_swings,d,HTFName()):"";
   checks[2]=Require_Progressive_Swings && Use_MTF?SwingProblem(mtf_swings,d,MTFName()):"";
   checks[3]=Require_Progressive_Swings && Use_LTF?SwingProblem(ltf_swings,d,LTFName()):"";
   checks[4]=Require_Internal_Agreement?InternalProblem(htf_internal,d,HTFName()):"";
   checks[5]=Use_Hurst_Filter?HurstProblem(hurst):"";
   string problems[6];
   int count=0;
   for(int k=0;k<6;k++)
      if(checks[k]!="") problems[count++]=checks[k];
   string lead=names+(named==1?" is ":named==2?" are both ":" are all ")+TrendWord(d);
   if(count==0)
     {
      reason=lead+" and the "+HTFName()+" trend quality "+DoubleToString(quality,2)+" is at least "+
             DoubleToString(Trend_Quality_Minimum,2);
      if(Require_Progressive_Swings) reason+=", with "+(d>0?"HH + HL":"LL + LH");
      if(Require_Internal_Agreement) reason+=", the "+HTFName()+" internal structure agrees";
      if(Use_Hurst_Filter) reason+=", the Hurst exponent "+DoubleToString(hurst.value,2)+" is above "+
                                   DoubleToString(Hurst_Minimum,2);
      reason+=".";
      return BASE_TRADABLE;
     }
   reason=lead+", but "+JoinProblems(problems,count)+".";
   return BASE_NOT_TRADABLE;
  }

// Healthy Extension blocks only an overextended market.  In the HTF trend
// direction, the extension is how far the latest LTF close is beyond the
// latest MTF swing on the other side (the swing low in a bullish trend, the
// swing high in a bearish one), in MTF ATR (14 candles); more than
// Maximum_Extension_ATR (10) is overextended.  With no trend direction or no
// MTF swing yet, or price back beyond that swing, the market is not
// overextended.  On real data (an index H1/M15/M5, EURUSD D1/H4/H1, five
// stocks MN/W1/D1) the 6% of Tradable candles beyond 10 MTF ATR were
// followed by a pullback of 1 ATR before a 1 ATR move on 56% of the time
// (48% for the rest), and price was 0.9 ATR lower after 50 candles.  The
// v2.40 rule (0 to 3 LTF ATR from an LTF HL/LH) blocked 83% of Tradable
// candles without those blocked doing any worse.
// Returns EMPTY_VALUE when there is nothing to measure.
double TrendExtension(const BASE_STRUCTURE_STATE &htf,const BASE_STRUCTURE_STATE &mtf,
                      const double close,const double mtf_atr)
  {
   int direction=BiasDirection(htf);
   if(direction==0 || mtf_atr<=0.0) return EMPTY_VALUE;
   if(direction>0 && mtf.have_low) return (close-mtf.last_low)/mtf_atr;
   if(direction<0 && mtf.have_high) return (mtf.last_high-close)/mtf_atr;
   return EMPTY_VALUE;
  }

bool HealthyExtension(const double extension)
  {
   return extension==EMPTY_VALUE || extension<=Maximum_Extension_ATR;
  }

// "4.2 H1 ATR" for the dashboard; empty when nothing was measured.
string ExtensionText(const double extension)
  {
   return extension==EMPTY_VALUE?"":DoubleToString(extension,1)+" "+MTFName()+" ATR";
  }

// Optimal Conditions: every enabled requirement must pass.  Returns the
// result and the reason listing each failed requirement.
bool EvaluateOptimal(const bool bias_ready,const bool healthy_extension,
                     const bool good_volume,const double volume_ratio,
                     const bool good_momentum,const double momentum_ratio,string &reason,
                     const double extension=EMPTY_VALUE)
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
      reason+=(reason==""?"":"; ")+"price is overextended"+
              (extension==EMPTY_VALUE?"":" ("+ExtensionText(extension)+" beyond the latest "+MTFName()+" swing)");
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
// the HH/HL/LH/LL/EQH/EQL labels (the first swing on each side has none), a
// dotted line joining each equal high or low to the swing it equals, every
// BOS/CHoCH/LS whose swing is drawn, and the dotted latest swing high and
// low.
void DrawStructure(const MqlRates &rates[],const int total,const int first,
                   const BASE_STRUCTURE_STATE &state,const BASE_STRUCTURE_POINT &points[],
                   const BASE_STRUCTURE_EVENT &events[])
  {
   int point_count=ArraySize(points);
   for(int i=0;i<point_count;i++)
     {
      if(points[i].kind==0 || points[i].pivot<first) continue;
      DrawStructurePoint(StructureLabel(points[i]),points[i].side,points[i].time,points[i].price);
      int equal=points[i].equal;
      if(Show_Swing_Points && Show_Equal_Highs_Lows && equal>=0 && points[equal].pivot>=first)
         DrawSegment("EQUAL_"+(string)points[i].time,points[equal].time,points[equal].price,
                     points[i].time,points[i].price,points[i].side>0?clrIndianRed:clrTeal,STYLE_DOT,1);
     }
   // A break is drawn only with its swing, so every BOS, CHoCH and LS starts
   // from a drawn candle.
   int event_count=ArraySize(events);
   for(int i=0;i<event_count;i++)
      if(events[i].swing_bar>=first)
        {
         int end=FirstTouchBar(rates,events[i].swing_bar,events[i].bar,events[i].direction,events[i].level);
         int middle=(int)MathRound(0.5*(events[i].swing_bar+end));
         DrawSignal(events[i].ls?"LS":(events[i].bos?"BOS":"CHoCH"),events[i].direction,
                    events[i].swing_time,events[i].level,rates[events[i].bar].time,
                    rates[end].time,rates[middle].time);
        }
   if(Show_Swing_Points && state.have_high)
      DrawSegment("LAST_HIGH",state.last_high_time,state.last_high,rates[total-1].time,
                  state.last_high,clrIndianRed,STYLE_DOT,1);
   if(Show_Swing_Points && state.have_low)
      DrawSegment("LAST_LOW",state.last_low_time,state.last_low,rates[total-1].time,
                  state.last_low,clrTeal,STYLE_DOT,1);
  }

// A caption faded towards the chart background (internal captions are drawn
// at 70% strength).
color FadeColor(const color clr,const double amount)
  {
   color background=(color)ChartGetInteger(0,CHART_COLOR_BACKGROUND);
   int r=(int)MathRound((clr&0xFF)*(1.0-amount)+(background&0xFF)*amount);
   int g=(int)MathRound(((clr>>8)&0xFF)*(1.0-amount)+((background>>8)&0xFF)*amount);
   int b=(int)MathRound(((clr>>16)&0xFF)*(1.0-amount)+((background>>16)&0xFF)*amount);
   return (color)((b<<16)|(g<<8)|r);
  }

// The internal structure's BOS/CHoCH/LS: a dashed width-1 line from the
// broken internal swing to the first candle touching its level and a faded
// caption centred on it, above a line broken upwards and below one broken
// downwards.  A swing that is also a main swing is skipped, since the main
// structure draws that level.  A break is drawn when its closing candle is
// in the drawn window.
void DrawInternalBreaks(const MqlRates &rates[],const BASE_STRUCTURE_EVENT &breaks[],
                        const BASE_STRUCTURE_POINT &points[],const datetime first_time)
  {
   if(!Show_Internal_Structure) return;
   int count=ArraySize(points);
   for(int i=0;i<ArraySize(breaks);i++)
     {
      if(rates[breaks[i].bar].time<first_time) continue;
      bool swing=false;
      for(int k=count-1;k>=0 && !swing;k--)
         if(points[k].side==breaks[i].direction && points[k].time==breaks[i].swing_time) swing=true;
      if(swing) continue;
      color clr=breaks[i].direction>0?Internal_Bullish_Color:Internal_Bearish_Color;
      int end=FirstTouchBar(rates,breaks[i].swing_bar,breaks[i].bar,breaks[i].direction,breaks[i].level);
      int middle=(int)MathRound(0.5*(breaks[i].swing_bar+end));
      string key="INTERNAL_"+(breaks[i].direction>0?"BULL_":"BEAR_")+(string)rates[breaks[i].bar].time;
      DrawSegment(key+"_SEGMENT",breaks[i].swing_time,breaks[i].level,rates[end].time,
                  breaks[i].level,clr,STYLE_DASH,1);
      DrawText(key,rates[middle].time,breaks[i].level,breaks[i].ls?"LS":breaks[i].bos?"BOS":"CHoCH",
               FadeColor(clr,0.3),breaks[i].direction<0,(int)Label_Size);
     }
  }

// Strong/Weak High/Low: dashed lines to 20 candles right of the latest
// closed candle with their names just right of the line ends.  In a bullish
// trend the protected low is the Strong Low and the running high since the
// BOS the Weak High (bearish mirrors this); a range shows its Range High and
// Range Low.
void DrawStrongWeak(const BASE_STRUCTURE_STATE &state,const datetime last_time,
                    const ENUM_TIMEFRAMES timeframe)
  {
   if(!Show_Strong_Weak_High_Low) return;
   datetime right=last_time+20*PeriodSeconds(timeframe);
   bool have_high=false,have_low=false;
   double high=0.0,low=0.0;
   datetime high_time=0,low_time=0;
   string high_name="",low_name="";
   if(state.trend>0)
     {
      have_low=state.have_protected;
      low=state.protected_level;
      low_time=state.protected_time;
      low_name="Strong Low";
      have_high=state.have_trail;
      high=state.trail;
      high_time=state.trail_time;
      high_name="Weak High";
     }
   else if(state.trend<0)
     {
      have_high=state.have_protected;
      high=state.protected_level;
      high_time=state.protected_time;
      high_name="Strong High";
      have_low=state.have_trail;
      low=state.trail;
      low_time=state.trail_time;
      low_name="Weak Low";
     }
   else
     {
      have_high=state.have_range_high;
      high=state.range_high;
      high_time=state.range_high_time;
      high_name="Range High";
      have_low=state.have_range_low;
      low=state.range_low;
      low_time=state.range_low_time;
      low_name="Range Low";
     }
   if(have_high)
     {
      DrawSegment("STRONG_WEAK_HIGH",high_time,high,right,high,clrIndianRed,STYLE_DASH,1);
      DrawTextAnchored("STRONG_WEAK_HIGH_TEXT",right,high,high_name,clrIndianRed,ANCHOR_LEFT,(int)Label_Size);
     }
   if(have_low)
     {
      DrawSegment("STRONG_WEAK_LOW",low_time,low,right,low,clrTeal,STYLE_DASH,1);
      DrawTextAnchored("STRONG_WEAK_LOW_TEXT",right,low,low_name,clrTeal,ANCHOR_LEFT,(int)Label_Size);
     }
  }

// One chart replay drawn: its structure, its internal structure (the same
// engine with the internal swing size) and its Strong/Weak High/Low.
void DrawChart(const MqlRates &rates[],const int total,const int first,const BASE_STRUCTURE_STATE &state,
               const BASE_STRUCTURE_POINT &points[],const BASE_STRUCTURE_EVENT &events[],
               const double internal_size,const ENUM_TIMEFRAMES timeframe)
  {
   DrawStructure(rates,total,first,state,points,events);
   if(Show_Internal_Structure)
     {
      BASE_STRUCTURE_STATE internal;
      BASE_STRUCTURE_POINT internal_points[];
      BASE_STRUCTURE_EVENT breaks[];
      if(ReplayStructure(rates,total,internal_size,internal,internal_points,breaks))
         DrawInternalBreaks(rates,breaks,points,rates[first].time);
     }
   DrawStrongWeak(state,rates[total-1].time,timeframe);
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
// outputs are coloured.  Trends are green (Bullish), red (Bearish) or grey
// (Range); tradability and conditions are green when they pass and red when
// they do not.  There is no background or border.
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

// The swing structure under a timeframe's Market Trend, indented: the latest
// swing high against the previous one and the same for lows; green for an HH
// and an HL, red for an LL and an LH.
void AddSwingStructureRow(BASE_DASHBOARD_ROW &rows[],const BASE_SWINGS &swings)
  {
   int progression=SwingProgression(swings);
   string tip="Latest swing high "+(swings.have_highs?PriceText(swings.high)+" vs previous "+PriceText(swings.prev_high):"-")+
              "; latest swing low "+(swings.have_lows?PriceText(swings.low)+" vs previous "+PriceText(swings.prev_low):"-")+
              "\nMarket Tradability needs HH + HL (bullish) or LL + LH (bearish).";
   AddDashboardRow(rows,"Swing Structure:",SwingStructureText(swings),
                   progression>0?DASHBOARD_POSITIVE_COLOR:progression<0?DASHBOARD_NEGATIVE_COLOR:DASHBOARD_NEUTRAL_COLOR,
                   tip,true,DASHBOARD_INDENT);
  }

// The internal structure under its timeframe's Market Trend, indented; the
// tooltip gives its latest break and how it relates to the Market Trend.
void AddInternalStructureRow(BASE_DASHBOARD_ROW &rows[],const BASE_STRUCTURE_STATE &internal,
                             const BASE_STRUCTURE_EVENT &internal_events[],
                             const BASE_STRUCTURE_STATE &state,const string name,const double size)
  {
   if(!Show_Internal_On_Dashboard) return;
   AddDashboardRow(rows,"Internal Structure:",InternalTrendText(internal,internal_events),TrendColor(internal),
                   InternalStructureTooltip(internal,internal_events,state,name,size),true,DASHBOARD_INDENT);
  }

// Each selected timeframe's Market Trend (its breakdown is the tooltip) with
// its swing and internal structure, the HTF Trend Quality, the Hurst
// exponent when it is required, Market Tradability (the entry filters are
// its tooltip), the reason, the HTF trade recommendation, and, when any is
// selected, Optimal Conditions with each selected condition (the reason is
// the tooltip).
void DrawDashboard(const BASE_STRUCTURE_STATE &htf,const string htf_breakdown,
                   const string recommendation,const BASE_STRUCTURE_STATE &mtf,
                   const string mtf_breakdown,const BASE_STRUCTURE_STATE &ltf,
                   const string ltf_breakdown,const BASE_STRUCTURE_STATE &htf_internal,
                   const BASE_STRUCTURE_EVENT &htf_internal_events[],const BASE_STRUCTURE_STATE &mtf_internal,
                   const BASE_STRUCTURE_EVENT &mtf_internal_events[],const BASE_STRUCTURE_STATE &ltf_internal,
                   const BASE_STRUCTURE_EVENT &ltf_internal_events[],
                   const BASE_SWINGS &htf_swings,const BASE_SWINGS &mtf_swings,const BASE_SWINGS &ltf_swings,
                   const bool have_quality,const double quality,const int quality_direction,
                   const BASE_HURST &hurst,const BASE_TRADABILITY tradability,
                   const string tradability_reason,const string filter_tooltip,
                   const bool optimal,const string optimal_reason,const bool correlated,
                   const bool healthy_extension,const double extension,const bool good_volume,const double volume_ratio,
                   const bool good_momentum,const double momentum_ratio)
  {
   Comment("");
   BASE_DASHBOARD_ROW rows[];
   if(Use_HTF)
     {
      AddDashboardRow(rows,"HTF Market Trend ("+HTFName()+"):",BiasText(htf),TrendColor(htf),
                      htf_breakdown);
      AddSwingStructureRow(rows,htf_swings);
      AddInternalStructureRow(rows,htf_internal,htf_internal_events,htf,HTFName(),HTFSwingSize());
     }
   if(Use_MTF)
     {
      AddDashboardRow(rows,"MTF Market Trend ("+MTFName()+"):",BiasText(mtf),TrendColor(mtf),
                      mtf_breakdown);
      AddSwingStructureRow(rows,mtf_swings);
      AddInternalStructureRow(rows,mtf_internal,mtf_internal_events,mtf,MTFName(),MTFSwingSize());
     }
   if(Use_LTF)
     {
      AddDashboardRow(rows,"LTF Market Trend ("+LTFName()+"):",BiasText(ltf),TrendColor(ltf),
                      ltf_breakdown);
      AddSwingStructureRow(rows,ltf_swings);
      AddInternalStructureRow(rows,ltf_internal,ltf_internal_events,ltf,LTFName(),LTFSwingSize());
     }
   AddDashboardRow(rows,"Trend Quality ("+HTFName()+"):",QualityText(have_quality,quality,quality_direction),
                   !have_quality || htf.trend==0?DASHBOARD_NEUTRAL_COLOR:
                   PassColor(quality>=Trend_Quality_Minimum && quality_direction==htf.trend),
                   "Efficiency of the last "+(string)Trend_Quality_Candles+" closed "+HTFName()+
                   " candles: the net move divided by the distance travelled close to close, from 0 (chop) to 1 "+
                   "(a straight line), and its direction. Market Tradability needs at least "+
                   DoubleToString(Trend_Quality_Minimum,2)+" in the trend's direction.");
   if(Use_Hurst_Filter)
      AddDashboardRow(rows,"Hurst Exponent ("+HurstName()+"):",
                      hurst.have?"H "+DoubleToString(hurst.value,2)+" ("+HurstWord(hurst.value)+")":"Not available",
                      hurst.have?PassColor(hurst.value>Hurst_Minimum):DASHBOARD_NEUTRAL_COLOR,
                      "The last "+(string)Hurst_Candles+" closed "+HurstName()+" candles. Market Tradability needs H above "+
                      DoubleToString(Hurst_Minimum,2)+"; about 0.5 is a random walk, above it a trending market, below it a "+
                      "mean-reverting one.");
   AddDashboardRow(rows,"Market Tradability:",tradability==BASE_TRADABLE?"Tradable":"Not Tradable",
                   PassColor(tradability==BASE_TRADABLE),filter_tooltip);
   AddWrappedDashboardRow(rows,"Tradability Reason:",tradability_reason,DASHBOARD_TEXT_COLOR);
   AddWrappedDashboardRow(rows,"Trade Recommendations:",recommendation,DASHBOARD_TEXT_COLOR);
   // Optimal Conditions only when at least one requirement is selected (none
   // by default).
   if(!Use_Timeframe_Correlation_For_Optimal && !Use_Healthy_Extension_For_Optimal &&
      !Use_Market_Volume_For_Optimal && !Use_Price_Momentum_For_Optimal)
     {
      DrawDashboardRows(rows);
      return;
     }
   AddDashboardRow(rows,"","",DASHBOARD_TEXT_COLOR);
   AddDashboardRow(rows,"Optimal Conditions:",optimal?"OPTIMAL":"NOT OPTIMAL",PassColor(optimal),
                   optimal_reason);
   if(Use_Timeframe_Correlation_For_Optimal)
      AddDashboardRow(rows,"Timeframe Correlation:",PassText(correlated),PassColor(correlated),
                      optimal_reason,true,DASHBOARD_INDENT);
   if(Use_Healthy_Extension_For_Optimal)
      AddDashboardRow(rows,"Healthy Extension:",PassText(healthy_extension)+
                      (extension==EMPTY_VALUE?"":" ("+ExtensionText(extension)+")"),
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
   double size=HTFSwingSize();
   int displayed=StructureBars();
   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   int total=CopyRates(_Symbol,timeframe,1,ReplayBars(displayed),rates);
   if(total<SWING_ATR_LENGTH+2) return false;

   // Only the MA line needs history; the filters use the latest closed bar.
   double ma[],adx[],atr[];
   if(Use_HTF_MA_Filter && !CopyIndicator(g_htf_ma_handle,0,Show_HTF_MA_Line?total:1,ma)) return false;
   if(Use_ADX_Filter && !CopyIndicator(g_adx_handle,0,1,adx)) return false;
   if(Use_ATR_Filter && !CopyIndicator(g_atr_handle,0,1,atr)) return false;

   // The MTF and LTF trends are replayed over the same elapsed time as the
   // structure timeframe (plus the same warm-up), so every trend has
   // comparable context instead of a few hours of lower-timeframe candles.
   BASE_STRUCTURE_STATE setup_state,ltf_state;
   MqlRates setup_rates[],ltf_rates[];
   BASE_STRUCTURE_POINT setup_points[],ltf_points[];
   BASE_STRUCTURE_EVENT setup_events[],ltf_events[];
   if(!AnalyseStructure(SetupTimeframe(),ReplayBars(ChartStructureBars(SetupTimeframe())),
                        MTFSwingSize(),setup_state,setup_rates,setup_points,setup_events))
      return false;
   if(!AnalyseStructure(LTFTimeframe(),ReplayBars(ChartStructureBars(LTFTimeframe())),
                        LTFSwingSize(),ltf_state,ltf_rates,ltf_points,ltf_events))
      return false;
   int ltf_total=ArraySize(ltf_rates);

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
   ReplayStructure(rates,total,size,structure_state,points,events);

   // The internal structure of each trend timeframe (the same engine with the
   // internal swing size), for the dashboard and, when required, Market
   // Tradability.
   BASE_STRUCTURE_STATE htf_internal,mtf_internal,ltf_internal;
   BASE_STRUCTURE_POINT unused[];
   BASE_STRUCTURE_EVENT htf_internal_events[],mtf_internal_events[],ltf_internal_events[];
   ReplayStructure(rates,total,InternalSize(size),htf_internal,unused,htf_internal_events);
   ReplayStructure(setup_rates,ArraySize(setup_rates),InternalSize(MTFSwingSize()),mtf_internal,unused,
                   mtf_internal_events);
   ReplayStructure(ltf_rates,ltf_total,InternalSize(LTFSwingSize()),ltf_internal,unused,ltf_internal_events);

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

   ObjectsDeleteAll(0,g_prefix);
   if(anchored)
      DrawChart(rates,total,MathMax(0,total-displayed),structure_state,points,events,
                InternalSize(size),timeframe);
   else
     {
      BASE_STRUCTURE_STATE chart_state;
      BASE_STRUCTURE_POINT chart_points[];
      BASE_STRUCTURE_EVENT chart_events[];
      double chart_size=ChartSwingSize(chart_timeframe);
      if(ReplayStructure(chart_rates,chart_total,chart_size,chart_state,chart_points,chart_events))
         DrawChart(chart_rates,chart_total,MathMax(0,chart_total-ChartStructureBars(chart_timeframe)),
                   chart_state,chart_points,chart_events,InternalSize(chart_size),chart_timeframe);
     }
   DrawAverageLines(rates,total,displayed,ma,mtf_rates,mtf_ma,mtf_count);

   // The latest two swings on each side of each trend timeframe, the HTF
   // trend quality and the Hurst exponent, for Market Tradability.
   BASE_SWINGS htf_swings,mtf_swings,ltf_swings;
   ReadSwings(points,htf_swings);
   ReadSwings(setup_points,mtf_swings);
   ReadSwings(ltf_points,ltf_swings);
   double quality=0.0;
   int quality_direction=0;
   bool have_quality=TrendQuality(rates,total,Trend_Quality_Candles,quality,quality_direction);
   BASE_HURST hurst;
   ZeroMemory(hurst);
   if(Use_Hurst_Filter) ReadHurst(hurst);
   string tradability_reason="";
   BASE_TRADABILITY tradability=EvaluateTradability(structure_state,setup_state,ltf_state,htf_internal,
                                                    htf_swings,mtf_swings,ltf_swings,have_quality,quality,
                                                    quality_direction,hurst,tradability_reason);
   // The timeframes correlate whenever the market is Tradable: every selected
   // timeframe then agrees on the direction.
   bool bias_ready=tradability==BASE_TRADABLE;
   double setup_atr[];
   int setup_total=ArraySize(setup_rates);
   SwingATR(setup_rates,setup_total,setup_atr);
   double extension=TrendExtension(structure_state,setup_state,ltf_rates[ltf_total-1].close,
                                   setup_total>0?setup_atr[setup_total-1]:0.0);
   bool healthy_extension=HealthyExtension(extension);

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
                                good_momentum,momentum_ratio,optimal_reason,extension);

   DrawDashboard(structure_state,BreakdownText(structure_state,events),
                 TradeRecommendation(structure_state,setup_state,ltf_state,tradability),
                 setup_state,BreakdownText(setup_state,setup_events),
                 ltf_state,BreakdownText(ltf_state,ltf_events),
                 htf_internal,htf_internal_events,mtf_internal,mtf_internal_events,ltf_internal,ltf_internal_events,
                 htf_swings,mtf_swings,ltf_swings,have_quality,quality,quality_direction,hurst,
                 tradability,tradability_reason,EntryFilterTooltip(rates[total-1],ma,adx,atr),
                 optimal,optimal_reason,bias_ready,healthy_extension,extension,good_volume,volume_ratio,
                 good_momentum,momentum_ratio);
   // Alert every break that became known on the newest closed candle; an LS
   // (the old trend resuming after a CHoCH) comes first, then the BOS that
   // resumed it.
   string signal="";
   for(int i=ArraySize(events)-1;i>=0 && events[i].bar==total-1;i--)
      signal=(events[i].bos?"BOS ":"CHoCH ")+(events[i].direction>0?"bullish":"bearish")+
             (signal==""?"":" + ")+signal;
   for(int i=ArraySize(events)-1;i>=0;i--)
      if(events[i].ls && events[i].ls_bar==total-1)
        {
         signal="LS (the "+(events[i].direction>0?"bullish":"bearish")+" CHoCH failed)"+
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
      problem="each Swing Size must be between "+(string)MIN_DETECTION_LEVEL+" and "+
              (string)MAX_DETECTION_LEVEL;
   else if(Internal_Swing_Ratio<0.2 || Internal_Swing_Ratio>0.9)
      problem="the Internal Swing Size must be between 0.2 and 0.9 of the swing size";
   else if(Trend_Quality_Candles<5 || Trend_Quality_Candles>200)
      problem="the Trend Quality Window must be 5 to 200 candles";
   else if(Trend_Quality_Minimum<0.0 || Trend_Quality_Minimum>=1.0)
      problem="the Trend Quality minimum must be 0 to below 1";
   else if(Bars_To_Process<100)
      problem="Bars_To_Process must be at least 100";
   else if(HTF_MA_Length<1 || MTF_MA_Length<1 || ADX_Length<1 || ATR_Length<1)
      problem="HTF MA, MTF MA, ADX and ATR lengths must be positive";
   else if(Equal_Highs_Lows_Threshold<0.0 || Equal_Highs_Lows_Threshold>0.5)
      problem="the EQH/EQL Threshold must be between 0 and 0.5";
   else if(Hurst_Candles<50 || Hurst_Candles>400)
      problem="Hurst_Candles must be 50 to 400";
   else if(Hurst_Minimum<0.0 || Hurst_Minimum>=1.0)
      problem="Hurst_Minimum must be 0 to below 1";
   else if(!Use_HTF && !Use_MTF && !Use_LTF)
      problem="enable at least one trend analysis timeframe";
   if(problem=="") return true;
   Print("BASE 2.0: invalid input - ",problem,".");
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
   g_prefix="BASE2_"+(string)ChartID()+"_";
   if(Use_HTF_MA_Filter && (g_htf_ma_handle=iMA(_Symbol,timeframe,HTF_MA_Length,0,BASEMAMethod(HTF_MA_Type),PRICE_CLOSE))==INVALID_HANDLE) return INIT_FAILED;
   if(Use_MTF_MA_Filter && (g_mtf_ma_handle=iMA(_Symbol,SetupTimeframe(),MTF_MA_Length,0,BASEMAMethod(MTF_MA_Type),PRICE_CLOSE))==INVALID_HANDLE) return INIT_FAILED;
   if(Use_ADX_Filter && (g_adx_handle=iADX(_Symbol,timeframe,ADX_Length))==INVALID_HANDLE) return INIT_FAILED;
   if(Use_ATR_Filter && (g_atr_handle=iATR(_Symbol,timeframe,ATR_Length))==INVALID_HANDLE) return INIT_FAILED;
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
   g_htf_ma_handle=INVALID_HANDLE;
   g_mtf_ma_handle=INVALID_HANDLE;
   g_adx_handle=INVALID_HANDLE;
   g_atr_handle=INVALID_HANDLE;
   ObjectsDeleteAll(0,g_prefix);
   Comment("");
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
