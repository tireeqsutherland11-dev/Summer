#property copyright "Market Trend Analyser conversion"
#property version   "1.69"
#property strict
#property description "Road: MT5 port of the Market Trend Analyser Pine Script."
#property description "Signal/visualisation EA only; the source indicator contains no trading rules."

enum ROAD_MA_TYPE { ROAD_SMA=0, ROAD_EMA=1 };
enum ROAD_MA_FILTER_MODE { ROAD_PRICE_ABOVE_BELOW=0, ROAD_FULL_BODY_CLOSE=1 };
enum ROAD_SESSION { ROAD_NEW_YORK=0, ROAD_LONDON=1, ROAD_TOKYO=2, ROAD_SYDNEY=3, ROAD_CUSTOM=4, ROAD_24X7=5 };
enum ROAD_ADX_SCOPE { ROAD_BOS_ONLY=0, ROAD_BOS_AND_CHOCH=1 };
enum ROAD_ATR_MODE { ROAD_ATR_MINIMUM=0, ROAD_ATR_MAXIMUM=1, ROAD_ATR_RANGE=2 };
enum ROAD_LABEL_SIZE { ROAD_TINY=7, ROAD_SMALL=9, ROAD_NORMAL=11, ROAD_LARGE=14 };
enum ROAD_TREND_PIVOT_SOURCE { ROAD_TREND_HIGH_LOW=0, ROAD_TREND_CLOSE=1 };

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
input ROAD_LABEL_SIZE Label_Size=ROAD_SMALL;
input bool Show_Structure_Lines=true;
input ENUM_LINE_STYLE Line_Style=STYLE_DASH;
input int Line_Width=1;

input group "MA Filter (LTF)"
input bool Use_MA_Filter=true;
input int MA_Length=50;
input ROAD_MA_TYPE MA_Type=ROAD_EMA;
input bool Show_MA_Line=false;
input color MA_Color=clrBlue;

input group "MA Filter (HTF)"
input bool Use_HTF_MA_Filter=true;
input ENUM_TIMEFRAMES HTF_Timeframe=PERIOD_H1;
input int HTF_MA_Length=100;
input ROAD_MA_TYPE HTF_MA_Type=ROAD_EMA; // MA Type
input bool Show_HTF_MA_Line=false;
input color HTF_MA_Color=clrOrange;

input group "Session Filter"
input bool Use_Session_Filter=false;
input ROAD_SESSION Session_Preset=ROAD_NEW_YORK;
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

// Internal tuning values are deliberately kept out of the Inputs dialog. The
// streamlined UI exposes only settings that are useful during normal use.
const ROAD_TREND_PIVOT_SOURCE Trendline_Pivot_Source=ROAD_TREND_HIGH_LOW;
const int Trendline_Pivot_Strength=10;
const ROAD_MA_FILTER_MODE MA_Filter_Mode=ROAD_PRICE_ABOVE_BELOW;
const ROAD_MA_FILTER_MODE HTF_MA_Filter_Mode=ROAD_PRICE_ABOVE_BELOW;
const double ADX_Minimum=25.0;
const ROAD_ADX_SCOPE Apply_ADX_Filter_To=ROAD_BOS_ONLY;
const ROAD_ATR_MODE ATR_Filter_Mode=ROAD_ATR_MINIMUM;
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

struct ROAD_STRUCTURE_STATE
  {
   int direction;
   bool last_break_was_bos;
   int last_high_kind;
   int last_low_kind;
   bool have_high;
   bool have_low;
   double last_high;
   double last_low;
  };

ENUM_TIMEFRAMES SetupTimeframe()
  {
   return Setup_Entry_Timeframe==PERIOD_CURRENT?(ENUM_TIMEFRAMES)_Period:Setup_Entry_Timeframe;
  }

ENUM_TIMEFRAMES LTFTimeframe()
  {
   return LTF_Timeframe==PERIOD_CURRENT?(ENUM_TIMEFRAMES)_Period:LTF_Timeframe;
  }

// Replays confirmed pivots on any timeframe without drawing them.  This keeps
// the structure and setup biases independent and prevents an HTF candle from
// being mistaken for lower-timeframe confirmation.
bool AnalyseStructure(const ENUM_TIMEFRAMES timeframe,const int wanted,
                      ROAD_STRUCTURE_STATE &state,MqlRates &rates[])
  {
   ArraySetAsSeries(rates,false);
   int total=CopyRates(_Symbol,timeframe,1,wanted,rates);
   int length=MathMax(1,MathMin(50,Swing_Detection_Length));
   if(total<2*length+2) return false;
   state.direction=0; state.last_break_was_bos=false;
   state.last_high_kind=0; state.last_low_kind=0;
   state.have_high=false; state.have_low=false;
   state.last_high=0.0; state.last_low=0.0;
   bool high_broken=false,low_broken=false;
   int last_pivot_side=0;
   bool have_high_reference=false,have_low_reference=false;
   double high_reference=0.0,low_reference=0.0;
   for(int i=length;i<total;i++)
     {
      int pivot=i-length;
      if(PivotHigh(rates,total,pivot,length))
        {
         double value=rates[pivot].high;
         int kind=0;
         if(AcceptStructureHigh(value,state.have_high,state.last_high,last_pivot_side,
                                have_high_reference,high_reference,kind))
           {
            state.last_high_kind=kind;
            high_broken=false;
           }
        }
      if(PivotLow(rates,total,pivot,length))
        {
         double value=rates[pivot].low;
         int kind=0;
         if(AcceptStructureLow(value,state.have_low,state.last_low,last_pivot_side,
                               have_low_reference,low_reference,kind))
           {
            state.last_low_kind=kind;
            low_broken=false;
           }
        }
      if(state.have_high && state.last_high_kind!=0 && !high_broken &&
         rates[i].close>state.last_high)
        {
         high_broken=true; state.direction=1;
         state.last_break_was_bos=state.last_high_kind>0;
        }
      if(state.have_low && state.last_low_kind!=0 && !low_broken &&
         rates[i].close<state.last_low)
        {
         low_broken=true; state.direction=-1;
         state.last_break_was_bos=state.last_low_kind>0;
        }
     }
   return true;
  }

bool DefiniteBias(const ROAD_STRUCTURE_STATE &state)
  {
   return (state.direction>0 && state.last_break_was_bos &&
           state.last_high_kind>0 && state.last_low_kind<0) ||
          (state.direction<0 && state.last_break_was_bos &&
           state.last_high_kind<0 && state.last_low_kind>0);
  }

bool DefiniteSetupBias(const ROAD_STRUCTURE_STATE &state)
  {
   // On the lower timeframe, CHoCH begins the transition and the next BOS
   // completes it. Later pivot classifications cannot make it transitional
   // again unless another CHoCH actually occurs.
   return state.direction!=0 && state.last_break_was_bos;
  }

string BiasText(const ROAD_STRUCTURE_STATE &state)
  {
   if(state.direction==0) return "Consolidating";
   bool definite=DefiniteBias(state);
   if(state.direction>0) return definite?"Bullish":"Bullish (Transition)";
   return definite?"Bearish":"Bearish (Transition)";
  }

string SetupBiasText(const ROAD_STRUCTURE_STATE &state)
  {
   if(state.direction==0) return "Consolidating";
   bool definite=DefiniteSetupBias(state);
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

ENUM_TIMEFRAMES BoundaryTimeframe()
  {
   return Boundary_Timeframe==PERIOD_CURRENT?(ENUM_TIMEFRAMES)_Period:Boundary_Timeframe;
  }

ENUM_TIMEFRAMES RoadTimeframe()
  {
   return Structure_Timeframe==PERIOD_CURRENT?(ENUM_TIMEFRAMES)_Period:Structure_Timeframe;
  }

ENUM_MA_METHOD RoadMAMethod(const ROAD_MA_TYPE value)
  {
   return value==ROAD_EMA?MODE_EMA:MODE_SMA;
  }

bool PivotHigh(const MqlRates &rates[],const int total,const int index,const int length)
  {
   if(index-length<0 || index+length>=total) return false;
   for(int i=index-length;i<=index+length;i++)
      if(i!=index && rates[i].high>=rates[index].high) return false;
   return true;
  }

bool PivotLow(const MqlRates &rates[],const int total,const int index,const int length)
  {
   if(index-length<0 || index+length>=total) return false;
   for(int i=index-length;i<=index+length;i++)
      if(i!=index && rates[i].low<=rates[index].low) return false;
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
   if(!Use_Session_Filter || Session_Preset==ROAD_24X7) return true;
   string session="0000-2359";
   int zone_offset=0;
   if(Session_Preset==ROAD_NEW_YORK) { session="0930-1600"; zone_offset=-300; }
   else if(Session_Preset==ROAD_LONDON) { session="0800-1700"; zone_offset=0; }
   else if(Session_Preset==ROAD_TOKYO) { session="0900-1500"; zone_offset=540; }
   else if(Session_Preset==ROAD_SYDNEY) { session="0800-1700"; zone_offset=600; }
   else { session=Custom_Session; zone_offset=Custom_UTC_Offset_Minutes; }
   int begin=0,end=0;
   if(!ParseSession(session,begin,end)) return false;
   datetime local_time=server_time+(zone_offset-Server_UTC_Offset_Minutes)*60;
   MqlDateTime stamp; TimeToStruct(local_time,stamp);
   int minute=stamp.hour*60+stamp.min;
   if(begin==end) return true;
   return begin<end?(minute>=begin && minute<end):(minute>=begin || minute<end);
  }

bool CopyIndicator(const int handle,const int buffer,const int count,double &values[])
  {
   ArrayResize(values,count);
   ArraySetAsSeries(values,false);
   return handle!=INVALID_HANDLE && BarsCalculated(handle)>=count+1 && CopyBuffer(handle,buffer,1,count,values)==count;
  }

bool HTFValues(const datetime time,double &ma,double &open,double &close)
  {
   int shift=iBarShift(_Symbol,HTF_Timeframe,time,false);
   // Pine's request.security(..., lookahead_off) exposes the containing HTF
   // candle only when that candle has closed. Earlier child bars use the
   // preceding completed HTF candle, avoiding historical future leakage.
   datetime htf_open_time=shift>=0?iTime(_Symbol,HTF_Timeframe,shift):0;
   int ltf_seconds=PeriodSeconds(RoadTimeframe());
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

bool TrendPivot(const MqlRates &rates[],const int total,const int index,
                const int strength,const bool high)
  {
   if(index-strength<0 || index+strength>=total) return false;
   double value=Trendline_Pivot_Source==ROAD_TREND_CLOSE?rates[index].close:
                (high?rates[index].high:rates[index].low);
   for(int i=index-strength;i<=index+strength;i++)
     {
      if(i==index) continue;
      double other=Trendline_Pivot_Source==ROAD_TREND_CLOSE?rates[i].close:
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
   string channel=g_prefix+"TREND_ZONE_"+id;
   if(ObjectCreate(0,channel,OBJ_CHANNEL,0,from_time,from_bottom,to_time,to_bottom,
                   from_time,from_top))
     {
      ObjectSetInteger(0,channel,OBJPROP_COLOR,TrendZoneColor(clr,Trendline_Zone_Transparency));
      ObjectSetInteger(0,channel,OBJPROP_FILL,true);
      ObjectSetInteger(0,channel,OBJPROP_RAY_RIGHT,true);
      ObjectSetInteger(0,channel,OBJPROP_BACK,true);
      ObjectSetInteger(0,channel,OBJPROP_SELECTABLE,false);
     }
   DrawSegment("TREND_TOP_"+id,from_time,from_top,to_time,to_top,
               TrendZoneColor(clr,50),STYLE_SOLID,1);
   DrawSegment("TREND_BOTTOM_"+id,from_time,from_bottom,to_time,to_bottom,
               TrendZoneColor(clr,50),STYLE_SOLID,1);
   ObjectSetInteger(0,g_prefix+"TREND_TOP_"+id,OBJPROP_RAY_RIGHT,true);
   ObjectSetInteger(0,g_prefix+"TREND_BOTTOM_"+id,OBJPROP_RAY_RIGHT,true);
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
         ArrayResize(prices,prices_count+1);
         ArrayResize(indices,prices_count+1);
         prices[prices_count]=Trendline_Pivot_Source==ROAD_TREND_CLOSE?rates[i].close:
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
            ArrayResize(candidate_y,candidate_count);
            ArrayResize(candidate_slope,candidate_count);
            ArrayResize(candidate_up,candidate_count);
            ArrayResize(candidate_down,candidate_count);
            ArrayResize(candidate_projected,candidate_count);
            ArrayResize(candidate_distance,candidate_count);
            ArrayResize(candidate_index,candidate_count);
            ArrayResize(candidate_touches,candidate_count);
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
        }
      double end_y=candidate_projected[rank];
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

void EvaluateTrendlineZones(bool &have_resistance,double &resistance_top,
                            double &resistance_bottom,bool &have_support,
                            double &support_top,double &support_bottom)
  {
   have_resistance=false;
   have_support=false;
   if(!Show_Trendline_Zones && !Use_Optimal_Conditions_Meter) return;
   double trend_atr[];
   if(!CopyIndicator(g_trend_atr_handle,0,1,trend_atr) || trend_atr[0]==EMPTY_VALUE)
      return;
   int wanted=Trendline_Bars_To_Apply+2*Trendline_Pivot_Strength+1;
   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   int total=CopyRates(_Symbol,BoundaryTimeframe(),1,wanted,rates);
   if(total<2*Trendline_Pivot_Strength+1) return;
   const double fixed_atr_multiplier=0.5;
   double threshold=trend_atr[0]*fixed_atr_multiplier;
   have_resistance=FindTrendZones(rates,total,threshold,true,resistance_top,resistance_bottom);
   have_support=FindTrendZones(rates,total,threshold,false,support_top,support_bottom);
  }

// Market High is the highest confirmed swing high in the boundary lookback;
// Market Low is the lowest confirmed swing low in those same bars.
void EvaluateSignificantSR(const datetime chart_time,const double current_price,
                           bool &have_market_high,double &market_high,
                           bool &have_market_low,double &market_low)
  {
   have_market_high=false;
   have_market_low=false;
   int length=MathMax(1,MathMin(20,SR_Pivot_Length));
   // Include older padding so a swing near the start of the lookback window
   // can still be identified without making the padding part of the search.
   MqlRates rates[]; ArraySetAsSeries(rates,false);
   int total=CopyRates(_Symbol,BoundaryTimeframe(),1,Boundary_Lookback_Bars+length,rates);
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

void DrawStructurePoint(const string kind,const datetime time,const double price)
  {
   if(!Show_Swing_Points) return;
   bool low=kind=="HL" || kind=="LL";
   color clr=low?clrTeal:clrIndianRed;
   DrawText("STRUCTURE_"+kind+"_"+(string)time,time,price,kind,clr,low,(int)Label_Size);
  }

// Structure drawings deliberately follow the chart period, while the state
// used by the dashboard is calculated separately on Structure_Timeframe.
// Preserve the same amount of elapsed history as Bars_To_Process represents
// on the structure timeframe (for example, 100 H1 bars become 400 M15 bars).
void DrawChartTimeframeStructure()
  {
   ENUM_TIMEFRAMES chart_timeframe=(ENUM_TIMEFRAMES)_Period;
   int structure_seconds=PeriodSeconds(RoadTimeframe());
   int chart_seconds=PeriodSeconds(chart_timeframe);
   if(structure_seconds<=0 || chart_seconds<=0) return;
   int wanted=(int)MathCeil((double)Bars_To_Process*structure_seconds/chart_seconds);
   wanted=MathMax(2*Swing_Detection_Length+2,MathMin(wanted,100000));
   MqlRates rates[]; ArraySetAsSeries(rates,false);
   int total=CopyRates(_Symbol,chart_timeframe,1,wanted,rates);
   int length=MathMax(1,MathMin(50,Swing_Detection_Length));
   if(total<2*length+2) return;

   bool have_high=false,have_low=false,high_broken=false,low_broken=false;
   int last_high_kind=0,last_low_kind=0;
   int last_pivot_side=0;
   bool have_high_reference=false,have_low_reference=false;
   double high_reference=0.0,low_reference=0.0;
   double last_high=0.0,last_low=0.0;
   datetime last_high_time=0,last_low_time=0;
   for(int i=length;i<total;i++)
     {
      int pivot=i-length;
      if(PivotHigh(rates,total,pivot,length))
        {
         double value=rates[pivot].high;
         int kind=0;
         bool replacing=last_pivot_side==1;
         int old_kind=last_high_kind;
         datetime old_time=last_high_time;
         if(AcceptStructureHigh(value,have_high,last_high,last_pivot_side,
                                have_high_reference,high_reference,kind))
           {
            if(replacing && old_kind!=0)
               ObjectDelete(0,g_prefix+"STRUCTURE_"+(old_kind>0?"HH_":"LH_")+(string)old_time);
            last_high_time=rates[pivot].time;
            last_high_kind=kind; high_broken=false;
            if(kind!=0) DrawStructurePoint(kind>0?"HH":"LH",last_high_time,last_high);
           }
        }
      if(PivotLow(rates,total,pivot,length))
        {
         double value=rates[pivot].low;
         int kind=0;
         bool replacing=last_pivot_side==-1;
         int old_kind=last_low_kind;
         datetime old_time=last_low_time;
         if(AcceptStructureLow(value,have_low,last_low,last_pivot_side,
                               have_low_reference,low_reference,kind))
           {
            if(replacing && old_kind!=0)
               ObjectDelete(0,g_prefix+"STRUCTURE_"+(old_kind>0?"LL_":"HL_")+(string)old_time);
            last_low_time=rates[pivot].time;
            last_low_kind=kind; low_broken=false;
            if(kind!=0) DrawStructurePoint(kind>0?"LL":"HL",last_low_time,last_low);
           }
        }
      if(have_high && last_high_kind!=0 && !high_broken && rates[i].close>last_high)
        {
         high_broken=true;
         DrawSignal(last_high_kind<0?"CHoCH":"BOS",1,last_high_time,last_high,rates[i]);
        }
      if(have_low && last_low_kind!=0 && !low_broken && rates[i].close<last_low)
        {
         low_broken=true;
         DrawSignal(last_low_kind<0?"CHoCH":"BOS",-1,last_low_time,last_low,rates[i]);
        }
     }
   if(Show_Swing_Points && have_high)
      DrawSegment("LAST_HIGH",last_high_time,last_high,rates[total-1].time,last_high,clrIndianRed,STYLE_DOT,1);
   if(Show_Swing_Points && have_low)
      DrawSegment("LAST_LOW",last_low_time,last_low,rates[total-1].time,last_low,clrTeal,STYLE_DOT,1);
  }

void SendRoadAlert(const string signal,const datetime bar_time)
  {
   static datetime last_alert=0;
   if(bar_time<=last_alert) return;
   last_alert=bar_time;
   string message=_Symbol+" "+EnumToString(RoadTimeframe())+" "+signal;
   if(Enable_Popup_Alerts) Alert(message);
   if(Enable_Push_Notifications) SendNotification(message);
  }

void DrawDashboardLine(const int row,const string value)
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
  }

void DrawDashboard(const string structure_bias,const string setup_bias,const string ltf_bias,
                   const bool bias_ready,const bool tradeable,const string tradeability_reason,
                   const bool optimal,const bool clear_space,const bool healthy_extension,
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
   DrawDashboardLine(row++,"Market Tradeability: "+(tradeable?"Tradable":"Not Tradable"));
   DrawDashboardLine(row++,"Tradeability Reason: "+tradeability_reason);
   row++;
   DrawDashboardLine(row++,"Optimal Conditions: "+(optimal?"OPTIMAL":"NOT OPTIMAL"));
   if(Use_Timeframe_Correlation_For_Optimal)
      DrawDashboardLine(row++,"Timeframe Correlation: "+(bias_ready?"PASS":"BLOCKED"));
   if(Use_Technical_Space_For_Optimal)
      DrawDashboardLine(row++,"Technical Space: "+(clear_space?"PASS":"BLOCKED"));
   if(Use_Healthy_Extension_For_Optimal)
      DrawDashboardLine(row++,"Healthy Extension: "+(healthy_extension?"PASS":"BLOCKED"));
   if(Use_Market_Volume_For_Optimal)
      DrawDashboardLine(row++,"Market Volume: "+(good_volume?"PASS":"BLOCKED")+
                              " ("+DoubleToString(volume_ratio,2)+"x average)");
   if(Use_Price_Momentum_For_Optimal)
      DrawDashboardLine(row++,"Price Momentum: "+(good_momentum?"PASS":"BLOCKED")+
                               " ("+DoubleToString(momentum_ratio,2)+"x average range)");
   DrawDashboardLine(row,"Reason: "+optimal_reason);
  }

// Returns false while history or an indicator is still being synchronized.
// This is especially important after a chart timeframe change: MT5 recreates
// the EA before all requested series are necessarily ready, so the timer must
// be allowed to retry the same bar instead of treating a partial build as done.
bool Rebuild(const bool permit_alert)
  {
   ENUM_TIMEFRAMES timeframe=RoadTimeframe();
   bool draw_anchored_structure=timeframe==(ENUM_TIMEFRAMES)_Period;
   int wanted=MathMax(100,MathMin(Bars_To_Process,100000));
   MqlRates rates[]; ArraySetAsSeries(rates,false);
   int total=CopyRates(_Symbol,timeframe,1,wanted,rates);
   int length=MathMax(1,MathMin(50,Swing_Detection_Length));
   if(total<2*length+2) return false;

   double ma[],adx[],atr[];
   if((Use_MA_Filter && !CopyIndicator(g_ma_handle,0,total,ma)) ||
      (Use_ADX_Filter && !CopyIndicator(g_adx_handle,0,total,adx)) ||
      ((Use_ATR_Filter || Use_Optimal_Conditions_Meter) && !CopyIndicator(g_atr_handle,0,total,atr))) return false;

   // Preflight the setup-timeframe inputs before clearing any existing chart
   // output.  A timeframe switch can make this series ready slightly later
   // than the structure series; retaining the previous display avoids a blank
   // chart while CheckForBar retries the rebuild.
   ROAD_STRUCTURE_STATE setup_state;
   MqlRates setup_rates[];
   bool have_setup=AnalyseStructure(SetupTimeframe(),wanted,setup_state,setup_rates);
   int setup_total=ArraySize(setup_rates);
   if(!have_setup) return false;

   ROAD_STRUCTURE_STATE ltf_state;
   MqlRates ltf_rates[];
   bool have_ltf=AnalyseStructure(LTFTimeframe(),wanted,ltf_state,ltf_rates);
   int ltf_total=ArraySize(ltf_rates);
   double ltf_atr_values[];
   bool have_ltf_atr=have_ltf && CopyIndicator(g_ltf_atr_handle,0,ltf_total,ltf_atr_values);
   if(!have_ltf || !have_ltf_atr) return false;

   ObjectsDeleteAll(0,g_prefix);
   bool have_high=false,have_low=false,high_broken=false,low_broken=false;
   // 1 means HH/LL, -1 means LH/HL, and 0 means that the first pivot in the
   // processed range has no preceding pivot against which it can be typed.
   int last_high_kind=0,last_low_kind=0;
   int last_pivot_side=0;
   bool have_high_reference=false,have_low_reference=false;
   double high_reference=0.0,low_reference=0.0;
   double last_high=0.0,last_low=0.0,last_htf_ma=0.0;
   datetime last_high_time=0,last_low_time=0,newest_signal_time=0;
   int structure=0;
   int last_break_direction=0;
   bool last_break_was_bos=false;
   string newest_signal="";
   bool dashboard_bull_bos=false,dashboard_bear_bos=false;
   bool dashboard_bull_choch=false,dashboard_bear_choch=false;
   bool dashboard_session=true,dashboard_adx=false,dashboard_atr=false;

   for(int i=length;i<total;i++)
     {
      int pivot=i-length;
      if(PivotHigh(rates,total,pivot,length))
        {
         double swing_high=rates[pivot].high;
         // A high can only be called HH or LH when both pivots are inside the
         // processed range.  Treating its first high as an HH would create a
         // false BOS without evidence of an earlier high.
         int high_kind=0;
         bool replacing=last_pivot_side==1;
         int old_kind=last_high_kind;
         datetime old_time=last_high_time;
         if(AcceptStructureHigh(swing_high,have_high,last_high,last_pivot_side,
                                have_high_reference,high_reference,high_kind))
           {
            if(draw_anchored_structure && replacing && old_kind!=0)
               ObjectDelete(0,g_prefix+"STRUCTURE_"+(old_kind>0?"HH_":"LH_")+(string)old_time);
            last_high_time=rates[pivot].time; high_broken=false;
            last_high_kind=high_kind;
            if(draw_anchored_structure && high_kind!=0)
               DrawStructurePoint(high_kind>0?"HH":"LH",last_high_time,last_high);
           }
        }
      if(PivotLow(rates,total,pivot,length))
        {
         double swing_low=rates[pivot].low;
         // As with highs, do not invent a type for the first visible low.
         int low_kind=0;
         bool replacing=last_pivot_side==-1;
         int old_kind=last_low_kind;
         datetime old_time=last_low_time;
         if(AcceptStructureLow(swing_low,have_low,last_low,last_pivot_side,
                               have_low_reference,low_reference,low_kind))
           {
            if(draw_anchored_structure && replacing && old_kind!=0)
               ObjectDelete(0,g_prefix+"STRUCTURE_"+(old_kind>0?"LL_":"HL_")+(string)old_time);
            last_low_time=rates[pivot].time; low_broken=false;
            last_low_kind=low_kind;
            if(draw_anchored_structure && low_kind!=0)
               DrawStructurePoint(low_kind>0?"LL":"HL",last_low_time,last_low);
           }
        }

      bool ma_long=true,ma_short=true;
      if(Use_MA_Filter)
        {
         ma_long=MA_Filter_Mode==ROAD_PRICE_ABOVE_BELOW?rates[i].close>ma[i]
                  :rates[i].close>ma[i] && rates[i].open>ma[i] && rates[i].close>rates[i].open;
         ma_short=MA_Filter_Mode==ROAD_PRICE_ABOVE_BELOW?rates[i].close<ma[i]
                   :rates[i].close<ma[i] && rates[i].open<ma[i] && rates[i].close<rates[i].open;
        }
      double htf_ma=0.0,htf_open=0.0,htf_close=0.0;
      bool htf_long=!Use_HTF_MA_Filter,htf_short=!Use_HTF_MA_Filter;
      if(Use_HTF_MA_Filter && HTFValues(rates[i].time,htf_ma,htf_open,htf_close))
        {
         htf_long=HTF_MA_Filter_Mode==ROAD_PRICE_ABOVE_BELOW?rates[i].close>htf_ma
                   :htf_close>htf_ma && htf_open>htf_ma && htf_close>htf_open;
         htf_short=HTF_MA_Filter_Mode==ROAD_PRICE_ABOVE_BELOW?rates[i].close<htf_ma
                    :htf_close<htf_ma && htf_open<htf_ma && htf_close<htf_open;
        }
      bool session=InSession(rates[i].time);
      bool adx_pass=!Use_ADX_Filter || (adx[i]!=EMPTY_VALUE && adx[i]>=ADX_Minimum);
      bool atr_pass=!Use_ATR_Filter || (atr[i]!=EMPTY_VALUE &&
                    (ATR_Filter_Mode==ROAD_ATR_MINIMUM?atr[i]>=ATR_Minimum:
                     ATR_Filter_Mode==ROAD_ATR_MAXIMUM?atr[i]<=ATR_Maximum:
                     atr[i]>=ATR_Minimum && atr[i]<=ATR_Maximum));
      bool long_direction=ma_long && htf_long && session;
      bool short_direction=ma_short && htf_short && session;
      bool choch_adx=!Use_ADX_Filter || Apply_ADX_Filter_To==ROAD_BOS_ONLY || adx_pass;
      bool bull_bos=long_direction && adx_pass && atr_pass;
      bool bear_bos=short_direction && adx_pass && atr_pass;
      bool bull_choch=long_direction && choch_adx && atr_pass;
      bool bear_choch=short_direction && choch_adx && atr_pass;

      // A structure break is confirmed only by a candle body closing beyond
      // the level.  A wick through a swing is a liquidity sweep, not a BOS or
      // CHoCH, and must leave the level available for a later confirmed close.
      bool bullish_break=have_high && last_high_kind!=0 && !high_broken && rates[i].close>last_high;
      bool bearish_break=have_low && last_low_kind!=0 && !low_broken && rates[i].close<last_low;
      // Only confirmed pivots are valid structure levels.  Expansion beyond
      // an unconfirmed candle extreme must not produce lower-timeframe BOS
      // noise on the structure timeframe.  Breaking an LH/HL changes
      // character; breaking an HH/LL continues structure with a BOS.
      if(bullish_break)
        {
         high_broken=true;
         // An HH made after an LH is a bullish change of character.  An HH
         // made by breaking an HH is bullish continuation (BOS).
         if(last_high_kind<0)
           {
            // Structure events are facts of price action. MA/session/ADX/ATR
            // qualify a setup; they cannot erase a confirmed CHoCH from the
            // analytical history or the separate chart-timeframe drawing.
            if(draw_anchored_structure) DrawSignal("CHoCH",1,last_high_time,last_high,rates[i]);
            structure=1;
            last_break_direction=1; last_break_was_bos=false;
            newest_signal="CHoCH bullish"; newest_signal_time=rates[i].time;
           }
         else
           {
            if(draw_anchored_structure) DrawSignal("BOS",1,last_high_time,last_high,rates[i]);
            structure=1;
            last_break_direction=1; last_break_was_bos=true;
            newest_signal="BOS bullish"; newest_signal_time=rates[i].time;
           }
        }
      if(bearish_break)
        {
         low_broken=true;
         // An LL made after an HL is a bearish change of character.  An LL
         // made by breaking an LL is bearish continuation (BOS).
         if(last_low_kind<0)
           {
            if(draw_anchored_structure) DrawSignal("CHoCH",-1,last_low_time,last_low,rates[i]);
            structure=-1;
            last_break_direction=-1; last_break_was_bos=false;
            newest_signal="CHoCH bearish"; newest_signal_time=rates[i].time;
           }
         else
           {
            if(draw_anchored_structure) DrawSignal("BOS",-1,last_low_time,last_low,rates[i]);
            structure=-1;
            last_break_direction=-1; last_break_was_bos=true;
            newest_signal="BOS bearish"; newest_signal_time=rates[i].time;
           }
        }
      if(i==total-1)
        {
         last_htf_ma=htf_ma; dashboard_session=session; dashboard_adx=adx_pass; dashboard_atr=atr_pass;
         dashboard_bull_bos=bull_bos; dashboard_bear_bos=bear_bos;
         dashboard_bull_choch=bull_choch; dashboard_bear_choch=bear_choch;
        }
     }

   int first=MathMax(1,total-500);
   if(Show_MA_Line && Use_MA_Filter)
      for(int i=first;i<total;i++) DrawSegment("MA_"+(string)rates[i].time,rates[i-1].time,ma[i-1],rates[i].time,ma[i],MA_Color,STYLE_SOLID,2);
   if(Show_HTF_MA_Line && Use_HTF_MA_Filter)
      for(int i=first;i<total;i++)
        {
         double a=0,o=0,c=0,b=0;
         if(HTFValues(rates[i-1].time,a,o,c) && HTFValues(rates[i].time,b,o,c))
            DrawSegment("HTF_MA_"+(string)rates[i].time,rates[i-1].time,a,rates[i].time,b,HTF_MA_Color,STYLE_SOLID,2);
        }
   if(draw_anchored_structure && Show_Swing_Points && have_high)
      DrawSegment("LAST_HIGH",last_high_time,last_high,rates[total-1].time,last_high,clrIndianRed,STYLE_DOT,1);
   if(draw_anchored_structure && Show_Swing_Points && have_low)
      DrawSegment("LAST_LOW",last_low_time,last_low,rates[total-1].time,last_low,clrTeal,STYLE_DOT,1);
   if(!draw_anchored_structure) DrawChartTimeframeStructure();

   MqlTick current_tick;
   double current_price=SymbolInfoTick(_Symbol,current_tick) && current_tick.bid>0.0
                        ?current_tick.bid:rates[total-1].close;
   bool have_market_high=false,have_market_low=false;
   double market_high=0.0,market_low=0.0;
   EvaluateSignificantSR(rates[total-1].time,current_price,have_market_high,market_high,
                         have_market_low,market_low);
   bool have_resistance=false,have_support=false;
   double resistance_top=0.0,resistance_bottom=0.0,support_top=0.0,support_bottom=0.0;
   EvaluateTrendlineZones(have_resistance,resistance_top,resistance_bottom,
                          have_support,support_top,support_bottom);

   ROAD_STRUCTURE_STATE structure_state;
   structure_state.direction=structure;
   structure_state.last_break_was_bos=last_break_was_bos;
   structure_state.last_high_kind=last_high_kind; structure_state.last_low_kind=last_low_kind;
   structure_state.have_high=have_high; structure_state.have_low=have_low;
   structure_state.last_high=last_high; structure_state.last_low=last_low;
   // Only enabled tradeability timeframes participate in correlation. HTF and
   // MTF may be transitional. When enabled, LTF must have a definite BOS;
   // CHoCH remains transitional until a subsequent BOS.
   bool ltf_definite=have_ltf && DefiniteSetupBias(ltf_state);
   bool selected_biases_available=(!Use_HTF_For_Tradeability || structure!=0) &&
                                  (!Use_MTF_For_Tradeability || setup_state.direction!=0) &&
                                  (!Use_LTF_For_Tradeability || ltf_state.direction!=0);
   bool selected_biases_match=(!Use_HTF_For_Tradeability || !Use_MTF_For_Tradeability ||
                               structure==setup_state.direction) &&
                              (!Use_HTF_For_Tradeability || !Use_LTF_For_Tradeability ||
                               structure==ltf_state.direction) &&
                              (!Use_MTF_For_Tradeability || !Use_LTF_For_Tradeability ||
                               setup_state.direction==ltf_state.direction);
   bool bias_ready=selected_biases_available && selected_biases_match &&
                   (!Use_LTF_For_Tradeability || ltf_definite);

   double latest_atr=have_ltf_atr?ltf_atr_values[ltf_total-1]:0.0;
   double clearance=latest_atr*Boundary_Clearance_ATR;
   bool clear_space=latest_atr!=EMPTY_VALUE && latest_atr>0.0;
   string space_reason="";
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
   if(latest_atr!=EMPTY_VALUE && latest_atr>0.0)
     {
      if(ltf_state.direction>0 && ltf_state.have_low)
         extension=(ltf_rates[ltf_total-1].close-ltf_state.last_low)/latest_atr;
      else if(ltf_state.direction<0 && ltf_state.have_high)
         extension=(ltf_state.last_high-ltf_rates[ltf_total-1].close)/latest_atr;
     }
   bool healthy_extension=latest_atr!=EMPTY_VALUE && latest_atr>0.0 && extension>=0.0 &&
                          extension<=Maximum_Extension_ATR;

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
   if(Use_LTF_For_Tradeability) tradeability_reason+="; LTF is confirmed by BOS";
   if(!tradeable)
     {
      if(Use_MTF_For_Tradeability && !have_setup) tradeability_reason="MTF structure data is unavailable";
      else if(Use_LTF_For_Tradeability && !have_ltf) tradeability_reason="LTF structure data is unavailable";
      else if(Use_HTF_For_Tradeability && structure==0) tradeability_reason="HTF is consolidating";
      else if(Use_MTF_For_Tradeability && setup_state.direction==0) tradeability_reason="MTF is consolidating";
      else if(Use_LTF_For_Tradeability && ltf_state.direction==0) tradeability_reason="LTF is consolidating";
      else if(!selected_biases_match)
         tradeability_reason=TradeabilityTimeframesText()+" biases conflict";
      else if(Use_LTF_For_Tradeability && !ltf_definite)
         tradeability_reason="LTF bias is transitional (CHoCH has no subsequent BOS)";
     }
   DrawDashboard(BiasText(structure_state),have_setup?SetupBiasText(setup_state):"Consolidating",
                 have_ltf?SetupBiasText(ltf_state):"Consolidating",
                 bias_ready,tradeable,tradeability_reason,optimal,clear_space,
                 healthy_extension,good_volume,volume_ratio,good_momentum,
                 momentum_ratio,optimal_reason);
   if(permit_alert && newest_signal_time==rates[total-1].time && newest_signal!="")
      SendRoadAlert(newest_signal,newest_signal_time);
   ChartRedraw();
   return true;
  }

int OnInit()
  {
   if(Swing_Detection_Length<1 || Swing_Detection_Length>50 || MA_Length<1 ||
      HTF_MA_Length<1 || ADX_Length<1 || ATR_Length<1 || Bars_To_Process<100 ||
      Boundary_Lookback_Bars<1 || Boundary_Lookback_Bars>100000 ||
      SR_Pivot_Length<1 || SR_Pivot_Length>20 ||
      Trendline_Bars_To_Apply<50 || Trendline_Bars_To_Apply>100000 ||
      Trendline_Zones_Per_Side<1 || Trendline_Zones_Per_Side>10 ||
      Trendline_Pivot_Strength<5 || Trendline_Pivot_Strength>15 ||
      Trendline_Minimum_Touches<3 || Trendline_Minimum_Touches>8 ||
      Trendline_Zone_Transparency<0 || Trendline_Zone_Transparency>100 ||
      Boundary_Clearance_ATR<0.0 || Maximum_Extension_ATR<=0.0 ||
      Volume_Average_Length<1 || Volume_Minimum_Ratio<0.0 ||
      Volume_Maximum_Ratio<Volume_Minimum_Ratio ||
      Momentum_Average_Length<1 || Momentum_Minimum_Ratio<0.0 ||
      Momentum_Maximum_Ratio<Momentum_Minimum_Ratio ||
      (!Use_Timeframe_Correlation_For_Optimal && !Use_Technical_Space_For_Optimal &&
       !Use_Healthy_Extension_For_Optimal && !Use_Market_Volume_For_Optimal &&
       !Use_Price_Momentum_For_Optimal) ||
      (!Use_HTF_For_Tradeability && !Use_MTF_For_Tradeability && !Use_LTF_For_Tradeability))
      return INIT_PARAMETERS_INCORRECT;
   ENUM_TIMEFRAMES timeframe=RoadTimeframe();
   g_prefix="Road_"+(string)ChartID()+"_";
   if(Use_MA_Filter && (g_ma_handle=iMA(_Symbol,timeframe,MA_Length,0,RoadMAMethod(MA_Type),PRICE_CLOSE))==INVALID_HANDLE) return INIT_FAILED;
   if(Use_HTF_MA_Filter && (g_htf_ma_handle=iMA(_Symbol,HTF_Timeframe,HTF_MA_Length,0,RoadMAMethod(HTF_MA_Type),PRICE_CLOSE))==INVALID_HANDLE) return INIT_FAILED;
   if(Use_ADX_Filter && (g_adx_handle=iADX(_Symbol,timeframe,ADX_Length))==INVALID_HANDLE) return INIT_FAILED;
   if((Use_ATR_Filter || Use_Optimal_Conditions_Meter) &&
      (g_atr_handle=iATR(_Symbol,timeframe,ATR_Length))==INVALID_HANDLE) return INIT_FAILED;
   if((g_ltf_atr_handle=iATR(_Symbol,LTFTimeframe(),ATR_Length))==INVALID_HANDLE) return INIT_FAILED;
   if((Show_Trendline_Zones || Use_Optimal_Conditions_Meter) &&
      (g_trend_atr_handle=iATR(_Symbol,BoundaryTimeframe(),ATR_Length))==INVALID_HANDLE) return INIT_FAILED;
   if(!EventSetTimer(2)) return INIT_FAILED;
   datetime current=iTime(_Symbol,LTFTimeframe(),0);
   datetime structure_current=iTime(_Symbol,RoadTimeframe(),0);
   datetime setup_current=iTime(_Symbol,SetupTimeframe(),0);
   if(current!=0 && structure_current!=0 && setup_current!=0 && Rebuild(false))
     {
      g_last_ltf_bar=current;
      g_last_structure_bar=structure_current;
      g_last_setup_bar=setup_current;
     }
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
   ObjectsDeleteAll(0,g_prefix);
   Comment("");
  }

void CheckForBar()
  {
   datetime current=iTime(_Symbol,LTFTimeframe(),0);
   datetime structure_current=iTime(_Symbol,RoadTimeframe(),0);
   datetime setup_current=iTime(_Symbol,SetupTimeframe(),0);
   if(current==0 || structure_current==0 || setup_current==0) return;
   bool changed=current!=g_last_ltf_bar || structure_current!=g_last_structure_bar ||
                setup_current!=g_last_setup_bar;
   if(changed)
     {
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
