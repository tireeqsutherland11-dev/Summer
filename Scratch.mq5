#property copyright "MT5 conversion"
#property version   "2.00"
#property strict
#property description "Market-trend, BoS and CHoCH port of the supplied Pine indicator."
#property description "Analysis and alerts only; this Expert Advisor never places orders."

input ENUM_TIMEFRAMES Analysis_Timeframe=PERIOD_CURRENT;
input int Swing_Detection_Length=5;
input int Bars_To_Process=5000;

enum MAKind { MA_EMA=0, MA_SMA=1 };
enum MAMode { Price_Above_Below=0, Full_Body_Close=1 };
enum ADXScope { ADX_BOS_Only=0, ADX_BOS_And_CHoCH=1 };
enum ATRMode { ATR_Minimum=0, ATR_Maximum=1, ATR_Range=2 };
enum SessionPreset { Session_New_York=0, Session_London=1, Session_Tokyo=2,
                     Session_Sydney=3, Session_Custom=4, Session_24x7=5 };

input group "MA Filter (LTF)"
input bool Use_MA_Filter=true;
input int MA_Length=50;
input MAKind MA_Type=MA_EMA;
input MAMode MA_Filter_Mode=Price_Above_Below;

input group "MA Filter (HTF)"
input bool Use_HTF_MA_Filter=false;
input ENUM_TIMEFRAMES HTF_Timeframe=PERIOD_H4;
input int HTF_MA_Length=200;
input MAKind HTF_MA_Type=MA_EMA;
input MAMode HTF_MA_Filter_Mode=Price_Above_Below;

input group "Session Filter"
input bool Use_Session_Filter=false;
input SessionPreset Session_Preset=Session_New_York;
input int Custom_Session_Start_Hour=9;
input int Custom_Session_Start_Minute=30;
input int Custom_Session_End_Hour=16;
input int Custom_Session_End_Minute=0;

input group "ADX Filter"
input bool Use_ADX_Filter=true;
input int ADX_Length=14;
input double ADX_Threshold=25.0;
input ADXScope ADX_Filter_Scope=ADX_BOS_Only;

input group "ATR Filter"
input bool Use_ATR_Filter=true;
input int ATR_Length=14;
input ATRMode ATR_Filter_Mode=ATR_Minimum;
input double ATR_Minimum_Value=1.0;
input double ATR_Maximum_Value=10.0;

input bool Show_Swing_Points=true;
input bool Show_BoS=true;
input bool Show_CHoCH=true;
input bool Show_Structure_Lines=true;
input color Bullish_BoS_Color=clrTeal;
input color Bearish_BoS_Color=clrRed;
input color Bullish_CHoCH_Color=clrLime;
input color Bearish_CHoCH_Color=clrMagenta;
input ENUM_LINE_STYLE Structure_Line_Style=STYLE_DASH;
input int Structure_Line_Width=1;

input bool Alert_BoS=true;
input bool Alert_CHoCH=true;
input bool Push_Notifications=false;

string prefix="ScratchMT5_";
datetime last_bar=0;
int current_structure=0; // 1 = bullish, -1 = bearish, 0 = undefined

bool IsPivotHigh(const MqlRates &rates[],const int total,const int index,const int length)
  {
   if(index-length<0 || index+length>=total) return false;
   const double candidate=rates[index].high;
   for(int i=index-length;i<=index+length;i++)
      if(i!=index && rates[i].high>=candidate) return false;
   return true;
  }

bool IsPivotLow(const MqlRates &rates[],const int total,const int index,const int length)
  {
   if(index-length<0 || index+length>=total) return false;
   const double candidate=rates[index].low;
   for(int i=index-length;i<=index+length;i++)
      if(i!=index && rates[i].low<=candidate) return false;
   return true;
  }

void DrawText(const string id,const datetime time,const double price,
              const string value,const color clr,const bool above,const int size=9)
  {
   string name=prefix+id;
   if(ObjectFind(0,name)>=0 || !ObjectCreate(0,name,OBJ_TEXT,0,time,price)) return;
   ObjectSetString(0,name,OBJPROP_TEXT,value);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,above?ANCHOR_LOWER:ANCHOR_UPPER);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
  }

void DrawEvent(const string kind,const int direction,const datetime swing_time,
               const double level,const MqlRates &event_bar)
  {
   bool bos=(kind=="BOS");
   if((bos && !Show_BoS) || (!bos && !Show_CHoCH)) return;
   color clr=direction>0
             ?(bos?Bullish_BoS_Color:Bullish_CHoCH_Color)
             :(bos?Bearish_BoS_Color:Bearish_CHoCH_Color);
   string id=kind+"_"+(direction>0?"bull_":"bear_")+(string)event_bar.time;
   if(Show_Structure_Lines)
     {
      string name=prefix+id+"_line";
      if(ObjectCreate(0,name,OBJ_TREND,0,swing_time,level,event_bar.time,level))
        {
         ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
         ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
         ObjectSetInteger(0,name,OBJPROP_STYLE,Structure_Line_Style);
         ObjectSetInteger(0,name,OBJPROP_WIDTH,Structure_Line_Width);
        }
     }
   DrawText(id+"_label",event_bar.time,direction>0?event_bar.low:event_bar.high,
            kind,clr,direction>0,10);
  }

void Notify(const string signal)
  {
   string message=_Symbol+" "+signal;
   Alert(message);
   if(Push_Notifications) SendNotification(message);
  }

bool InSession(const datetime time)
  {
   if(!Use_Session_Filter || Session_Preset==Session_24x7) return true;
   int start_hour=0,start_minute=0,end_hour=23,end_minute=59;
   if(Session_Preset==Session_New_York) { start_hour=9; start_minute=30; end_hour=16; end_minute=0; }
   else if(Session_Preset==Session_London) { start_hour=8; end_hour=17; }
   else if(Session_Preset==Session_Tokyo) { start_hour=9; end_hour=15; }
   else if(Session_Preset==Session_Sydney) { start_hour=8; end_hour=17; }
   else
     {
      start_hour=Custom_Session_Start_Hour; start_minute=Custom_Session_Start_Minute;
      end_hour=Custom_Session_End_Hour; end_minute=Custom_Session_End_Minute;
     }
   MqlDateTime parts; TimeToStruct(time,parts);
   int minute=parts.hour*60+parts.min;
   int start=start_hour*60+start_minute,end=end_hour*60+end_minute;
   return start<=end ? minute>=start && minute<end : minute>=start || minute<end;
  }

bool CopyValue(const int handle,const int buffer,const int shift,double &value)
  {
   double data[1];
   if(handle==INVALID_HANDLE || CopyBuffer(handle,buffer,shift,1,data)!=1) return false;
   value=data[0];
   return value!=EMPTY_VALUE;
  }

void Rebuild(const bool permit_alerts)
  {
   ENUM_TIMEFRAMES timeframe=Analysis_Timeframe==PERIOD_CURRENT
                            ?(ENUM_TIMEFRAMES)_Period:Analysis_Timeframe;
   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   int wanted=MathMax(100,MathMin(Bars_To_Process,100000));
   // Start at one so decisions are based on completed candles, like a Pine
   // alert configured "once per bar close".
   int total=CopyRates(_Symbol,timeframe,1,wanted,rates);
   if(total<2*Swing_Detection_Length+2) return;

   int ma_handle=INVALID_HANDLE,htf_ma_handle=INVALID_HANDLE;
   int adx_handle=INVALID_HANDLE,atr_handle=INVALID_HANDLE;
   if(Use_MA_Filter)
      ma_handle=iMA(_Symbol,timeframe,MA_Length,0,MA_Type==MA_EMA?MODE_EMA:MODE_SMA,PRICE_CLOSE);
   if(Use_HTF_MA_Filter)
      htf_ma_handle=iMA(_Symbol,HTF_Timeframe,HTF_MA_Length,0,
                        HTF_MA_Type==MA_EMA?MODE_EMA:MODE_SMA,PRICE_CLOSE);
   if(Use_ADX_Filter) adx_handle=iADX(_Symbol,timeframe,ADX_Length);
   if(Use_ATR_Filter) atr_handle=iATR(_Symbol,timeframe,ATR_Length);

   ObjectsDeleteAll(0,prefix);
   double last_high=0.0,last_low=0.0;
   datetime last_high_time=0,last_low_time=0;
   bool have_high=false,have_low=false;
   bool high_broken=false,low_broken=false;
   int structure=0;
   string newest_signal="";
   datetime newest_signal_time=0;

   for(int i=2*Swing_Detection_Length;i<total;i++)
     {
      // ta.pivothigh/ta.pivotlow confirm a candidate Swing_Detection_Length
      // bars later.  The candidate is therefore i-length, not the current bar.
      int candidate=i-Swing_Detection_Length;
      if(IsPivotHigh(rates,total,candidate,Swing_Detection_Length))
        {
         last_high=rates[candidate].high;
         last_high_time=rates[candidate].time;
         have_high=true;
         high_broken=false;
         if(Show_Swing_Points)
            DrawText("swing_high_"+(string)last_high_time,last_high_time,last_high,
                     "◆",Bearish_BoS_Color,true,7);
        }
      if(IsPivotLow(rates,total,candidate,Swing_Detection_Length))
        {
         last_low=rates[candidate].low;
         last_low_time=rates[candidate].time;
         have_low=true;
         low_broken=false;
         if(Show_Swing_Points)
            DrawText("swing_low_"+(string)last_low_time,last_low_time,last_low,
                     "◆",Bullish_BoS_Color,false,7);
        }

      // A break needs a close-through crossover and each swing level can emit
      // only once.  This is the supplied Pine logic, evaluated chronologically.
      bool bullish_break=have_high && !high_broken &&
                         rates[i].close>last_high && rates[i-1].close<=last_high;
      bool bearish_break=have_low && !low_broken &&
                         rates[i].close<last_low && rates[i-1].close>=last_low;

      // Evaluate the Pine filters on the event candle. CopyRates excludes the
      // live candle, so its oldest-to-newest index maps to an MT5 series shift.
      int shift=total-i;
      double ma=0.0,adx=0.0,atr=0.0,htf_ma=0.0;
      bool ma_ready=!Use_MA_Filter || CopyValue(ma_handle,0,shift,ma);
      bool adx_ready=!Use_ADX_Filter || CopyValue(adx_handle,0,shift,adx);
      bool atr_ready=!Use_ATR_Filter || CopyValue(atr_handle,0,shift,atr);
      int htf_shift=Use_HTF_MA_Filter?iBarShift(_Symbol,HTF_Timeframe,rates[i].time,false):-1;
      bool htf_ready=!Use_HTF_MA_Filter ||
                     (htf_shift>=0 && CopyValue(htf_ma_handle,0,htf_shift,htf_ma));

      bool ma_long=true,ma_short=true;
      if(Use_MA_Filter && ma_ready)
        {
         ma_long=MA_Filter_Mode==Price_Above_Below
                 ?rates[i].close>ma
                 :rates[i].close>ma && rates[i].open>ma && rates[i].close>rates[i].open;
         ma_short=MA_Filter_Mode==Price_Above_Below
                  ?rates[i].close<ma
                  :rates[i].close<ma && rates[i].open<ma && rates[i].close<rates[i].open;
        }
      else if(!ma_ready) ma_long=ma_short=false;

      bool htf_long=true,htf_short=true;
      if(Use_HTF_MA_Filter && htf_ready)
        {
         if(HTF_MA_Filter_Mode==Price_Above_Below)
           { htf_long=rates[i].close>htf_ma; htf_short=rates[i].close<htf_ma; }
         else
           {
            double htf_open=iOpen(_Symbol,HTF_Timeframe,htf_shift);
            double htf_close=iClose(_Symbol,HTF_Timeframe,htf_shift);
            htf_long=htf_close>htf_ma && htf_open>htf_ma && htf_close>htf_open;
            htf_short=htf_close<htf_ma && htf_open<htf_ma && htf_close<htf_open;
           }
        }
      else if(!htf_ready) htf_long=htf_short=false;

      bool session_pass=InSession(rates[i].time);
      bool adx_pass=!Use_ADX_Filter || (adx_ready && adx>=ADX_Threshold);
      bool atr_pass=!Use_ATR_Filter;
      if(Use_ATR_Filter && atr_ready)
        {
         if(ATR_Filter_Mode==ATR_Minimum) atr_pass=atr>=ATR_Minimum_Value;
         else if(ATR_Filter_Mode==ATR_Maximum) atr_pass=atr<=ATR_Maximum_Value;
         else atr_pass=atr>=ATR_Minimum_Value && atr<=ATR_Maximum_Value;
        }
      bool bull_direction=ma_long && htf_long && session_pass;
      bool bear_direction=ma_short && htf_short && session_pass;
      bool bull_bos_pass=bull_direction && adx_pass && atr_pass;
      bool bear_bos_pass=bear_direction && adx_pass && atr_pass;
      bool choch_adx_pass=!Use_ADX_Filter || ADX_Filter_Scope==ADX_BOS_Only || adx_pass;
      bool bull_choch_pass=bull_direction && choch_adx_pass && atr_pass;
      bool bear_choch_pass=bear_direction && choch_adx_pass && atr_pass;

      if(bullish_break)
        {
         high_broken=true;
         string kind=(structure==-1)?"CHoCH":"BOS";
         bool pass=kind=="BOS"?bull_bos_pass:bull_choch_pass;
         if(pass)
           {
            DrawEvent(kind,1,last_high_time,last_high,rates[i]);
            structure=1;
            newest_signal="Bullish "+kind;
            newest_signal_time=rates[i].time;
           }
        }
      if(bearish_break)
        {
         low_broken=true;
         string kind=(structure==1)?"CHoCH":"BOS";
         bool pass=kind=="BOS"?bear_bos_pass:bear_choch_pass;
         if(pass)
           {
            DrawEvent(kind,-1,last_low_time,last_low,rates[i]);
            structure=-1;
            newest_signal="Bearish "+kind;
            newest_signal_time=rates[i].time;
           }
        }
     }

   current_structure=structure;
   Comment("Market Structure: ",structure>0?"BULLISH":structure<0?"BEARISH":"UNDEFINED",
           "\nLast Swing High: ",have_high?DoubleToString(last_high,_Digits):"-",
           "\nLast Swing Low: ",have_low?DoubleToString(last_low,_Digits):"-");
   ChartRedraw();

   if(ma_handle!=INVALID_HANDLE) IndicatorRelease(ma_handle);
   if(htf_ma_handle!=INVALID_HANDLE) IndicatorRelease(htf_ma_handle);
   if(adx_handle!=INVALID_HANDLE) IndicatorRelease(adx_handle);
   if(atr_handle!=INVALID_HANDLE) IndicatorRelease(atr_handle);

   if(permit_alerts && newest_signal_time==rates[total-1].time)
     {
      bool bos=StringFind(newest_signal,"BOS")>=0;
      if((bos && Alert_BoS) || (!bos && Alert_CHoCH)) Notify(newest_signal);
     }
  }

int OnInit()
  {
   if(Swing_Detection_Length<1 || Swing_Detection_Length>50 ||
      Bars_To_Process<100 || Structure_Line_Width<1 || Structure_Line_Width>5 ||
      MA_Length<1 || HTF_MA_Length<1 || ADX_Length<1 || ATR_Length<1 ||
      ADX_Threshold<0 || ATR_Minimum_Value<0 || ATR_Maximum_Value<0 ||
      Custom_Session_Start_Hour<0 || Custom_Session_Start_Hour>23 ||
      Custom_Session_End_Hour<0 || Custom_Session_End_Hour>23 ||
      Custom_Session_Start_Minute<0 || Custom_Session_Start_Minute>59 ||
      Custom_Session_End_Minute<0 || Custom_Session_End_Minute>59)
      return INIT_PARAMETERS_INCORRECT;
   EventSetTimer(2);
   Rebuild(false);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0,prefix);
   Comment("");
  }

void OnTimer()
  {
   if(last_bar==0) Rebuild(false);
  }

void OnTick()
  {
   ENUM_TIMEFRAMES timeframe=Analysis_Timeframe==PERIOD_CURRENT
                            ?(ENUM_TIMEFRAMES)_Period:Analysis_Timeframe;
   datetime bar=iTime(_Symbol,timeframe,0);
   if(bar!=last_bar)
     {
      bool initialized=(last_bar!=0);
      last_bar=bar;
      Rebuild(initialized);
     }
  }
