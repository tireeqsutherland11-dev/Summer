#property copyright "The_Forex_Steward / MT5 conversion"
#property link      "https://www.mozilla.org/MPL/2.0/"
#property version   "1.00"
#property strict
#property description "MT5 port of Scratch.pine. Analysis/alerts only; the source does not place trades."

enum TriggerVersion { SmartEngulfments=1, SMA=2, ATRExpansion=3, Displacement=4, Loopback=5, Area=6, Candles=7, RegressionMA=8 };
enum StructureMode { LTF=0, MTF=1, HTF=2 };
enum PriceSource { SourceOpen=0, SourceClose=1, HL2=2, HLC3=3, OHLC4=4, HLCC4=5 };
enum BreakSource { BreakClose=0, BreakWick=1 };

input ENUM_TIMEFRAMES Timeframe=PERIOD_CURRENT;
input TriggerVersion IndicatorVersion=SmartEngulfments;
input StructureMode CalculateZigZagBy=MTF;
input BreakSource InternalShiftSource=BreakClose;
input PriceSource ReversalSource=HL2;
input double DisplacementThreshold=0.1;
input int TriggerPhaseLoopback=5;
input int LTF_SMA_Length=2;
input int MTF_SMA_Length=5;
input int HTF_SMA_Length=15;
input bool Show_BoS_Lines=true;
input bool Show_CHoCH_Lines=true;
input bool Show_Line_Labels=true;
input bool Use_Quantitative_Labels=false;
input int Line_Width=2;
input ENUM_LINE_STYLE Structure_Line_Style=STYLE_SOLID;
input color Bullish_BoS_Color=clrGreen;
input color Bearish_BoS_Color=clrRed;
input color CHoCH_Color=clrBlue;
input bool Plot_Swing_Labels=true;
input bool Use_Expansion_Compression_Color=false;
input color HH_HL_Color=clrGreen;
input color LL_LH_Color=clrRed;
input bool Alert_BoS=true;
input bool Alert_CHoCH=true;
input bool Alert_Swings=true;
input bool Push_Notifications=false;
input int Significance_ATR_Period=14;
input double Minimum_Swing_ATR=1.0;
input double Break_Buffer_ATR=0.10;
input int Bars_To_Process=5000;

string prefix="ScratchMT5_";
datetime lastBar=0;
struct Pivot { datetime time; double price; int type; bool broken; };
Pivot pivots[];

double Source(const MqlRates &r)
  {
   if(ReversalSource==SourceOpen) return r.open;
   if(ReversalSource==SourceClose) return r.close;
   if(ReversalSource==HL2) return (r.high+r.low)/2.0;
   if(ReversalSource==HLC3) return (r.high+r.low+r.close)/3.0;
   if(ReversalSource==OHLC4) return (r.open+r.high+r.low+r.close)/4.0;
   return (r.high+r.low+2.0*r.close)/4.0;
  }
double SMAValue(const MqlRates &r[],int i,int n)
  {
   if(i<n-1) return EMPTY_VALUE; double s=0;
   for(int k=0;k<n;k++) s+=r[i-k].close;
   return s/n;
  }
double SourceSMA(const MqlRates &r[],int i,int n)
  {
   if(i<n-1) return EMPTY_VALUE; double s=0;
   for(int k=0;k<n;k++) s+=Source(r[i-k]);
   return s/n;
  }
double TrueRange(const MqlRates &r[],int i)
  {
   if(i<1) return r[i].high-r[i].low;
   return MathMax(r[i].high-r[i].low,MathMax(MathAbs(r[i].high-r[i-1].close),MathAbs(r[i].low-r[i-1].close)));
  }
double ATRValue(const MqlRates &r[],int i,int n)
  {
   if(i<n) return EMPTY_VALUE; double s=0;
   for(int k=0;k<n;k++) s+=TrueRange(r,i-k);
   return s/n;
  }
double Regression(const MqlRates &r[],int i,int n)
  {
   if(i<n-1) return EMPTY_VALUE;
   double sx=0,sy=0,sxy=0,sxx=0;
   for(int k=0;k<n;k++) { double x=n-1-k,y=Source(r[i-k]); sx+=x; sy+=y; sxy+=x*y; sxx+=x*x; }
   double d=n*sxx-sx*sx, slope=(d==0?0:(n*sxy-sx*sy)/d);
   return (sy-slope*sx)/n+slope*(n-1);
  }
void Line(string id,datetime t1,double p1,datetime t2,double p2,color c,ENUM_LINE_STYLE style)
  {
   string n=prefix+id; if(ObjectFind(0,n)>=0) return;
   if(ObjectCreate(0,n,OBJ_TREND,0,t1,p1,t2,p2)) { ObjectSetInteger(0,n,OBJPROP_RAY_RIGHT,false); ObjectSetInteger(0,n,OBJPROP_COLOR,c); ObjectSetInteger(0,n,OBJPROP_WIDTH,Line_Width); ObjectSetInteger(0,n,OBJPROP_STYLE,style); }
  }
void Text(string id,datetime t,double p,string value,color c,bool above)
  {
   if(!Show_Line_Labels && StringFind(id,"swing")<0) return;
   string n=prefix+id; if(ObjectFind(0,n)>=0) return;
   if(ObjectCreate(0,n,OBJ_TEXT,0,t,p)) { ObjectSetString(0,n,OBJPROP_TEXT,value); ObjectSetInteger(0,n,OBJPROP_COLOR,c); ObjectSetInteger(0,n,OBJPROP_FONTSIZE,9); ObjectSetInteger(0,n,OBJPROP_ANCHOR,above?ANCHOR_LOWER:ANCHOR_UPPER); ObjectSetInteger(0,n,OBJPROP_BACK,false); }
  }
void Fire(string message)
  {
   if(lastBar==0) return; Alert(_Symbol+" "+message); if(Push_Notifications) SendNotification(_Symbol+" "+message);
  }
void AddPivot(datetime t,double price,int type)
  {
   int n=ArraySize(pivots);
   if(n>0 && pivots[n-1].type==type)
     { if((type==1 && price>pivots[n-1].price)||(type==-1 && price<pivots[n-1].price)) { pivots[n-1].time=t; pivots[n-1].price=price; } return; }
   ArrayResize(pivots,n+1); pivots[n].time=t; pivots[n].price=price; pivots[n].type=type; pivots[n].broken=false;
  }
int PreviousSame(int at)
  { for(int j=at-1;j>=0;j--) if(pivots[j].type==pivots[at].type) return j; return -1; }
void DrawPivot(int p)
  {
   if(p<0 || p>=ArraySize(pivots)) return;
   int q=PreviousSame(p); if(q<0 || !Plot_Swing_Labels) return;
   string label; color c;
   if(pivots[p].type==1) { label=pivots[p].price>pivots[q].price?"HH":"LH"; c=label=="HH"?HH_HL_Color:LL_LH_Color; }
   else { label=pivots[p].price<pivots[q].price?"LL":"HL"; c=label=="HL"?HH_HL_Color:LL_LH_Color; }
   if(Use_Quantitative_Labels) label=DoubleToString(MathAbs(pivots[p].price-pivots[p-1].price),_Digits);
   Text("swing_"+(string)p,pivots[p].time,pivots[p].price,label,c,pivots[p].type==1);
  }
// Return the first later candle whose range reaches a horizontal structure
// level. This keeps structure lines from running through candles after their
// first contact. The supplied fallback is used when no contact is available.
datetime FirstTouchTime(const MqlRates &rates[],const int total,
                        const datetime origin,const datetime fallback,
                        const double level)
  {
   for(int i=0;i<total;i++)
     {
      if(rates[i].time<=origin)
         continue;
      if(rates[i].time>fallback)
         break;
      if(rates[i].low<=level && rates[i].high>=level)
         return rates[i].time;
     }
   return fallback;
  }
void BreakLine(string kind,int p,datetime now,color c,bool above,
               const MqlRates &rates[],const int total)
  {
   datetime touch=FirstTouchTime(rates,total,pivots[p].time,now,pivots[p].price);
   datetime middle=(datetime)(((long)pivots[p].time+(long)touch)/2);
   Line(kind+"_"+(string)p,pivots[p].time,pivots[p].price,touch,pivots[p].price,c,Structure_Line_Style);
   string txt=Use_Quantitative_Labels?(string)((touch-pivots[p].time)/PeriodSeconds(Timeframe)):kind;
   Text(kind+"_label_"+(string)p,middle,pivots[p].price,txt,c,above);
  }
int BarIndexAtOrAfter(const MqlRates &rates[],const int total,const datetime time)
  {
   int left=0,right=total-1,result=-1;
   while(left<=right)
     {
      int middle=(left+right)/2;
      if(rates[middle].time>=time) { result=middle; right=middle-1; }
      else left=middle+1;
     }
   return result;
  }
bool SignificantPivot(const int p,const MqlRates &rates[],const int total)
  {
   if(p<1 || p>=ArraySize(pivots)) return false;
   int bar=BarIndexAtOrAfter(rates,total,pivots[p].time);
   if(bar<0 || bar>=total) return false;
   double atr=ATRValue(rates,bar,Significance_ATR_Period);
   if(atr==EMPTY_VALUE || atr<=0) return false;
   return MathAbs(pivots[p].price-pivots[p-1].price)>=Minimum_Swing_ATR*atr;
  }
bool BrokeLevel(const double value,const double level,const int direction,const double buffer)
  {
   return direction==1?value>level+buffer:value<level-buffer;
  }
void Rebuild()
  {
   ENUM_TIMEFRAMES tf=Timeframe==PERIOD_CURRENT?(ENUM_TIMEFRAMES)_Period:Timeframe;
   MqlRates r[]; ArraySetAsSeries(r,false);
   int wanted=MathMax(100,MathMin(Bars_To_Process,5000)); int copied=CopyRates(_Symbol,tf,0,wanted,r); if(copied<TriggerPhaseLoopback+20) return;
   ObjectsDeleteAll(0,prefix); ArrayResize(pivots,0);
   int start=MathMax(TriggerPhaseLoopback+2,HTF_SMA_Length+2);
   int lastSignal=0,lastShift=0,lastUp=start,lastDown=start;
   double runningHigh=0,runningLow=0; bool first=true,lastBull=false;
   for(int i=start;i<copied;i++)
     {
      bool up=false,down=false;
      if(IndicatorVersion==SmartEngulfments)
        {
         bool starterBull=r[i-1].close<r[i-1].open && r[i].close>r[i].open && r[i].close>r[i-1].high;
         bool starterBear=r[i-1].close>r[i-1].open && r[i].close<r[i].open && r[i].close<r[i-1].low;
         if(lastSignal==0) { if(starterBull){lastSignal=1;runningLow=r[i].low;} else if(starterBear){lastSignal=-1;runningHigh=r[i].high;} }
         if(lastSignal==-1) runningHigh=(runningHigh==0?r[i].high:MathMin(runningHigh,r[i].high)); else if(lastSignal==1) runningLow=(runningLow==0?r[i].low:MathMax(runningLow,r[i].low));
         up=lastSignal==-1 && (InternalShiftSource==BreakClose?r[i].close:r[i].high)>runningHigh;
         down=lastSignal==1 && (InternalShiftSource==BreakClose?r[i].close:r[i].low)<runningLow;
         if(up){lastSignal=1;runningHigh=0;runningLow=r[i].low;} if(down){lastSignal=-1;runningLow=0;runningHigh=r[i].high;}
        }
      else if(IndicatorVersion==SMA) { double a=SourceSMA(r,i,TriggerPhaseLoopback),b=SourceSMA(r,i-1,TriggerPhaseLoopback); up=a>b; down=a<b; }
      else if(IndicatorVersion==ATRExpansion)
        { double a=ATRValue(r,i,TriggerPhaseLoopback),avg=0; for(int k=0;k<TriggerPhaseLoopback;k++) avg+=ATRValue(r,i-k,TriggerPhaseLoopback); avg/=TriggerPhaseLoopback; up=a>avg&&r[i].close>r[i].open&&r[i].close>r[i-1].high; down=a>avg&&r[i].close<r[i].open&&r[i].close<r[i-1].low; }
      else if(IndicatorVersion==Displacement)
        { if(first){runningHigh=r[i].high;runningLow=r[i].low;first=false;} runningHigh=MathMax(runningHigh,r[i].high); runningLow=MathMin(runningLow,r[i].low); up=!lastBull&&(InternalShiftSource==BreakClose?r[i].close:r[i].high)>runningLow+DisplacementThreshold&&r[i].close>r[i].open; down=lastBull&&(InternalShiftSource==BreakClose?r[i].close:r[i].low)<runningHigh-DisplacementThreshold&&r[i].close<r[i].open; if(up||down){lastBull=up;runningHigh=r[i].high;runningLow=r[i].low;} }
      else if(IndicatorVersion==Loopback)
        { double s=Source(r[i]),hi=s,lo=s; for(int k=1;k<TriggerPhaseLoopback;k++){hi=MathMax(hi,Source(r[i-k]));lo=MathMin(lo,Source(r[i-k]));} up=s==hi; down=s==lo; }
      else if(IndicatorVersion==Area) { up=r[i].close>=r[i-TriggerPhaseLoopback].close; down=!up; }
      else if(IndicatorVersion==Candles) { up=r[i].close>r[i].open; down=r[i].close<r[i].open; }
      else { double a=Regression(r,i,TriggerPhaseLoopback),b=Regression(r,i-1,TriggerPhaseLoopback); up=a>b; down=a<b; }
      int signal=up?1:(down?-1:0);
      if(up) lastUp=i-1; if(down) lastDown=i-1;
      if(signal==0 || signal==lastShift) continue;
      int from=signal==1?lastDown:lastUp; from=MathMax(start,MathMin(from,i));
      int ext=from; double price=signal==1?r[from].low:r[from].high;
      for(int k=from;k<=i;k++) if((signal==1&&r[k].low<price)||(signal==-1&&r[k].high>price)){price=signal==1?r[k].low:r[k].high;ext=k;}
      AddPivot(r[ext].time,price,signal==1?-1:1); lastShift=signal;
     }
   for(int p=0;p<ArraySize(pivots);p++)
     {
      DrawPivot(p);
     }
   // Evaluate the latest significant, unbroken swing on each closed bar. The
   // first confirmed break establishes direction as a BoS; later breaks in the
   // same direction are BoS, while an opposite break is a CHoCH. This avoids
   // requiring a fully classified HH/HL or LH/LL sequence before any BoS can
   // appear, while retaining the ATR significance and clearance filters.
   int trend=0;
   for(int i=start;i<copied-1;i++)
     {
      double atr=ATRValue(r,i,Significance_ATR_Period); if(atr==EMPTY_VALUE) continue;
      double buffer=atr*Break_Buffer_ATR;
      int averageLength=CalculateZigZagBy==LTF?LTF_SMA_Length:(CalculateZigZagBy==MTF?MTF_SMA_Length:HTF_SMA_Length);
      double breakValue=SMAValue(r,i,averageLength); if(breakValue==EMPTY_VALUE) continue;
      for(int p=ArraySize(pivots)-1;p>=0;p--)
        {
         if(pivots[p].time>=r[i].time || pivots[p].broken || !SignificantPivot(p,r,copied)) continue;
         int dir=pivots[p].type;
         if(!BrokeLevel(breakValue,pivots[p].price,dir,buffer)) continue;
         bool choch=trend!=0 && dir!=trend;
         pivots[p].broken=true;
         trend=dir;
         if(choch && Show_CHoCH_Lines) BreakLine("CHoCH",p,r[i].time,CHoCH_Color,dir==1,r,copied);
         else if(!choch && Show_BoS_Lines) BreakLine("BoS",p,r[i].time,dir==1?Bullish_BoS_Color:Bearish_BoS_Color,dir==1,r,copied);
         if(i==copied-2) { if(choch&&Alert_CHoCH) Fire(dir==1?"Bullish CHoCH":"Bearish CHoCH"); else if(!choch&&Alert_BoS) Fire(dir==1?"Bullish BoS":"Bearish BoS"); }
         break;
        }
     }
   ChartRedraw();
  }
int OnInit() { if(TriggerPhaseLoopback<1||LTF_SMA_Length<1||MTF_SMA_Length<1||HTF_SMA_Length<1||Significance_ATR_Period<1||Minimum_Swing_ATR<0||Break_Buffer_ATR<0) return INIT_PARAMETERS_INCORRECT; EventSetTimer(2); Rebuild(); return INIT_SUCCEEDED; }
void OnDeinit(const int reason) { EventKillTimer(); ObjectsDeleteAll(0,prefix); }
void OnTimer() { if(lastBar==0) Rebuild(); }
void OnTick()
  {
   ENUM_TIMEFRAMES tf=Timeframe==PERIOD_CURRENT?(ENUM_TIMEFRAMES)_Period:Timeframe; datetime t=iTime(_Symbol,tf,0);
   if(t!=lastBar) { lastBar=t; Rebuild(); }
  }
