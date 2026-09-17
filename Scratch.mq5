#property copyright "The_Forex_Steward / MT5 conversion"
#property link      "https://www.mozilla.org/MPL/2.0/"
#property version   "1.01"
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
input color BoS_Color=clrBlue;
input color CHoCH_Color=clrRed;
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
input int Bars_To_Process=5000;
input bool Show_Trend_EMA=true;
input bool Show_Trend_Panel=true;
input int Trend_EMA_Length=50;
input int EMA_Slope_Lookback=5;
input double EMA_Flat_ATR_Threshold=0.05;
input int EMA_Cut_Lookback=10;
input double EMA_Cut_Ratio=0.5;
input bool Alert_Trend_Changes=true;
input color Uptrend_Color=clrLimeGreen;
input color Downtrend_Color=clrTomato;
input color Consolidation_Color=clrOrange;
input color Neutral_Trend_Color=clrSilver;

string prefix="ScratchMT5_";
datetime lastBar=0;
int previousMarketTrend=-1;
struct Pivot { datetime time; double price; int type; };
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
void EMAValues(const MqlRates &r[],const int total,const int length,double &values[])
  {
   ArrayResize(values,total);
   if(total<=0) return;
   double alpha=2.0/(length+1.0);
   values[0]=r[0].close;
   for(int i=1;i<total;i++) values[i]=alpha*r[i].close+(1.0-alpha)*values[i-1];
  }
void PanelLabel(const string id,const int x,const int y,const string value,const color c,const int size=9)
  {
   string n=prefix+id;
   if(!ObjectCreate(0,n,OBJ_LABEL,0,0,0)) return;
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,size);
   ObjectSetString(0,n,OBJPROP_FONT,"Arial");
   ObjectSetString(0,n,OBJPROP_TEXT,value);
  }
void DrawTrendDisplay(const MqlRates &r[],const int total,const double &ema[],
                      const int state,const string structure,const string momentum)
  {
   color c=state==1?Uptrend_Color:(state==2?Downtrend_Color:(state==3?Consolidation_Color:Neutral_Trend_Color));
   if(Show_Trend_EMA)
     {
      int first=MathMax(1,total-250);
      for(int i=first;i<total;i++)
        {
         string id="TrendEMA_"+(string)i;
         Line(id,r[i-1].time,ema[i-1],r[i].time,ema[i],c,STYLE_SOLID);
        }
     }
   if(!Show_Trend_Panel) return;
   string trend=state==1?"UPTREND":(state==2?"DOWNTREND":(state==3?"CONSOLIDATION":"NEUTRAL / TRANSITION"));
   string bg=prefix+"TrendPanelBG";
   if(ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0))
     {
      ObjectSetInteger(0,bg,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
      ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,8); ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,18);
      ObjectSetInteger(0,bg,OBJPROP_XSIZE,260); ObjectSetInteger(0,bg,OBJPROP_YSIZE,93);
      ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,clrBlack); ObjectSetInteger(0,bg,OBJPROP_BORDER_COLOR,c);
     }
   PanelLabel("TrendTitle",252,25,"CURRENT TREND",clrWhite,10);
   PanelLabel("TrendValue",18,25,trend,c,10);
   PanelLabel("StructureTitle",252,47,"Structure",clrWhite);
   PanelLabel("StructureValue",18,47,structure,c);
   PanelLabel("EMAValue",252,67,(string)Trend_EMA_Length+" EMA  "+DoubleToString(ema[total-1],_Digits),c);
   PanelLabel("MomentumValue",252,87,"Momentum  "+momentum,c);
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
   ArrayResize(pivots,n+1); pivots[n].time=t; pivots[n].price=price; pivots[n].type=type;
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
void StructureLine(string kind,int origin,datetime event_time,color c,bool above,
                   const MqlRates &rates[],const int total,const int direction)
  {
   if(origin<0 || origin>=ArraySize(pivots)) return;
   datetime end=event_time;
   // A continuation ends at the first retest/break of the old extreme.  For a
   // CHoCH, require price to pass the protected pullback so that the line is
   // not shortened by an ordinary retest immediately after that pullback.
   if(kind=="BoS")
      end=FirstTouchTime(rates,total,pivots[origin].time,event_time,pivots[origin].price);
   else
     {
      for(int i=0;i<total;i++)
        {
         if(rates[i].time<=pivots[origin].time) continue;
         if(rates[i].time>event_time) break;
         if((direction==1 && rates[i].high>pivots[origin].price) ||
            (direction==-1 && rates[i].low<pivots[origin].price))
           { end=rates[i].time; break; }
        }
     }
   datetime middle=(datetime)(((long)pivots[origin].time+(long)end)/2);
   string id=kind+"_"+(string)origin+"_"+(string)event_time;
   Line(id,pivots[origin].time,pivots[origin].price,end,pivots[origin].price,c,Structure_Line_Style);
   ENUM_TIMEFRAMES tf=Timeframe==PERIOD_CURRENT?(ENUM_TIMEFRAMES)_Period:Timeframe;
   string txt=Use_Quantitative_Labels?(string)((end-pivots[origin].time)/PeriodSeconds(tf)):kind;
   Text(id+"_label",middle,pivots[origin].price,txt,c,above);
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
   // Market-structure events are based on completed, significant swing
   // sequences.  A trend requires HH+HL or LL+LH.  Continuation BoS is only
   // possible once that trend exists and a prior HH/LL is exceeded.  A trend
   // reversal remains pending until the countertrend extreme is followed by
   // its confirming pullback (LL then LH, or HH then HL).
   int trend=0,lastHigh=-1,lastLow=-1;
   int highClass=0,lowClass=0; // +1=HH/HL, -1=LH/LL
   int pending=0,transitionOrigin=-1,transitionExtreme=-1;
   for(int p=0;p<ArraySize(pivots);p++)
     {
      if(!SignificantPivot(p,r,copied)) continue;
      if(pivots[p].type==1)
        {
         if(lastHigh<0) { lastHigh=p; continue; }
         int classification=pivots[p].price>pivots[lastHigh].price?1:-1;
         if(trend==1 && classification==1)
           {
            if(highClass==1 && Show_BoS_Lines)
               StructureLine("BoS",lastHigh,pivots[p].time,BoS_Color,true,r,copied,1);
            if(highClass==1 && p==ArraySize(pivots)-1 && Alert_BoS) Fire("Bullish BoS");
            pending=0;
           }
         else if(trend==-1 && classification==1)
           {
            if(pending==0) { pending=1; transitionOrigin=lastHigh; }
            transitionExtreme=p;
           }
         else if(trend==1 && pending==-1 && classification==-1)
           {
            if(Show_CHoCH_Lines) StructureLine("CHoCH",transitionOrigin,pivots[transitionExtreme].time,CHoCH_Color,true,r,copied,-1);
            if(p==ArraySize(pivots)-1 && Alert_CHoCH) Fire("Bearish CHoCH");
            trend=-1; pending=0;
           }
         highClass=classification; lastHigh=p;
        }
      else
        {
         if(lastLow<0) { lastLow=p; continue; }
         int classification=pivots[p].price>pivots[lastLow].price?1:-1;
         if(trend==-1 && classification==-1)
           {
            if(lowClass==-1 && Show_BoS_Lines)
               StructureLine("BoS",lastLow,pivots[p].time,BoS_Color,false,r,copied,-1);
            if(lowClass==-1 && p==ArraySize(pivots)-1 && Alert_BoS) Fire("Bearish BoS");
            pending=0;
           }
         else if(trend==1 && classification==-1)
           {
            if(pending==0) { pending=-1; transitionOrigin=lastLow; }
            transitionExtreme=p;
           }
         else if(trend==-1 && pending==1 && classification==1)
           {
            if(Show_CHoCH_Lines) StructureLine("CHoCH",transitionOrigin,pivots[transitionExtreme].time,CHoCH_Color,false,r,copied,1);
            if(p==ArraySize(pivots)-1 && Alert_CHoCH) Fire("Bullish CHoCH");
            trend=1; pending=0;
           }
         lowClass=classification; lastLow=p;
        }

      if(trend==0 && highClass!=0 && lowClass!=0)
        {
         if(highClass==1 && lowClass==1) trend=1;
         else if(highClass==-1 && lowClass==-1) trend=-1;
        }
     }

   // Market structure is the primary trend filter.  The EMA may confirm an
   // established HH+HL / LL+LH sequence, but can never create one by itself.
   double ema[]; EMAValues(r,copied,Trend_EMA_Length,ema);
   int current=copied-1,slopeBar=current-EMA_Slope_Lookback;
   double atr=ATRValue(r,current,14);
   double threshold=(atr==EMPTY_VALUE?0.0:atr*EMA_Flat_ATR_Threshold);
   double emaChange=slopeBar>=0?ema[current]-ema[slopeBar]:0.0;
   bool emaFlat=slopeBar>=0 && MathAbs(emaChange)<=threshold;
   bool emaRising=slopeBar>=0 && emaChange>threshold;
   bool emaFalling=slopeBar>=0 && emaChange<-threshold;
   int cutStart=MathMax(0,current-EMA_Cut_Lookback+1),cuts=0,samples=current-cutStart+1;
   for(int i=cutStart;i<=current;i++)
      if(r[i].low<=ema[i] && r[i].high>=ema[i]) cuts++;
   bool emaThroughCandles=samples>0 && (double)cuts/samples>=EMA_Cut_Ratio;
   bool bullishStructure=highClass==1 && lowClass==1;
   bool bearishStructure=highClass==-1 && lowClass==-1;
   bool structureAboveEMA=lastHigh>=0 && lastLow>=0 &&
                          pivots[lastHigh].price>ema[current] && pivots[lastLow].price>ema[current];
   bool structureBelowEMA=lastHigh>=0 && lastLow>=0 &&
                          pivots[lastHigh].price<ema[current] && pivots[lastLow].price<ema[current];
   bool marketUptrend=bullishStructure && structureAboveEMA && r[current].close>ema[current] && emaRising;
   bool marketDowntrend=bearishStructure && structureBelowEMA && r[current].close<ema[current] && emaFalling;
   bool marketConsolidation=!bullishStructure && !bearishStructure && emaFlat && emaThroughCandles;
   int marketTrend=marketUptrend?1:(marketDowntrend?2:(marketConsolidation?3:0));
   string structure=bullishStructure?"HH + HL":(bearishStructure?"LL + LH":"Mixed / Unclear");
   string momentum=emaFlat?(emaThroughCandles?"Flat; cutting candles":"Flat"):
                   (emaRising?"Rising":(emaFalling?"Falling":"Neutral"));
   DrawTrendDisplay(r,copied,ema,marketTrend,structure,momentum);
   if(Alert_Trend_Changes && previousMarketTrend>=0 && marketTrend!=previousMarketTrend)
     {
      if(marketTrend==1) Fire("Market trend changed to UPTREND: HH + HL above a rising "+(string)Trend_EMA_Length+" EMA");
      else if(marketTrend==2) Fire("Market trend changed to DOWNTREND: LL + LH below a falling "+(string)Trend_EMA_Length+" EMA");
      else if(marketTrend==3) Fire("Market trend changed to CONSOLIDATION: unclear structure and a flat EMA through price");
     }
   previousMarketTrend=marketTrend;
   ChartRedraw();
  }
int OnInit() { if(TriggerPhaseLoopback<1||LTF_SMA_Length<1||MTF_SMA_Length<1||HTF_SMA_Length<1||Significance_ATR_Period<1||Minimum_Swing_ATR<0||Trend_EMA_Length<1||EMA_Slope_Lookback<1||EMA_Flat_ATR_Threshold<0||EMA_Cut_Lookback<2||EMA_Cut_Ratio<0.0||EMA_Cut_Ratio>1.0) return INIT_PARAMETERS_INCORRECT; EventSetTimer(2); Rebuild(); return INIT_SUCCEEDED; }
void OnDeinit(const int reason) { EventKillTimer(); ObjectsDeleteAll(0,prefix); }
void OnTimer() { if(lastBar==0) Rebuild(); }
void OnTick()
  {
   ENUM_TIMEFRAMES tf=Timeframe==PERIOD_CURRENT?(ENUM_TIMEFRAMES)_Period:Timeframe; datetime t=iTime(_Symbol,tf,0);
   if(t!=lastBar) { lastBar=t; Rebuild(); }
  }
