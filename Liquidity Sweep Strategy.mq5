#property copyright "Base + Model Base conversions"
#property version   "2.31"
#property strict
#property description "Liquidity Sweep Strategy: merged Base and Model Base EA."
#property description "Trades MTF liquidity-zone sweeps at 1:2 with breakeven at 1:1; by default only in the Strategy Tester."

#include <Trade\Trade.mqh>

enum BASE_MA_TYPE { BASE_SMA=0, BASE_EMA=1 };
enum BASE_MA_FILTER_MODE { BASE_PRICE_ABOVE_BELOW=0, BASE_FULL_BODY_CLOSE=1 };
enum BASE_SESSION { BASE_NEW_YORK=0, BASE_LONDON=1, BASE_TOKYO=2, BASE_SYDNEY=3, BASE_CUSTOM=4, BASE_24X7=5 };
enum BASE_ADX_SCOPE { BASE_BOS_ONLY=0, BASE_BOS_AND_CHOCH=1 };
enum BASE_ATR_MODE { BASE_ATR_MINIMUM=0, BASE_ATR_MAXIMUM=1, BASE_ATR_RANGE=2 };
enum BASE_LABEL_SIZE { BASE_TINY=7, BASE_SMALL=9, BASE_NORMAL=11, BASE_LARGE=14 };
enum BASE_TREND_PIVOT_SOURCE { BASE_TREND_HIGH_LOW=0, BASE_TREND_CLOSE=1 };

input group "Timeframe Inputs"
input ENUM_TIMEFRAMES Boundary_Timeframe=PERIOD_H4;
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

input group "Market Boundaries - Support / Resistance"
input bool Show_HTF_Support_Resistance=true;
input int Boundary_Lookback_Bars=50;
input int SR_Pivot_Length=3;
input ENUM_LINE_STYLE SR_Line_Style=STYLE_DOT;
input int SR_Line_Width=2;
input bool Show_SR_Labels=true;

input group "Market Boundaries - Trendline Zones"
input bool Show_Trendline_Zones=true;
input int Trendline_Bars_To_Apply=300;
input int Trendline_Zones_Per_Side=3;
input int Trendline_Minimum_Touches=3;
input color Trendline_Resistance_Color=clrRed;
input color Trendline_Support_Color=clrGreen;
input int Trendline_Zone_Transparency=50;

input group "BOS Display"
input bool Show_BOS_Labels=true;
input color Bullish_BOS_Color=clrTeal;
input color Bearish_BOS_Color=clrRed;

input group "CHoCH Display"
input bool Show_CHoCH_Labels=true;
input color Bullish_CHoCH_Color=clrLime;
input color Bearish_CHoCH_Color=clrMagenta;

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
input bool Use_Technical_Space_For_Optimal=true;
input bool Use_Healthy_Extension_For_Optimal=false;
input bool Use_Market_Volume_For_Optimal=true;
input bool Use_Price_Momentum_For_Optimal=false;

input group "Alerts"
input bool Enable_Popup_Alerts=false;
input bool Enable_Push_Notifications=false;
// Sweep alerts are delivered through the popup/push switches above.
input bool Alert_On_Liquidity_Sweep=true;

// Internal tuning values are deliberately kept out of the Inputs dialog. The
// streamlined UI exposes only settings that are useful during normal use.
const BASE_TREND_PIVOT_SOURCE Trendline_Pivot_Source=BASE_TREND_HIGH_LOW;
const int Trendline_Pivot_Strength=10;
const BASE_MA_FILTER_MODE MA_Filter_Mode=BASE_PRICE_ABOVE_BELOW;
const BASE_MA_FILTER_MODE HTF_MA_Filter_Mode=BASE_PRICE_ABOVE_BELOW;
const double ADX_Minimum=25.0;
const BASE_ADX_SCOPE Apply_ADX_Filter_To=BASE_BOS_ONLY;
const BASE_ATR_MODE ATR_Filter_Mode=BASE_ATR_MINIMUM;
const double ATR_Minimum=1.0;
const double ATR_Maximum=10.0;
const bool Use_Optimal_Conditions_Meter=true;
const double Boundary_Clearance_ATR=1.0;
const double Maximum_Extension_ATR=3.0;
const int Volume_Average_Length=20;
const double Volume_Minimum_Ratio=0.50;
const double Volume_Maximum_Ratio=2.00;
const int Momentum_Average_Length=20;
const double Momentum_Minimum_Ratio=0.50;
const double Momentum_Maximum_Ratio=2.00;

enum MODEL_SWING_AREA
  {
   MODEL_WICK_EXTREMITY=0,
   MODEL_FULL_RANGE=1
  };

enum MODEL_FILTER_MODE
  {
   MODEL_FILTER_COUNT=0,
   MODEL_FILTER_VOLUME=1
  };

enum MODEL_LABEL_SIZE
  {
   MODEL_TINY=7,
   MODEL_SMALL=9,
   MODEL_NORMAL=11
  };

input group "Settings"
input MODEL_SWING_AREA  Swing_Area=MODEL_WICK_EXTREMITY;
input bool              Intrabar_Precision=false;
input ENUM_TIMEFRAMES   Intrabar_Timeframe=PERIOD_M1;
input MODEL_FILTER_MODE Filter_Areas_By=MODEL_FILTER_COUNT;
input double            Filter_Value=0.0;

input group "Style"
input bool             Show_Swing_High=true;
input color            Swing_High_Color=clrRed;
input color            Swing_High_Area_Color=clrRed;
input bool             Show_Swing_Low=true;
input color            Swing_Low_Color=clrTeal;
input color            Swing_Low_Area_Color=clrTeal;
input bool             Show_Liquidity_Sweeps=true;
input MODEL_LABEL_SIZE Labels_Size=MODEL_TINY;

enum LSS_TRADE_MODE
  {
   LSS_TRADING_OFF=0,     // Off (analysis only)
   LSS_TRADING_TESTER=1,  // Strategy Tester only
   LSS_TRADING_LIVE=2     // Strategy Tester and live charts
  };

enum LSS_LOT_MODE
  {
   LSS_RISK_PERCENT=0,    // Risk % of balance per trade
   LSS_FIXED_LOTS=1       // Fixed lots
  };

input group "Trading"
input LSS_TRADE_MODE Trade_Mode=LSS_TRADING_TESTER;
input LSS_LOT_MODE   Lot_Sizing=LSS_RISK_PERCENT;
input double         Risk_Percent=1.0;
input double         Fixed_Lots=0.10;
// Take profit in multiples of the initial risk (R).
input double         Reward_Risk_Ratio=2.0;
// Move the stop to the entry price at this profit in R (0 disables).
input double         Breakeven_At_R=1.0;
// Stop distance beyond the zone's far edge, in setup-timeframe ATRs.
input double         SL_Buffer_ATR=0.5;
// Skip a setup whose stop would be wider than this, in setup-timeframe ATRs.
input double         Max_SL_ATR=2.0;
// MTF candles after the sweep candle during which an entry may be taken.
input int            Entry_Window_Candles=3;
// Also skip when a Market High/Low or trendline lies between entry and target.
input bool           Require_Clear_Path_To_Target=true;
input ulong          Magic_Number=20260927;

string g_prefix="";
datetime g_last_ltf_bar=0;
datetime g_last_structure_bar=0;
datetime g_last_setup_bar=0;
int g_ma_handle=INVALID_HANDLE;
int g_htf_ma_handle=INVALID_HANDLE;
int g_adx_handle=INVALID_HANDLE;
int g_atr_handle=INVALID_HANDLE;
int g_trend_atr_handle=INVALID_HANDLE;
int g_ltf_atr_handle=INVALID_HANDLE;
string g_model_prefix="";
datetime g_model_last_bar=0;
int g_model_last_state=-99;
bool g_model_draw=false;
bool g_htf_ready=false;
int g_sweep_count=0;

CTrade g_trade;
int g_setup_atr_handle=INVALID_HANDLE;
// Latest Base analysis, published by Rebuild for the trading layer.
bool g_conditions_ready=false;
bool g_tradeable=false;
string g_optimal_block="";
bool g_have_clearance=false;
bool g_boundaries_complete=false;
double g_clearance=0.0;
bool g_have_market_high=false,g_have_market_low=false;
double g_market_high=0.0,g_market_low=0.0;
double g_trend_top[],g_trend_bottom[],g_trend_slope[];
datetime g_trend_time=0;
// Live liquidity zone on the bias side, published by RebuildModel.
bool g_zone_valid=false;
int g_zone_side=0;          // -1 sell at an LH zone, 1 buy at an HL zone
double g_zone_top=0.0,g_zone_bottom=0.0;
datetime g_zone_id=0;       // time of the zone's swing candle
datetime g_zone_sweep_time=0;   // candle that swept the zone (0 = not yet)
double g_zone_sweep_price=0.0;  // that candle's wick extreme beyond the zone
bool g_zone_fresh_sweep=false;  // the entry window after the sweep is still open
datetime g_traded_zone_id=0;
datetime g_rejected_zone_id=0;
string g_rejected_reason="";
string g_trade_status="";
ulong g_breakeven_failed_ticket=0;

struct BASE_STRUCTURE_STATE
  {
   int direction;           // 1 bullish, -1 bearish, 0 no confirmed break
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
   int bar;                 // bar index of the confirming candle
   int direction;           // 1 bullish, -1 bearish
   bool bos;                // true BOS (continuation), false CHoCH
   datetime swing_time;     // pivot time of the broken level
   double level;
  };

// Latest structure-timeframe (HTF) state from the last completed Base build.
// The liquidity engine reads it instead of replaying the HTF on every tick.
BASE_STRUCTURE_STATE g_htf_structure;

ENUM_TIMEFRAMES SetupTimeframe()
  {
   return Setup_Entry_Timeframe==PERIOD_CURRENT?(ENUM_TIMEFRAMES)_Period:Setup_Entry_Timeframe;
  }

ENUM_TIMEFRAMES LTFTimeframe()
  {
   return LTF_Timeframe==PERIOD_CURRENT?(ENUM_TIMEFRAMES)_Period:LTF_Timeframe;
  }

ENUM_TIMEFRAMES BoundaryTimeframe()
  {
   return Boundary_Timeframe==PERIOD_CURRENT?(ENUM_TIMEFRAMES)_Period:Boundary_Timeframe;
  }

ENUM_TIMEFRAMES BASETimeframe()
  {
   return Structure_Timeframe==PERIOD_CURRENT?(ENUM_TIMEFRAMES)_Period:Structure_Timeframe;
  }

// The Strategy Tester's non-visual mode (including optimisation) never shows
// a chart, so nothing is drawn there; analysis and trading still run.
bool DrawingEnabled()
  {
   return MQLInfoInteger(MQL_TESTER)==0 || MQLInfoInteger(MQL_VISUAL_MODE)!=0;
  }

bool ModelDisplayEnabled()
  {
   return DrawingEnabled() && (ENUM_TIMEFRAMES)_Period==SetupTimeframe();
  }

bool BaseDisplayEnabled()
  {
   // The liquidity engine owns the MTF chart, including its HH/HL/LH/LL
   // labels, and has priority if timeframe inputs overlap.  Base overlays
   // belong to the structure (HTF) and boundary charts.
   if(!DrawingEnabled() || ModelDisplayEnabled()) return false;
   return (ENUM_TIMEFRAMES)_Period==BASETimeframe() ||
          (ENUM_TIMEFRAMES)_Period==BoundaryTimeframe();
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

// Chart-timeframe structure covers the same elapsed time as Bars_To_Process
// represents on the structure timeframe (100 H1 bars become 400 M15 bars).
int ChartStructureBars(const ENUM_TIMEFRAMES timeframe)
  {
   int structure_seconds=PeriodSeconds(BASETimeframe());
   int chart_seconds=PeriodSeconds(timeframe);
   int wanted=StructureBars();
   if(structure_seconds>0 && chart_seconds>0)
      wanted=(int)MathCeil((double)StructureBars()*structure_seconds/chart_seconds);
   return MathMax(2*SwingLength()+2,MathMin(wanted,100000));
  }

// Market High/Low and the trendline zones share one boundary-timeframe copy.
int BoundaryBars()
  {
   int sr_length=MathMax(1,MathMin(20,SR_Pivot_Length));
   return MathMax(Boundary_Lookback_Bars+sr_length,
                  Trendline_Bars_To_Apply+2*Trendline_Pivot_Strength+1);
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
   ArrayResize(points,index+1,32);
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
                       const int bar,const int direction,const bool bos,
                       const datetime swing_time,const double level)
  {
   int index=ArraySize(events);
   ArrayResize(events,index+1,32);
   events[index].bar=bar;
   events[index].direction=direction;
   events[index].bos=bos;
   events[index].swing_time=swing_time;
   events[index].level=level;
   state.direction=direction;
   state.last_break_was_bos=bos;
  }

// Replays confirmed pivots and close-confirmed breaks over closed candles.
// Market bias, chart labels and BOS/CHoCH drawings all come from this single
// routine, so they can never disagree about structure.
//
// Only a candle close beyond a typed level is a break; a wick is a liquidity
// sweep.  Breaking an HH/LL is a BOS.  Breaking an LH/HL is a CHoCH
// candidate: bullish CHoCH is confirmed when the next swing low formed after
// the breaking close is an HL (an LL cancels it), and bearish CHoCH when the
// next swing high after the close is an LH.  A swing printed before the
// breaking close, even if confirmed after it, can neither confirm nor cancel
// the candidate.
bool ReplayStructure(const MqlRates &rates[],const int total,const int length,
                     BASE_STRUCTURE_STATE &state,BASE_STRUCTURE_POINT &points[],
                     BASE_STRUCTURE_EVENT &events[])
  {
   ZeroMemory(state);
   ArrayResize(points,0);
   ArrayResize(events,0);
   if(total<2*length+2) return false;
   bool high_broken=false,low_broken=false;
   int last_side=0;
   bool have_high_reference=false,have_low_reference=false;
   double high_reference=0.0,low_reference=0.0;
   int high_point=-1,low_point=-1;
   int pending_choch=0,pending_bar=-1;
   datetime pending_swing_time=0;
   double pending_level=0.0;
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
            if(same_leg && high_point>=0) points[high_point].superseded=true;
            high_point=AddStructurePoint(points,pivot,i,rates[pivot],1,kind);
            state.last_high_kind=kind;
            state.last_high_time=rates[pivot].time;
            high_broken=false;
            if(pending_choch<0 && pivot>pending_bar)
              {
               if(kind<0)
                  AddStructureEvent(events,state,i,-1,false,pending_swing_time,pending_level);
               pending_choch=0;
              }
           }
        }
      if(PivotLow(rates,total,pivot,length))
        {
         int kind=0;
         bool same_leg=last_side==-1;
         if(AcceptStructureLow(rates[pivot].low,state.have_low,state.last_low,last_side,
                               have_low_reference,low_reference,kind))
           {
            if(same_leg && low_point>=0) points[low_point].superseded=true;
            low_point=AddStructurePoint(points,pivot,i,rates[pivot],-1,kind);
            state.last_low_kind=kind;
            state.last_low_time=rates[pivot].time;
            low_broken=false;
            if(pending_choch>0 && pivot>pending_bar)
              {
               if(kind<0)
                  AddStructureEvent(events,state,i,1,false,pending_swing_time,pending_level);
               pending_choch=0;
              }
           }
        }
      if(state.have_high && state.last_high_kind!=0 && !high_broken &&
         rates[i].close>state.last_high)
        {
         high_broken=true;
         if(state.last_high_kind<0)
           {
            pending_choch=1;
            pending_bar=i;
            pending_swing_time=state.last_high_time;
            pending_level=state.last_high;
           }
         else
           {
            pending_choch=0;
            AddStructureEvent(events,state,i,1,true,state.last_high_time,state.last_high);
           }
        }
      if(state.have_low && state.last_low_kind!=0 && !low_broken &&
         rates[i].close<state.last_low)
        {
         low_broken=true;
         if(state.last_low_kind<0)
           {
            pending_choch=-1;
            pending_bar=i;
            pending_swing_time=state.last_low_time;
            pending_level=state.last_low;
           }
         else
           {
            pending_choch=0;
            AddStructureEvent(events,state,i,-1,true,state.last_low_time,state.last_low);
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
   // Pivot labels can change while price is merely forming a pullback. They
   // must not put an established trend back into transition: only an actual
   // counter-trend CHoCH does that, and the following BOS ends it.
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
   if(!BaseDisplayEnabled()) return;
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
   if(!BaseDisplayEnabled()) return;
   string name=g_prefix+id;
   if(ObjectFind(0,name)>=0 || !ObjectCreate(0,name,OBJ_TREND,0,from,from_price,to,to_price)) return;
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,MathMax(1,MathMin(4,width)));
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
  }

bool TrendPivot(const MqlRates &rates[],const int total,const int index,
                const int strength,const bool high)
  {
   if(index-strength<0 || index+strength>=total) return false;
   double value=Trendline_Pivot_Source==BASE_TREND_CLOSE?rates[index].close:
                (high?rates[index].high:rates[index].low);
   for(int i=index-strength;i<=index+strength;i++)
     {
      if(i==index) continue;
      double other=Trendline_Pivot_Source==BASE_TREND_CLOSE?rates[i].close:
                   (high?rates[i].high:rates[i].low);
      if((high && other>=value) || (!high && other<=value)) return false;
     }
   return true;
  }

color TrendZoneColor(const color base,const int transparency)
  {
   int opacity=(int)MathRound(255.0*(100-MathMax(0,MathMin(100,transparency)))/100.0);
   return (color)ColorToARGB(base,(uchar)opacity);
  }

void DrawTrendZone(const string id,const datetime from_time,const double from_top,
                   const double from_bottom,const datetime to_time,const double to_top,
                   const double to_bottom,const color clr)
  {
   if(!BaseDisplayEnabled()) return;
   // Keep the ATR-derived zone bounds for qualification, but render their
   // centre as one thin line. Filled channels become visually very thick on
   // volatile symbols and MT5 can leave unpainted seams where they overlap.
   double from_middle=(from_top+from_bottom)/2.0;
   double to_middle=(to_top+to_bottom)/2.0;
   DrawSegment("TREND_LINE_"+id,from_time,from_middle,to_time,to_middle,
               TrendZoneColor(clr,Trendline_Zone_Transparency),STYLE_SOLID,1);
   ObjectSetInteger(0,g_prefix+"TREND_LINE_"+id,OBJPROP_RAY_RIGHT,true);
  }

bool FindTrendZones(const MqlRates &rates[],const int total,const double threshold,
                    const bool resistance,double &projected_top,double &projected_bottom)
  {
   int strength=MathMax(5,MathMin(15,Trendline_Pivot_Strength));
   int first=MathMax(strength,total-1-Trendline_Bars_To_Apply);
   int prices_count=0;
   double prices[];
   int indices[];
   for(int i=first;i<total-strength;i++)
      if(TrendPivot(rates,total,i,strength,resistance))
        {
         ArrayResize(prices,prices_count+1,32);
         ArrayResize(indices,prices_count+1,32);
         prices[prices_count]=Trendline_Pivot_Source==BASE_TREND_CLOSE?rates[i].close:
                              (resistance?rates[i].high:rates[i].low);
         indices[prices_count++]=i;
        }

   int required=MathMax(3,MathMin(8,Trendline_Minimum_Touches));
   if(prices_count<required || threshold<=0.0) return false;
   double candidate_y[],candidate_slope[],candidate_up[],candidate_down[];
   double candidate_projected[],candidate_distance[];
   int candidate_index[],candidate_touches[];
   int candidate_count=0;
   // The newest five bars form the same stability buffer as the Pine source.
   int stability=total-1-5;
   for(int i=0;i<prices_count-1;i++)
      for(int j=i+1;j<prices_count;j++)
        {
         int span=indices[j]-indices[i];
         if(span<=0) continue;
         double slope=(prices[j]-prices[i])/span;
         int touches=0;
         bool broken=false;
         double max_up=0.0,max_down=0.0;
         for(int k=0;k<prices_count;k++)
           {
            if(indices[k]<indices[i]) continue;
            double expected=prices[i]+slope*(indices[k]-indices[i]);
            double difference=prices[k]-expected;
            if(MathAbs(difference)<=threshold)
              {
               touches++;
               if(difference>max_up) max_up=difference;
               if(difference<max_down) max_down=difference;
              }
            if(indices[k]<stability &&
               ((resistance && difference>threshold) || (!resistance && difference<-threshold)))
              {
               broken=true;
               break;
              }
           }
         if(touches<required || broken) continue;
         double projected=prices[i]+slope*(total-1-indices[i]);
         double distance=MathAbs(projected-rates[total-1].close);
         int duplicate=-1;
         for(int candidate=0;candidate<candidate_count;candidate++)
           {
            int overlap=total-1-MathMin(indices[i],candidate_index[candidate]);
            if(MathAbs(projected-candidate_projected[candidate])<=threshold &&
               MathAbs(slope-candidate_slope[candidate])*overlap<=threshold)
              {
               duplicate=candidate;
               break;
              }
           }
         if(duplicate>=0)
           {
            if(touches<candidate_touches[duplicate] ||
               (touches==candidate_touches[duplicate] && distance>=candidate_distance[duplicate]))
               continue;
           }
         else
           {
            duplicate=candidate_count++;
            ArrayResize(candidate_y,candidate_count,16);
            ArrayResize(candidate_slope,candidate_count,16);
            ArrayResize(candidate_up,candidate_count,16);
            ArrayResize(candidate_down,candidate_count,16);
            ArrayResize(candidate_projected,candidate_count,16);
            ArrayResize(candidate_distance,candidate_count,16);
            ArrayResize(candidate_index,candidate_count,16);
            ArrayResize(candidate_touches,candidate_count,16);
           }
         candidate_index[duplicate]=indices[i];
         candidate_y[duplicate]=prices[i];
         candidate_slope[duplicate]=slope;
         candidate_up[duplicate]=max_up;
         candidate_down[duplicate]=max_down;
         candidate_projected[duplicate]=projected;
         candidate_distance[duplicate]=distance;
         candidate_touches[duplicate]=touches;
        }
   if(candidate_count==0) return false;

   int draw_count=MathMin(Trendline_Zones_Per_Side,candidate_count);
   for(int rank=0;rank<draw_count;rank++)
     {
      int best=rank;
      for(int candidate=rank+1;candidate<candidate_count;candidate++)
         if(candidate_distance[candidate]<candidate_distance[best]) best=candidate;
      if(best!=rank)
        {
         double swap_double;
         int swap_int;
         swap_double=candidate_y[rank]; candidate_y[rank]=candidate_y[best]; candidate_y[best]=swap_double;
         swap_double=candidate_slope[rank]; candidate_slope[rank]=candidate_slope[best]; candidate_slope[best]=swap_double;
         swap_double=candidate_up[rank]; candidate_up[rank]=candidate_up[best]; candidate_up[best]=swap_double;
         swap_double=candidate_down[rank]; candidate_down[rank]=candidate_down[best]; candidate_down[best]=swap_double;
         swap_double=candidate_projected[rank]; candidate_projected[rank]=candidate_projected[best]; candidate_projected[best]=swap_double;
         swap_double=candidate_distance[rank]; candidate_distance[rank]=candidate_distance[best]; candidate_distance[best]=swap_double;
         swap_int=candidate_index[rank]; candidate_index[rank]=candidate_index[best]; candidate_index[best]=swap_int;
         swap_int=candidate_touches[rank]; candidate_touches[rank]=candidate_touches[best]; candidate_touches[best]=swap_int;
        }
      double end_y=candidate_projected[rank];
      RecordTrendZone(end_y+candidate_up[rank],end_y+candidate_down[rank],candidate_slope[rank]);
      if(rank==0)
        {
         projected_top=end_y+candidate_up[rank];
         projected_bottom=end_y+candidate_down[rank];
        }
      if(Show_Trendline_Zones)
         DrawTrendZone((resistance?"RESISTANCE_":"SUPPORT_")+(string)(rank+1),
                       rates[candidate_index[rank]].time,
                       candidate_y[rank]+candidate_up[rank],
                       candidate_y[rank]+candidate_down[rank],rates[total-1].time,
                       end_y+candidate_up[rank],end_y+candidate_down[rank],
                       resistance?Trendline_Resistance_Color:Trendline_Support_Color);
     }
   return true;
  }

// Keeps every trendline zone found (nearest first, projected to the latest
// closed boundary candle) for the trading layer's clearance checks.
void RecordTrendZone(const double top,const double bottom,const double slope)
  {
   int index=ArraySize(g_trend_top);
   ArrayResize(g_trend_top,index+1,16);
   ArrayResize(g_trend_bottom,index+1,16);
   ArrayResize(g_trend_slope,index+1,16);
   g_trend_top[index]=top;
   g_trend_bottom[index]=bottom;
   g_trend_slope[index]=slope;
  }

void EvaluateTrendlineZones(const MqlRates &rates[],const int total,const double trend_atr,
                            bool &have_resistance,double &resistance_top,
                            double &resistance_bottom,bool &have_support,
                            double &support_top,double &support_bottom)
  {
   have_resistance=false;
   have_support=false;
   ArrayResize(g_trend_top,0);
   ArrayResize(g_trend_bottom,0);
   ArrayResize(g_trend_slope,0);
   g_trend_time=total>0?rates[total-1].time:0;
   if(!Show_Trendline_Zones && !Use_Optimal_Conditions_Meter) return;
   if(trend_atr==EMPTY_VALUE || total<2*Trendline_Pivot_Strength+1) return;
   const double fixed_atr_multiplier=0.5;
   double threshold=trend_atr*fixed_atr_multiplier;
   have_resistance=FindTrendZones(rates,total,threshold,true,resistance_top,resistance_bottom);
   have_support=FindTrendZones(rates,total,threshold,false,support_top,support_bottom);
  }

// Market High is the highest confirmed swing high in the boundary lookback;
// Market Low is the lowest confirmed swing low in those same bars.  Older
// candles in the shared copy are only padding for confirming a swing near
// the start of the lookback window.
void EvaluateSignificantSR(const MqlRates &rates[],const int total,const datetime chart_time,
                           const double current_price,bool &have_market_high,
                           double &market_high,bool &have_market_low,double &market_low)
  {
   have_market_high=false;
   have_market_low=false;
   int length=MathMax(1,MathMin(20,SR_Pivot_Length));
   if(total<Boundary_Lookback_Bars+length) return;
   int first=total-Boundary_Lookback_Bars;

   int high_index=-1,low_index=-1;
   double high_price=0.0,low_price=0.0;
   for(int i=first;i<total-length;i++)
     {
      if(PivotHigh(rates,total,i,length))
        {
         double level=rates[i].high;
         if(high_index<0 || level>high_price)
           {
            high_index=i;
            high_price=level;
           }
        }
      if(PivotLow(rates,total,i,length))
        {
         double level=rates[i].low;
         if(low_index<0 || level<low_price)
           {
            low_index=i;
            low_price=level;
           }
        }
     }

   if(high_index>=0 && high_price>current_price)
     {
      have_market_high=true;
      market_high=high_price;
      if(Show_HTF_Support_Resistance)
        {
         string key="HTF_SR_MARKET_HIGH";
         DrawSegment(key,rates[high_index].time,high_price,chart_time,
                     high_price,clrBlack,SR_Line_Style,SR_Line_Width);
         ObjectSetInteger(0,g_prefix+key,OBJPROP_RAY_RIGHT,true);
         if(Show_SR_Labels)
            DrawText(key+"_LABEL",chart_time,high_price,"Market High",clrBlack,false,8);
        }
     }
   if(low_index>=0 && low_price<current_price)
     {
      have_market_low=true;
      market_low=low_price;
      if(Show_HTF_Support_Resistance)
        {
         string key="HTF_SR_MARKET_LOW";
         DrawSegment(key,rates[low_index].time,low_price,chart_time,
                     low_price,clrBlack,SR_Line_Style,SR_Line_Width);
         ObjectSetInteger(0,g_prefix+key,OBJPROP_RAY_RIGHT,true);
         if(Show_SR_Labels)
            DrawText(key+"_LABEL",chart_time,low_price,"Market Low",clrBlack,true,8);
        }
     }
  }

void DrawSignal(const string kind,const int direction,const datetime swing_time,
                const double level,const MqlRates &bar)
  {
   bool bos=kind=="BOS";
   if((bos && !Show_BOS_Labels) || (!bos && !Show_CHoCH_Labels)) return;
   color clr=direction>0?(bos?Bullish_BOS_Color:Bullish_CHoCH_Color)
                         :(bos?Bearish_BOS_Color:Bearish_CHoCH_Color);
   string key=kind+(direction>0?"_UP_":"_DOWN_")+(string)bar.time;
   double label_price=direction>0?bar.low:bar.high;
   DrawText(key,bar.time,label_price,kind,clr,direction>0,(int)Label_Size);
   if(Show_Structure_Lines)
      DrawSegment(key+"_LINE",swing_time,level,bar.time,level,clr,Line_Style,Line_Width);
  }

string StructureLabel(const BASE_STRUCTURE_POINT &point)
  {
   if(point.side>0) return point.kind>0?"HH":"LH";
   return point.kind>0?"LL":"HL";
  }

void CreateStructureLabel(const string prefix,const string kind,const datetime time,
                          const double price)
  {
   bool low=kind=="HL" || kind=="LL";
   color clr=low?clrTeal:clrIndianRed;
   string name=prefix+"STRUCTURE_"+kind+"_"+(string)time;
   if(ObjectFind(0,name)>=0 || !ObjectCreate(0,name,OBJ_TEXT,0,time,price)) return;
   ObjectSetString(0,name,OBJPROP_TEXT,kind);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,(int)Label_Size);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,low?ANCHOR_UPPER:ANCHOR_LOWER);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

void DrawStructurePoint(const string kind,const datetime time,const double price)
  {
   if(!Show_Swing_Points || !BaseDisplayEnabled()) return;
   CreateStructureLabel(g_prefix,kind,time,price);
  }

// Draws one replay: HH/HL/LH/LL labels (superseded and untyped points are
// skipped), BOS/CHoCH signals and the dotted current swing levels.
void DrawStructure(const MqlRates &rates[],const int total,const BASE_STRUCTURE_STATE &state,
                   const BASE_STRUCTURE_POINT &points[],const BASE_STRUCTURE_EVENT &events[])
  {
   int point_count=ArraySize(points);
   for(int i=0;i<point_count;i++)
      if(!points[i].superseded && points[i].kind!=0)
         DrawStructurePoint(StructureLabel(points[i]),points[i].time,points[i].price);
   int event_count=ArraySize(events);
   for(int i=0;i<event_count;i++)
      DrawSignal(events[i].bos?"BOS":"CHoCH",events[i].direction,events[i].swing_time,
                 events[i].level,rates[events[i].bar]);
   if(Show_Swing_Points && state.have_high)
      DrawSegment("LAST_HIGH",state.last_high_time,state.last_high,rates[total-1].time,
                  state.last_high,clrIndianRed,STYLE_DOT,1);
   if(Show_Swing_Points && state.have_low)
      DrawSegment("LAST_LOW",state.last_low_time,state.last_low,rates[total-1].time,
                  state.last_low,clrTeal,STYLE_DOT,1);
  }

void DrawAverageLines(const MqlRates &rates[],const int total,const double &ma[])
  {
   int first=MathMax(1,total-500);
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
   if(!BaseDisplayEnabled()) return;
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
                   const string filter_tooltip,
                   const bool optimal,const bool clear_space,const bool healthy_extension,
                   const bool good_volume,const double volume_ratio,
                   const bool good_momentum,const double momentum_ratio,
                   const string optimal_reason)
  {
   Comment("");
   if(!BaseDisplayEnabled()) return;
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
   if(Use_Technical_Space_For_Optimal)
      DrawDashboardLine(row++,"Technical Space: "+PassText(clear_space));
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
   int wanted=StructureBars();
   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   int total=CopyRates(_Symbol,timeframe,1,wanted,rates);
   if(total<2*length+2) return false;

   // Only the MA line needs history; the filters use the latest closed bar.
   double ma[],adx[],atr[];
   if(Use_MA_Filter && !CopyIndicator(g_ma_handle,0,Show_MA_Line?total:1,ma)) return false;
   if(Use_ADX_Filter && !CopyIndicator(g_adx_handle,0,1,adx)) return false;
   if(Use_ATR_Filter && !CopyIndicator(g_atr_handle,0,1,atr)) return false;

   BASE_STRUCTURE_STATE setup_state,ltf_state;
   MqlRates setup_rates[],ltf_rates[];
   if(!AnalyseStructure(SetupTimeframe(),wanted,setup_state,setup_rates)) return false;
   if(!AnalyseStructure(LTFTimeframe(),wanted,ltf_state,ltf_rates)) return false;
   int ltf_total=ArraySize(ltf_rates);
   double ltf_atr[];
   if(!CopyIndicator(g_ltf_atr_handle,0,1,ltf_atr)) return false;

   MqlRates boundary_rates[];
   ArraySetAsSeries(boundary_rates,false);
   int boundary_total=CopyRates(_Symbol,BoundaryTimeframe(),1,BoundaryBars(),boundary_rates);
   double trend_atr[];
   if(boundary_total<=0 || !CopyIndicator(g_trend_atr_handle,0,1,trend_atr)) return false;

   // Labels follow the chart period, while the dashboard state stays on
   // Structure_Timeframe.  The MTF chart's labels are drawn by the liquidity
   // engine from the same replay that identifies its liquidity swings.
   bool base_display=BaseDisplayEnabled();
   bool anchored=base_display && chart_timeframe==timeframe;
   MqlRates chart_rates[];
   ArraySetAsSeries(chart_rates,false);
   int chart_total=0;
   if(base_display && !anchored)
     {
      chart_total=CopyRates(_Symbol,chart_timeframe,1,ChartStructureBars(chart_timeframe),chart_rates);
      if(chart_total<=0) return false;
     }

   BASE_STRUCTURE_STATE structure_state;
   BASE_STRUCTURE_POINT points[];
   BASE_STRUCTURE_EVENT events[];
   ReplayStructure(rates,total,length,structure_state,points,events);

   ObjectsDeleteAll(0,g_prefix);
   if(anchored)
      DrawStructure(rates,total,structure_state,points,events);
   else if(base_display)
     {
      BASE_STRUCTURE_STATE chart_state;
      BASE_STRUCTURE_POINT chart_points[];
      BASE_STRUCTURE_EVENT chart_events[];
      if(ReplayStructure(chart_rates,chart_total,length,chart_state,chart_points,chart_events))
         DrawStructure(chart_rates,chart_total,chart_state,chart_points,chart_events);
     }
   if(base_display) DrawAverageLines(rates,total,ma);

   MqlTick current_tick;
   double current_price=SymbolInfoTick(_Symbol,current_tick) && current_tick.bid>0.0
                        ?current_tick.bid:rates[total-1].close;
   bool have_market_high=false,have_market_low=false;
   double market_high=0.0,market_low=0.0;
   EvaluateSignificantSR(boundary_rates,boundary_total,rates[total-1].time,current_price,
                         have_market_high,market_high,have_market_low,market_low);
   bool have_resistance=false,have_support=false;
   double resistance_top=0.0,resistance_bottom=0.0,support_top=0.0,support_bottom=0.0;
   EvaluateTrendlineZones(boundary_rates,boundary_total,trend_atr[0],
                          have_resistance,resistance_top,resistance_bottom,
                          have_support,support_top,support_bottom);

   g_htf_structure=structure_state;
   g_htf_ready=true;
   int structure=structure_state.direction;
   // Only enabled tradeability timeframes participate in correlation, but a
   // clean HTF continuation is always the gateway to tradeability. A CHoCH
   // leaves the HTF transitional until the next BOS; unbroken pullback pivots
   // do not change its established bias. When enabled, LTF must likewise have
   // a definite BOS.
   bool htf_definite=DefiniteBias(structure_state);
   bool ltf_definite=DefiniteBias(ltf_state);
   bool selected_biases_available=(!Use_HTF_For_Tradeability || structure!=0) &&
                                  (!Use_MTF_For_Tradeability || setup_state.direction!=0) &&
                                  (!Use_LTF_For_Tradeability || ltf_state.direction!=0);
   bool selected_biases_match=(!Use_HTF_For_Tradeability || !Use_MTF_For_Tradeability ||
                               structure==setup_state.direction) &&
                              (!Use_HTF_For_Tradeability || !Use_LTF_For_Tradeability ||
                               structure==ltf_state.direction) &&
                              (!Use_MTF_For_Tradeability || !Use_LTF_For_Tradeability ||
                               setup_state.direction==ltf_state.direction);
   bool bias_ready=htf_definite && selected_biases_available && selected_biases_match &&
                   (!Use_LTF_For_Tradeability || ltf_definite);

   double latest_atr=ltf_atr[0];
   bool have_atr=latest_atr!=EMPTY_VALUE && latest_atr>0.0;
   double clearance=have_atr?latest_atr*Boundary_Clearance_ATR:0.0;
   bool clear_space=have_atr;
   string space_reason=have_atr?"":"LTF ATR is unavailable";
   if(clear_space && have_market_high && market_high-current_price<=clearance)
     { clear_space=false; space_reason="too close to Market High"; }
   if(clear_space && have_market_low && current_price-market_low<=clearance)
     { clear_space=false; space_reason="too close to Market Low"; }
   if(clear_space && have_resistance &&
      current_price>=resistance_bottom-clearance && current_price<=resistance_top+clearance)
     { clear_space=false; space_reason="too close to resistance trendline"; }
   if(clear_space && have_support &&
      current_price>=support_bottom-clearance && current_price<=support_top+clearance)
     { clear_space=false; space_reason="too close to support trendline"; }

   double extension=DBL_MAX;
   if(have_atr)
     {
      if(ltf_state.direction>0 && ltf_state.have_low)
         extension=(ltf_rates[ltf_total-1].close-ltf_state.last_low)/latest_atr;
      else if(ltf_state.direction<0 && ltf_state.have_high)
         extension=(ltf_state.last_high-ltf_rates[ltf_total-1].close)/latest_atr;
     }
   bool healthy_extension=have_atr && extension>=0.0 && extension<=Maximum_Extension_ATR;

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
   bool optimal=(!Use_Timeframe_Correlation_For_Optimal || bias_ready) &&
                (!Use_Technical_Space_For_Optimal || clear_space) &&
                (!Use_Healthy_Extension_For_Optimal || healthy_extension) &&
                (!Use_Market_Volume_For_Optimal || good_volume) &&
                (!Use_Price_Momentum_For_Optimal || good_momentum);
   string optimal_reason="All selected requirements are met";
   if(!optimal)
     {
      optimal_reason="";
      if(Use_Timeframe_Correlation_For_Optimal && !bias_ready)
         optimal_reason=TradeabilityTimeframesText()+
                                     " tradeability biases do not meet the selected correlation requirements";
      if(Use_Technical_Space_For_Optimal && !clear_space)
         optimal_reason+=(optimal_reason==""?"":"; ")+space_reason;
      if(Use_Healthy_Extension_For_Optimal && !healthy_extension)
         optimal_reason+=(optimal_reason==""?"":"; ")+"price is overextended or lacks a valid corrective anchor";
      if(Use_Market_Volume_For_Optimal && !good_volume)
         optimal_reason+=(optimal_reason==""?"":"; ")+
                         (volume_ratio<Volume_Minimum_Ratio?"volume is too low":"volume is too high");
      if(Use_Price_Momentum_For_Optimal && !good_momentum)
         optimal_reason+=(optimal_reason==""?"":"; ")+
                           (momentum_ratio<Momentum_Minimum_Ratio?
                            "momentum is too low (price is sluggish)":
                            "momentum is too high (price would need to be chased)");
     }
   bool tradeable=bias_ready;
   int selected_timeframe_count=(Use_HTF_For_Tradeability?1:0)+
                                (Use_MTF_For_Tradeability?1:0)+
                                (Use_LTF_For_Tradeability?1:0);
   string tradeability_reason=TradeabilityTimeframesText()+
                              (selected_timeframe_count>1?" correlate":" is directional");
   tradeability_reason+="; HTF is confirmed by HH/LL BOS";
   if(Use_LTF_For_Tradeability) tradeability_reason+="; LTF is confirmed by BOS";
   if(!tradeable)
     {
      if(structure==0) tradeability_reason="HTF is consolidating";
      else if(!htf_definite)
         tradeability_reason="HTF bias is transitional (no confirmed HH/LL BOS)";
      else if(Use_MTF_For_Tradeability && setup_state.direction==0) tradeability_reason="MTF is consolidating";
      else if(Use_LTF_For_Tradeability && ltf_state.direction==0) tradeability_reason="LTF is consolidating";
      else if(!selected_biases_match)
         tradeability_reason=TradeabilityTimeframesText()+" biases conflict";
      else if(Use_LTF_For_Tradeability && !ltf_definite)
         tradeability_reason="LTF bias is transitional (CHoCH has no subsequent BOS)";
     }
   // Publish the analysis for the trading layer.  Technical space is checked
   // there at the actual entry price, so it is not part of this summary.
   string optimal_block="";
   if(Use_Timeframe_Correlation_For_Optimal && !bias_ready) optimal_block="timeframe correlation";
   if(Use_Healthy_Extension_For_Optimal && !healthy_extension)
      optimal_block+=(optimal_block==""?"":", ")+"healthy extension";
   if(Use_Market_Volume_For_Optimal && !good_volume)
      optimal_block+=(optimal_block==""?"":", ")+"market volume";
   if(Use_Price_Momentum_For_Optimal && !good_momentum)
      optimal_block+=(optimal_block==""?"":", ")+"price momentum";
   g_tradeable=tradeable;
   g_optimal_block=optimal_block;
   g_have_clearance=have_atr;
   g_boundaries_complete=boundary_total>=BoundaryBars();
   g_clearance=clearance;
   g_have_market_high=have_market_high;
   g_market_high=market_high;
   g_have_market_low=have_market_low;
   g_market_low=market_low;
   g_conditions_ready=true;
   DrawDashboard(BiasText(structure_state),BiasText(setup_state),BiasText(ltf_state),
                 bias_ready,tradeable,tradeability_reason,
                 EntryFilterTooltip(rates[total-1],ma,adx,atr),optimal,clear_space,
                 healthy_extension,good_volume,volume_ratio,good_momentum,
                 momentum_ratio,optimal_reason);
   // Events are stored in replay order, so the last one is the newest.  On a
   // candle with both a bullish and a bearish event the bearish one is later.
   int event_count=ArraySize(events);
   if(permit_alert && event_count>0 && events[event_count-1].bar==total-1)
      SendBASEAlert((events[event_count-1].bos?"BOS ":"CHoCH ")+
                    (events[event_count-1].direction>0?"bullish":"bearish"),
                    rates[total-1].time);
   ChartRedraw();
   return true;
  }

bool ValidInputs()
  {
   string problem="";
   if(Intrabar_Precision && PeriodSeconds(Intrabar_Timeframe)>=PeriodSeconds(SetupTimeframe()))
      problem="Intrabar_Timeframe must be lower than Setup_Entry_Timeframe";
   else if(Swing_Detection_Length<1 || Swing_Detection_Length>50)
      problem="Swing_Detection_Length must be between 1 and 50";
   else if(Bars_To_Process<100)
      problem="Bars_To_Process must be at least 100";
   else if(MA_Length<1 || HTF_MA_Length<1 || ADX_Length<1 || ATR_Length<1)
      problem="MA, HTF MA, ADX and ATR lengths must be positive";
   else if(Boundary_Lookback_Bars<1 || Boundary_Lookback_Bars>100000)
      problem="Boundary_Lookback_Bars must be between 1 and 100000";
   else if(SR_Pivot_Length<1 || SR_Pivot_Length>20)
      problem="SR_Pivot_Length must be between 1 and 20";
   else if(Trendline_Bars_To_Apply<50 || Trendline_Bars_To_Apply>100000)
      problem="Trendline_Bars_To_Apply must be between 50 and 100000";
   else if(Trendline_Zones_Per_Side<1 || Trendline_Zones_Per_Side>10)
      problem="Trendline_Zones_Per_Side must be between 1 and 10";
   else if(Trendline_Minimum_Touches<3 || Trendline_Minimum_Touches>8)
      problem="Trendline_Minimum_Touches must be between 3 and 8";
   else if(Trendline_Zone_Transparency<0 || Trendline_Zone_Transparency>100)
      problem="Trendline_Zone_Transparency must be between 0 and 100";
   else if(!Use_Timeframe_Correlation_For_Optimal && !Use_Technical_Space_For_Optimal &&
           !Use_Healthy_Extension_For_Optimal && !Use_Market_Volume_For_Optimal &&
           !Use_Price_Momentum_For_Optimal)
      problem="enable at least one Optimal Conditions requirement";
   else if(!Use_HTF_For_Tradeability && !Use_MTF_For_Tradeability && !Use_LTF_For_Tradeability)
      problem="enable at least one tradeability timeframe";
   else if(Trade_Mode!=LSS_TRADING_OFF)
     {
      if(Lot_Sizing==LSS_RISK_PERCENT && (Risk_Percent<=0.0 || Risk_Percent>100.0))
         problem="Risk_Percent must be above 0 and at most 100";
      else if(Lot_Sizing==LSS_FIXED_LOTS && Fixed_Lots<=0.0)
         problem="Fixed_Lots must be positive";
      else if(Reward_Risk_Ratio<=0.0)
         problem="Reward_Risk_Ratio must be positive";
      else if(Breakeven_At_R<0.0 || Breakeven_At_R>=Reward_Risk_Ratio)
         problem="Breakeven_At_R must be 0 (off) or below Reward_Risk_Ratio";
      else if(SL_Buffer_ATR<0.0 || Max_SL_ATR<=0.0)
         problem="SL_Buffer_ATR must not be negative and Max_SL_ATR must be positive";
      else if(Entry_Window_Candles<1 || Entry_Window_Candles>100)
         problem="Entry_Window_Candles must be between 1 and 100";
     }
   if(problem=="") return true;
   Print("Liquidity Sweep Strategy: invalid input - ",problem,".");
   return false;
  }


struct MODEL_SWING
  {
   bool active;
   bool crossed;
   bool qualified;
   bool swept;
   datetime sweep_time;     // candle that swept the level (0 = not swept)
   double sweep_price;      // that candle's wick extreme beyond the level
   int  serial;
   int  pivot;              // bar index of the liquidity swing
   int  count;
   long volume;
   datetime start;
   double top;
   double bottom;
   string active_box;
   string zone;
   string level;
  };

void DrawStatus(const string text,const color colour=clrSilver)
  {
   if(!ModelDisplayEnabled()) return;
   string name=g_model_prefix+"STATUS";
   if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_LABEL,0,0,0)) return;
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,10);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,20);
   ObjectSetInteger(0,name,OBJPROP_COLOR,colour);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ChartRedraw();
  }

uint WithAlpha(const color value,const uchar alpha)
  {
   return ColorToARGB(value,alpha);
  }

datetime ProjectTime(const datetime value,const int bars)
  {
   int seconds=PeriodSeconds(SetupTimeframe());
   if(seconds<=0) seconds=60;
   return value+(datetime)(bars*seconds);
  }

// Time of a bar index; indices beyond the newest closed candle are projected.
// Measuring zone widths in bars (as Pine does) keeps them correct across
// weekends and session gaps.
datetime BarTime(const MqlRates &rates[],const int total,const int index)
  {
   if(index<total) return rates[index].time;
   return ProjectTime(rates[total-1].time,index-(total-1));
  }

void SetCommonObject(const string name)
  {
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

void CreateRectangle(const string name,const datetime left,const double top,
                     const datetime right,const double bottom,const color colour,
                     const uchar alpha)
  {
   if(!g_model_draw || !ObjectCreate(0,name,OBJ_RECTANGLE,0,left,top,right,bottom)) return;
   ObjectSetInteger(0,name,OBJPROP_COLOR,WithAlpha(colour,alpha));
   ObjectSetInteger(0,name,OBJPROP_FILL,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   SetCommonObject(name);
  }

void CreateLevel(const string name,const datetime left,const double price)
  {
   if(!g_model_draw || !ObjectCreate(0,name,OBJ_TREND,0,left,price,left,price)) return;
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrNONE);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   SetCommonObject(name);
  }

double Target(const MODEL_SWING &swing)
  {
   return Filter_Areas_By==MODEL_FILTER_COUNT?(double)swing.count:(double)swing.volume;
  }

// Loads every lower-timeframe candle in the window with one CopyRates call
// and maps each MTF candle to its slice (first index and count), instead of
// one CopyRates call per candle and per swing.
bool LoadIntrabar(const MqlRates &rates[],const int total,MqlRates &intrabar[],
                  int &first[],int &count[])
  {
   ArrayResize(first,total);
   ArrayResize(count,total);
   ArrayInitialize(first,0);
   ArrayInitialize(count,0);
   int seconds=PeriodSeconds(SetupTimeframe());
   ArraySetAsSeries(intrabar,false);
   int copied=CopyRates(_Symbol,Intrabar_Timeframe,rates[0].time,
                        rates[total-1].time+seconds-1,intrabar);
   if(copied<=0) return false;
   int cursor=0;
   for(int bar=0;bar<total;bar++)
     {
      while(cursor<copied && intrabar[cursor].time<rates[bar].time) cursor++;
      first[bar]=cursor;
      while(cursor<copied && intrabar[cursor].time<rates[bar].time+seconds) cursor++;
      count[bar]=cursor-first[bar];
     }
   return true;
  }

long OverlapVolume(const MqlRates &rates[],const int index,const double top,const double bottom,
                   const MqlRates &intrabar[],const int &intrabar_first[],
                   const int &intrabar_count[])
  {
   if(!Intrabar_Precision)
      return rates[index].low<top && rates[index].high>bottom?(long)rates[index].tick_volume:0;
   long result=0;
   int last=intrabar_first[index]+intrabar_count[index];
   for(int i=intrabar_first[index];i<last;i++)
      if(intrabar[i].low<top && intrabar[i].high>bottom)
         result+=(long)intrabar[i].tick_volume;
   return result;
  }

void StartSwing(MODEL_SWING &swing,const bool high,const MqlRates &pivot_bar,const int pivot,
                const int serial,const color area_colour)
  {
   swing.active=true;
   swing.crossed=false;
   swing.qualified=false;
   swing.swept=false;
   swing.sweep_time=0;
   swing.sweep_price=0.0;
   swing.serial=serial;
   swing.pivot=pivot;
   swing.count=0;
   swing.volume=0;
   swing.start=pivot_bar.time;
   swing.top=high?pivot_bar.high:(Swing_Area==MODEL_WICK_EXTREMITY?
                                  MathMin(pivot_bar.open,pivot_bar.close):pivot_bar.high);
   swing.bottom=high?(Swing_Area==MODEL_WICK_EXTREMITY?
                      MathMax(pivot_bar.open,pivot_bar.close):pivot_bar.low):pivot_bar.low;
   string side=high?"H_":"L_";
   string suffix=IntegerToString(serial);
   swing.active_box=g_model_prefix+side+"ACTIVE_"+suffix;
   swing.zone=g_model_prefix+side+"ZONE_"+suffix;
   swing.level=g_model_prefix+side+"LEVEL_"+suffix;
   CreateRectangle(swing.active_box,swing.start,swing.top,swing.start,swing.bottom,
                   area_colour,45);
   CreateLevel(swing.level,swing.start,high?swing.top:swing.bottom);
  }

// Only the latest liquidity swing on each side is tracked, as in the Pine
// source.  When it is replaced, remove its live projection box, drop a level
// that never qualified (it was never visible), and end an unbroken level
// where tracking stopped instead of leaving it projected into the future.
void FinishSwing(MODEL_SWING &swing,const bool high,const datetime end_time)
  {
   if(!swing.active) return;
   ObjectDelete(0,swing.active_box);
   if(!swing.qualified)
      ObjectDelete(0,swing.level);
   else if(!swing.crossed)
      ObjectMove(0,swing.level,1,end_time,high?swing.top:swing.bottom);
   swing.active=false;
  }

void DrawSweep(const MODEL_SWING &swing,const bool high,const MqlRates &bar,const color colour)
  {
   if(!g_model_draw || !Show_Liquidity_Sweeps) return;
   string name=g_model_prefix+(high?"H_SWEEP_":"L_SWEEP_")+IntegerToString(swing.serial);
   if(!ObjectCreate(0,name,high?OBJ_ARROW_DOWN:OBJ_ARROW_UP,0,bar.time,high?bar.high:bar.low))
      return;
   ObjectSetInteger(0,name,OBJPROP_COLOR,colour);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,high?ANCHOR_BOTTOM:ANCHOR_TOP);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,"Liquidity sweep of "+(high?"LH ":"HL ")+
                   DoubleToString(high?swing.top:swing.bottom,_Digits));
   SetCommonObject(name);
  }

// Advances one tracked swing by the closed MTF candle `now`.  As in Pine,
// overlap counts use the candle Swing_Detection_Length bars earlier.  A close
// beyond the level crosses (breaks) it; a wick beyond it with a close back
// inside sweeps its resting liquidity.  Returns true when `now` swept it.
bool UpdateSwing(MODEL_SWING &swing,const bool high,const MqlRates &rates[],const int total,
                 const int now,const int length,const MqlRates &intrabar[],
                 const int &intrabar_first[],const int &intrabar_count[],
                 const color line_colour,const color area_colour)
  {
   if(!swing.active) return false;
   int counted=now-length;
   bool overlaps=rates[counted].low<swing.top && rates[counted].high>swing.bottom;
   double previous=Target(swing);
   if(overlaps) swing.count++;
   swing.volume+=OverlapVolume(rates,counted,swing.top,swing.bottom,intrabar,
                               intrabar_first,intrabar_count);
   double target=Target(swing);

   if(!swing.qualified && previous<=Filter_Value && target>Filter_Value)
     {
      swing.qualified=true;
      CreateRectangle(swing.zone,swing.start,swing.top,
                      BarTime(rates,total,swing.pivot+swing.count),swing.bottom,area_colour,128);
      ObjectSetInteger(0,swing.level,OBJPROP_COLOR,line_colour);
     }
   if(swing.qualified)
      ObjectMove(0,swing.zone,1,BarTime(rates,total,swing.pivot+swing.count),swing.bottom);

   double level=high?swing.top:swing.bottom;
   bool swept=false;
   // sweep_price keeps the most extreme wick from the sweep candle onwards, so
   // a stop placed after a later, deeper wick is still beyond all of them.
   if(!swing.crossed && ((high && rates[now].close>swing.top) ||
                         (!high && rates[now].close<swing.bottom)))
     {
      swing.crossed=true;
      ObjectMove(0,swing.level,1,rates[now].time,level);
      ObjectSetInteger(0,swing.level,OBJPROP_STYLE,STYLE_DASH);
     }
   else if(!swing.crossed && !swing.swept && swing.qualified &&
           ((high && rates[now].high>swing.top) || (!high && rates[now].low<swing.bottom)))
     {
      swing.swept=true;
      swing.sweep_time=rates[now].time;
      swing.sweep_price=high?rates[now].high:rates[now].low;
      swept=true;
      g_sweep_count++;
      DrawSweep(swing,high,rates[now],line_colour);
     }
   else if(swing.swept && !swing.crossed)
      swing.sweep_price=high?MathMax(swing.sweep_price,rates[now].high)
                            :MathMin(swing.sweep_price,rates[now].low);

   datetime active_right=swing.crossed?swing.start:ProjectTime(rates[now].time,3);
   ObjectMove(0,swing.active_box,1,active_right,swing.bottom);
   if(!swing.crossed)
      ObjectMove(0,swing.level,1,ProjectTime(rates[now].time,3),level);
   return swept;
  }

// Starts tracking a newly identified liquidity swing.  Identification waits
// for the following opposite-side structure point, so the candles between
// the swing's own confirmation and `now` are replayed immediately: overlap
// counts, crossing and sweeps are then identical to tracking it from its
// confirmation.  Returns true when candle `now` swept it.
bool StartLiquidity(MODEL_SWING &swing,const bool high,const MqlRates &rates[],const int total,
                    const int length,const int pivot,const int now,const int serial,
                    const MqlRates &intrabar[],const int &intrabar_first[],
                    const int &intrabar_count[],const color line_colour,const color area_colour)
  {
   FinishSwing(swing,high,rates[now].time);
   StartSwing(swing,high,rates[pivot],pivot,serial,area_colour);
   bool swept_now=false;
   for(int bar=pivot+length+1;bar<=now;bar++)
      swept_now=UpdateSwing(swing,high,rates,total,bar,length,intrabar,intrabar_first,
                            intrabar_count,line_colour,area_colour);
   return swept_now;
  }

bool LiquidityAlertsEnabled()
  {
   return Alert_On_Liquidity_Sweep && (Enable_Popup_Alerts || Enable_Push_Notifications);
  }

void SendLiquidityAlert(const string text,const datetime bar_time)
  {
   static datetime last_alert=0;
   if(bar_time<=last_alert) return;
   last_alert=bar_time;
   string message=_Symbol+" "+TimeframeName(SetupTimeframe())+" "+text;
   if(Enable_Popup_Alerts) Alert(message);
   if(Enable_Push_Notifications) SendNotification(message);
  }

void DeleteModelObjects()
  {
   ObjectsDeleteAll(0,g_model_prefix);
  }

// Rebuilds MTF liquidity when a new MTF candle closes or the HTF state
// changes.  Liquidity is drawn only on the MTF chart; on other charts it is
// evaluated (without drawing) only when sweep alerts are enabled.  Returns
// false while data is still loading so the timer can retry.
//
// One replay of the MTF structure supplies both the chart's HH/HL/LH/LL
// labels and the liquidity swings.  With an established bearish HTF bias an
// LH becomes liquidity when the next structure low is an LL; with a bullish
// bias an HL becomes liquidity when the next structure high is an HH.  A
// transitional or consolidating HTF bias identifies no liquidity.
bool RebuildModel()
  {
   g_model_draw=ModelDisplayEnabled();
   if(!g_model_draw && !LiquidityAlertsEnabled() && !TradingActive())
     {
      if(g_model_last_bar!=0) DeleteModelObjects();
      g_model_last_bar=0;
      return true;
     }
   ENUM_TIMEFRAMES timeframe=SetupTimeframe();
   datetime current_bar=iTime(_Symbol,timeframe,0);
   if(current_bar<=0)
     {
      g_zone_valid=false;
      DrawStatus("Liquidity: waiting for "+TimeframeName(timeframe)+" history...",clrOrange);
      return false;
     }
   if(!g_htf_ready)
     {
      g_zone_valid=false;
      DrawStatus("Liquidity: waiting for the HTF market bias...",clrOrange);
      return false;
     }
   int state_code=g_htf_structure.direction*2+(g_htf_structure.last_break_was_bos?1:0);
   if(current_bar==g_model_last_bar && state_code==g_model_last_state) return true;

   int length=SwingLength();
   int minimum=2*length+2;
   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   int copied=CopyRates(_Symbol,timeframe,1,ChartStructureBars(timeframe),rates);
   if(copied<minimum)
     {
      g_zone_valid=false;
      DrawStatus("Liquidity: insufficient "+TimeframeName(timeframe)+" bars ("+
                 IntegerToString(MathMax(copied,0))+"/"+IntegerToString(minimum)+")",clrOrange);
      return false;
     }
   MqlRates intrabar[];
   int intrabar_first[],intrabar_count[];
   if(Intrabar_Precision && !LoadIntrabar(rates,copied,intrabar,intrabar_first,intrabar_count))
     {
      DrawStatus("Liquidity: waiting for "+TimeframeName(Intrabar_Timeframe)+
                 " intrabar history...",clrOrange);
      return false;
     }

   // The first build after attaching never alerts.
   bool permit_alert=g_model_last_bar!=0;
   g_model_last_bar=current_bar;
   g_model_last_state=state_code;

   BASE_STRUCTURE_STATE state;
   BASE_STRUCTURE_POINT points[];
   BASE_STRUCTURE_EVENT events[];
   ReplayStructure(rates,copied,length,state,points,events);
   DeleteModelObjects();
   g_trade_status="";
   int point_count=ArraySize(points);
   if(g_model_draw && Show_Swing_Points)
      for(int i=0;i<point_count;i++)
         if(!points[i].superseded && points[i].kind!=0)
            CreateStructureLabel(g_model_prefix,StructureLabel(points[i]),points[i].time,
                                 points[i].price);

   int market_bias=DefiniteBias(g_htf_structure)?g_htf_structure.direction:0;
   MODEL_SWING ph,pl;
   ZeroMemory(ph);
   ZeroMemory(pl);
   g_sweep_count=0;
   int high_serial=0,low_serial=0;
   int next_point=0,high_leg=-1,low_leg=-1,used_high=-1,used_low=-1;
   bool latest_high_sweep=false,latest_low_sweep=false;
   for(int now=length;now<copied;now++)
     {
      bool started_high=false,started_low=false,swept_high=false,swept_low=false;
      while(next_point<point_count && points[next_point].confirmed<=now)
        {
         int p=next_point++;
         if(points[p].side>0)
           {
            high_leg=p;
            // Same-leg replacements can re-confirm an HH; each HL becomes
            // liquidity at most once.
            if(market_bias>0 && Show_Swing_Low && points[p].kind>0 && low_leg>=0 &&
               points[low_leg].kind<0 && used_low!=low_leg)
              {
               used_low=low_leg;
               swept_low=StartLiquidity(pl,false,rates,copied,length,points[low_leg].pivot,now,
                                        ++low_serial,intrabar,intrabar_first,intrabar_count,
                                        Swing_Low_Color,Swing_Low_Area_Color);
               started_low=true;
              }
           }
         else
           {
            low_leg=p;
            if(market_bias<0 && Show_Swing_High && points[p].kind>0 && high_leg>=0 &&
               points[high_leg].kind<0 && used_high!=high_leg)
              {
               used_high=high_leg;
               swept_high=StartLiquidity(ph,true,rates,copied,length,points[high_leg].pivot,now,
                                         ++high_serial,intrabar,intrabar_first,intrabar_count,
                                         Swing_High_Color,Swing_High_Area_Color);
               started_high=true;
              }
           }
        }
      if(ph.active && !started_high)
         swept_high=UpdateSwing(ph,true,rates,copied,now,length,intrabar,intrabar_first,
                                intrabar_count,Swing_High_Color,Swing_High_Area_Color);
      if(pl.active && !started_low)
         swept_low=UpdateSwing(pl,false,rates,copied,now,length,intrabar,intrabar_first,
                               intrabar_count,Swing_Low_Color,Swing_Low_Area_Color);
      if(now==copied-1)
        {
         latest_high_sweep=swept_high;
         latest_low_sweep=swept_low;
        }
     }

   // Offer the live (visible, unbroken) zone on the bias side for trading.
   g_zone_valid=false;
   datetime window_start=rates[MathMax(0,copied-Entry_Window_Candles)].time;
   if(market_bias<0 && ph.active && ph.qualified && !ph.crossed)
      SetTradeZone(-1,ph,window_start);
   if(market_bias>0 && pl.active && pl.qualified && !pl.crossed)
      SetTradeZone(1,pl,window_start);

   string text="Liquidity "+TimeframeName(timeframe)+" | HTF "+BiasText(g_htf_structure)+" | ";
   if(market_bias<0)
      text+=IntegerToString(high_serial)+" LH->LL swing"+(high_serial==1?"":"s");
   else if(market_bias>0)
      text+=IntegerToString(low_serial)+" HL->HH swing"+(low_serial==1?"":"s");
   else
      text+="none until the HTF bias is established";
   if(market_bias!=0) text+=", "+IntegerToString(g_sweep_count)+" swept";
   DrawStatus(text,(market_bias!=0 && high_serial+low_serial>0)?clrSilver:clrOrange);

   if(permit_alert && Alert_On_Liquidity_Sweep)
     {
      if(latest_high_sweep)
         SendLiquidityAlert("bearish liquidity sweep above LH "+DoubleToString(ph.top,_Digits),
                            rates[copied-1].time);
      if(latest_low_sweep)
         SendLiquidityAlert("bullish liquidity sweep below HL "+DoubleToString(pl.bottom,_Digits),
                            rates[copied-1].time);
     }
   ChartRedraw();
   return true;
  }

// ---------------------------------------------------------------------------
// Trading.  Entries are taken at the live MTF liquidity zone published by
// RebuildModel, in the direction of the established HTF bias, and only while
// the Base analysis (published by Rebuild) says the market is tradable and
// the enabled optimal conditions pass.
// ---------------------------------------------------------------------------

bool TradingActive()
  {
   if(Trade_Mode==LSS_TRADING_OFF) return false;
   if(MQLInfoInteger(MQL_TESTER)!=0) return true;
   return Trade_Mode==LSS_TRADING_LIVE;
  }

// Publishes the live zone.  Its sweep is "fresh" while the sweep candle is one
// of the newest Entry_Window_Candles closed MTF candles (window_start is the
// oldest of them), which limits the entry to that many candles after it.
void SetTradeZone(const int side,const MODEL_SWING &swing,const datetime window_start)
  {
   g_zone_valid=true;
   g_zone_side=side;
   g_zone_top=swing.top;
   g_zone_bottom=swing.bottom;
   g_zone_id=swing.start;
   g_zone_sweep_time=swing.sweep_time;
   g_zone_sweep_price=swing.sweep_price;
   g_zone_fresh_sweep=swing.swept && swing.sweep_time>=window_start;
  }

void DrawTradeStatus(const string text)
  {
   if(!ModelDisplayEnabled() || text==g_trade_status) return;
   g_trade_status=text;
   string name=g_model_prefix+"TRADE_STATUS";
   if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_LABEL,0,0,0)) return;
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,10);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,38);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrSilver);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   ObjectSetString(0,name,OBJPROP_TEXT,"Trading: "+text);
  }

// Journals why a zone was not traded, once per zone and reason.
void NoteRejection(const string reason)
  {
   DrawTradeStatus("blocked at the zone - "+reason);
   if(g_zone_id==g_rejected_zone_id && reason==g_rejected_reason) return;
   g_rejected_zone_id=g_zone_id;
   g_rejected_reason=reason;
   if(MQLInfoInteger(MQL_OPTIMIZATION)==0)
      Print("Liquidity Sweep Strategy: ",(g_zone_side<0?"LH":"HL")," zone ",
            DoubleToString(g_zone_bottom,_Digits),"-",DoubleToString(g_zone_top,_Digits),
            " not traded: ",reason);
  }

bool FindPosition(ulong &ticket)
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

// The broker's minimum distance between the market and a stop order.
double MinimumStopDistance()
  {
   long level=MathMax(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),
                      SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL));
   return (double)(level+1)*_Point;
  }

// "At or approaching" a Market High/Low or trendline: within the dashboard's
// clearance (Boundary_Clearance_ATR x LTF ATR) of the entry price, or, with
// Require_Clear_Path_To_Target, anywhere between the entry and the target.
// Trendline zones are projected to the current boundary-timeframe candle.
string SpaceBlocker(const double entry,const double target)
  {
   if(!g_have_clearance) return "LTF ATR is unavailable for the clearance check";
   // Without the full boundary history an absent Market High/Low or trendline
   // could simply be unknown, so the space requirement cannot be confirmed.
   if(!g_boundaries_complete)
      return "not enough "+TimeframeName(BoundaryTimeframe())+" history yet for the Market High/Low and trendline checks";
   double path_low=MathMin(entry,target),path_high=MathMax(entry,target);
   if(g_have_market_high)
     {
      if(MathAbs(g_market_high-entry)<=g_clearance) return "at or approaching the Market High";
      if(Require_Clear_Path_To_Target && g_market_high>path_low && g_market_high<path_high)
         return "the Market High lies before the target";
     }
   if(g_have_market_low)
     {
      if(MathAbs(entry-g_market_low)<=g_clearance) return "at or approaching the Market Low";
      if(Require_Clear_Path_To_Target && g_market_low>path_low && g_market_low<path_high)
         return "the Market Low lies before the target";
     }
   int shift=iBarShift(_Symbol,BoundaryTimeframe(),g_trend_time,false);
   if(shift<0) shift=0;
   int count=ArraySize(g_trend_top);
   for(int i=0;i<count;i++)
     {
      double top=g_trend_top[i]+g_trend_slope[i]*shift;
      double bottom=g_trend_bottom[i]+g_trend_slope[i]*shift;
      if(entry>=bottom-g_clearance && entry<=top+g_clearance)
         return "at or approaching a trendline";
      if(Require_Clear_Path_To_Target && top>path_low && bottom<path_high)
         return "a trendline lies before the target";
     }
   return "";
  }

// Volume for the trade: Risk_Percent of the balance lost at the stop, or
// Fixed_Lots.  Returns 0 when the result is below the symbol's minimum.
double TradeVolume(const bool sell,const double entry,const double sl)
  {
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double minimum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maximum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double lots=Fixed_Lots;
   if(Lot_Sizing==LSS_RISK_PERCENT)
     {
      double loss=0.0;
      if(!OrderCalcProfit(sell?ORDER_TYPE_SELL:ORDER_TYPE_BUY,_Symbol,1.0,entry,sl,loss) ||
         loss>=0.0)
         return 0.0;
      lots=AccountInfoDouble(ACCOUNT_BALANCE)*Risk_Percent/100.0/(-loss);
     }
   if(step>0.0)
     {
      lots=MathFloor(lots/step+1e-8)*step;
      lots=NormalizeDouble(lots,(int)MathMax(0.0,MathCeil(-MathLog10(step)-1e-8)));
     }
   if(lots<minimum) return 0.0;
   return MathMin(lots,maximum);
  }

// Checks every entry requirement at the current price and, when all pass,
// fills in the order.  Returns the first failed requirement, or "".
string PlanEntry(const bool sell,const double entry,const double spread,
                 double &sl,double &tp,double &lots)
  {
   int direction=sell?-1:1;
   if(!DefiniteBias(g_htf_structure) || g_htf_structure.direction!=direction)
      return "the HTF bias is not established in the trade direction";
   if(!g_tradeable) return "the market is not tradable";
   if(g_optimal_block!="") return "optimal conditions not met ("+g_optimal_block+")";
   double atr[];
   if(!CopyIndicator(g_setup_atr_handle,0,1,atr) || atr[0]==EMPTY_VALUE || atr[0]<=0.0)
      return "the MTF ATR is unavailable";

   // The sweep has already traded beyond the zone, so the stop sits beyond
   // the most extreme wick since the sweep, including the forming MTF candle,
   // by SL_Buffer_ATR MTF ATRs.  A sell stop is triggered by the ask, so the
   // spread is added to keep it behind the wick as drawn on the (bid) chart.
   double buffer=SL_Buffer_ATR*atr[0];
   double extreme=sell?MathMax(g_zone_top,g_zone_sweep_price):MathMin(g_zone_bottom,g_zone_sweep_price);
   double forming=sell?iHigh(_Symbol,SetupTimeframe(),0):iLow(_Symbol,SetupTimeframe(),0);
   if(forming>0.0) extreme=sell?MathMax(extreme,forming):MathMin(extreme,forming);
   sl=sell?AlignPrice(extreme+buffer+spread,1):AlignPrice(extreme-buffer,-1);
   double risk=sell?sl-entry:entry-sl;
   double minimum=MinimumStopDistance();
   if(risk<minimum)
     {
      risk=minimum;
      sl=sell?AlignPrice(entry+risk,1):AlignPrice(entry-risk,-1);
      risk=sell?sl-entry:entry-sl;
     }
   if(risk>Max_SL_ATR*atr[0])
      return "a stop beyond the sweep would exceed "+DoubleToString(Max_SL_ATR,1)+" MTF ATR";
   tp=AlignPrice(sell?entry-Reward_Risk_Ratio*risk:entry+Reward_Risk_Ratio*risk,0);

   string space=SpaceBlocker(entry,tp);
   if(space!="") return space;

   lots=TradeVolume(sell,entry,sl);
   if(lots<=0.0) return "the position size is below the minimum volume";
   double margin=0.0;
   if(OrderCalcMargin(sell?ORDER_TYPE_SELL:ORDER_TYPE_BUY,_Symbol,lots,entry,margin) &&
      margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE))
      return "insufficient free margin";
   return "";
  }

// Enters after the live zone has been swept: an MTF candle's wick traded
// beyond the zone's level and the candle closed back inside.  The entry is
// taken within Entry_Window_Candles MTF candles after the sweep candle, on the
// first tick at which every requirement passes and price is still back inside
// the swept level.  A zone is swept once, so each zone is traded at most once,
// with one position open at a time.
void CheckEntry()
  {
   ulong ticket=0;
   if(FindPosition(ticket))
     {
      DrawTradeStatus("position open");
      return;
     }
   if(!g_zone_valid || !g_conditions_ready)
     {
      DrawTradeStatus("no live liquidity zone");
      return;
     }
   string zone_text=(g_zone_side<0?"sell LH zone ":"buy HL zone ")+
                    DoubleToString(g_zone_bottom,_Digits)+"-"+DoubleToString(g_zone_top,_Digits);
   if(g_zone_id==g_traded_zone_id)
     {
      DrawTradeStatus(zone_text+" already traded");
      return;
     }
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0.0 || tick.ask<=0.0) return;
   bool sell=g_zone_side<0;
   if(g_zone_sweep_time==0)
     {
      DrawTradeStatus("waiting for a sweep of the "+zone_text);
      return;
     }
   if(!g_zone_fresh_sweep)
     {
      DrawTradeStatus(zone_text+" was swept without an entry");
      return;
     }
   double entry=sell?tick.bid:tick.ask;
   if(sell?entry>g_zone_top:entry<g_zone_bottom)
     {
      DrawTradeStatus(zone_text+" swept; waiting for price to return inside the level");
      return;
     }
   if(MQLInfoInteger(MQL_TESTER)==0 &&
      (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)==0 || MQLInfoInteger(MQL_TRADE_ALLOWED)==0))
     {
      NoteRejection("Algo Trading is disabled");
      return;
     }
   double sl=0.0,tp=0.0,lots=0.0;
   string reason=PlanEntry(sell,entry,tick.ask-tick.bid,sl,tp,lots);
   if(reason!="")
     {
      NoteRejection(reason);
      return;
     }
   string comment="LSS "+(sell?"LH ":"HL ")+DoubleToString(sell?g_zone_top:g_zone_bottom,_Digits);
   bool sent=sell?g_trade.Sell(lots,_Symbol,0.0,sl,tp,comment)
                 :g_trade.Buy(lots,_Symbol,0.0,sl,tp,comment);
   uint retcode=g_trade.ResultRetcode();
   // A zone is used up even when the request fails, so a rejected order
   // (for example invalid stops) cannot be resent on every tick.
   g_traded_zone_id=g_zone_id;
   if(sent && (retcode==TRADE_RETCODE_DONE || retcode==TRADE_RETCODE_PLACED))
     {
      DrawTradeStatus("position open");
      if(MQLInfoInteger(MQL_OPTIMIZATION)==0)
         Print("Liquidity Sweep Strategy: ",sell?"sell ":"buy ",DoubleToString(lots,2),
               " at ",DoubleToString(entry,_Digits)," SL ",DoubleToString(sl,_Digits),
               " TP ",DoubleToString(tp,_Digits)," (",zone_text,")");
     }
   else
      Print("Liquidity Sweep Strategy: order for the ",zone_text," failed - ",
            g_trade.ResultRetcodeDescription());
  }

// Moves the stop to the entry price once price has travelled Breakeven_At_R
// times the initial risk.  The initial risk is recovered from the take profit
// (TP = Reward_Risk_Ratio x risk), so nothing has to survive a restart.
void ManagePosition()
  {
   if(Breakeven_At_R<=0.0) return;
   ulong ticket=0;
   if(!FindPosition(ticket)) return;
   double open=PositionGetDouble(POSITION_PRICE_OPEN);
   double sl=PositionGetDouble(POSITION_SL);
   double tp=PositionGetDouble(POSITION_TP);
   if(tp<=0.0 || sl<=0.0) return;
   bool buy=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
   bool at_breakeven=buy?sl>=open:sl<=open;
   if(at_breakeven || ticket==g_breakeven_failed_ticket) return;
   double risk=MathAbs(tp-open)/Reward_Risk_Ratio;
   MqlTick tick;
   if(risk<=0.0 || !SymbolInfoTick(_Symbol,tick)) return;
   double progress=buy?tick.bid-open:open-tick.ask;
   if(progress<Breakeven_At_R*risk || progress<MinimumStopDistance()) return;
   if(!g_trade.PositionModify(ticket,open,tp))
     {
      g_breakeven_failed_ticket=ticket;
      Print("Liquidity Sweep Strategy: moving the stop to breakeven failed - ",
            g_trade.ResultRetcodeDescription());
     }
  }

int OnInit()
  {
   if(!ValidInputs()) return INIT_PARAMETERS_INCORRECT;
   // MT5 keeps an EA's global variables across a chart timeframe change, so
   // explicitly forget the previous chart's builds.  Otherwise a first build
   // that waits for data would not be retried until the next candle.
   g_last_ltf_bar=0;
   g_last_structure_bar=0;
   g_last_setup_bar=0;
   g_model_last_bar=0;
   g_model_last_state=-99;
   g_htf_ready=false;
   g_conditions_ready=false;
   g_zone_valid=false;
   g_zone_fresh_sweep=false;
   g_trade_status="";
   ENUM_TIMEFRAMES timeframe=BASETimeframe();
   g_prefix="BASE_"+(string)ChartID()+"_";
   g_model_prefix="ModelBase_"+IntegerToString(ChartID())+"_";
   if(Use_MA_Filter && (g_ma_handle=iMA(_Symbol,timeframe,MA_Length,0,BASEMAMethod(MA_Type),PRICE_CLOSE))==INVALID_HANDLE) return INIT_FAILED;
   if(Use_HTF_MA_Filter && (g_htf_ma_handle=iMA(_Symbol,HTF_Timeframe,HTF_MA_Length,0,BASEMAMethod(HTF_MA_Type),PRICE_CLOSE))==INVALID_HANDLE) return INIT_FAILED;
   if(Use_ADX_Filter && (g_adx_handle=iADX(_Symbol,timeframe,ADX_Length))==INVALID_HANDLE) return INIT_FAILED;
   if(Use_ATR_Filter && (g_atr_handle=iATR(_Symbol,timeframe,ATR_Length))==INVALID_HANDLE) return INIT_FAILED;
   if((g_ltf_atr_handle=iATR(_Symbol,LTFTimeframe(),ATR_Length))==INVALID_HANDLE) return INIT_FAILED;
   if((g_trend_atr_handle=iATR(_Symbol,BoundaryTimeframe(),ATR_Length))==INVALID_HANDLE) return INIT_FAILED;
   if(Trade_Mode!=LSS_TRADING_OFF)
     {
      if((g_setup_atr_handle=iATR(_Symbol,SetupTimeframe(),ATR_Length))==INVALID_HANDLE) return INIT_FAILED;
      g_trade.SetExpertMagicNumber(Magic_Number);
      g_trade.SetDeviationInPoints(20);
      g_trade.SetTypeFillingBySymbol(_Symbol);
      g_trade.LogLevel(LOG_LEVEL_ERRORS);
     }
   if(!EventSetTimer(2)) return INIT_FAILED;
   RefreshForCurrentChart();
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
   if(g_trend_atr_handle!=INVALID_HANDLE) IndicatorRelease(g_trend_atr_handle);
   if(g_setup_atr_handle!=INVALID_HANDLE) IndicatorRelease(g_setup_atr_handle);
   g_setup_atr_handle=INVALID_HANDLE;
   g_ma_handle=INVALID_HANDLE;
   g_htf_ma_handle=INVALID_HANDLE;
   g_adx_handle=INVALID_HANDLE;
   g_atr_handle=INVALID_HANDLE;
   g_ltf_atr_handle=INVALID_HANDLE;
   g_trend_atr_handle=INVALID_HANDLE;
   ObjectsDeleteAll(0,g_prefix);
   DeleteModelObjects();
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

// Both engines only do work when a relevant candle closes (or the HTF state
// changes); otherwise a tick or timer event costs a few iTime lookups.
void RefreshForCurrentChart()
  {
   CheckForBar();
   RebuildModel();
  }

void OnTick()
  {
   RefreshForCurrentChart();
   if(!TradingActive()) return;
   ManagePosition();
   CheckEntry();
  }
void OnTimer() { RefreshForCurrentChart(); }

void OnChartEvent(const int id,const long &lparam,const double &dparam,
                  const string &sparam)
  {
   // Scrolling, zooming and resizing raise CHART_CHANGE continuously.  Both
   // engines use fixed history windows, so these events cannot change what
   // is drawn and must not trigger a redraw.  A timeframe change reinitialises
   // the EA through OnInit.  Only a build still waiting for data is retried
   // here, sooner than the two-second timer.
   if(id!=CHARTEVENT_CHART_CHANGE) return;
   if(g_last_ltf_bar==0 || (ModelDisplayEnabled() && g_model_last_bar==0))
      RefreshForCurrentChart();
  }
