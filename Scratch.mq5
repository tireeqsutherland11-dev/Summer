#property copyright "MT5 conversion"
#property version   "2.10"
#property strict
#property description "Market-trend, BoS and CHoCH port of the supplied Pine indicator."
#property description "Analysis and alerts only; this Expert Advisor never places orders."

input ENUM_TIMEFRAMES Analysis_Timeframe=PERIOD_CURRENT;
input int Swing_Detection_Length=5;
input int Bars_To_Process=5000;

input group "Optional signal filters"
input bool Use_MA_Filter=false;
input int MA_Period=50;
input ENUM_MA_METHOD MA_Method=MODE_EMA;
input ENUM_APPLIED_PRICE MA_Applied_Price=PRICE_CLOSE;
input bool Use_Session_Filter=false;
input int Session_Start_Hour=7;
input int Session_End_Hour=17;
input bool Use_ADX_Filter=false;
input int ADX_Period=14;
input double Minimum_ADX=20.0;
input bool Require_DI_Direction=true;
input bool Use_ATR_Filter=false;
input int ATR_Period=14;
input double Minimum_ATR_Points=0.0;
input double Minimum_ATR_Ratio=1.0;

input group "Display"
input bool Show_Structure_Labels=true;
input color HH_HL_Color=clrLimeGreen;
input color LH_LL_Color=clrTomato;

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

double AppliedPrice(const MqlRates &bar)
  {
   if(MA_Applied_Price==PRICE_OPEN) return bar.open;
   if(MA_Applied_Price==PRICE_HIGH) return bar.high;
   if(MA_Applied_Price==PRICE_LOW) return bar.low;
   if(MA_Applied_Price==PRICE_MEDIAN) return (bar.high+bar.low)/2.0;
   if(MA_Applied_Price==PRICE_TYPICAL) return (bar.high+bar.low+bar.close)/3.0;
   if(MA_Applied_Price==PRICE_WEIGHTED) return (bar.high+bar.low+2.0*bar.close)/4.0;
   return bar.close;
  }

double TrueRange(const MqlRates &rates[],const int index)
  {
   if(index==0) return rates[index].high-rates[index].low;
   return MathMax(rates[index].high-rates[index].low,
                  MathMax(MathAbs(rates[index].high-rates[index-1].close),
                          MathAbs(rates[index].low-rates[index-1].close)));
  }

void BuildFilterValues(const MqlRates &rates[],const int total,double &ma[],
                       double &atr[],double &adx[],double &plus_di[],double &minus_di[])
  {
   ArrayResize(ma,total); ArrayResize(atr,total); ArrayResize(adx,total);
   ArrayResize(plus_di,total); ArrayResize(minus_di,total);
   double alpha=2.0/(MA_Period+1.0),atr_sum=0.0;
   double adx_tr_sum=0.0,plus_sum=0.0,minus_sum=0.0,dx_sum=0.0;
   for(int i=0;i<total;i++)
     {
      ma[i]=EMPTY_VALUE; atr[i]=EMPTY_VALUE; adx[i]=EMPTY_VALUE;
      plus_di[i]=EMPTY_VALUE; minus_di[i]=EMPTY_VALUE;
      double price=AppliedPrice(rates[i]);
      if(MA_Method==MODE_EMA || MA_Method==MODE_SMMA)
        {
         double a=MA_Method==MODE_EMA?alpha:1.0/MA_Period;
         ma[i]=(i==0?price:a*price+(1.0-a)*ma[i-1]);
        }
      else if(i>=MA_Period-1)
        {
         double weighted=0.0,weight_sum=0.0;
         for(int k=0;k<MA_Period;k++)
           {
            double weight=MA_Method==MODE_LWMA?(double)(MA_Period-k):1.0;
            weighted+=AppliedPrice(rates[i-k])*weight; weight_sum+=weight;
           }
         ma[i]=weighted/weight_sum;
        }

      double tr=TrueRange(rates,i),plus=0.0,minus=0.0;
      if(i<ATR_Period) atr_sum+=tr;
      if(i==ATR_Period-1) atr[i]=atr_sum/ATR_Period;
      else if(i>=ATR_Period) atr[i]=(atr[i-1]*(ATR_Period-1)+tr)/ATR_Period;
      if(i>0)
        {
         double up=rates[i].high-rates[i-1].high;
         double down=rates[i-1].low-rates[i].low;
         plus=(up>down && up>0.0)?up:0.0;
         minus=(down>up && down>0.0)?down:0.0;
        }
      if(i<=ADX_Period) { adx_tr_sum+=tr; plus_sum+=plus; minus_sum+=minus; }
      else { adx_tr_sum=adx_tr_sum-adx_tr_sum/ADX_Period+tr; plus_sum=plus_sum-plus_sum/ADX_Period+plus; minus_sum=minus_sum-minus_sum/ADX_Period+minus; }
      if(i>=ADX_Period)
        {
         plus_di[i]=adx_tr_sum>0.0?100.0*plus_sum/adx_tr_sum:0.0;
         minus_di[i]=adx_tr_sum>0.0?100.0*minus_sum/adx_tr_sum:0.0;
         double divisor=plus_di[i]+minus_di[i];
         double dx=divisor>0.0?100.0*MathAbs(plus_di[i]-minus_di[i])/divisor:0.0;
         if(i<2*ADX_Period) dx_sum+=dx;
         if(i==2*ADX_Period-1) adx[i]=dx_sum/ADX_Period;
         else if(i>=2*ADX_Period) adx[i]=(adx[i-1]*(ADX_Period-1)+dx)/ADX_Period;
        }
     }
  }

bool InSession(const datetime time)
  {
   if(!Use_Session_Filter || Session_Start_Hour==Session_End_Hour) return true;
   MqlDateTime stamp; TimeToStruct(time,stamp);
   if(Session_Start_Hour<Session_End_Hour)
      return stamp.hour>=Session_Start_Hour && stamp.hour<Session_End_Hour;
   return stamp.hour>=Session_Start_Hour || stamp.hour<Session_End_Hour;
  }

bool FiltersPass(const int direction,const int index,const MqlRates &rates[],
                 const double &ma[],const double &atr[],const double &adx[],
                 const double &plus_di[],const double &minus_di[])
  {
   if(Use_MA_Filter && (ma[index]==EMPTY_VALUE ||
      (direction>0 && rates[index].close<=ma[index]) ||
      (direction<0 && rates[index].close>=ma[index]))) return false;
   if(!InSession(rates[index].time)) return false;
   if(Use_ADX_Filter && (adx[index]==EMPTY_VALUE || adx[index]<Minimum_ADX ||
      (Require_DI_Direction && ((direction>0 && plus_di[index]<=minus_di[index]) ||
                                (direction<0 && minus_di[index]<=plus_di[index]))))) return false;
   if(Use_ATR_Filter)
     {
      if(atr[index]==EMPTY_VALUE || atr[index]<_Point*Minimum_ATR_Points) return false;
      double average=0.0; int count=0;
      for(int k=MathMax(0,index-ATR_Period+1);k<=index;k++)
         if(atr[k]!=EMPTY_VALUE) { average+=atr[k]; count++; }
      if(count==0 || atr[index]<(average/count)*Minimum_ATR_Ratio) return false;
     }
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
   if(Show_Structure_Labels)
      // Put the caption at the right endpoint: bullish text sits above the
      // level and bearish text below it, rather than on the event candle.
      DrawText(id+"_label",event_bar.time,level,kind,clr,direction>0,10);
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
   double ma[],atr[],adx[],plus_di[],minus_di[];
   BuildFilterValues(rates,total,ma,atr,adx,plus_di,minus_di);
   double previous_high=0.0,previous_low=0.0;
   bool have_previous_high=false,have_previous_low=false;

   for(int i=2*Swing_Detection_Length;i<total;i++)
     {
      // ta.pivothigh/ta.pivotlow confirm a candidate Swing_Detection_Length
      // bars later.  The candidate is therefore i-length, not the current bar.
      int candidate=i-Swing_Detection_Length;
      if(IsPivotHigh(rates,total,candidate,Swing_Detection_Length))
        {
         if(Show_Swing_Points && have_previous_high)
            DrawText("swing_high_"+(string)rates[candidate].time,rates[candidate].time,
                     rates[candidate].high,rates[candidate].high>previous_high?"HH":"LH",
                     rates[candidate].high>previous_high?HH_HL_Color:LH_LL_Color,true,9);
         previous_high=rates[candidate].high; have_previous_high=true;
         last_high=rates[candidate].high;
         last_high_time=rates[candidate].time;
         have_high=true;
         high_broken=false;
        }
      if(IsPivotLow(rates,total,candidate,Swing_Detection_Length))
        {
         if(Show_Swing_Points && have_previous_low)
            DrawText("swing_low_"+(string)rates[candidate].time,rates[candidate].time,
                     rates[candidate].low,rates[candidate].low>previous_low?"HL":"LL",
                     rates[candidate].low>previous_low?HH_HL_Color:LH_LL_Color,false,9);
         previous_low=rates[candidate].low; have_previous_low=true;
         last_low=rates[candidate].low;
         last_low_time=rates[candidate].time;
         have_low=true;
         low_broken=false;
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
         if(!FiltersPass(1,i,rates,ma,atr,adx,plus_di,minus_di)) continue;
         string kind=(structure==-1)?"CHoCH":"BOS";
         DrawEvent(kind,1,last_high_time,last_high,rates[i]);
         structure=1;
         newest_signal="Bullish "+kind;
         newest_signal_time=rates[i].time;
        }
      if(bearish_break)
        {
         low_broken=true;
         if(!FiltersPass(-1,i,rates,ma,atr,adx,plus_di,minus_di)) continue;
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
      Bars_To_Process<100 || Structure_Line_Width<1 || Structure_Line_Width>5 ||
      MA_Period<1 || ADX_Period<2 || ATR_Period<1 || Minimum_ADX<0.0 ||
      Minimum_ATR_Points<0.0 || Minimum_ATR_Ratio<0.0 ||
      Session_Start_Hour<0 || Session_Start_Hour>23 ||
      Session_End_Hour<0 || Session_End_Hour>23)
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
