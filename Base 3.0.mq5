#property copyright "Market Trend Analyser conversion"
#property version   "4.00"
#property strict
#property description "BASE 3.0: the trend purely from market structure - Trending, Transition or Consolidation - with swing sensitivity set automatically for each symbol."
#property description "Signal/visualisation EA only; it contains no trading rules."

// How detailed the swings are.  Auto sizes them from the symbol's own
// movement (see AutoSwingSize); the other two scale that size.
enum BASE_SENSITIVITY { BASE_AUTO=0, BASE_MORE_DETAILED=1, BASE_SMOOTHER=2 };

input group "Timeframes"
input ENUM_TIMEFRAMES HTF_Timeframe=PERIOD_H1; // HTF (the main trend)
input ENUM_TIMEFRAMES MTF_Timeframe=PERIOD_M30; // MTF
input ENUM_TIMEFRAMES LTF_Timeframe=PERIOD_M15; // LTF
input bool Use_MTF=false; // Use MTF (dashboard and Market Tradability)
input bool Use_LTF=false; // Use LTF (dashboard and Market Tradability)

input group "Structure"
input BASE_SENSITIVITY Swing_Sensitivity=BASE_AUTO; // Swing Sensitivity
input int Bars_To_Process=100; // Bars To Process (HTF candles drawn, at least 100)

input group "Display"
input bool Show_Swing_Points=true; // Show HH / HL / LH / LL
input bool Show_Structure_Breaks=true; // Show BOS / CHoCH / LS
input bool Show_Internal_Structure=true; // Show Internal Structure
input bool Show_Strong_Weak_High_Low=true; // Show Strong / Weak High / Low

input group "Alerts"
input bool Enable_Popup_Alerts=false; // Popup alerts (HTF breaks and state changes)
input bool Enable_Push_Notifications=false; // Push notifications

// ------------------------------------------------------------------ rules
// Swings: a swing is confirmed by the first close one swing size back from
// the leg's extreme.  The swing size is K x the 14-candle ATR; K comes from
// the symbol's variance ratio (see AutoSwingSize).  Internal swings use half
// the swing size.
const int SWING_ATR_LENGTH=14;
const int VR_LAG=20;              // the variance ratio's lag (candles)
const int VR_WINDOW=1000;         // the closes it is measured over
const double AUTO_SCALE=0.8;      // K = AUTO_SCALE / sqrt(VR - 1)
const double K_MIN=0.5;
const double K_MAX=2.0;
const double INTERNAL_RATIO=0.5;
// EQH/EQL: a swing within this many ATR of the previous one on its side.
const double EQUAL_ATR=0.2;
// Consolidation: this many swings without a BOS (and its range is the last
// this many swings).
const int MAX_SWINGS=5;
// Successive internal BOS that make a waiting break a Transition (and, the
// other way, an LS).
const int INTERNAL_BREAKS=2;

// Every replay covers this many times the drawn history, so the swings and
// the state settle before the first drawn candle.
const int STRUCTURE_WARMUP_FACTOR=3;

// Drawing.
const int LABEL_SIZE=9;
const color HIGH_COLOR=clrIndianRed;
const color LOW_COLOR=clrTeal;
const color BOS_COLOR=clrBlue;
const color CHOCH_COLOR=clrRed;
const color LS_COLOR=C'229,184,0';
const color INTERNAL_BULL_COLOR=C'8,153,129';
const color INTERNAL_BEAR_COLOR=C'242,54,69';

const int BASE_CONSOLIDATION=0;
const int BASE_TRANSITION=1;
const int BASE_TRENDING=2;
const int BASE_BOS=0;
const int BASE_CHOCH=1;

string g_prefix="";
datetime g_last_bar[4];

// --------------------------------------------------------------- structs
struct BASE_LEVEL
  {
   bool have;
   double price;
   int bar;
  };

// One confirmed swing.  Swings never change once confirmed.
struct BASE_POINT
  {
   int pivot;               // the swing's candle
   int confirmed;           // the candle whose close confirmed it
   datetime time;
   double price;
   int side;                // 1 high, -1 low
   int kind;                // 1 HH/LL, -1 LH/HL, 0 the first swing on its side
   int equal;               // the swing it equals (EQH/EQL), -1 if none
  };

// One close beyond a level (main or internal).
struct BASE_EVENT
  {
   int bar;                 // the candle that closed beyond the level
   int direction;           // 1 bullish, -1 bearish
   int kind;                // BASE_BOS or BASE_CHOCH
   bool ls;                 // the break failed (a liquidity sweep)
   int ls_bar;              // the candle on which it failed, -1 if none
   double level;
   int swing_bar;           // the swing that held the level
   datetime swing_time;
  };

// A break that waits for the Transition conditions.
struct BASE_ATTEMPT
  {
   bool active;
   int u;                   // its direction
   int bar;                 // the candle that broke
   BASE_LEVEL broken;       // the level it broke
   BASE_LEVEL origin;       // the extreme before it, which a pullback must hold
   int event;               // its event
   int with;                // successive internal BOS in its direction since
   int against;             // ... and against it
   BASE_LEVEL best;         // the furthest swing in its direction since
   BASE_LEVEL pullback;     // condition A's pullback swing
   int from;                // BASE_TRENDING (a trend's CHoCH) or BASE_CONSOLIDATION
  };

// The latest internal swing on one side.
struct BASE_INTERNAL_SWING
  {
   bool have;
   double price;
   int pivot;
   int confirmed;
   bool broken;
  };

// The zigzag that confirms swings.
struct BASE_ZIGZAG
  {
   int leg;                 // 1 rising (tracking its high), -1 falling, 0 before the first swing
   bool have;
   double hi;
   int hi_bar;
   double lo;
   int lo_bar;
   double ext;
   int ext_bar;
  };

// The structure of one timeframe (see ReplayStructure).
struct BASE_STATE
  {
   int state;               // BASE_TRENDING, BASE_TRANSITION or BASE_CONSOLIDATION
   int direction;           // 1 bullish, -1 bearish; in Consolidation the last direction (0 before any)
   BASE_LEVEL weak;         // a close beyond it in the direction is a BOS
   BASE_LEVEL prot;         // a close beyond it against the direction breaks the structure
   BASE_LEVEL inval;        // Transition: the extreme before its break
   int resume;              // Transition: BASE_TRENDING when it came from a trend's CHoCH
   int since;               // swings since the latest BOS or state change
   int break_bar;           // the latest break in the direction
   int changed_bar;         // the candle of the latest state change
   bool by_internal;        // Transition: made by two internal BOS (B), not a pullback (A)
   BASE_LEVEL trans_break;  // Transition: the level its break went through
   BASE_ATTEMPT att;
   int last_high;           // points index of the latest swing high, -1 if none
   int last_low;
   BASE_INTERNAL_SWING ihigh;
   BASE_INTERNAL_SWING ilow;
   int internal_direction;  // the latest internal break's direction, 0 if none
   int internal_kind;       // its kind
   double k;                // the swing size (ATR) at the latest candle
  };

// ------------------------------------------------------------- timeframes
string TimeframeName(const ENUM_TIMEFRAMES timeframe)
  {
   // EnumToString returns "PERIOD_H1"; texts only need "H1".
   return StringSubstr(EnumToString(timeframe),7);
  }

ENUM_TIMEFRAMES ResolveTimeframe(const ENUM_TIMEFRAMES timeframe)
  {
   return timeframe==PERIOD_CURRENT?(ENUM_TIMEFRAMES)_Period:timeframe;
  }

ENUM_TIMEFRAMES HTF() { return ResolveTimeframe(HTF_Timeframe); }
ENUM_TIMEFRAMES MTF() { return ResolveTimeframe(MTF_Timeframe); }
ENUM_TIMEFRAMES LTF() { return ResolveTimeframe(LTF_Timeframe); }
string HTFName() { return TimeframeName(HTF()); }
string MTFName() { return TimeframeName(MTF()); }
string LTFName() { return TimeframeName(LTF()); }

int StructureBars()
  {
   return MathMax(100,MathMin(Bars_To_Process,100000));
  }

// Drawn history on another timeframe covers the same time as Bars_To_Process
// HTF candles (100 H1 candles become 400 M15 candles).
int DisplayedBars(const ENUM_TIMEFRAMES timeframe)
  {
   int htf_seconds=PeriodSeconds(HTF());
   int seconds=PeriodSeconds(timeframe);
   int wanted=StructureBars();
   if(htf_seconds>0 && seconds>0)
      wanted=(int)MathCeil((double)StructureBars()*htf_seconds/seconds);
   return MathMax(50,MathMin(wanted,100000));
  }

int ReplayBars(const int displayed)
  {
   return MathMin(100000,displayed*STRUCTURE_WARMUP_FACTOR);
  }

// ------------------------------------------------------------ the engine
void SetLevel(BASE_LEVEL &level,const double price,const int bar)
  {
   level.have=true;
   level.price=price;
   level.bar=bar;
  }

void ClearLevel(BASE_LEVEL &level)
  {
   level.have=false;
   level.price=0.0;
   level.bar=-1;
  }

// Average true range over SWING_ATR_LENGTH candles (fewer at the start) at
// every candle, from that candle and the ones before it only.
void SwingATR(const MqlRates &rates[],const int total,double &atr[])
  {
   ArrayResize(atr,total);
   double ranges[];
   ArrayResize(ranges,total);
   double sum=0.0;
   for(int i=0;i<total;i++)
     {
      double r=rates[i].high-rates[i].low;
      if(i>0)
         r=MathMax(r,MathMax(MathAbs(rates[i].high-rates[i-1].close),MathAbs(rates[i].low-rates[i-1].close)));
      ranges[i]=r;
      sum+=r;
      if(i>=SWING_ATR_LENGTH) sum-=ranges[i-SWING_ATR_LENGTH];
      atr[i]=sum/MathMin(i+1,SWING_ATR_LENGTH);
     }
  }

double SensitivityScale()
  {
   if(Swing_Sensitivity==BASE_MORE_DETAILED) return 0.7;
   if(Swing_Sensitivity==BASE_SMOOTHER) return 1.4;
   return 1.0;
  }

// The swing size (in ATR) at every candle, set by the symbol's own movement.
// The variance ratio VR of the last VR_WINDOW closes compares the squared
// 20-candle moves with 20 times the squared 1-candle moves: about 1 when the
// closes wander at random, more when moves persist.  The more of the movement
// is trend rather than noise, the smaller a swing needs to be, so
// K = AUTO_SCALE / sqrt(VR - 1), kept between K_MIN and K_MAX (K_MAX when VR
// is 1 or less), then scaled by Swing_Sensitivity.  The window sums are
// differences of running sums, as in the Pine version.
void AutoSwingSize(const MqlRates &rates[],const int total,double &k[])
  {
   ArrayResize(k,total);
   double sum1[],sumN[];
   ArrayResize(sum1,total+1);
   ArrayResize(sumN,total+1);
   sum1[0]=0.0;
   sumN[0]=0.0;
   for(int t=0;t<total;t++)
     {
      double d1=t>=1?(rates[t].close-rates[t-1].close):0.0;
      double dn=t>=VR_LAG?(rates[t].close-rates[t-VR_LAG].close):0.0;
      sum1[t+1]=sum1[t]+d1*d1;
      sumN[t+1]=sumN[t]+dn*dn;
     }
   double scale=SensitivityScale();
   for(int t=0;t<total;t++)
     {
      int from=MathMax(0,t+1-VR_WINDOW);
      double s1=sum1[t+1]-sum1[from];
      double sn=sumN[t+1]-sumN[from];
      double size=K_MAX;
      if(t>=VR_LAG && s1>0.0)
        {
         double excess=sn/(VR_LAG*s1)-1.0;
         if(excess>0.0) size=MathMin(K_MAX,MathMax(K_MIN,AUTO_SCALE/MathSqrt(excess)));
        }
      k[t]=size*scale;
     }
  }

// The candle of the highest high (side 1) or lowest low (-1) after `from` up
// to `to` (`to` itself when from is to), the latest of equal ones.
int ExtremeAfter(const MqlRates &rates[],const int side,const int from,const int to)
  {
   int best=MathMin(from+1,to);
   for(int j=best;j<=to;j++)
      if(side>0?rates[j].high>=rates[best].high:rates[j].low<=rates[best].low) best=j;
   return best;
  }

// The same from `from` itself up to `to`.
int ExtremeSince(const MqlRates &rates[],const int side,const int from,const int to)
  {
   int best=from;
   for(int j=from;j<=to;j++)
      if(side>0?rates[j].high>=rates[best].high:rates[j].low<=rates[best].low) best=j;
   return best;
  }

double SidePrice(const MqlRates &rates[],const int side,const int bar)
  {
   return side>0?rates[bar].high:rates[bar].low;
  }

void AddFound(int &sides[],double &prices[],int &pivots[],const int side,const double price,const int pivot)
  {
   int n=ArraySize(sides);
   ArrayResize(sides,n+1);
   ArrayResize(prices,n+1);
   ArrayResize(pivots,n+1);
   sides[n]=side;
   prices[n]=price;
   pivots[n]=pivot;
  }

// One candle of the zigzag: the leg tracks its extreme (a later equal high or
// low takes over), and the first close unit[pivot] back from it confirms the
// swing; the next leg starts from the extreme after it.  Before the first
// swing both extremes are tracked and whichever is confirmed first starts
// the legs.  A big candle can confirm a swing and the next one, but a leg
// that starts on this candle waits for a later close.
void ZigzagStep(BASE_ZIGZAG &z,const MqlRates &rates[],const double &unit[],const int i,
                int &sides[],double &prices[],int &pivots[])
  {
   ArrayResize(sides,0);
   ArrayResize(prices,0);
   ArrayResize(pivots,0);
   if(z.leg==0)
     {
      if(!z.have || rates[i].high>=z.hi) { z.hi=rates[i].high; z.hi_bar=i; }
      if(!z.have || rates[i].low<=z.lo) { z.lo=rates[i].low; z.lo_bar=i; }
      z.have=true;
      bool up=rates[i].close>=z.lo+unit[z.lo_bar];
      bool down=rates[i].close<=z.hi-unit[z.hi_bar];
      bool low_first=up && (!down || z.lo_bar<z.hi_bar);
      if(low_first)
        {
         AddFound(sides,prices,pivots,-1,z.lo,z.lo_bar);
         z.leg=1;
         z.ext_bar=ExtremeAfter(rates,1,z.lo_bar,i);
         z.ext=rates[z.ext_bar].high;
         if(down)
           {
            AddFound(sides,prices,pivots,1,z.hi,z.hi_bar);
            z.leg=-1;
            z.ext_bar=ExtremeAfter(rates,-1,z.hi_bar,i);
            z.ext=rates[z.ext_bar].low;
           }
        }
      else if(down)
        {
         AddFound(sides,prices,pivots,1,z.hi,z.hi_bar);
         z.leg=-1;
         z.ext_bar=ExtremeAfter(rates,-1,z.hi_bar,i);
         z.ext=rates[z.ext_bar].low;
         if(up)
           {
            AddFound(sides,prices,pivots,-1,z.lo,z.lo_bar);
            z.leg=1;
            z.ext_bar=ExtremeAfter(rates,1,z.lo_bar,i);
            z.ext=rates[z.ext_bar].high;
           }
        }
      return;
     }
   if(z.leg>0 && rates[i].high>=z.ext) { z.ext=rates[i].high; z.ext_bar=i; }
   if(z.leg<0 && rates[i].low<=z.ext) { z.ext=rates[i].low; z.ext_bar=i; }
   for(int pass=0;pass<4;pass++)
     {
      int pivot=z.ext_bar;
      if(z.leg>0 && rates[i].close<=z.ext-unit[pivot])
        {
         AddFound(sides,prices,pivots,1,z.ext,pivot);
         z.leg=-1;
         z.ext_bar=ExtremeAfter(rates,-1,pivot,i);
         z.ext=rates[z.ext_bar].low;
        }
      else if(z.leg<0 && rates[i].close>=z.ext+unit[pivot])
        {
         AddFound(sides,prices,pivots,-1,z.ext,pivot);
         z.leg=1;
         z.ext_bar=ExtremeAfter(rates,1,pivot,i);
         z.ext=rates[z.ext_bar].high;
        }
      else break;
      if(pivot==i) break;
     }
  }

int AddEvent(BASE_EVENT &events[],const MqlRates &rates[],const int bar,const int direction,const int kind,
             const BASE_LEVEL &level)
  {
   int n=ArraySize(events);
   ArrayResize(events,n+1);
   events[n].bar=bar;
   events[n].direction=direction;
   events[n].kind=kind;
   events[n].ls=false;
   events[n].ls_bar=-1;
   events[n].level=level.price;
   events[n].swing_bar=level.bar;
   events[n].swing_time=rates[level.bar].time;
   return n;
  }

void ChangeState(BASE_STATE &s,const int state,const int direction,const int bar)
  {
   if(s.state!=state || s.direction!=direction) s.changed_bar=bar;
   s.state=state;
   s.direction=direction;
  }

// A waiting break becomes a Transition in its direction.  Its BOS level is
// the furthest swing in that direction since the break; its own structure is
// condition A's pullback swing, or with B the level it broke.
void EnterTransition(BASE_STATE &s,const int bar)
  {
   s.resume=s.att.from;
   s.inval=s.att.origin;
   ChangeState(s,BASE_TRANSITION,s.att.u,bar);
   s.weak=s.att.best;
   s.by_internal=!s.att.pullback.have;
   s.prot=s.att.pullback.have?s.att.pullback:s.att.broken;
   s.trans_break=s.att.broken;
   s.break_bar=s.att.bar;
   s.since=0;
   s.att.active=false;
  }

void StartAttempt(BASE_STATE &s,BASE_EVENT &events[],const MqlRates &rates[],const int bar,const int u,
                  const BASE_LEVEL &level,const BASE_LEVEL &origin,const int from,const int kind)
  {
   s.att.event=AddEvent(events,rates,bar,u,kind,level);
   s.att.active=true;
   s.att.u=u;
   s.att.bar=bar;
   s.att.broken=level;
   s.att.origin=origin;
   s.att.with=0;
   s.att.against=0;
   ClearLevel(s.att.best);
   ClearLevel(s.att.pullback);
   s.att.from=from;
  }

void ToConsolidation(BASE_STATE &s,const int bar)
  {
   ChangeState(s,BASE_CONSOLIDATION,s.direction,bar);
   ClearLevel(s.weak);
   ClearLevel(s.prot);
   ClearLevel(s.inval);
   s.since=0;
   if(s.att.active) s.att.from=BASE_CONSOLIDATION;
  }

// A swing confirmed on candle i: labelled against the previous swing on its
// side, then offered to the trend and to a waiting break (condition A).
void OnSwing(BASE_STATE &s,BASE_POINT &points[],const MqlRates &rates[],const double &atr[],
             const int side,const double price,const int pivot,const int i)
  {
   int prev=side>0?s.last_high:s.last_low;
   int kind=0,equal=-1;
   if(prev>=0)
     {
      kind=(side>0?price>points[prev].price:price<points[prev].price)?1:-1;
      if(MathAbs(price-points[prev].price)<EQUAL_ATR*atr[pivot]) equal=prev;
     }
   int n=ArraySize(points);
   ArrayResize(points,n+1);
   points[n].pivot=pivot;
   points[n].confirmed=i;
   points[n].time=rates[pivot].time;
   points[n].price=price;
   points[n].side=side;
   points[n].kind=kind;
   points[n].equal=equal;
   if(side>0) s.last_high=n;
   else s.last_low=n;
   s.since++;
   int d=s.direction;
   if(s.state!=BASE_CONSOLIDATION)
     {
      if(side==d && (!s.weak.have || (d>0?price>s.weak.price:price<s.weak.price))) SetLevel(s.weak,price,pivot);
      if(side==-d) SetLevel(s.prot,price,pivot);
     }
   if(s.att.active)
     {
      int u=s.att.u;
      if(side==u && (!s.att.best.have || (u>0?price>s.att.best.price:price<s.att.best.price)))
         SetLevel(s.att.best,price,pivot);
      if(side==-u)
        {
         double tolerance=EQUAL_ATR*atr[pivot];
         if(u>0?price>=s.att.origin.price-tolerance:price<=s.att.origin.price+tolerance)
           {
            SetLevel(s.att.pullback,price,pivot);
            EnterTransition(s,i);
           }
        }
     }
  }

// Consolidation's range: the highest high and lowest low of the last
// MAX_SWINGS swings.
void ConsolidationRange(const BASE_POINT &points[],BASE_LEVEL &high,BASE_LEVEL &low)
  {
   ClearLevel(high);
   ClearLevel(low);
   int n=ArraySize(points);
   for(int j=MathMax(0,n-MAX_SWINGS);j<n;j++)
     {
      if(points[j].side>0 && (!high.have || points[j].price>high.price)) SetLevel(high,points[j].price,points[j].pivot);
      if(points[j].side<0 && (!low.have || points[j].price<low.price)) SetLevel(low,points[j].price,points[j].pivot);
     }
  }

// The structure after candle i closed.
void OnClose(BASE_STATE &s,BASE_EVENT &events[],const BASE_POINT &points[],const MqlRates &rates[],const int i)
  {
   double c=rates[i].close;
   if(s.att.active)
     {
      int u=s.att.u;
      bool beyond_origin=u<0?c>s.att.origin.price:c<s.att.origin.price;
      if(s.att.with>=INTERNAL_BREAKS)
         EnterTransition(s,i);                      // condition B
      else if(beyond_origin || s.att.against>=INTERNAL_BREAKS)
        {
         // The break failed: a liquidity sweep.  A trend holds, with the
         // sweep's extreme as its new strong level.
         events[s.att.event].ls=true;
         events[s.att.event].ls_bar=i;
         s.att.active=false;
         if(s.att.from==BASE_TRENDING)
           {
            int b=ExtremeSince(rates,-s.direction,s.att.bar,i);
            SetLevel(s.prot,SidePrice(rates,-s.direction,b),b);
           }
        }
     }
   int d=s.direction;
   if(s.state==BASE_TRENDING)
     {
      if(s.weak.have && (d>0?c>s.weak.price:c<s.weak.price))
        {
         AddEvent(events,rates,i,d,BASE_BOS,s.weak);
         ClearLevel(s.weak);
         s.since=0;
         s.break_bar=i;
         s.att.active=false;
        }
      else if(!s.att.active && s.prot.have && (d>0?c<s.prot.price:c>s.prot.price))
        {
         // A CHoCH: the trend holds until the Transition conditions are met.
         BASE_LEVEL origin;
         int b=ExtremeSince(rates,d,s.prot.bar,i);
         SetLevel(origin,SidePrice(rates,d,b),b);
         BASE_LEVEL level=s.prot;
         StartAttempt(s,events,rates,i,-d,level,origin,BASE_TRENDING,BASE_CHOCH);
        }
      else if(s.since>=MAX_SWINGS)
         ToConsolidation(s,i);
      return;
     }
   if(s.state==BASE_TRANSITION)
     {
      if(s.weak.have && (d>0?c>s.weak.price:c<s.weak.price))
        {
         // The second break: a trend.
         AddEvent(events,rates,i,d,BASE_BOS,s.weak);
         ChangeState(s,BASE_TRENDING,d,i);
         ClearLevel(s.weak);
         s.since=0;
         s.break_bar=i;
        }
      else if(s.prot.have && (d>0?c<s.prot.price:c>s.prot.price))
        {
         if(s.resume==BASE_TRENDING && (d>0?c<s.inval.price:c>s.inval.price))
           {
            // Beyond the old trend's extreme too: the old trend resumes.
            AddEvent(events,rates,i,-d,BASE_BOS,s.inval);
            ChangeState(s,BASE_TRENDING,-d,i);
            s.since=0;
            s.break_bar=i;
            ClearLevel(s.weak);
            int b=ExtremeSince(rates,d,s.inval.bar,i);
            SetLevel(s.prot,SidePrice(rates,d,b),b);
           }
         else
           {
            // The Transition broke its own structure: that break waits.
            BASE_LEVEL level=s.prot;
            ToConsolidation(s,i);
            BASE_LEVEL origin;
            int b=ExtremeSince(rates,d,level.bar,i);
            SetLevel(origin,SidePrice(rates,d,b),b);
            StartAttempt(s,events,rates,i,-d,level,origin,BASE_CONSOLIDATION,BASE_CHOCH);
           }
        }
      else if(s.since>=MAX_SWINGS)
         ToConsolidation(s,i);
      return;
     }
   // Consolidation: a close beyond its range is a break that waits; the
   // pullback must hold the latest swing on the other side.
   if(s.att.active) return;
   BASE_LEVEL high,low,origin;
   ConsolidationRange(points,high,low);
   if(high.have && c>high.price)
     {
      if(s.last_low>=0) SetLevel(origin,points[s.last_low].price,points[s.last_low].pivot);
      else { int b=ExtremeSince(rates,-1,high.bar,i); SetLevel(origin,rates[b].low,b); }
      StartAttempt(s,events,rates,i,1,high,origin,BASE_CONSOLIDATION,d>0?BASE_BOS:BASE_CHOCH);
     }
   else if(low.have && c<low.price)
     {
      if(s.last_high>=0) SetLevel(origin,points[s.last_high].price,points[s.last_high].pivot);
      else { int b=ExtremeSince(rates,1,low.bar,i); SetLevel(origin,rates[b].high,b); }
      StartAttempt(s,events,rates,i,-1,low,origin,BASE_CONSOLIDATION,d<0?BASE_BOS:BASE_CHOCH);
     }
  }

// An internal swing broken by candle i's close: an internal BOS (in the
// direction of the previous internal break) or CHoCH, counted for a waiting
// break when the swing formed after it.
void InternalBreak(BASE_STATE &s,BASE_INTERNAL_SWING &q,BASE_EVENT &internal_events[],const MqlRates &rates[],
                   const int side,const int i)
  {
   if(!q.have || q.broken || (side>0?rates[i].close<=q.price:rates[i].close>=q.price)) return;
   q.broken=true;
   int n=ArraySize(internal_events);
   ArrayResize(internal_events,n+1);
   internal_events[n].bar=i;
   internal_events[n].direction=side;
   internal_events[n].kind=s.internal_direction==side?BASE_BOS:BASE_CHOCH;
   internal_events[n].ls=false;
   internal_events[n].ls_bar=-1;
   internal_events[n].level=q.price;
   internal_events[n].swing_bar=q.pivot;
   internal_events[n].swing_time=rates[q.pivot].time;
   s.internal_direction=side;
   s.internal_kind=internal_events[n].kind;
   if(s.att.active && q.confirmed>=s.att.bar)
     {
      if(side==s.att.u) { s.att.with++; s.att.against=0; }
      else { s.att.against++; s.att.with=0; }
     }
  }

// Replays the structure from candle `start` (earlier candles only feed the
// ATR and the swing size) to the latest closed candle.  The order on each
// candle: main swings, internal swings, internal breaks, then the closes
// against the structure's levels.
bool ReplayStructure(const MqlRates &rates[],const int total,const int start,BASE_STATE &s,
                     BASE_POINT &points[],BASE_EVENT &events[],BASE_EVENT &internal_events[])
  {
   ZeroMemory(s);
   ArrayResize(points,0);
   ArrayResize(events,0);
   ArrayResize(internal_events,0);
   s.state=BASE_CONSOLIDATION;
   s.last_high=-1;
   s.last_low=-1;
   s.break_bar=-1;
   s.changed_bar=-1;
   ClearLevel(s.weak);
   ClearLevel(s.prot);
   ClearLevel(s.inval);
   ClearLevel(s.trans_break);
   if(total<SWING_ATR_LENGTH+2 || start<0 || start>=total) return false;
   double atr[],k[],unit[],inner[];
   SwingATR(rates,total,atr);
   AutoSwingSize(rates,total,k);
   ArrayResize(unit,total);
   ArrayResize(inner,total);
   for(int i=0;i<total;i++)
     {
      unit[i]=k[i]*atr[i];
      inner[i]=unit[i]*INTERNAL_RATIO;
     }
   BASE_ZIGZAG main_zz,inner_zz;
   ZeroMemory(main_zz);
   ZeroMemory(inner_zz);
   int sides[],pivots[];
   double prices[];
   for(int i=start;i<total;i++)
     {
      ZigzagStep(main_zz,rates,unit,i,sides,prices,pivots);
      for(int j=0;j<ArraySize(sides);j++)
         OnSwing(s,points,rates,atr,sides[j],prices[j],pivots[j],i);
      ZigzagStep(inner_zz,rates,inner,i,sides,prices,pivots);
      for(int j=0;j<ArraySize(sides);j++)
        {
         if(sides[j]>0)
           {
            s.ihigh.have=true; s.ihigh.price=prices[j]; s.ihigh.pivot=pivots[j];
            s.ihigh.confirmed=i; s.ihigh.broken=false;
           }
         else
           {
            s.ilow.have=true; s.ilow.price=prices[j]; s.ilow.pivot=pivots[j];
            s.ilow.confirmed=i; s.ilow.broken=false;
           }
        }
      InternalBreak(s,s.ihigh,internal_events,rates,1,i);
      InternalBreak(s,s.ilow,internal_events,rates,-1,i);
      OnClose(s,events,points,rates,i);
     }
   s.k=k[total-1];
   return true;
  }

// Copies a timeframe's closed candles for `displayed` drawn candles: the
// replay (STRUCTURE_WARMUP_FACTOR times that) plus the closes the swing size
// is measured over, and replays it.
bool AnalyseStructure(const ENUM_TIMEFRAMES timeframe,const int displayed,BASE_STATE &state,MqlRates &rates[],
                      int &start,BASE_POINT &points[],BASE_EVENT &events[],BASE_EVENT &internal_events[])
  {
   ArraySetAsSeries(rates,false);
   int replay=ReplayBars(displayed);
   int total=CopyRates(_Symbol,timeframe,1,replay+VR_WINDOW+VR_LAG,rates);
   if(total<SWING_ATR_LENGTH+2) return false;
   start=MathMax(0,total-replay);
   return ReplayStructure(rates,total,start,state,points,events,internal_events);
  }

// ------------------------------------------------------------------ texts
string PriceText(const double price)
  {
   return DoubleToString(price,_Digits);
  }

string DirectionWord(const int direction)
  {
   return direction>0?"bullish":"bearish";
  }

string StateText(const BASE_STATE &s)
  {
   if(s.state==BASE_CONSOLIDATION) return "Consolidation";
   return (s.direction>0?"Bullish ":"Bearish ")+(s.state==BASE_TRENDING?"Trending":"Transition");
  }

// The dashboard output: the state, and a break waiting for the Transition
// conditions.
string StateOutput(const BASE_STATE &s)
  {
   string text=StateText(s);
   if(s.att.active)
      text+=s.state==BASE_TRENDING?" (CHoCH)":" ("+DirectionWord(s.att.u)+" break)";
   return text;
  }

int Direction(const BASE_STATE &s)
  {
   return s.state==BASE_CONSOLIDATION?0:s.direction;
  }

string LabelText(const BASE_POINT &point)
  {
   if(point.equal>=0) return point.side>0?"EQH":"EQL";
   if(point.side>0) return point.kind>0?"HH":"LH";
   return point.kind>0?"LL":"HL";
  }

// "HH + HL": the latest swing high against the previous one, and the same
// for lows.
int PreviousOnSide(const BASE_POINT &points[],const int index)
  {
   for(int j=index-1;j>=0;j--)
      if(points[j].side==points[index].side) return j;
   return -1;
  }

int SwingProgression(const BASE_STATE &s,const BASE_POINT &points[])
  {
   if(s.last_high<0 || s.last_low<0) return 0;
   int ph=PreviousOnSide(points,s.last_high),pl=PreviousOnSide(points,s.last_low);
   if(ph<0 || pl<0) return 0;
   bool hh=points[s.last_high].price>points[ph].price,hl=points[s.last_low].price>points[pl].price;
   bool lh=points[s.last_high].price<points[ph].price,ll=points[s.last_low].price<points[pl].price;
   return hh && hl?1:(ll && lh?-1:0);
  }

string SwingStructureText(const BASE_STATE &s,const BASE_POINT &points[])
  {
   string high="no swing high yet",low="no swing low yet";
   if(s.last_high>=0) high=points[s.last_high].kind==0?"first high":LabelText(points[s.last_high]);
   if(s.last_low>=0) low=points[s.last_low].kind==0?"first low":LabelText(points[s.last_low]);
   return high+" + "+low;
  }

string LatestSwingsText(const BASE_STATE &s,const BASE_POINT &points[])
  {
   string high=s.last_high<0?"no swing high yet":
               (points[s.last_high].kind==0?"first high":LabelText(points[s.last_high]))+" "+PriceText(points[s.last_high].price);
   string low=s.last_low<0?"no swing low yet":
              (points[s.last_low].kind==0?"first low":LabelText(points[s.last_low]))+" "+PriceText(points[s.last_low].price);
   return high+" | "+low;
  }

// Strong/Weak High/Low: in a trend or transition the level against it is
// Strong and the level its BOS must close beyond is Weak (before the next
// swing forms, the running extreme since its last break); Consolidation
// shows its range.
void StrongWeakLevels(const BASE_STATE &s,const BASE_POINT &points[],const MqlRates &rates[],const int total,
                      BASE_LEVEL &high,string &high_name,BASE_LEVEL &low,string &low_name)
  {
   ClearLevel(high);
   ClearLevel(low);
   if(s.state==BASE_CONSOLIDATION)
     {
      ConsolidationRange(points,high,low);
      high_name="Range High";
      low_name="Range Low";
      return;
     }
   BASE_LEVEL weak=s.weak;
   if(!weak.have && s.break_bar>=0 && s.break_bar<total)
     {
      int b=ExtremeSince(rates,s.direction,s.break_bar,total-1);
      SetLevel(weak,SidePrice(rates,s.direction,b),b);
     }
   if(s.direction>0)
     {
      low=s.prot;
      low_name="Strong Low";
      high=weak;
      high_name="Weak High";
     }
   else
     {
      high=s.prot;
      high_name="Strong High";
      low=weak;
      low_name="Weak Low";
     }
  }

// Why the timeframe reads its state.
string WhyText(const BASE_STATE &s)
  {
   if(s.state==BASE_TRENDING)
      return "two "+DirectionWord(s.direction)+" breaks with a "+(s.direction>0?"higher low":"lower high")+
             " between them; the trend holds while price closes "+(s.direction>0?"above the strong low":
             "below the strong high");
   if(s.state==BASE_TRANSITION)
      return "a "+DirectionWord(s.direction)+" break through "+PriceText(s.trans_break.price)+", then "+
             (s.by_internal?"two internal BOS "+(s.direction>0?"up":"down"):
              (s.direction>0?"a higher low":"a lower high")+" at "+PriceText(s.prot.price)+
              " that held "+PriceText(s.inval.price))+
             "; a BOS through the "+(s.direction>0?"weak high":"weak low")+" makes it Trending";
   return "no trending or transitional structure within the last "+(string)MAX_SWINGS+" swings";
  }

// A break waiting for the Transition conditions, in words.
string WaitingText(const BASE_STATE &s)
  {
   if(!s.att.active) return "";
   int u=s.att.u;
   string side=u>0?"higher low":"lower high";
   return "A "+DirectionWord(u)+" "+(s.state==BASE_TRENDING?"CHoCH":"break")+" through "+PriceText(s.att.broken.price)+
          " is waiting: a "+side+" that holds "+PriceText(s.att.origin.price)+", or two internal BOS "+(u>0?"up":"down")+
          ", makes it a "+(u>0?"Bullish":"Bearish")+" Transition; two internal breaks "+(u>0?"down":"up")+
          " or a close "+(u>0?"below ":"above ")+PriceText(s.att.origin.price)+" make it an LS.";
  }

string BreakdownText(const BASE_STATE &s,const BASE_POINT &points[],const MqlRates &rates[],const int total)
  {
   BASE_LEVEL high,low;
   string high_name="",low_name="";
   StrongWeakLevels(s,points,rates,total,high,high_name,low,low_name);
   string levels=high_name+" "+(high.have?PriceText(high.price):"none yet")+" | "+
                 low_name+" "+(low.have?PriceText(low.price):"none yet");
   string text="Market Trend: "+StateText(s)+"\nWhy: "+WhyText(s)+"\nLatest Swings: "+LatestSwingsText(s,points)+
               "\nStrong/Weak: "+levels+"\nSwing Size: "+DoubleToString(s.k,2)+" ATR ("+
               (Swing_Sensitivity==BASE_AUTO?"auto":Swing_Sensitivity==BASE_MORE_DETAILED?"auto, more detailed":
                "auto, smoother")+"), internal "+DoubleToString(s.k*INTERNAL_RATIO,2)+" ATR";
   string waiting=WaitingText(s);
   if(waiting!="") text+="\n"+waiting;
   return text;
  }

string InternalText(const BASE_STATE &s)
  {
   if(s.internal_direction==0) return "No break yet";
   return (s.internal_direction>0?"Bullish":"Bearish")+(s.internal_kind==BASE_BOS?" (BOS)":" (CHoCH)");
  }

// "H4", "H4 and M15" or "H4, M30 and M15": the timeframes Market
// Tradability uses.
string TradabilityTimeframes()
  {
   string names[3];
   int count=0;
   names[count++]=HTFName();
   if(Use_MTF) names[count++]=MTFName();
   if(Use_LTF) names[count++]=LTFName();
   string text="";
   for(int i=0;i<count;i++) text+=(i==0?"":i==count-1?" and ":", ")+names[i];
   return text;
  }

// Market Tradability: Tradable when the HTF is Trending and every selected
// MTF/LTF is Trending or in Transition the same way.
bool EvaluateTradability(const BASE_STATE &htf,const BASE_STATE &mtf,const BASE_STATE &ltf,string &reason)
  {
   if(htf.state==BASE_CONSOLIDATION)
     {
      reason=HTFName()+" is in Consolidation: no trending or transitional structure within the last "+
             (string)MAX_SWINGS+" swings.";
      return false;
     }
   int d=htf.direction;
   if(htf.state==BASE_TRANSITION)
     {
      reason=HTFName()+" is in a "+StateText(htf)+": wait for the BOS that makes it Trending.";
      return false;
     }
   string other[2],other_text[2];
   int count=0;
   if(Use_MTF && Direction(mtf)!=d) { other[count]=MTFName(); other_text[count]=StateText(mtf); count++; }
   if(Use_LTF && Direction(ltf)!=d) { other[count]=LTFName(); other_text[count]=StateText(ltf); count++; }
   if(count>0)
     {
      reason=HTFName()+" is "+StateText(htf)+", but "+other[0]+" is "+
             (other_text[0]=="Consolidation"?"in Consolidation":other_text[0])+
             (count>1?" and "+other[1]+" is "+(other_text[1]=="Consolidation"?"in Consolidation":other_text[1]):"")+".";
      return false;
     }
   reason=(Use_MTF || Use_LTF?TradabilityTimeframes()+" agree: "+HTFName()+" is "+StateText(htf):
           HTFName()+" is "+StateText(htf))+".";
   if(htf.att.active)
      reason+=" A "+DirectionWord(htf.att.u)+" CHoCH is waiting (see the Market Trend tooltip).";
   return true;
  }

// --------------------------------------------------------------- drawing
void DrawTextAnchored(const string id,const datetime time,const double price,const string text,
                      const color clr,const ENUM_ANCHOR_POINT anchor)
  {
   string name=g_prefix+id;
   if(ObjectFind(0,name)>=0 || !ObjectCreate(0,name,OBJ_TEXT,0,time,price)) return;
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,LABEL_SIZE);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,anchor);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
  }

// Text centred above the point, or below it when `below`.
void DrawText(const string id,const datetime time,const double price,const string text,
              const color clr,const bool below)
  {
   DrawTextAnchored(id,time,price,text,clr,below?ANCHOR_UPPER:ANCHOR_LOWER);
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
   ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
  }

// A structure line never clips through a candle: it ends on the first candle
// after the swing whose wick or body reaches the level (the breaking candle
// at the latest).
int FirstTouchBar(const MqlRates &rates[],const int swing_bar,const int break_bar,
                  const int direction,const double level)
  {
   for(int b=swing_bar+1;b<break_bar;b++)
      if(direction>0?rates[b].high>=level:rates[b].low<=level) return b;
   return break_bar;
  }

// A caption faded towards the chart background (internal captions are drawn
// at 70% strength).
color FadeColor(const color clr,const double amount)
  {
   color background=(color)ChartGetInteger(0,CHART_COLOR_BACKGROUND);
   int r=(int)MathRound((clr&0xFF)*(1.0-amount)+(background&0xFF)*amount);
   int g=(int)MathRound(((clr>>8)&0xFF)*(1.0-amount)+((background>>8)&0xFF)*amount);
   int b=(int)MathRound(((clr>>16)&0xFF)*(1.0-amount)+((background>>16)&0xFF)*amount);
   return (color)((b<<16)|(g<<8)|r);
  }

// Draws one replay from candle `first` onwards:
//  * HH/HL/LH/LL/EQH/EQL labels (the first swing on each side has none), and a
//    dotted line joining each equal high or low to the swing it equals;
//  * every BOS/CHoCH/LS whose swing is drawn: a line from the swing to the
//    first candle that touches its level and the caption centred on it (BOS
//    blue, CHoCH red, LS deep yellow);
//  * the internal BOS/CHoCH (dashed, faded), except a break of a main swing;
//  * Strong/Weak High/Low (Range High/Low in Consolidation), to 20 candles
//    right of the latest one;
//  * the latest swing high and low, dotted.
void DrawChart(const MqlRates &rates[],const int total,const int first,const BASE_STATE &s,
               const BASE_POINT &points[],const BASE_EVENT &events[],const BASE_EVENT &internal_events[],
               const ENUM_TIMEFRAMES timeframe)
  {
   int count=ArraySize(points);
   if(Show_Swing_Points)
      for(int i=0;i<count;i++)
        {
         if(points[i].kind==0 || points[i].pivot<first) continue;
         bool low=points[i].side<0;
         DrawText("SWING_"+(string)points[i].time+(low?"_L":"_H"),points[i].time,points[i].price,LabelText(points[i]),
                  low?LOW_COLOR:HIGH_COLOR,low);
         int equal=points[i].equal;
         if(equal>=0 && points[equal].pivot>=first)
            DrawSegment("EQUAL_"+(string)points[i].time+(low?"_L":"_H"),points[equal].time,points[equal].price,
                        points[i].time,points[i].price,low?LOW_COLOR:HIGH_COLOR,STYLE_DOT,1);
        }
   if(Show_Structure_Breaks)
      for(int i=0;i<ArraySize(events);i++)
        {
         if(events[i].swing_bar<first) continue;
         string kind=events[i].ls?"LS":events[i].kind==BASE_BOS?"BOS":"CHoCH";
         color clr=events[i].ls?LS_COLOR:events[i].kind==BASE_BOS?BOS_COLOR:CHOCH_COLOR;
         int end=FirstTouchBar(rates,events[i].swing_bar,events[i].bar,events[i].direction,events[i].level);
         int middle=(int)MathRound(0.5*(events[i].swing_bar+end));
         string key="BREAK_"+(events[i].direction>0?"UP_":"DOWN_")+(string)rates[events[i].bar].time;
         DrawText(key,rates[middle].time,events[i].level,kind,clr,events[i].direction<0);
         DrawSegment(key+"_LINE",events[i].swing_time,events[i].level,rates[end].time,events[i].level,clr,STYLE_SOLID,2);
        }
   if(Show_Internal_Structure)
      for(int i=0;i<ArraySize(internal_events);i++)
        {
         if(internal_events[i].bar<first) continue;
         bool main_swing=false;
         for(int k=count-1;k>=0 && !main_swing;k--)
            if(points[k].side==internal_events[i].direction && points[k].pivot==internal_events[i].swing_bar)
               main_swing=true;
         if(main_swing) continue;
         color clr=internal_events[i].direction>0?INTERNAL_BULL_COLOR:INTERNAL_BEAR_COLOR;
         int end=FirstTouchBar(rates,internal_events[i].swing_bar,internal_events[i].bar,internal_events[i].direction,
                               internal_events[i].level);
         int middle=(int)MathRound(0.5*(internal_events[i].swing_bar+end));
         string key="INTERNAL_"+(internal_events[i].direction>0?"UP_":"DOWN_")+(string)rates[internal_events[i].bar].time;
         DrawSegment(key+"_LINE",internal_events[i].swing_time,internal_events[i].level,rates[end].time,
                     internal_events[i].level,clr,STYLE_DASH,1);
         DrawText(key,rates[middle].time,internal_events[i].level,internal_events[i].kind==BASE_BOS?"BOS":"CHoCH",
                  FadeColor(clr,0.3),internal_events[i].direction<0);
        }
   if(Show_Strong_Weak_High_Low)
     {
      BASE_LEVEL high,low;
      string high_name="",low_name="";
      StrongWeakLevels(s,points,rates,total,high,high_name,low,low_name);
      datetime right=rates[total-1].time+20*PeriodSeconds(timeframe);
      if(high.have)
        {
         DrawSegment("STRONG_WEAK_HIGH",rates[high.bar].time,high.price,right,high.price,HIGH_COLOR,STYLE_DASH,1);
         DrawTextAnchored("STRONG_WEAK_HIGH_TEXT",right,high.price,high_name,HIGH_COLOR,ANCHOR_LEFT);
        }
      if(low.have)
        {
         DrawSegment("STRONG_WEAK_LOW",rates[low.bar].time,low.price,right,low.price,LOW_COLOR,STYLE_DASH,1);
         DrawTextAnchored("STRONG_WEAK_LOW_TEXT",right,low.price,low_name,LOW_COLOR,ANCHOR_LEFT);
        }
     }
   if(Show_Swing_Points && s.last_high>=0)
      DrawSegment("LAST_HIGH",points[s.last_high].time,points[s.last_high].price,rates[total-1].time,
                  points[s.last_high].price,HIGH_COLOR,STYLE_DOT,1);
   if(Show_Swing_Points && s.last_low>=0)
      DrawSegment("LAST_LOW",points[s.last_low].time,points[s.last_low].price,rates[total-1].time,
                  points[s.last_low].price,LOW_COLOR,STYLE_DOT,1);
  }

// -------------------------------------------------------------- dashboard
// Component names are black and bold, and only the outputs are coloured:
// green bullish / Tradable, red bearish / Not Tradable, grey Consolidation.
const int DASHBOARD_FONT_SIZE=10;
const int DASHBOARD_ROW_HEIGHT=18;
const int DASHBOARD_INDENT=12;
const int DASHBOARD_WRAP_CHARS=48;
const color DASHBOARD_TEXT_COLOR=clrBlack;
const color DASHBOARD_POSITIVE_COLOR=clrGreen;
const color DASHBOARD_NEGATIVE_COLOR=clrRed;
const color DASHBOARD_NEUTRAL_COLOR=clrGray;

struct BASE_DASHBOARD_ROW
  {
   string label;            // component name; empty for a continuation row
   string value;
   color value_color;
   string tooltip;
   int indent;
  };

void AddDashboardRow(BASE_DASHBOARD_ROW &rows[],const string label,const string value,
                     const color value_color,const string tooltip="",const int indent=0)
  {
   int index=ArraySize(rows);
   ArrayResize(rows,index+1);
   rows[index].label=label;
   rows[index].value=value;
   rows[index].value_color=value_color;
   rows[index].tooltip=tooltip;
   rows[index].indent=indent;
  }

// A long output wraps onto continuation rows of at most DASHBOARD_WRAP_CHARS
// characters, broken between words.
void AddWrappedDashboardRow(BASE_DASHBOARD_ROW &rows[],const string label,const string value,
                            const color value_color)
  {
   string words[];
   int count=StringSplit(value,' ',words);
   string line="";
   bool first=true;
   for(int i=0;i<count;i++)
     {
      if(words[i]=="") continue;
      if(line!="" && StringLen(line)+1+StringLen(words[i])>DASHBOARD_WRAP_CHARS)
        {
         AddDashboardRow(rows,first?label:"",line,value_color);
         first=false;
         line="";
        }
      line+=(line==""?"":" ")+words[i];
     }
   if(line!="" || first) AddDashboardRow(rows,first?label:"",line,value_color);
  }

int DashboardTextWidth(const string text)
  {
   uint width=0,height=0;
   // A negative size is in tenths of a point, as OBJPROP_FONTSIZE is drawn.
   if(!TextSetFont("Arial Bold",-DASHBOARD_FONT_SIZE*10) || !TextGetSize(text,width,height))
      return StringLen(text)*DASHBOARD_FONT_SIZE;
   return (int)width;
  }

void DrawDashboardText(const string name,const int x,const int y,const string text,
                       const color clr,const bool bold,const string tooltip)
  {
   if(!ObjectCreate(0,name,OBJ_LABEL,0,0,0)) return;
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,DASHBOARD_FONT_SIZE);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetString(0,name,OBJPROP_FONT,bold?"Arial Bold":"Arial");
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   // "\n" suppresses MT5's default tooltip, which would show the object name.
   ObjectSetString(0,name,OBJPROP_TOOLTIP,tooltip==""?"\n":tooltip);
  }

void DrawDashboardRows(const BASE_DASHBOARD_ROW &rows[])
  {
   int count=ArraySize(rows);
   int column=0;
   for(int i=0;i<count;i++)
      if(rows[i].label!="") column=MathMax(column,rows[i].indent+DashboardTextWidth(rows[i].label));
   column+=10+8;
   for(int i=0;i<count;i++)
     {
      int y=10+i*DASHBOARD_ROW_HEIGHT;
      string name=g_prefix+"DASHBOARD_"+(string)i;
      if(rows[i].label!="")
         DrawDashboardText(name,10+rows[i].indent,y,rows[i].label,DASHBOARD_TEXT_COLOR,true,rows[i].tooltip);
      DrawDashboardText(name+"_VALUE",column,y,rows[i].value,rows[i].value_color,false,rows[i].tooltip);
     }
  }

color DirectionColor(const int direction)
  {
   return direction>0?DASHBOARD_POSITIVE_COLOR:direction<0?DASHBOARD_NEGATIVE_COLOR:DASHBOARD_NEUTRAL_COLOR;
  }

// One timeframe: its Market Trend (the breakdown is the tooltip), its swing
// structure and its internal structure.
void AddTimeframeRows(BASE_DASHBOARD_ROW &rows[],const string title,const BASE_STATE &s,const BASE_POINT &points[],
                      const MqlRates &rates[],const int total)
  {
   AddDashboardRow(rows,title,StateOutput(s),DirectionColor(Direction(s)),BreakdownText(s,points,rates,total));
   AddDashboardRow(rows,"Swing Structure:",SwingStructureText(s,points),DirectionColor(SwingProgression(s,points)),
                   "The latest swing high and the latest swing low, each against the previous one on its side.",
                   DASHBOARD_INDENT);
   AddDashboardRow(rows,"Internal Structure:",InternalText(s),DirectionColor(s.internal_direction),
                   "The latest break of the internal structure (swings of half the swing size).",DASHBOARD_INDENT);
  }

void SendBaseAlert(const string signal,const datetime bar_time)
  {
   static datetime last_alert=0;
   if(bar_time<=last_alert) return;
   last_alert=bar_time;
   string message=_Symbol+" "+HTFName()+" "+signal;
   if(Enable_Popup_Alerts) Alert(message);
   if(Enable_Push_Notifications) SendNotification(message);
  }

// The HTF breaks and state change of its newest closed candle, for the alert.
string NewestSignal(const BASE_STATE &s,const BASE_EVENT &events[],const int total)
  {
   string signal="";
   for(int i=0;i<ArraySize(events);i++)
     {
      if(events[i].ls && events[i].ls_bar==total-1)
         signal+=(signal==""?"":" + ")+"LS (the "+DirectionWord(events[i].direction)+" break failed)";
      if(events[i].bar==total-1)
         signal+=(signal==""?"":" + ")+(events[i].kind==BASE_BOS?"BOS ":"CHoCH ")+DirectionWord(events[i].direction);
     }
   if(s.changed_bar==total-1) signal+=(signal==""?"":"; ")+"now "+StateText(s);
   return signal;
  }

// ---------------------------------------------------------------- rebuild
// Returns false while history is still being synchronized.  Every series is
// gathered before any chart object is touched, so a retry keeps the previous
// drawing instead of blanking the chart; the timer retries every two seconds.
bool Rebuild(const bool permit_alert)
  {
   ENUM_TIMEFRAMES chart_timeframe=(ENUM_TIMEFRAMES)_Period;
   BASE_STATE htf,mtf,ltf,chart;
   MqlRates htf_rates[],mtf_rates[],ltf_rates[],chart_rates[];
   BASE_POINT htf_points[],mtf_points[],ltf_points[],chart_points[];
   BASE_EVENT htf_events[],mtf_events[],ltf_events[],chart_events[];
   BASE_EVENT htf_internal[],mtf_internal[],ltf_internal[],chart_internal[];
   int htf_start=0,mtf_start=0,ltf_start=0,chart_start=0;
   ZeroMemory(mtf);
   ZeroMemory(ltf);
   if(!AnalyseStructure(HTF(),StructureBars(),htf,htf_rates,htf_start,htf_points,htf_events,htf_internal))
      return false;
   if(Use_MTF && !AnalyseStructure(MTF(),DisplayedBars(MTF()),mtf,mtf_rates,mtf_start,mtf_points,mtf_events,mtf_internal))
      return false;
   if(Use_LTF && !AnalyseStructure(LTF(),DisplayedBars(LTF()),ltf,ltf_rates,ltf_start,ltf_points,ltf_events,ltf_internal))
      return false;
   bool anchored=chart_timeframe==HTF();
   if(!anchored &&
      !AnalyseStructure(chart_timeframe,DisplayedBars(chart_timeframe),chart,chart_rates,chart_start,chart_points,
                        chart_events,chart_internal))
      return false;

   ObjectsDeleteAll(0,g_prefix);
   int htf_total=ArraySize(htf_rates);
   if(anchored)
      DrawChart(htf_rates,htf_total,MathMax(htf_start,htf_total-StructureBars()),htf,htf_points,htf_events,
                htf_internal,chart_timeframe);
   else
     {
      int chart_total=ArraySize(chart_rates);
      DrawChart(chart_rates,chart_total,MathMax(chart_start,chart_total-DisplayedBars(chart_timeframe)),chart,
                chart_points,chart_events,chart_internal,chart_timeframe);
     }

   BASE_DASHBOARD_ROW rows[];
   AddTimeframeRows(rows,"HTF Market Trend ("+HTFName()+"):",htf,htf_points,htf_rates,htf_total);
   if(Use_MTF) AddTimeframeRows(rows,"MTF Market Trend ("+MTFName()+"):",mtf,mtf_points,mtf_rates,ArraySize(mtf_rates));
   if(Use_LTF) AddTimeframeRows(rows,"LTF Market Trend ("+LTFName()+"):",ltf,ltf_points,ltf_rates,ArraySize(ltf_rates));
   string reason="";
   bool tradable=EvaluateTradability(htf,mtf,ltf,reason);
   AddDashboardRow(rows,"Market Tradability:",tradable?"Tradable":"Not Tradable",
                   tradable?DASHBOARD_POSITIVE_COLOR:DASHBOARD_NEGATIVE_COLOR,
                   "Tradable when the HTF is Trending and every selected MTF/LTF is Trending or in Transition the same way.");
   AddWrappedDashboardRow(rows,"Tradability Reason:",reason,DASHBOARD_TEXT_COLOR);
   Comment("");
   DrawDashboardRows(rows);

   string signal=NewestSignal(htf,htf_events,htf_total);
   if(permit_alert && signal!="") SendBaseAlert(signal,htf_rates[htf_total-1].time);
   ChartRedraw();
   return true;
  }

bool ValidInputs()
  {
   if(Bars_To_Process>=100) return true;
   Print("BASE 3.0: invalid input - Bars To Process must be at least 100.");
   return false;
  }

int OnInit()
  {
   if(!ValidInputs()) return INIT_PARAMETERS_INCORRECT;
   // MT5 keeps an EA's global variables across a chart timeframe change, so
   // forget the previous chart's candles; otherwise a first build that waits
   // for data would not be retried until the next candle.
   ArrayInitialize(g_last_bar,0);
   g_prefix="BASE3_"+(string)ChartID()+"_";
   if(!EventSetTimer(2)) return INIT_FAILED;
   CheckForBar();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0,g_prefix);
   Comment("");
  }

// Rebuilds when a new candle opens on the chart, the HTF, or a selected MTF
// or LTF.
void CheckForBar()
  {
   ENUM_TIMEFRAMES watched[4];
   watched[0]=(ENUM_TIMEFRAMES)_Period;
   watched[1]=HTF();
   watched[2]=Use_MTF?MTF():HTF();
   watched[3]=Use_LTF?LTF():HTF();
   datetime now[4];
   bool changed=false,first=false;
   for(int i=0;i<4;i++)
     {
      now[i]=iTime(_Symbol,watched[i],0);
      if(now[i]==0) return;
      if(now[i]!=g_last_bar[i]) changed=true;
      if(g_last_bar[i]==0) first=true;
     }
   if(!changed) return;
   // The first build after attaching never alerts.  The candles are only
   // consumed once every series has loaded.
   if(Rebuild(!first))
      for(int i=0;i<4;i++) g_last_bar[i]=now[i];
  }

void OnTick() { CheckForBar(); }
void OnTimer() { CheckForBar(); }
