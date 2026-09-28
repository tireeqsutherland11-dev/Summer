#property copyright "Market Trend Analyser conversion"
#property version   "2.00"
#property strict
#property description "BASE: MT5 port of the Market Trend Analyser Pine Script."
#property description "Signal/visualisation EA only; the source indicator contains no trading rules."

enum BASE_MA_TYPE { BASE_SMA=0, BASE_EMA=1 };
enum BASE_MA_FILTER_MODE { BASE_PRICE_ABOVE_BELOW=0, BASE_FULL_BODY_CLOSE=1 };
enum BASE_SESSION { BASE_NEW_YORK=0, BASE_LONDON=1, BASE_TOKYO=2, BASE_SYDNEY=3, BASE_CUSTOM=4, BASE_24X7=5 };
enum BASE_ADX_SCOPE { BASE_BOS_ONLY=0, BASE_BOS_AND_CHOCH=1 };
enum BASE_ATR_MODE { BASE_ATR_MINIMUM=0, BASE_ATR_MAXIMUM=1, BASE_ATR_RANGE=2 };
enum BASE_LABEL_SIZE { BASE_TINY=7, BASE_SMALL=9, BASE_NORMAL=11, BASE_LARGE=14 };

input group "Timeframe Inputs"
input ENUM_TIMEFRAMES Structure_Timeframe=PERIOD_H1; // HTF
input ENUM_TIMEFRAMES Setup_Entry_Timeframe=PERIOD_M15; // MTF
input ENUM_TIMEFRAMES LTF_Timeframe=PERIOD_M5;

input group "Tradeability Timeframes"
input bool Use_HTF_For_Tradeability=true;
input bool Use_MTF_For_Tradeability=false;
input bool Use_LTF_For_Tradeability=false;

input group "Structure Processing"
input int Bars_To_Process=100;

input group "Swing Detection"
input int Swing_Detection_Length=5;
input bool Show_Swing_Points=true;

input group "BOS Display"
input bool Show_BOS_Labels=true;
input color Bullish_BOS_Color=clrBlue;
input color Bearish_BOS_Color=clrBlue;

input group "CHoCH Display"
input bool Show_CHoCH_Labels=true;
input color Bullish_CHoCH_Color=clrRed;
input color Bearish_CHoCH_Color=clrRed;

input group "Labels and Lines"
input BASE_LABEL_SIZE Label_Size=BASE_SMALL;
input bool Show_Structure_Lines=true;
input ENUM_LINE_STYLE Line_Style=STYLE_DASH;
input int Line_Width=1;

input group "MA Filter (LTF)"
input bool Use_MA_Filter=true;
input int MA_Length=50;
input BASE_MA_TYPE MA_Type=BASE_EMA;
input bool Show_MA_Line=false;
input color MA_Color=clrBlue;

input group "MA Filter (HTF)"
input bool Use_HTF_MA_Filter=true;
input ENUM_TIMEFRAMES HTF_Timeframe=PERIOD_H1;
input int HTF_MA_Length=100;
input BASE_MA_TYPE HTF_MA_Type=BASE_EMA; // MA Type
input bool Show_HTF_MA_Line=false;
input color HTF_MA_Color=clrOrange;

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
const BASE_MA_FILTER_MODE MA_Filter_Mode=BASE_PRICE_ABOVE_BELOW;
const BASE_MA_FILTER_MODE HTF_MA_Filter_Mode=BASE_PRICE_ABOVE_BELOW;
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

string g_prefix="";
datetime g_last_ltf_bar=0;
datetime g_last_structure_bar=0;
datetime g_last_setup_bar=0;
int g_ma_handle=INVALID_HANDLE;
int g_htf_ma_handle=INVALID_HANDLE;
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

int SwingLength()
  {
   return MathMax(1,MathMin(50,Swing_Detection_Length));
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
   return MathMax(2*SwingLength()+2,MathMin(wanted,100000));
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
// against when deciding HH/LH or LL/HL.
bool AcceptStructureHigh(const double value,bool &have_high,double &last_high,
                         int &last_side,bool &have_reference,double &reference,
                         int &kind)
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
                        int &last_side,bool &have_reference,double &reference,
                        int &kind)
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
   state.direction=direction;
   state.last_break_was_bos=bos;
  }

int LowestBar(const MqlRates &rates[],const int from,const int to)
  {
   int best=MathMax(0,from);
   for(int i=best+1;i<=to;i++)
      if(rates[i].low<rates[best].low) best=i;
   return best;
  }

int HighestBar(const MqlRates &rates[],const int from,const int to)
  {
   int best=MathMax(0,from);
   for(int i=best+1;i<=to;i++)
      if(rates[i].high>rates[best].high) best=i;
   return best;
  }

// One swing level that a candle close can break.  `point` is the swing's
// index in the structure points, so the level is dropped when that swing is
// superseded by a more extreme pivot of the same leg.
struct BASE_LEVEL
  {
   bool active;
   double price;
   datetime time;
   int point;
  };

// A CHoCH whose LH (bullish) or HL (bearish) has been broken and which waits
// for the swings that confirm it: an HH then an HL (bullish), or an LL then
// an LH (bearish), after the broken swing.
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

void DropLevel(BASE_LEVEL &level,const int point)
  {
   if(level.active && level.point==point) level.active=false;
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

// The swings after the broken LH (HL) have reached an HH (LL) and nothing
// has formed after it yet: the CHoCH waits for its HL (LH).
bool CHoCHExtreme(const BASE_CHOCH_CANDIDATE &choch,const BASE_STRUCTURE_POINT &points[],
                  const int high_point,const int low_point)
  {
   int extreme=choch.direction>0?high_point:low_point;
   int opposite=choch.direction>0?low_point:high_point;
   return extreme>choch.level_point && points[extreme].kind>0 && opposite<extreme;
  }

// The swings after the broken LH read HH then HL (bullish), or after the
// broken HL read LL then LH (bearish).
bool CHoCHComplete(const BASE_CHOCH_CANDIDATE &choch,const BASE_STRUCTURE_POINT &points[],
                   const int high_point,const int low_point)
  {
   int extreme=choch.direction>0?high_point:low_point;
   int opposite=choch.direction>0?low_point:high_point;
   return extreme>choch.level_point && points[extreme].kind>0 && opposite>extreme &&
          points[opposite].kind<0;
  }

void ConfirmCHoCH(BASE_STRUCTURE_EVENT &events[],BASE_STRUCTURE_STATE &state,
                  const int bar,BASE_CHOCH_CANDIDATE &choch)
  {
   AddStructureEvent(events,state,bar,choch.break_bar,choch.direction,false,
                     choch.level_time,choch.level);
   choch.direction=0;
  }

// Replays confirmed swings and close-confirmed breaks over closed candles.
// Market bias, chart labels and BOS/CHoCH drawings all come from this single
// routine, so they can never disagree about structure.
//
// Swings: a pivot (see PivotHigh) accepted by the alternating-leg rules and
// labelled HH/LH or LL/HL against the previous leg's extreme.
//
// Only a candle close through a swing is a break; a wick is a liquidity
// sweep.  The label of the broken swing decides the event:
//  * BOS (bullish): the most recent HH is broken, creating a new HH.
//  * BOS (bearish): the most recent LL is broken, creating a new LL.
//  * CHoCH (becoming bullish): while the trend is not already bullish, the
//    most recent LH is broken and the swings after it read HH then HL.  The
//    CHoCH is confirmed when both have happened: normally by that HL, or by
//    the breaking close itself when a wick through the LH already made the
//    HH and the HL followed.  If price
//    instead closes above the new HH first, and the pullback since the
//    break held above the previous low, that close confirms the CHoCH and is
//    also the first BOS.  An LH or LL formed after the break cancels it;
//    swings printed before the breaking close never do.
//  * CHoCH (becoming bearish): the mirror image; the most recent HL is
//    broken, then an LL and an LH form.
//  * A broken LH in a bullish trend (or HL in a bearish trend) is a pullback
//    inside that trend and prints nothing.
// Trend/bias: bullish after a bullish BOS, bullish transitional after a
// bullish CHoCH until the next bullish BOS; bearish mirrors this.
bool ReplayStructure(const MqlRates &rates[],const int total,const int length,
                     BASE_STRUCTURE_STATE &state,BASE_STRUCTURE_POINT &points[],
                     BASE_STRUCTURE_EVENT &events[])
  {
   ZeroMemory(state);
   ArrayResize(points,0);
   ArrayResize(events,0);
   if(total<2*length+2) return false;
   int last_side=0;
   bool have_high_reference=false,have_low_reference=false;
   double high_reference=0.0,low_reference=0.0;
   int high_point=-1,low_point=-1;
   // The most recent unbroken HH, LH, LL and HL, plus the LH and HL they
   // replaced: if a higher high in the same leg turns the newest LH into an
   // HH, the LH before it is the most recent LH again (lows mirror this).
   BASE_LEVEL hh,lh,ll,hl,previous_lh,previous_hl;
   ZeroMemory(hh);
   ZeroMemory(lh);
   ZeroMemory(ll);
   ZeroMemory(hl);
   ZeroMemory(previous_lh);
   ZeroMemory(previous_hl);
   BASE_CHOCH_CANDIDATE choch;
   ZeroMemory(choch);
   for(int i=length;i<total;i++)
     {
      int pivot=i-length;
      if(PivotHigh(rates,total,pivot,length))
        {
         int kind=0;
         bool same_leg=last_side==1;
         if(AcceptStructureHigh(rates[pivot].high,state.have_high,state.last_high,last_side,
                                have_high_reference,high_reference,kind))
           {
            int replaced=same_leg?high_point:-1;
            bool unbroken_lh_replaced=replaced>=0 && lh.active && lh.point==replaced;
            if(replaced>=0)
              {
               points[high_point].superseded=true;
               DropLevel(hh,high_point);
               DropLevel(lh,high_point);
              }
            high_point=AddStructurePoint(points,pivot,i,rates[pivot],1,kind);
            state.last_high_kind=kind;
            state.last_high_time=rates[pivot].time;
            if(kind>0) SetLevel(hh,points,high_point);
            if(kind<0)
              {
               if(replaced<0) previous_lh=lh;
               SetLevel(lh,points,high_point);
              }
            else if(unbroken_lh_replaced) lh=previous_lh;
            // A higher LH in the same leg replaces the broken one on the
            // chart; it is the LH to break now.
            if(choch.direction>0 && kind<0 && replaced>=0 && replaced==choch.level_point)
               choch.direction=0;
            // Only swings formed after the breaking close can cancel a
            // CHoCH; the LH that completes HL -> LL -> LH confirms it.
            else if(choch.direction>0 && kind<0 && pivot>choch.break_bar)
               CancelCHoCH(choch,lh,hl,high_point,low_point);   // the break made only an LH
            else if(choch.direction<0 && kind>0 && pivot>choch.break_bar)
               CancelCHoCH(choch,lh,hl,high_point,low_point);   // an HH, not an LH
            else if(choch.direction<0 && CHoCHComplete(choch,points,high_point,low_point))
               ConfirmCHoCH(events,state,i,choch);             // HL broken, LL, then LH
           }
        }
      if(PivotLow(rates,total,pivot,length))
        {
         int kind=0;
         bool same_leg=last_side==-1;
         if(AcceptStructureLow(rates[pivot].low,state.have_low,state.last_low,last_side,
                               have_low_reference,low_reference,kind))
           {
            int replaced=same_leg?low_point:-1;
            bool unbroken_hl_replaced=replaced>=0 && hl.active && hl.point==replaced;
            if(replaced>=0)
              {
               points[low_point].superseded=true;
               DropLevel(ll,low_point);
               DropLevel(hl,low_point);
              }
            low_point=AddStructurePoint(points,pivot,i,rates[pivot],-1,kind);
            state.last_low_kind=kind;
            state.last_low_time=rates[pivot].time;
            if(kind>0) SetLevel(ll,points,low_point);
            if(kind<0)
              {
               if(replaced<0) previous_hl=hl;
               SetLevel(hl,points,low_point);
              }
            else if(unbroken_hl_replaced) hl=previous_hl;
            if(choch.direction<0 && kind<0 && replaced>=0 && replaced==choch.level_point)
               choch.direction=0;
            else if(choch.direction<0 && kind<0 && pivot>choch.break_bar)
               CancelCHoCH(choch,lh,hl,high_point,low_point);   // the break made only an HL
            else if(choch.direction>0 && kind>0 && pivot>choch.break_bar)
               CancelCHoCH(choch,lh,hl,high_point,low_point);   // an LL, not an HL
            else if(choch.direction>0 && CHoCHComplete(choch,points,high_point,low_point))
               ConfirmCHoCH(events,state,i,choch);             // LH broken, HH, then HL
           }
        }

      double close=rates[i].close;
      // Price closes above the HH of a bullish CHoCH before its HL is
      // confirmed.  If the pullback from that HH held above the previous low
      // it was the HL, so the CHoCH is confirmed and this close is the first
      // BOS; otherwise it is only the BOS of an HH.
      if(choch.direction>0 && hh.active && hh.point==high_point && close>hh.price &&
         CHoCHExtreme(choch,points,high_point,low_point))
        {
         int lowest=LowestBar(rates,points[high_point].pivot+1,i);
         if(rates[lowest].low>=state.last_low) ConfirmCHoCH(events,state,i,choch);
         choch.direction=0;
         AddStructureEvent(events,state,i,i,1,true,hh.time,hh.price);
         hh.active=false;
        }
      if(choch.direction<0 && ll.active && ll.point==low_point && close<ll.price &&
         CHoCHExtreme(choch,points,high_point,low_point))
        {
         int highest=HighestBar(rates,points[low_point].pivot+1,i);
         if(rates[highest].high<=state.last_high) ConfirmCHoCH(events,state,i,choch);
         choch.direction=0;
         AddStructureEvent(events,state,i,i,-1,true,ll.time,ll.price);
         ll.active=false;
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
            // A wick may already have made the HH and HL.
            if(CHoCHComplete(choch,points,high_point,low_point)) ConfirmCHoCH(events,state,i,choch);
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
            if(CHoCHComplete(choch,points,high_point,low_point)) ConfirmCHoCH(events,state,i,choch);
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
   return true;
  }

// Replays structure on any timeframe without drawing it.  This keeps the
// structure, setup and LTF biases independent of each other.
bool AnalyseStructure(const ENUM_TIMEFRAMES timeframe,const int wanted,
                      BASE_STRUCTURE_STATE &state,MqlRates &rates[])
  {
   ArraySetAsSeries(rates,false);
   int total=CopyRates(_Symbol,timeframe,1,wanted,rates);
   BASE_STRUCTURE_POINT points[];
   BASE_STRUCTURE_EVENT events[];
   return total>0 && ReplayStructure(rates,total,SwingLength(),state,points,events);
  }

bool DefiniteBias(const BASE_STRUCTURE_STATE &state)
  {
   // A trend is established once its latest break is a BOS.  A CHoCH starts
   // a transition that the next BOS completes; pullback swings that break
   // nothing cannot put an established trend back into transition.
   return state.direction!=0 && state.last_break_was_bos;
  }

string BiasText(const BASE_STRUCTURE_STATE &state)
  {
   if(state.direction==0) return "Consolidating";
   bool definite=DefiniteBias(state);
   if(state.direction>0) return definite?"Bullish":"Bullish (Transition)";
   return definite?"Bearish":"Bearish (Transition)";
  }

string TradeabilityTimeframesText()
  {
   string result="";
   if(Use_HTF_For_Tradeability) result="HTF";
   if(Use_MTF_For_Tradeability) result+=(result==""?"":" and ")+"MTF";
   if(Use_LTF_For_Tradeability) result+=(result==""?"":" and ")+"LTF";
   return result;
  }

// Market Tradeability: the HTF bias must be established (latest break a
// BOS); every enabled tradeability timeframe must have a direction and they
// must all agree; an enabled LTF must itself be established.  The MTF may be
// transitional.  Returns the result and the reason shown on the dashboard.
bool EvaluateTradeability(const BASE_STRUCTURE_STATE &htf,const BASE_STRUCTURE_STATE &mtf,
                          const BASE_STRUCTURE_STATE &ltf,string &reason)
  {
   bool htf_definite=DefiniteBias(htf);
   bool ltf_definite=DefiniteBias(ltf);
   bool available=(!Use_HTF_For_Tradeability || htf.direction!=0) &&
                  (!Use_MTF_For_Tradeability || mtf.direction!=0) &&
                  (!Use_LTF_For_Tradeability || ltf.direction!=0);
   bool match=(!Use_HTF_For_Tradeability || !Use_MTF_For_Tradeability ||
               htf.direction==mtf.direction) &&
              (!Use_HTF_For_Tradeability || !Use_LTF_For_Tradeability ||
               htf.direction==ltf.direction) &&
              (!Use_MTF_For_Tradeability || !Use_LTF_For_Tradeability ||
               mtf.direction==ltf.direction);
   bool tradeable=htf_definite && available && match && (!Use_LTF_For_Tradeability || ltf_definite);
   if(tradeable)
     {
      int selected=(Use_HTF_For_Tradeability?1:0)+(Use_MTF_For_Tradeability?1:0)+
                   (Use_LTF_For_Tradeability?1:0);
      reason=TradeabilityTimeframesText()+(selected>1?" correlate":" is directional")+
             "; HTF is confirmed by HH/LL BOS";
      if(Use_LTF_For_Tradeability) reason+="; LTF is confirmed by BOS";
     }
   else if(htf.direction==0) reason="HTF is consolidating";
   else if(!htf_definite) reason="HTF bias is transitional (CHoCH has no subsequent BOS)";
   else if(Use_MTF_For_Tradeability && mtf.direction==0) reason="MTF is consolidating";
   else if(Use_LTF_For_Tradeability && ltf.direction==0) reason="LTF is consolidating";
   else if(!match) reason=TradeabilityTimeframesText()+" biases conflict";
   else reason="LTF bias is transitional (CHoCH has no subsequent BOS)";
   return tradeable;
  }

// Healthy Extension: measured in the HTF bias direction (the trading
// direction) from the newest corrective LTF swing, which must be an HL for a
// bullish bias or an LH for a bearish bias, to the latest LTF close.
bool HealthyExtension(const BASE_STRUCTURE_STATE &htf,const BASE_STRUCTURE_STATE &ltf,
                      const double close,const double atr)
  {
   if(atr==EMPTY_VALUE || atr<=0.0) return false;
   double extension=-1.0;
   if(htf.direction>0 && ltf.have_low && ltf.last_low_kind<0)
      extension=(close-ltf.last_low)/atr;
   else if(htf.direction<0 && ltf.have_high && ltf.last_high_kind<0)
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
      reason=TradeabilityTimeframesText()+
             " tradeability biases do not meet the selected correlation requirements";
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

bool HTFValues(const datetime time,double &ma,double &open,double &close)
  {
   int shift=iBarShift(_Symbol,HTF_Timeframe,time,false);
   // Pine's request.security(..., lookahead_off) exposes the containing HTF
   // candle only when that candle has closed. Earlier child bars use the
   // preceding completed HTF candle, avoiding historical future leakage.
   datetime htf_open_time=shift>=0?iTime(_Symbol,HTF_Timeframe,shift):0;
   int ltf_seconds=PeriodSeconds(BASETimeframe());
   int htf_seconds=PeriodSeconds(HTF_Timeframe);
   if(shift>=0 && ltf_seconds>0 && htf_seconds>0 &&
      time+ltf_seconds<htf_open_time+htf_seconds)
      shift++;
   double value[1];
   if(shift<0 || CopyBuffer(g_htf_ma_handle,0,shift,1,value)!=1) return false;
   ma=value[0];
   open=iOpen(_Symbol,HTF_Timeframe,shift);
   close=iClose(_Symbol,HTF_Timeframe,shift);
   return open!=0.0 && close!=0.0;
  }

string PassText(const bool pass)
  {
   return pass?"PASS":"BLOCKED";
  }

// Qualifies the latest closed structure candle with the MA, HTF MA, session,
// ADX and ATR filters.  The filters never gate structure, bias or alerts;
// the result is shown as the tooltip of the dashboard's tradeability row.
string EntryFilterTooltip(const MqlRates &bar,const double &ma[],const double &adx[],
                          const double &atr[])
  {
   bool ma_long=true,ma_short=true;
   string ma_text="off";
   if(Use_MA_Filter)
     {
      double value=ma[ArraySize(ma)-1];
      ma_long=MA_Filter_Mode==BASE_PRICE_ABOVE_BELOW?bar.close>value
              :bar.close>value && bar.open>value && bar.close>bar.open;
      ma_short=MA_Filter_Mode==BASE_PRICE_ABOVE_BELOW?bar.close<value
               :bar.close<value && bar.open<value && bar.close<bar.open;
      ma_text=ma_long?"long":(ma_short?"short":"neutral");
     }
   bool htf_long=!Use_HTF_MA_Filter,htf_short=!Use_HTF_MA_Filter;
   string htf_text="off";
   double htf_ma=0.0,htf_open=0.0,htf_close=0.0;
   if(Use_HTF_MA_Filter)
     {
      htf_text="unavailable";
      if(HTFValues(bar.time,htf_ma,htf_open,htf_close))
        {
         htf_long=HTF_MA_Filter_Mode==BASE_PRICE_ABOVE_BELOW?bar.close>htf_ma
                  :htf_close>htf_ma && htf_open>htf_ma && htf_close>htf_open;
         htf_short=HTF_MA_Filter_Mode==BASE_PRICE_ABOVE_BELOW?bar.close<htf_ma
                   :htf_close<htf_ma && htf_open<htf_ma && htf_close<htf_open;
         htf_text=htf_long?"long":(htf_short?"short":"neutral");
        }
     }
   bool session=InSession(bar.time);
   bool adx_pass=!Use_ADX_Filter || (adx[0]!=EMPTY_VALUE && adx[0]>=ADX_Minimum);
   bool atr_pass=!Use_ATR_Filter || (atr[0]!=EMPTY_VALUE &&
                 (ATR_Filter_Mode==BASE_ATR_MINIMUM?atr[0]>=ATR_Minimum:
                  ATR_Filter_Mode==BASE_ATR_MAXIMUM?atr[0]<=ATR_Maximum:
                  atr[0]>=ATR_Minimum && atr[0]<=ATR_Maximum));
   bool long_direction=ma_long && htf_long && session;
   bool short_direction=ma_short && htf_short && session;
   bool choch_adx=!Use_ADX_Filter || Apply_ADX_Filter_To==BASE_BOS_ONLY || adx_pass;
   string text="Entry filters, latest closed "+TimeframeName(BASETimeframe())+" candle";
   text+="\nBOS: long "+PassText(long_direction && adx_pass && atr_pass)+
         ", short "+PassText(short_direction && adx_pass && atr_pass);
   text+="\nCHoCH: long "+PassText(long_direction && choch_adx && atr_pass)+
         ", short "+PassText(short_direction && choch_adx && atr_pass);
   text+="\nMA "+ma_text+" | HTF MA "+htf_text+" | Session "+
         (Use_Session_Filter?(session?"in":"out"):"off");
   text+="\nADX "+(Use_ADX_Filter?DoubleToString(adx[0],1)+" "+PassText(adx_pass):"off")+
         " | ATR "+(Use_ATR_Filter?DoubleToString(atr[0],_Digits)+" "+PassText(atr_pass):"off");
   return text;
  }

void DrawText(const string id,const datetime time,const double price,const string text,
              const color clr,const bool below,const int font_size)
  {
   string name=g_prefix+id;
   if(ObjectFind(0,name)>=0 || !ObjectCreate(0,name,OBJ_TEXT,0,time,price)) return;
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,font_size);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,below?ANCHOR_UPPER:ANCHOR_LOWER);
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

void DrawSignal(const string kind,const int direction,const datetime swing_time,
                const double level,const MqlRates &bar)
  {
   bool bos=kind=="BOS";
   if((bos && !Show_BOS_Labels) || (!bos && !Show_CHoCH_Labels)) return;
   color clr=direction>0?(bos?Bullish_BOS_Color:Bullish_CHoCH_Color)
                         :(bos?Bearish_BOS_Color:Bearish_CHoCH_Color);
   string key=kind+(direction>0?"_UP_":"_DOWN_")+(string)bar.time;
   // Keep the caption on the broken level.  ANCHOR_UPPER places bullish text
   // immediately below it; ANCHOR_LOWER places bearish text immediately above.
   DrawText(key,bar.time,level,kind,clr,direction>0,(int)Label_Size);
   if(Show_Structure_Lines)
      DrawSegment(key+"_LINE",swing_time,level,bar.time,level,
                  bos?clrBlue:clrRed,Line_Style,Line_Width);
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
   DrawText("STRUCTURE_"+kind+"_"+(string)time,time,price,kind,clr,low,(int)Label_Size);
  }

// Draws one replay from candle `first` onwards (earlier candles are warm-up):
// HH/HL/LH/LL labels (superseded and untyped points are skipped), BOS/CHoCH
// signals and the dotted current swing levels.  A CHoCH may be confirmed
// several candles after its break; it is drawn on the candle that actually
// closed through the level.
void DrawStructure(const MqlRates &rates[],const int total,const int first,
                   const BASE_STRUCTURE_STATE &state,const BASE_STRUCTURE_POINT &points[],
                   const BASE_STRUCTURE_EVENT &events[])
  {
   int point_count=ArraySize(points);
   for(int i=0;i<point_count;i++)
      if(!points[i].superseded && points[i].kind!=0 && points[i].pivot>=first)
         DrawStructurePoint(StructureLabel(points[i]),points[i].time,points[i].price);
   int event_count=ArraySize(events);
   for(int i=0;i<event_count;i++)
      if(events[i].break_bar>=first)
         DrawSignal(events[i].bos?"BOS":"CHoCH",events[i].direction,events[i].swing_time,
                    events[i].level,rates[events[i].break_bar]);
   if(Show_Swing_Points && state.have_high)
      DrawSegment("LAST_HIGH",state.last_high_time,state.last_high,rates[total-1].time,
                  state.last_high,clrIndianRed,STYLE_DOT,1);
   if(Show_Swing_Points && state.have_low)
      DrawSegment("LAST_LOW",state.last_low_time,state.last_low,rates[total-1].time,
                  state.last_low,clrTeal,STYLE_DOT,1);
  }

void DrawAverageLines(const MqlRates &rates[],const int total,const int displayed,
                      const double &ma[])
  {
   int first=MathMax(1,total-MathMin(500,displayed));
   if(Show_MA_Line && Use_MA_Filter && ArraySize(ma)==total)
      for(int i=first;i<total;i++)
         DrawSegment("MA_"+(string)rates[i].time,rates[i-1].time,ma[i-1],rates[i].time,ma[i],
                     MA_Color,STYLE_SOLID,2);
   if(Show_HTF_MA_Line && Use_HTF_MA_Filter)
     {
      double previous=0.0,open=0.0,close=0.0;
      bool have_previous=HTFValues(rates[first-1].time,previous,open,close);
      for(int i=first;i<total;i++)
        {
         double value=0.0;
         bool have=HTFValues(rates[i].time,value,open,close);
         if(have && have_previous)
            DrawSegment("HTF_MA_"+(string)rates[i].time,rates[i-1].time,previous,rates[i].time,
                        value,HTF_MA_Color,STYLE_SOLID,2);
         previous=value;
         have_previous=have;
        }
     }
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

void DrawDashboardLine(const int row,const string value,const string tooltip="")
  {
   string name=g_prefix+"DASHBOARD_"+(string)row;
   if(!ObjectCreate(0,name,OBJ_LABEL,0,0,0)) return;
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,10);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,10+row*18);
   color foreground=(color)ChartGetInteger(0,CHART_COLOR_FOREGROUND);
   ObjectSetInteger(0,name,OBJPROP_COLOR,foreground);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial Bold");
   ObjectSetString(0,name,OBJPROP_TEXT,value);
   // "\n" suppresses MT5's default tooltip, which would show the object name.
   ObjectSetString(0,name,OBJPROP_TOOLTIP,tooltip==""?"\n":tooltip);
  }

void DrawDashboard(const string structure_bias,const string setup_bias,const string ltf_bias,
                   const bool bias_ready,const bool tradeable,const string tradeability_reason,
                   const string filter_tooltip,const bool optimal,const bool healthy_extension,
                   const bool good_volume,const double volume_ratio,
                   const bool good_momentum,const double momentum_ratio,
                   const string optimal_reason)
  {
   Comment("");
   int row=0;
   if(Use_HTF_For_Tradeability)
      DrawDashboardLine(row++,"Market Bias (HTF/Structure): "+structure_bias);
   if(Use_MTF_For_Tradeability)
      DrawDashboardLine(row++,"Market Bias (MTF/Setup): "+setup_bias);
   if(Use_LTF_For_Tradeability)
      DrawDashboardLine(row++,"Market Bias (LTF): "+ltf_bias);
   DrawDashboardLine(row++,"Market Tradeability: "+(tradeable?"Tradable":"Not Tradable"),
                     filter_tooltip);
   DrawDashboardLine(row++,"Tradeability Reason: "+tradeability_reason);
   row++;
   DrawDashboardLine(row++,"Optimal Conditions: "+(optimal?"OPTIMAL":"NOT OPTIMAL"));
   if(Use_Timeframe_Correlation_For_Optimal)
      DrawDashboardLine(row++,"Timeframe Correlation: "+PassText(bias_ready));
   if(Use_Healthy_Extension_For_Optimal)
      DrawDashboardLine(row++,"Healthy Extension: "+PassText(healthy_extension));
   if(Use_Market_Volume_For_Optimal)
      DrawDashboardLine(row++,"Market Volume: "+PassText(good_volume)+
                              " ("+DoubleToString(volume_ratio,2)+"x average)");
   if(Use_Price_Momentum_For_Optimal)
      DrawDashboardLine(row++,"Price Momentum: "+PassText(good_momentum)+
                               " ("+DoubleToString(momentum_ratio,2)+"x average range)");
   DrawDashboardLine(row,"Reason: "+optimal_reason);
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
   int length=SwingLength();
   int displayed=StructureBars();
   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   int total=CopyRates(_Symbol,timeframe,1,ReplayBars(displayed),rates);
   if(total<2*length+2) return false;

   // Only the MA line needs history; the filters use the latest closed bar.
   double ma[],adx[],atr[];
   if(Use_MA_Filter && !CopyIndicator(g_ma_handle,0,Show_MA_Line?total:1,ma)) return false;
   if(Use_ADX_Filter && !CopyIndicator(g_adx_handle,0,1,adx)) return false;
   if(Use_ATR_Filter && !CopyIndicator(g_atr_handle,0,1,atr)) return false;

   // The MTF and LTF biases are replayed over the same elapsed time as the
   // structure timeframe (plus the same warm-up), so every bias has comparable
   // context instead of a few hours of lower-timeframe candles.
   BASE_STRUCTURE_STATE setup_state,ltf_state;
   MqlRates setup_rates[],ltf_rates[];
   if(!AnalyseStructure(SetupTimeframe(),ReplayBars(ChartStructureBars(SetupTimeframe())),
                        setup_state,setup_rates)) return false;
   if(!AnalyseStructure(LTFTimeframe(),ReplayBars(ChartStructureBars(LTFTimeframe())),
                        ltf_state,ltf_rates)) return false;
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
   ReplayStructure(rates,total,length,structure_state,points,events);

   ObjectsDeleteAll(0,g_prefix);
   if(anchored)
      DrawStructure(rates,total,MathMax(0,total-displayed),structure_state,points,events);
   else
     {
      BASE_STRUCTURE_STATE chart_state;
      BASE_STRUCTURE_POINT chart_points[];
      BASE_STRUCTURE_EVENT chart_events[];
      if(ReplayStructure(chart_rates,chart_total,length,chart_state,chart_points,chart_events))
         DrawStructure(chart_rates,chart_total,
                       MathMax(0,chart_total-ChartStructureBars(chart_timeframe)),
                       chart_state,chart_points,chart_events);
     }
   DrawAverageLines(rates,total,displayed,ma);

   string tradeability_reason="";
   bool bias_ready=EvaluateTradeability(structure_state,setup_state,ltf_state,tradeability_reason);
   bool tradeable=bias_ready;
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

   DrawDashboard(BiasText(structure_state),BiasText(setup_state),BiasText(ltf_state),
                 bias_ready,tradeable,tradeability_reason,
                 EntryFilterTooltip(rates[total-1],ma,adx,atr),optimal,
                 healthy_extension,good_volume,volume_ratio,good_momentum,
                 momentum_ratio,optimal_reason);
   // Alert every event that became known on the newest closed candle (a CHoCH
   // confirmed by a second break arrives together with its BOS).
   string signal="";
   for(int i=ArraySize(events)-1;i>=0 && events[i].bar==total-1;i--)
      signal=(events[i].bos?"BOS ":"CHoCH ")+(events[i].direction>0?"bullish":"bearish")+
             (signal==""?"":" + ")+signal;
   if(permit_alert && signal!="") SendBASEAlert(signal,rates[total-1].time);
   ChartRedraw();
   return true;
  }

bool ValidInputs()
  {
   string problem="";
   if(Swing_Detection_Length<1 || Swing_Detection_Length>50)
      problem="Swing_Detection_Length must be between 1 and 50";
   else if(Bars_To_Process<100)
      problem="Bars_To_Process must be at least 100";
   else if(MA_Length<1 || HTF_MA_Length<1 || ADX_Length<1 || ATR_Length<1)
      problem="MA, HTF MA, ADX and ATR lengths must be positive";
   else if(!Use_Timeframe_Correlation_For_Optimal && !Use_Healthy_Extension_For_Optimal &&
           !Use_Market_Volume_For_Optimal && !Use_Price_Momentum_For_Optimal)
      problem="enable at least one Optimal Conditions requirement";
   else if(!Use_HTF_For_Tradeability && !Use_MTF_For_Tradeability && !Use_LTF_For_Tradeability)
      problem="enable at least one tradeability timeframe";
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
   if(Use_MA_Filter && (g_ma_handle=iMA(_Symbol,timeframe,MA_Length,0,BASEMAMethod(MA_Type),PRICE_CLOSE))==INVALID_HANDLE) return INIT_FAILED;
   if(Use_HTF_MA_Filter && (g_htf_ma_handle=iMA(_Symbol,HTF_Timeframe,HTF_MA_Length,0,BASEMAMethod(HTF_MA_Type),PRICE_CLOSE))==INVALID_HANDLE) return INIT_FAILED;
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
   if(g_ma_handle!=INVALID_HANDLE) IndicatorRelease(g_ma_handle);
   if(g_htf_ma_handle!=INVALID_HANDLE) IndicatorRelease(g_htf_ma_handle);
   if(g_adx_handle!=INVALID_HANDLE) IndicatorRelease(g_adx_handle);
   if(g_atr_handle!=INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   if(g_ltf_atr_handle!=INVALID_HANDLE) IndicatorRelease(g_ltf_atr_handle);
   g_ma_handle=INVALID_HANDLE;
   g_htf_ma_handle=INVALID_HANDLE;
   g_adx_handle=INVALID_HANDLE;
   g_atr_handle=INVALID_HANDLE;
   g_ltf_atr_handle=INVALID_HANDLE;
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
