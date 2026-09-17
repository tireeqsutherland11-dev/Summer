#property copyright "MT5 conversion"
#property version   "2.00"
#property strict
#property description "Market-trend, BoS and CHoCH port of the supplied Pine indicator."
#property description "Analysis and alerts only; this Expert Advisor never places orders."

input ENUM_TIMEFRAMES Analysis_Timeframe=PERIOD_CURRENT;
input int Swing_Detection_Length=5;
input int Bars_To_Process=5000;

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

      if(bullish_break)
        {
         high_broken=true;
         string kind=(structure==-1)?"CHoCH":"BOS";
         DrawEvent(kind,1,last_high_time,last_high,rates[i]);
         structure=1;
         newest_signal="Bullish "+kind;
         newest_signal_time=rates[i].time;
        }
      if(bearish_break)
        {
         low_broken=true;
         string kind=(structure==1)?"CHoCH":"BOS";
         DrawEvent(kind,-1,last_low_time,last_low,rates[i]);
         structure=-1;
         newest_signal="Bearish "+kind;
         newest_signal_time=rates[i].time;
        }
     }

   current_structure=structure;
   Comment("Market Structure: ",structure>0?"BULLISH":structure<0?"BEARISH":"UNDEFINED",
           "\nLast Swing High: ",have_high?DoubleToString(last_high,_Digits):"-",
           "\nLast Swing Low: ",have_low?DoubleToString(last_low,_Digits):"-");
   ChartRedraw();

   if(permit_alerts && newest_signal_time==rates[total-1].time)
     {
      bool bos=StringFind(newest_signal,"BOS")>=0;
      if((bos && Alert_BoS) || (!bos && Alert_CHoCH)) Notify(newest_signal);
     }
  }

int OnInit()
  {
   if(Swing_Detection_Length<1 || Swing_Detection_Length>50 ||
      Bars_To_Process<100 || Structure_Line_Width<1 || Structure_Line_Width>5)
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
