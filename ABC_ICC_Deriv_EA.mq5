#property copyright "ABC/ICC Deriv EA"
#property version   "1.00"
#property strict
#property description "Self-contained, closed-bar ABC/ICC confluence Expert Advisor"

enum TradingMode { MODE_AUTOMATED, MODE_SIGNAL_ONLY, MODE_ALERT_ONLY };
enum ConfirmationPolicy { CONFIRM_ALL, CONFIRM_ANY };
enum FibToleranceMode { FIB_TOL_ATR, FIB_TOL_POINTS };
enum StopMode { SL_SWING, SL_ATR, SL_HYBRID };
enum Direction { DIR_NONE=0, DIR_BUY=1, DIR_SELL=-1 };

input group "General"
input TradingMode InpTradingMode=MODE_AUTOMATED;
input ulong InpMagicNumber=880015;
input bool InpEnableLongTrades=true;
input bool InpEnableShortTrades=true;
input int InpMaxSpreadPoints=0;
input int InpMaxSlippagePoints=20;
input int InpBarsToLoad=1000;

input group "Timeframes and confirmation"
input ENUM_TIMEFRAMES InpTrendTimeframe=PERIOD_H1;
input ENUM_TIMEFRAMES InpStructureTimeframe=PERIOD_M15;
input ENUM_TIMEFRAMES InpConfirmationTimeframe1=PERIOD_M15;
input ENUM_TIMEFRAMES InpConfirmationTimeframe2=PERIOD_M30;
input ConfirmationPolicy InpConfirmationPolicy=CONFIRM_ALL;

input group "Swings and structure"
input int InpFractalLength=3;
input bool InpATRFilter=true;
input int InpATRPeriod=14;
input double InpMinimumSwingATR=1.5;
input int InpZigZagDepth=12;
input int InpZigZagDeviation=5;
input int InpZigZagBackstep=3;
input bool InpStructureBreakOnClose=true;
input int InpABCMaxAgeBars=100;

input group "Boundaries, Fibonacci and liquidity"
input int InpMinimumLevelTouches=3;
input double InpZoneSizeATR=0.25;
input double InpTrendlineReactionATR=0.20;
input bool InpUseFibonacciFilter=true;
input double InpPrimaryFibLevel=0.88;
input FibToleranceMode InpFibToleranceMode=FIB_TOL_ATR;
input double InpFibTolerance=0.10;
input bool InpRequireFibStructuralConfluence=true;
input bool InpRequireLiquiditySweep=true;
input int InpLiquidityLookbackBars=20;
input double InpLiquidityMaxSweepATR=0.50;

input group "Pattern and scoring"
input double InpMinimumEngulfingStrength=1.25;
input int InpAverageBodyPeriod=10;
input int InpMinimumEntryScore=8;
input int InpScoreTrendAlignment=2;
input int InpScoreMarketStructure=2;
input int InpScoreMajorBoundary=2;
input int InpScoreTrendlineReaction=1;
input int InpScoreFibonacciZone=2;
input int InpScoreFibStructureReaction=3;
input int InpScoreABCICC=2;
input int InpScoreLiquiditySweep=2;
input int InpScoreEngulfing=2;
input int InpScoreConfirmationClose=2;

input group "Risk and limits"
input StopMode InpSLMode=SL_HYBRID;
input double InpSLATRBuffer=0.25;
input double InpSLATRMultiplier=2.0;
input int InpStructureTargetBuffer=20;
input double InpMinimumRR=1.7;
input double InpRiskPercentage=10.0;
input int InpMaximumOpenPositions=1;
input int InpMaximumTradesPerDay=2;
input int InpMaximumTradesPerWeek=6;
input int InpLossReductionAfter=2;
input double InpLossRiskMultiplier=0.50;
input double InpMaximumVolume=0.0;
input double InpMarginSafetyPercent=100.0;

input group "Display, alerts and logging"
input bool InpEnableVisualization=true;
input bool InpShowDashboard=true;
input bool InpShowStructureLabels=true;
input bool InpShowBoundaries=true;
input bool InpShowFibonacci=true;
input int InpMaxChartSwings=30;
input bool InpEnableTerminalAlert=true;
input bool InpEnablePushNotification=false;
input bool InpEnableEmailNotification=false;
input bool InpEnableCSVLogging=true;
input string InpLogFileName="ABC_ICC_Deriv_Trades.csv";
input bool InpVerboseJournal=false;

struct SwingPoint { datetime time; double price; bool high; int shift; };
struct Analysis {
   Direction direction; SwingPoint recentHigh,recentLow,priorHigh,priorLow;
   double atr,fib,fibLow,fibHigh,target; bool trendAligned,structure,majorBoundary;
   bool trendline,fibZone,fibStructure,abc,sweep,engulf1,engulf2,confirmed;
   int score,maxScore; string reason; datetime signalTime;
};
struct Plan { Direction direction; double entry,sl,tp,rr,volume; string id; };

int g_atrTrend=INVALID_HANDLE,g_atrStructure=INVALID_HANDLE;
datetime g_lastBar=0,g_lastSignal=0;
string g_prefix;
int g_lossStreak=0;

double NormalizePrice(const double p) { return NormalizeDouble(p,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)); }
double BufferValue(const int handle,const int shift) {
   double v[1]; if(handle==INVALID_HANDLE || CopyBuffer(handle,0,shift,1,v)!=1) return 0.0; return v[0];
}
bool Rates(const ENUM_TIMEFRAMES tf,const int count,MqlRates &r[]) {
   ArraySetAsSeries(r,true); return CopyRates(_Symbol,tf,0,count,r)>=count;
}
bool IsPivot(const MqlRates &r[],const int n,const int i,const bool high) {
   for(int k=1;k<=InpFractalLength;k++) {
      if(high && (r[i].high<=r[i-k].high || r[i].high<r[i+k].high)) return false;
      if(!high && (r[i].low>=r[i-k].low || r[i].low>r[i+k].low)) return false;
   }
   return true;
}
int CollectSwings(const ENUM_TIMEFRAMES tf,SwingPoint &out[]) {
   MqlRates r[]; int want=MathMin(InpBarsToLoad,5000);
   if(!Rates(tf,want,r)) return 0;
   ArrayResize(out,0);
   for(int i=want-InpFractalLength-1;i>InpFractalLength && ArraySize(out)<120;i--) {
      bool hi=IsPivot(r,want,i,true),lo=IsPivot(r,want,i,false);
      if(!hi && !lo) continue;
      SwingPoint p; p.time=r[i].time; p.high=hi; p.price=hi?r[i].high:r[i].low; p.shift=i;
      int n=ArraySize(out);
      if(n>0 && out[n-1].high==p.high) {
         bool stronger=(p.high?p.price>out[n-1].price:p.price<out[n-1].price);
         if(stronger) out[n-1]=p;
      } else { ArrayResize(out,n+1); out[n]=p; }
   }
   return ArraySize(out);
}
bool LastTwo(const SwingPoint &s[],const bool high,SwingPoint &last,SwingPoint &prior) {
   int found=0;
   for(int i=ArraySize(s)-1;i>=0;i--) if(s[i].high==high) {
      if(found==0) last=s[i]; else { prior=s[i]; return true; } found++;
   }
   return false;
}
Direction StructureDirection(const SwingPoint &s[],SwingPoint &rh,SwingPoint &rl,SwingPoint &ph,SwingPoint &pl) {
   if(!LastTwo(s,true,rh,ph)||!LastTwo(s,false,rl,pl)) return DIR_NONE;
   if(rh.price>ph.price && rl.price>pl.price) return DIR_BUY;
   if(rh.price<ph.price && rl.price<pl.price) return DIR_SELL;
   return DIR_NONE;
}
bool Engulfing(const ENUM_TIMEFRAMES tf,const Direction d) {
   MqlRates r[]; if(!Rates(tf,InpAverageBodyPeriod+3,r)) return false;
   double avg=0; for(int i=2;i<InpAverageBodyPeriod+2;i++) avg+=MathAbs(r[i].close-r[i].open);
   avg/=InpAverageBodyPeriod; double body=MathAbs(r[1].close-r[1].open);
   if(body<avg*InpMinimumEngulfingStrength) return false;
   double top1=MathMax(r[1].open,r[1].close),bot1=MathMin(r[1].open,r[1].close);
   double top2=MathMax(r[2].open,r[2].close),bot2=MathMin(r[2].open,r[2].close);
   return d==DIR_BUY ? r[1].close>r[1].open && top1>=top2 && bot1<=bot2
                     : r[1].close<r[1].open && top1>=top2 && bot1<=bot2;
}
bool LiquiditySweep(const MqlRates &r[],const Direction d,const double atr) {
   double ref=(d==DIR_BUY?DBL_MAX:-DBL_MAX);
   for(int i=2;i<InpLiquidityLookbackBars+2;i++) ref=d==DIR_BUY?MathMin(ref,r[i].low):MathMax(ref,r[i].high);
   double penetration=d==DIR_BUY?ref-r[1].low:r[1].high-ref;
   return penetration>0 && penetration<=atr*InpLiquidityMaxSweepATR && (d==DIR_BUY?r[1].close>ref:r[1].close<ref);
}
int ZoneTouches(const SwingPoint &s[],const double price,const double width) {
   int n=0; for(int i=0;i<ArraySize(s);i++) if(MathAbs(s[i].price-price)<=width) n++; return n;
}
double StructuralTarget(const SwingPoint &s[],const Direction d,const double entry) {
   double target=(d==DIR_BUY?DBL_MAX:-DBL_MAX);
   for(int i=0;i<ArraySize(s);i++) {
      if(d==DIR_BUY && s[i].high && s[i].price>entry) target=MathMin(target,s[i].price);
      if(d==DIR_SELL && !s[i].high && s[i].price<entry) target=MathMax(target,s[i].price);
   }
   if(target==DBL_MAX || target==-DBL_MAX) return 0; return target+(d==DIR_BUY?-1:1)*InpStructureTargetBuffer*_Point;
}
bool Analyze(Analysis &a) {
   SwingPoint trend[],structure[]; if(CollectSwings(InpTrendTimeframe,trend)<4||CollectSwings(InpStructureTimeframe,structure)<4) { a.reason="warming up"; return false; }
   SwingPoint th,tl,tph,tpl; Direction td=StructureDirection(trend,th,tl,tph,tpl);
   Direction sd=StructureDirection(structure,a.recentHigh,a.recentLow,a.priorHigh,a.priorLow);
   if(td==DIR_NONE||sd==DIR_NONE||td!=sd) { a.reason="timeframe structure not aligned"; return false; }
   a.direction=sd; a.trendAligned=true; a.structure=true; a.atr=BufferValue(g_atrStructure,1);
   if(a.atr<=0) { a.reason="ATR unavailable"; return false; }
   MqlRates r[]; int need=MathMax(InpLiquidityLookbackBars+3,InpABCMaxAgeBars+3); if(!Rates(InpStructureTimeframe,need,r)) return false;
   a.signalTime=r[1].time;
   double impulseLow=(sd==DIR_BUY?a.priorLow.price:a.recentLow.price);
   double impulseHigh=(sd==DIR_BUY?a.recentHigh.price:a.priorHigh.price);
   a.fib=sd==DIR_BUY?impulseHigh-(impulseHigh-impulseLow)*InpPrimaryFibLevel:impulseLow+(impulseHigh-impulseLow)*InpPrimaryFibLevel;
   double tolerance=InpFibToleranceMode==FIB_TOL_ATR?a.atr*InpFibTolerance:InpFibTolerance*_Point;
   a.fibLow=a.fib-tolerance; a.fibHigh=a.fib+tolerance;
   double close=r[1].close,zoneWidth=a.atr*InpZoneSizeATR;
   a.fibZone=(r[1].low<=a.fibHigh && r[1].high>=a.fibLow);
   double boundary=sd==DIR_BUY?a.recentLow.price:a.recentHigh.price;
   a.majorBoundary=ZoneTouches(structure,boundary,zoneWidth)>=InpMinimumLevelTouches;
   a.trendline=MathAbs(close-boundary)<=a.atr*InpTrendlineReactionATR;
   a.fibStructure=a.fibZone&&(a.majorBoundary||a.trendline||MathAbs(a.fib-boundary)<=zoneWidth);
   double breakLevel=sd==DIR_BUY?a.recentHigh.price:a.recentLow.price;
   a.abc=InpStructureBreakOnClose?(sd==DIR_BUY?r[1].close>breakLevel:r[1].close<breakLevel):(sd==DIR_BUY?r[1].high>breakLevel:r[1].low<breakLevel);
   a.sweep=LiquiditySweep(r,sd,a.atr); a.engulf1=Engulfing(InpConfirmationTimeframe1,sd); a.engulf2=Engulfing(InpConfirmationTimeframe2,sd);
   a.confirmed=InpConfirmationPolicy==CONFIRM_ALL?(a.engulf1&&a.engulf2):(a.engulf1||a.engulf2);
   a.maxScore=InpScoreTrendAlignment+InpScoreMarketStructure+InpScoreMajorBoundary+InpScoreTrendlineReaction+InpScoreFibonacciZone+InpScoreFibStructureReaction+InpScoreABCICC+InpScoreLiquiditySweep+InpScoreEngulfing+InpScoreConfirmationClose;
   a.score=InpScoreTrendAlignment+InpScoreMarketStructure;
   if(a.majorBoundary)a.score+=InpScoreMajorBoundary; if(a.trendline)a.score+=InpScoreTrendlineReaction;
   if(a.fibZone)a.score+=InpScoreFibonacciZone; if(a.fibStructure)a.score+=InpScoreFibStructureReaction;
   if(a.abc)a.score+=InpScoreABCICC; if(a.sweep)a.score+=InpScoreLiquiditySweep;
   if(a.engulf1||a.engulf2)a.score+=InpScoreEngulfing; if(a.confirmed)a.score+=InpScoreConfirmationClose;
   a.target=StructuralTarget(structure,sd,close);
   if(InpUseFibonacciFilter&&!a.fibZone) a.reason="outside Fibonacci zone";
   else if(InpRequireFibStructuralConfluence&&!a.fibStructure) a.reason="no Fibonacci/structure overlap";
   else if(InpRequireLiquiditySweep&&!a.sweep) a.reason="liquidity sweep absent";
   else if(!a.confirmed) a.reason="confirmation policy not met";
   else if(!a.abc) a.reason="ABC continuation not confirmed";
   else if(a.score<InpMinimumEntryScore) a.reason="score below threshold";
   else if(a.target==0) a.reason="no structural target"; else a.reason="ready";
   return a.reason=="ready";
}
int CountPositions() {
   int n=0; for(int i=PositionsTotal()-1;i>=0;i--) { ulong t=PositionGetTicket(i); if(t&&PositionGetString(POSITION_SYMBOL)==_Symbol&&(ulong)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber)n++; } return n;
}
datetime DayStart() { MqlDateTime x; TimeToStruct(TimeCurrent(),x); x.hour=0;x.min=0;x.sec=0; return StructToTime(x); }
datetime WeekStart() { datetime d=DayStart(); MqlDateTime x; TimeToStruct(d,x); int back=(x.day_of_week+6)%7; return d-back*86400; }
int EntryCount(const datetime from) {
   if(!HistorySelect(from,TimeCurrent())) return 0; int n=0;
   for(int i=0;i<HistoryDealsTotal();i++) { ulong t=HistoryDealGetTicket(i); if(t&&HistoryDealGetString(t,DEAL_SYMBOL)==_Symbol&&(ulong)HistoryDealGetInteger(t,DEAL_MAGIC)==InpMagicNumber&&HistoryDealGetInteger(t,DEAL_ENTRY)==DEAL_ENTRY_IN)n++; } return n;
}
double VolumeForRisk(const Direction d,const double entry,const double sl) {
   double risk=AccountInfoDouble(ACCOUNT_BALANCE)*InpRiskPercentage/100.0;
   if(g_lossStreak>=InpLossReductionAfter) risk*=InpLossRiskMultiplier;
   double profit=0; if(!OrderCalcProfit(d==DIR_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,1.0,entry,sl,profit)||profit==0)return 0;
   double raw=risk/MathAbs(profit),step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),minv=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),maxv=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   if(InpMaximumVolume>0)maxv=MathMin(maxv,InpMaximumVolume); raw=MathMin(raw,maxv); double v=MathFloor(raw/step+1e-9)*step;
   if(v<minv)return 0; return NormalizeDouble(v,8);
}
bool BuildPlan(const Analysis &a,Plan &p) {
   MqlTick q; if(!SymbolInfoTick(_Symbol,q))return false; p.direction=a.direction; p.entry=a.direction==DIR_BUY?q.ask:q.bid;
   double swingSL=a.direction==DIR_BUY?a.recentLow.price-a.atr*InpSLATRBuffer:a.recentHigh.price+a.atr*InpSLATRBuffer;
   double atrSL=p.entry+(a.direction==DIR_BUY?-1:1)*a.atr*InpSLATRMultiplier;
   p.sl=InpSLMode==SL_SWING?swingSL:(InpSLMode==SL_ATR?atrSL:(a.direction==DIR_BUY?MathMin(swingSL,atrSL):MathMax(swingSL,atrSL)));
   p.tp=a.target; double risk=MathAbs(p.entry-p.sl),reward=(a.direction==DIR_BUY?p.tp-p.entry:p.entry-p.tp); if(risk<=0||reward<=0)return false;
   p.rr=reward/risk; if(p.rr<InpMinimumRR)return false; p.volume=VolumeForRisk(a.direction,p.entry,p.sl); if(p.volume<=0)return false;
   p.entry=NormalizePrice(p.entry);p.sl=NormalizePrice(p.sl);p.tp=NormalizePrice(p.tp); p.id=_Symbol+"-"+IntegerToString((int)a.signalTime)+"-"+(a.direction==DIR_BUY?"B":"S"); return true;
}
bool LimitsPass(string &why) {
   MqlTick q; SymbolInfoTick(_Symbol,q); if(InpMaxSpreadPoints>0&&(q.ask-q.bid)/_Point>InpMaxSpreadPoints){why="spread limit";return false;}
   if(CountPositions()>=InpMaximumOpenPositions){why="position limit";return false;}
   if(EntryCount(DayStart())>=InpMaximumTradesPerDay){why="daily limit";return false;}
   if(EntryCount(WeekStart())>=InpMaximumTradesPerWeek){why="weekly limit";return false;} return true;
}
void LogSetup(const Analysis &a,const Plan &p,const string action) {
   if(!InpEnableCSVLogging)return; int f=FileOpen(InpLogFileName,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_SHARE_READ,','); if(f==INVALID_HANDLE)return;
   if(FileSize(f)==0)FileWrite(f,"time","setup","symbol","direction","entry","sl","tp","rr","score","maximum","action"); FileSeek(f,0,SEEK_END);
   FileWrite(f,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),p.id,_Symbol,p.direction==DIR_BUY?"BUY":"SELL",p.entry,p.sl,p.tp,p.rr,a.score,a.maxScore,action); FileClose(f);
}
void Draw(const Analysis &a) {
   if(!InpEnableVisualization||!InpShowDashboard)return; string name=g_prefix+"dashboard"; if(ObjectFind(0,name)<0)ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);ObjectSetInteger(0,name,OBJPROP_XDISTANCE,12);ObjectSetInteger(0,name,OBJPROP_YDISTANCE,18);ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);
   string d=a.direction==DIR_BUY?"BUY":(a.direction==DIR_SELL?"SELL":"WAIT"); ObjectSetString(0,name,OBJPROP_TEXT,"ABC/ICC  "+d+"  Score "+IntegerToString(a.score)+"/"+IntegerToString(a.maxScore)+"\n"+a.reason);
}
void DrawPriceLine(const string suffix,const double price,const color lineColor) {
   string name=g_prefix+suffix;
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_HLINE,0,0,price);
   ObjectSetDouble(0,name,OBJPROP_PRICE,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,lineColor);
}
void Draw(const Analysis &a,const Plan &p) {
   Draw(a); if(!InpEnableVisualization)return;
   DrawPriceLine("entry",p.entry,clrDodgerBlue);
   DrawPriceLine("sl",p.sl,clrTomato);
   DrawPriceLine("tp",p.tp,clrLimeGreen);
}
bool SendOrder(const Plan &p,string &result) {
   MqlTradeRequest req={}; MqlTradeResult res={}; req.action=TRADE_ACTION_DEAL;req.symbol=_Symbol;req.magic=InpMagicNumber;req.volume=p.volume;req.deviation=InpMaxSlippagePoints;req.sl=p.sl;req.tp=p.tp;req.comment=p.id;
   req.type=p.direction==DIR_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL;req.price=p.direction==DIR_BUY?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);
   long fill=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);req.type_filling=(fill&SYMBOL_FILLING_FOK)?ORDER_FILLING_FOK:((fill&SYMBOL_FILLING_IOC)?ORDER_FILLING_IOC:ORDER_FILLING_RETURN);
   double margin=0;if(!OrderCalcMargin(req.type,_Symbol,req.volume,req.price,margin)||AccountInfoDouble(ACCOUNT_MARGIN_FREE)<margin*InpMarginSafetyPercent/100.0){result="margin gate";return false;}
   if(!OrderSend(req,res)){result="OrderSend error "+IntegerToString(GetLastError());return false;} result=res.comment;return res.retcode==TRADE_RETCODE_DONE||res.retcode==TRADE_RETCODE_PLACED;
}
void ProcessBar() {
   Analysis a={}; if(!Analyze(a)){Draw(a);if(InpVerboseJournal)Print("ABC/ICC: ",a.reason);return;} if(a.signalTime==g_lastSignal)return;
   string why; if(!LimitsPass(why)){a.reason=why;Draw(a);return;} Plan p; if(!BuildPlan(a,p)){a.reason="invalid plan, volume, or RR";Draw(a);return;}
   g_lastSignal=a.signalTime;Draw(a,p);string action="signal";
   if(InpTradingMode==MODE_AUTOMATED){string response;action=SendOrder(p,response)?"order sent":"order rejected: "+response;}
   else if(InpTradingMode==MODE_ALERT_ONLY){string msg="ABC/ICC "+p.id+" score "+IntegerToString(a.score)+"/"+IntegerToString(a.maxScore);if(InpEnableTerminalAlert)Alert(msg);if(InpEnablePushNotification)SendNotification(msg);if(InpEnableEmailNotification)SendMail("ABC/ICC setup",msg);action="alert";}
   LogSetup(a,p,action);Print("ABC/ICC: ",action," ",p.id);
}
bool InputsValid() {
   return InpFractalLength>0&&InpATRPeriod>0&&InpBarsToLoad>=100&&InpZigZagDepth>InpZigZagBackstep&&InpPrimaryFibLevel>0&&InpPrimaryFibLevel<1&&InpFibTolerance>=0&&InpMinimumRR>0&&InpRiskPercentage>0&&InpRiskPercentage<=100&&InpAverageBodyPeriod>0&&InpMinimumEntryScore>=0;
}
int OnInit() {
   if(!InputsValid()){Print("ABC/ICC: invalid inputs");return INIT_PARAMETERS_INCORRECT;}
   g_atrTrend=iATR(_Symbol,InpTrendTimeframe,InpATRPeriod);g_atrStructure=iATR(_Symbol,InpStructureTimeframe,InpATRPeriod);if(g_atrTrend==INVALID_HANDLE||g_atrStructure==INVALID_HANDLE)return INIT_FAILED;
   g_prefix="ABCICC_"+IntegerToString((int)ChartID())+"_"+IntegerToString((int)InpMagicNumber)+"_";return INIT_SUCCEEDED;
}
void OnTick() { datetime t=iTime(_Symbol,InpStructureTimeframe,0);if(t!=0&&t!=g_lastBar){g_lastBar=t;ProcessBar();} }
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result) {
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD||!HistoryDealSelect(trans.deal))return;
   if(HistoryDealGetString(trans.deal,DEAL_SYMBOL)!=_Symbol||(ulong)HistoryDealGetInteger(trans.deal,DEAL_MAGIC)!=InpMagicNumber||HistoryDealGetInteger(trans.deal,DEAL_ENTRY)!=DEAL_ENTRY_OUT)return;
   double pnl=HistoryDealGetDouble(trans.deal,DEAL_PROFIT)+HistoryDealGetDouble(trans.deal,DEAL_SWAP)+HistoryDealGetDouble(trans.deal,DEAL_COMMISSION);g_lossStreak=pnl<0?g_lossStreak+1:0;
}
void OnDeinit(const int reason) { if(g_atrTrend!=INVALID_HANDLE)IndicatorRelease(g_atrTrend);if(g_atrStructure!=INVALID_HANDLE)IndicatorRelease(g_atrStructure);ObjectsDeleteAll(0,g_prefix);Comment(""); }
