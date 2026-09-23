#property copyright "Market Trend Analyser conversion"
#property version   "1.23"
#property strict
#property description "Road: MT5 port of the Market Trend Analyser Pine Script."
#property description "Signal/visualisation EA only; the source indicator contains no trading rules."

enum ROAD_MA_TYPE { ROAD_SMA=0, ROAD_EMA=1 };
enum ROAD_MA_FILTER_MODE { ROAD_PRICE_ABOVE_BELOW=0, ROAD_FULL_BODY_CLOSE=1 };
enum ROAD_SESSION { ROAD_NEW_YORK=0, ROAD_LONDON=1, ROAD_TOKYO=2, ROAD_SYDNEY=3, ROAD_CUSTOM=4, ROAD_24X7=5 };
enum ROAD_ADX_SCOPE { ROAD_BOS_ONLY=0, ROAD_BOS_AND_CHOCH=1 };
enum ROAD_ATR_MODE { ROAD_ATR_MINIMUM=0, ROAD_ATR_MAXIMUM=1, ROAD_ATR_RANGE=2 };
enum ROAD_LABEL_SIZE { ROAD_TINY=7, ROAD_SMALL=9, ROAD_NORMAL=11, ROAD_LARGE=14 };

input group "General"
input ENUM_TIMEFRAMES Analysis_Timeframe=PERIOD_CURRENT;
input int Bars_To_Process=100;

input group "Higher-Timeframe Support / Resistance"
input bool Show_HTF_Support_Resistance=true;
input ENUM_TIMEFRAMES SR_Timeframe=PERIOD_H4;
input int SR_Lookback_Bars=200;
input int SR_Pivot_Length=3;
input int SR_ATR_Length=14;
input double SR_Merge_Distance_ATR=0.25;
input int SR_Impulse_Lookahead=6;
input double SR_Minimum_Impulse_ATR=1.5;
input int SR_Minimum_Touches=3;
input int SR_Maximum_Levels_Per_Side=3;
input color SR_Support_Color=clrDeepSkyBlue;
input color SR_Resistance_Color=clrTomato;
input ENUM_LINE_STYLE SR_Line_Style=STYLE_DOT;
input int SR_Line_Width=2;
input bool Show_SR_Labels=true;

input group "Swing Detection"
input int Swing_Detection_Length=5;
input bool Show_Swing_Points=true;

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
input ROAD_MA_FILTER_MODE MA_Filter_Mode=ROAD_PRICE_ABOVE_BELOW;
input bool Show_MA_Line=false;
input color MA_Color=clrBlue;

input group "MA Filter (HTF)"
input bool Use_HTF_MA_Filter=true;
input ENUM_TIMEFRAMES HTF_Timeframe=PERIOD_H1;
input int HTF_MA_Length=100;
input ROAD_MA_TYPE HTF_MA_Type=ROAD_EMA;
input ROAD_MA_FILTER_MODE HTF_MA_Filter_Mode=ROAD_PRICE_ABOVE_BELOW;
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
input double ADX_Minimum=25.0;
input ROAD_ADX_SCOPE Apply_ADX_Filter_To=ROAD_BOS_ONLY;

input group "ATR Filter"
input bool Use_ATR_Filter=true;
input int ATR_Length=14;
input ROAD_ATR_MODE ATR_Filter_Mode=ROAD_ATR_MINIMUM;
input double ATR_Minimum=1.0;
input double ATR_Maximum=10.0;

input group "Alerts"
input bool Enable_Popup_Alerts=true;
input bool Enable_Push_Notifications=false;

string g_prefix="";
datetime g_last_bar=0;
int g_ma_handle=INVALID_HANDLE;
int g_htf_ma_handle=INVALID_HANDLE;
int g_adx_handle=INVALID_HANDLE;
int g_atr_handle=INVALID_HANDLE;
int g_sr_atr_handle=INVALID_HANDLE;

struct ROAD_SR_LEVEL
  {
   double price;
   double weight;
   int touches;
   datetime first_time;
   datetime last_time;
   datetime representative_time;
   double reaction_strength;
   double score;
   int structure_mask;
   bool strong_origin;
   bool significant_extreme;
   int strong_touches;
  };

enum ROAD_SR_STRUCTURE
  {
   ROAD_SR_HH=1,
   ROAD_SR_LH=2,
   ROAD_SR_HL=4,
   ROAD_SR_LL=8
  };

ENUM_TIMEFRAMES RoadTimeframe()
  {
   return Analysis_Timeframe==PERIOD_CURRENT?(ENUM_TIMEFRAMES)_Period:Analysis_Timeframe;
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

bool ParseSession(const string source,int &start_minutes,int &end_minutes)
  {
   string pieces[];
   if(StringSplit(source,'-',pieces)!=2 || StringLen(pieces[0])!=4 || StringLen(pieces[1])!=4)
      return false;
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

void AddSRLevel(ROAD_SR_LEVEL &levels[],const double price,const datetime time,
                const double tolerance,const double importance,
                const int structure_type,const bool strong_origin,
                const bool significant_extreme)
  {
   int count=ArraySize(levels),match=-1;
   double nearest=DBL_MAX;
   for(int i=0;i<count;i++)
     {
      double distance=MathAbs(levels[i].price-price);
      if(distance<=tolerance && distance<nearest) { nearest=distance; match=i; }
     }
   if(match<0)
     {
      ArrayResize(levels,count+1);
      levels[count].price=price;
      levels[count].weight=importance;
      levels[count].touches=1;
      levels[count].first_time=time;
      levels[count].last_time=time;
      levels[count].representative_time=time;
      levels[count].reaction_strength=importance;
      levels[count].score=0.0;
      levels[count].structure_mask=structure_type;
      levels[count].strong_origin=strong_origin;
      levels[count].significant_extreme=significant_extreme;
      levels[count].strong_touches=strong_origin?1:0;
      return;
     }
   double combined=levels[match].weight+importance;
   // Keep a nearby cluster on an actual pivot instead of inventing a weighted
   // average price.  The strongest rejection/impulse is representative; when
   // reactions are equal, the newer pivot wins.
   if(importance>levels[match].reaction_strength ||
      (importance==levels[match].reaction_strength && time>levels[match].representative_time))
     {
      levels[match].price=price;
      levels[match].representative_time=time;
      levels[match].reaction_strength=importance;
     }
   levels[match].weight=combined;
   levels[match].touches++;
   levels[match].structure_mask|=structure_type;
   levels[match].strong_origin=levels[match].strong_origin || strong_origin;
   levels[match].significant_extreme=levels[match].significant_extreme || significant_extreme;
   if(strong_origin) levels[match].strong_touches++;
   if(time<levels[match].first_time) levels[match].first_time=time;
   if(time>levels[match].last_time) levels[match].last_time=time;
  }

string SRStructureText(const int mask)
  {
   string result="";
   if((mask&ROAD_SR_HH)!=0) result="HH";
   if((mask&ROAD_SR_LH)!=0) result+=(result==""?"":"/")+"LH";
   if((mask&ROAD_SR_HL)!=0) result+=(result==""?"":"/")+"HL";
   if((mask&ROAD_SR_LL)!=0) result+=(result==""?"":"/")+"LL";
   return result;
  }

// A major level is the most significant confirmed swing extreme, the origin of
// an impulsive move, or a cluster of at least SR_Minimum_Touches pivots whose
// reactions each meet the impulse threshold.  Look-ahead is safe because only
// closed candles are copied and a level is not published until confirmation.
void BuildSRSide(const MqlRates &rates[],const double &atr[],const int total,
                 const bool resistance,ROAD_SR_LEVEL &levels[])
  {
   ArrayResize(levels,0);
   int length=MathMax(1,MathMin(20,SR_Pivot_Length));
   int impulse_bars=MathMax(1,MathMin(50,SR_Impulse_Lookahead));
   int significant_index=-1;
   for(int i=length;i<total-length;i++)
     {
      if(!(resistance?PivotHigh(rates,total,i,length):PivotLow(rates,total,i,length))) continue;
      if(significant_index<0 || (resistance && rates[i].high>rates[significant_index].high) ||
         (!resistance && rates[i].low<rates[significant_index].low))
         significant_index=i;
     }
   double previous_swing=0.0;
   bool have_previous=false;
   for(int i=length;i<total-length;i++)
     {
      bool pivot=resistance?PivotHigh(rates,total,i,length):PivotLow(rates,total,i,length);
      if(!pivot || atr[i]<=0.0 || atr[i]==EMPTY_VALUE) continue;
      double price=resistance?rates[i].high:rates[i].low;
      int structure_type=0;
      if(have_previous)
         structure_type=resistance?(price>previous_swing?ROAD_SR_HH:ROAD_SR_LH)
                                   :(price>previous_swing?ROAD_SR_HL:ROAD_SR_LL);
      previous_swing=price;
      have_previous=true;

      double furthest=price;
      int move_end=MathMin(total-1,i+impulse_bars);
      for(int j=i+1;j<=move_end;j++)
         furthest=resistance?MathMin(furthest,rates[j].low):MathMax(furthest,rates[j].high);
      double impulse=resistance?price-furthest:furthest-price;
      bool strong_origin=impulse>=atr[i]*SR_Minimum_Impulse_ATR;
      double rejection=resistance?price-MathMax(rates[i].open,rates[i].close)
                                  :MathMin(rates[i].open,rates[i].close)-price;
      double importance=1.0+MathMax(0.0,rejection/atr[i])+MathMax(0.0,impulse/atr[i]);
      double tolerance=MathMax(_Point,atr[i]*MathMax(0.0,SR_Merge_Distance_ATR));
      AddSRLevel(levels,price,rates[i].time,tolerance,importance,structure_type,strong_origin,
                 i==significant_index);
     }
   for(int i=0;i<ArraySize(levels);i++)
     {
      double recency=(double)(iBarShift(_Symbol,SR_Timeframe,levels[i].last_time,false));
      bool confirmed_touches=levels[i].strong_touches>=SR_Minimum_Touches;
      levels[i].score=(levels[i].significant_extreme?4000.0:0.0)+
                      (confirmed_touches?3000.0:0.0)+
                      (levels[i].strong_origin?2000.0:0.0)+
                      levels[i].strong_touches*100.0+levels[i].reaction_strength*10.0+
                      levels[i].weight-recency*0.01;
     }
  }

int BestSRLevel(const ROAD_SR_LEVEL &levels[],const bool &used[],const bool resistance,
                const double market_price)
  {
   int best=-1;
   for(int i=0;i<ArraySize(levels);i++)
     {
      bool valid=levels[i].significant_extreme || levels[i].strong_origin ||
                 levels[i].strong_touches>=SR_Minimum_Touches;
      if(used[i] || !valid) continue;
      if((resistance && levels[i].price<=market_price) || (!resistance && levels[i].price>=market_price)) continue;
      if(best<0 || levels[i].score>levels[best].score) best=i;
     }
   return best;
  }

void DrawSRSide(const ROAD_SR_LEVEL &levels[],const bool resistance,const double market_price,
                const datetime chart_time)
  {
   int count=ArraySize(levels);
   bool used[]; ArrayResize(used,count); ArrayInitialize(used,false);
   int maximum=MathMax(1,MathMin(10,SR_Maximum_Levels_Per_Side));
   color clr=resistance?SR_Resistance_Color:SR_Support_Color;
   string side=resistance?"R":"S";
   for(int rank=0;rank<maximum;rank++)
     {
      int selected=BestSRLevel(levels,used,resistance,market_price);
      if(selected<0) break;
      used[selected]=true;
      string key="HTF_SR_"+side+"_"+(string)levels[selected].representative_time;
      DrawSegment(key,levels[selected].representative_time,levels[selected].price,
                  chart_time,levels[selected].price,clr,SR_Line_Style,SR_Line_Width);
      string object_name=g_prefix+key;
      if(ObjectFind(0,object_name)>=0) ObjectSetInteger(0,object_name,OBJPROP_RAY_RIGHT,true);
      if(Show_SR_Labels)
        {
         string traits=SRStructureText(levels[selected].structure_mask);
         if(levels[selected].significant_extreme)
            traits+=(traits==""?"":" + ")+(resistance?"MAJOR HIGH":"MAJOR LOW");
         if(levels[selected].strong_origin) traits+=(traits==""?"":" + ")+"STRONG REACTION";
         if(levels[selected].strong_touches>=SR_Minimum_Touches)
            traits+=(traits==""?"":" + ")+IntegerToString(levels[selected].strong_touches)+" STRONG TOUCHES";
         string caption=EnumToString(SR_Timeframe)+" "+(resistance?"R":"S")+" ["+traits+"]";
         DrawText(key+"_LABEL",chart_time,levels[selected].price,caption,clr,!resistance,8);
        }
     }
  }

void DrawSignificantSR(const double market_price,const datetime chart_time)
  {
   if(!Show_HTF_Support_Resistance) return;
   int wanted=MathMax(50,MathMin(10000,SR_Lookback_Bars));
   MqlRates rates[]; ArraySetAsSeries(rates,false);
   int total=CopyRates(_Symbol,SR_Timeframe,1,wanted,rates);
   if(total<2*SR_Pivot_Length+2) return;
   double atr[]; ArrayResize(atr,total); ArraySetAsSeries(atr,false);
   if(g_sr_atr_handle==INVALID_HANDLE || CopyBuffer(g_sr_atr_handle,0,1,total,atr)!=total) return;
   ROAD_SR_LEVEL supports[],resistances[];
   BuildSRSide(rates,atr,total,false,supports);
   BuildSRSide(rates,atr,total,true,resistances);
   DrawSRSide(supports,false,market_price,chart_time);
   DrawSRSide(resistances,true,market_price,chart_time);
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

void SendRoadAlert(const string signal,const datetime bar_time)
  {
   static datetime last_alert=0;
   if(bar_time<=last_alert) return;
   last_alert=bar_time;
   string message=_Symbol+" "+EnumToString(RoadTimeframe())+" "+signal;
   if(Enable_Popup_Alerts) Alert(message);
   if(Enable_Push_Notifications) SendNotification(message);
  }

string PriceText(const bool available,const double value)
  {
   return available?DoubleToString(value,_Digits):"-";
  }

void DrawDashboard(const int structure,const bool have_high,const double last_high,
                   const bool have_low,const double last_low,const bool in_session,
                   const double adx,const bool adx_pass,const double atr,const bool atr_pass,
                   const double close,const double ma,const double htf_ma,
                   const bool bull_bos_pass,const bool bear_bos_pass,
                   const bool bull_choch_pass,const bool bear_choch_pass)
  {
   string bias=structure>0?"BULLISH":structure<0?"BEARISH":"UNDEFINED";
   string session=!Use_Session_Filter?"OFF":in_session?"IN":"OUT";
   string adx_text=!Use_ADX_Filter?"OFF":DoubleToString(adx,1)+" / "+DoubleToString(ADX_Minimum,0)+(adx_pass?" PASS":" BLOCKED");
   string atr_text=!Use_ATR_Filter?"OFF":DoubleToString(atr,_Digits)+(atr_pass?" PASS":" BLOCKED");
   string ltf=!Use_MA_Filter?"OFF":close>ma?"ABOVE":"BELOW";
   string htf=!Use_HTF_MA_Filter?"OFF":close>htf_ma?"ABOVE":"BELOW";
   bool bos_pass=(structure>=0 && bull_bos_pass)||(structure<=0 && bear_bos_pass);
   bool choch_pass=(structure<=0 && bull_choch_pass)||(structure>=0 && bear_choch_pass);
   Comment("ROAD — Market Trend Analyser\n",
           "Market Bias: ",bias,"\nLast High: ",PriceText(have_high,last_high),
           "\nLast Low: ",PriceText(have_low,last_low),"\nSession: ",session,
           "\nADX: ",adx_text,"\nADX Scope: ",!Use_ADX_Filter?"OFF":Apply_ADX_Filter_To==ROAD_BOS_AND_CHOCH?"BOS+CHoCH":"BOS Only",
           "\nATR: ",atr_text,"\nMA (LTF): ",ltf,"\nMA (HTF): ",htf,
           "\nBOS Filters: ",bos_pass?"PASS":"BLOCKED",
           "\nCHoCH Filters: ",choch_pass?"PASS":"BLOCKED");
  }

void Rebuild(const bool permit_alert)
  {
   ENUM_TIMEFRAMES timeframe=RoadTimeframe();
   int wanted=MathMax(100,MathMin(Bars_To_Process,100000));
   MqlRates rates[]; ArraySetAsSeries(rates,false);
   int total=CopyRates(_Symbol,timeframe,1,wanted,rates);
   int length=MathMax(1,MathMin(50,Swing_Detection_Length));
   if(total<MathMax(2*length+2,MathMax(MA_Length,2*ADX_Length)+2)) return;

   double ma[],adx[],atr[];
   if(!CopyIndicator(g_ma_handle,0,total,ma) || !CopyIndicator(g_adx_handle,0,total,adx) ||
      !CopyIndicator(g_atr_handle,0,total,atr)) return;

   ObjectsDeleteAll(0,g_prefix);
   bool have_high=false,have_low=false,high_broken=false,low_broken=false;
   double last_high=0.0,last_low=0.0,last_htf_ma=0.0;
   datetime last_high_time=0,last_low_time=0,newest_signal_time=0;
   int structure=0;
   // The first confirmed swing break establishes an initial bias.  BOS is
   // armed only after an opposite swing break has confirmed a CHoCH, so an
   // incomplete history cannot manufacture a continuation signal.
   bool choch_confirmed=false;
   string newest_signal="";
   bool dashboard_bull_bos=false,dashboard_bear_bos=false;
   bool dashboard_bull_choch=false,dashboard_bear_choch=false;
   bool dashboard_session=true,dashboard_adx=false,dashboard_atr=false;

   for(int i=length;i<total;i++)
     {
      int pivot=i-length;
      if(PivotHigh(rates,total,pivot,length))
        {
         have_high=true; last_high=rates[pivot].high; last_high_time=rates[pivot].time; high_broken=false;
         if(Show_Swing_Points) DrawText("SWING_HIGH_"+(string)rates[pivot].time,rates[pivot].time,last_high,"◆",clrIndianRed,false,7);
        }
      if(PivotLow(rates,total,pivot,length))
        {
         have_low=true; last_low=rates[pivot].low; last_low_time=rates[pivot].time; low_broken=false;
         if(Show_Swing_Points) DrawText("SWING_LOW_"+(string)rates[pivot].time,rates[pivot].time,last_low,"◆",clrTeal,true,7);
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
      bool htf_ready=HTFValues(rates[i].time,htf_ma,htf_open,htf_close);
      bool htf_long=!Use_HTF_MA_Filter,htf_short=!Use_HTF_MA_Filter;
      if(Use_HTF_MA_Filter && htf_ready)
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

      bool bullish_break=have_high && !high_broken && rates[i].close>last_high && rates[i-1].close<=last_high;
      bool bearish_break=have_low && !low_broken && rates[i].close<last_low && rates[i-1].close>=last_low;
      // Only confirmed pivots are valid structure levels.  Expansion beyond
      // an unconfirmed candle extreme must not produce lower-timeframe BOS
      // noise on the analysis timeframe.
      if(bullish_break)
        {
         high_broken=true;
         if(structure<0 && bull_choch)
           {
            DrawSignal("CHoCH",1,last_high_time,last_high,rates[i]);
            structure=1;
            choch_confirmed=true;
            newest_signal="CHoCH bullish"; newest_signal_time=rates[i].time;
           }
         else if(structure>0 && choch_confirmed && bull_bos)
           {
            DrawSignal("BOS",1,last_high_time,last_high,rates[i]);
            newest_signal="BOS bullish"; newest_signal_time=rates[i].time;
           }
         else if(structure==0)
            structure=1;
        }
      if(bearish_break)
        {
         low_broken=true;
         if(structure>0 && bear_choch)
           {
            DrawSignal("CHoCH",-1,last_low_time,last_low,rates[i]);
            structure=-1;
            choch_confirmed=true;
            newest_signal="CHoCH bearish"; newest_signal_time=rates[i].time;
           }
         else if(structure<0 && choch_confirmed && bear_bos)
           {
            DrawSignal("BOS",-1,last_low_time,last_low,rates[i]);
            newest_signal="BOS bearish"; newest_signal_time=rates[i].time;
           }
         else if(structure==0)
            structure=-1;
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
   if(Show_Swing_Points && have_high)
      DrawSegment("LAST_HIGH",last_high_time,last_high,rates[total-1].time,last_high,clrIndianRed,STYLE_DOT,1);
   if(Show_Swing_Points && have_low)
      DrawSegment("LAST_LOW",last_low_time,last_low,rates[total-1].time,last_low,clrTeal,STYLE_DOT,1);

   DrawSignificantSR(rates[total-1].close,rates[total-1].time);

   DrawDashboard(structure,have_high,last_high,have_low,last_low,dashboard_session,
                 adx[total-1],dashboard_adx,atr[total-1],dashboard_atr,rates[total-1].close,
                 ma[total-1],last_htf_ma,dashboard_bull_bos,dashboard_bear_bos,
                 dashboard_bull_choch,dashboard_bear_choch);
   if(permit_alert && newest_signal_time==rates[total-1].time && newest_signal!="")
      SendRoadAlert(newest_signal,newest_signal_time);
   ChartRedraw();
  }

int OnInit()
  {
   if(Swing_Detection_Length<1 || Swing_Detection_Length>50 || MA_Length<1 ||
      HTF_MA_Length<1 || ADX_Length<1 || ATR_Length<1 || Bars_To_Process<100 ||
      SR_Lookback_Bars<50 || SR_Pivot_Length<1 || SR_Pivot_Length>20 || SR_ATR_Length<1 ||
      SR_Merge_Distance_ATR<0.0 || SR_Impulse_Lookahead<1 || SR_Impulse_Lookahead>50 ||
      SR_Minimum_Impulse_ATR<=0.0 || SR_Minimum_Touches<3 ||
      SR_Maximum_Levels_Per_Side<1 || SR_Maximum_Levels_Per_Side>10)
      return INIT_PARAMETERS_INCORRECT;
   ENUM_TIMEFRAMES timeframe=RoadTimeframe();
   g_prefix="Road_"+(string)ChartID()+"_";
   g_ma_handle=iMA(_Symbol,timeframe,MA_Length,0,RoadMAMethod(MA_Type),PRICE_CLOSE);
   g_htf_ma_handle=iMA(_Symbol,HTF_Timeframe,HTF_MA_Length,0,RoadMAMethod(HTF_MA_Type),PRICE_CLOSE);
   g_adx_handle=iADX(_Symbol,timeframe,ADX_Length);
   g_atr_handle=iATR(_Symbol,timeframe,ATR_Length);
   g_sr_atr_handle=iATR(_Symbol,SR_Timeframe,SR_ATR_Length);
   if(g_ma_handle==INVALID_HANDLE || g_htf_ma_handle==INVALID_HANDLE ||
      g_adx_handle==INVALID_HANDLE || g_atr_handle==INVALID_HANDLE ||
      g_sr_atr_handle==INVALID_HANDLE) return INIT_FAILED;
   EventSetTimer(2);
   Rebuild(false);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(g_ma_handle!=INVALID_HANDLE) IndicatorRelease(g_ma_handle);
   if(g_htf_ma_handle!=INVALID_HANDLE) IndicatorRelease(g_htf_ma_handle);
   if(g_adx_handle!=INVALID_HANDLE) IndicatorRelease(g_adx_handle);
   if(g_atr_handle!=INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   if(g_sr_atr_handle!=INVALID_HANDLE) IndicatorRelease(g_sr_atr_handle);
   ObjectsDeleteAll(0,g_prefix);
   Comment("");
  }

void CheckForBar()
  {
   datetime current=iTime(_Symbol,RoadTimeframe(),0);
   if(current!=0 && current!=g_last_bar)
     {
      bool alert=g_last_bar!=0;
      g_last_bar=current;
      Rebuild(alert);
     }
  }

void OnTick() { CheckForBar(); }
void OnTimer() { CheckForBar(); }
