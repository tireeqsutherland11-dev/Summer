#property copyright "ABC1"
#property version   "1.51"
#property strict
#property description "ABC1 multi-timeframe hybrid market-structure EA with live provisional swings"

enum ENUM_STRUCTURE_TREND
  {
   STRUCTURE_NEUTRAL=0,
   STRUCTURE_BULLISH=1,
   STRUCTURE_BEARISH=-1
  };

input group "Timeframes"
input ENUM_TIMEFRAMES Structure_Timeframe=PERIOD_H1;
input ENUM_TIMEFRAMES Setup_Timeframe=PERIOD_M15;
input int              Bars_To_Scan=1000;

// Setup points are deliberately limited to this recent window.  Direction is
// never inferred from this faster timeframe.
#define SETUP_LOOKBACK_BARS 50
#define MAX_SETUP_POINTS    2

input group "Hybrid Swing Engine"
input int    Fractal_Length=3;
input bool   ATR_Filter=true;
input int    ATR_Period=14;
input double Minimum_Swing_ATR=1.5;
input double Minimum_Structure_Change_ATR=0.25;
input int    Minimum_Structure_Separation_Bars=5;
input double CHoCH_Break_ATR=0.25;
input int    ZigZag_Depth=12;
input int    ZigZag_Deviation=5;
input int    ZigZag_Backstep=3;
input int    Swing_Smoothing_Bars=5;
input double Swing_Cluster_ATR=0.35;
input int    Swing_Cluster_Bars=20;
input double Minimum_Reversal_ATR=0.75;
input double Setup_Sensitivity=0.75;

input group "Display and alerts"
input bool  Show_Structure_Labels=true;
input bool  Show_Equal_Labels=false;
input bool  Show_Dashboard=true;
input int   Maximum_Labels=40;
input bool  Avoid_Label_Overlap=true;
input int   Minimum_Label_Chart_Bars=1;
input color HH_Color=clrLimeGreen;
input color HL_Color=clrDeepSkyBlue;
input color LH_Color=clrOrange;
input color LL_Color=clrTomato;
input int   Label_Font_Size=9;
input bool  Show_CHoCH=true;
input int   CHoCH_Line_Bars=4;
input bool  Alert_On_Structure_Trend=false;

struct SwingPoint
  {
   datetime time;
   double   price;
   double   atr;
   int      shift;
   bool     is_high;
   bool     fractal_confirmed;
   bool     atr_confirmed;
   bool     zigzag_confirmed;
   bool     provisional;
   bool     choch;
   datetime choch_origin_time;
   double   choch_level;
   string   label;
  };

struct StructureState
  {
   ENUM_STRUCTURE_TREND trend;
   SwingPoint latest_high;
   SwingPoint previous_high;
   SwingPoint latest_low;
   SwingPoint previous_low;
   bool       ready;
  };

string   g_prefix="";
datetime g_last_setup_bar=0;
datetime g_last_alert_bar=0;
int      g_atr_structure=INVALID_HANDLE;
int      g_atr_setup=INVALID_HANDLE;

// Rates are series arrays: index zero is the live bar. Every candidate and
// confirmation below deliberately ends at index one or older.
bool LoadRates(const ENUM_TIMEFRAMES timeframe,const int requested,MqlRates &rates[])
  {
   ArraySetAsSeries(rates,true);
   int minimum=MathMax(ATR_Period+Fractal_Length*2+10,ZigZag_Depth+10);
   if(requested<minimum)
      return false;
   // Never silently shorten the scan while a newly selected timeframe is
   // downloading. CopyRates starts synchronization and the timer retries.
   int copied=CopyRates(_Symbol,timeframe,0,requested,rates);
   return copied==requested;
  }

bool LoadATR(const ENUM_TIMEFRAMES timeframe,const int count,double &values[])
  {
   ArraySetAsSeries(values,true);
   int handle=(timeframe==Structure_Timeframe ? g_atr_structure : g_atr_setup);
   if(handle==INVALID_HANDLE)
      return false;
   if(BarsCalculated(handle)<count)
      return false;
   int copied=CopyBuffer(handle,0,0,count,values);
   return copied==count;
  }

bool IsFractal(const MqlRates &rates[],const int total,const int shift,const bool high)
  {
   if(shift-Fractal_Length<1 || shift+Fractal_Length>=total)
      return false;

   for(int distance=1;distance<=Fractal_Length;distance++)
     {
      if(high && (rates[shift].high<=rates[shift-distance].high ||
                  rates[shift].high<=rates[shift+distance].high))
         return false;
      if(!high && (rates[shift].low>=rates[shift-distance].low ||
                   rates[shift].low>=rates[shift+distance].low))
         return false;
     }
   return true;
  }

// A candidate is significant only after a closed-bar excursion away from it.
bool HasATRExcursion(const MqlRates &rates[],const int shift,const bool high,
                     const double atr,const double sensitivity)
  {
   if(!ATR_Filter)
      return true;
   if(atr<=0.0 || Minimum_Swing_ATR<=0.0)
      return false;

   double required=atr*Minimum_Swing_ATR*sensitivity;
   for(int future=shift-1;future>=1;future--)
     {
      double movement=high ? rates[shift].high-rates[future].low
                           : rates[future].high-rates[shift].low;
      if(movement>=required)
         return true;
     }
   return false;
  }

bool IsDepthExtreme(const MqlRates &rates[],const int total,const int shift,const bool high)
  {
   int half=MathMax(1,ZigZag_Depth/2);
   int newest=MathMax(1,shift-half);
   int oldest=MathMin(total-1,shift+half);
   for(int i=newest;i<=oldest;i++)
     {
      if(i==shift)
         continue;
      if(high && rates[i].high>rates[shift].high)
         return false;
      if(!high && rates[i].low<rates[shift].low)
         return false;
     }
   return true;
  }

void AppendSwing(SwingPoint &items[],const SwingPoint &point)
  {
   int size=ArraySize(items);
   ArrayResize(items,size+1);
   items[size]=point;
  }

double SwingATRScale(const SwingPoint &first,const SwingPoint &second)
  {
   return MathMax(first.atr,second.atr);
  }

// Two highs (or two lows) belong to one structure area when their prices are
// close in volatility terms. The bar cap prevents unrelated, old levels from
// being merged simply because price revisits them much later.
bool SameSwingArea(const SwingPoint &first,const SwingPoint &second)
  {
   if(Swing_Cluster_ATR<=0.0 || Swing_Cluster_Bars<=0)
      return false;
   if(MathAbs(first.shift-second.shift)>Swing_Cluster_Bars)
      return false;
   double scale=SwingATRScale(first,second);
   return scale>0.0 && MathAbs(first.price-second.price)<=scale*Swing_Cluster_ATR;
  }

// Produces an alternating ZigZag. Nearby same-side pivots (including a small
// counter-swing between them) are collapsed into the most extreme pivot.
int BuildHybridSwings(const ENUM_TIMEFRAMES timeframe,SwingPoint &confirmed[],
                      const bool sensitive=false)
  {
   ArrayResize(confirmed,0);
   MqlRates rates[];
   double atr[];
   int requested=MathMax(Bars_To_Scan,ATR_Period+ZigZag_Depth+Fractal_Length*2+20);
   if(!LoadRates(timeframe,requested,rates))
      return 0;
   int total=ArraySize(rates);
   if(!LoadATR(timeframe,total,atr))
      return 0;

   SwingPoint legs[];
   ArrayResize(legs,0);
   int oldest=total-Fractal_Length-1;
   for(int shift=oldest;shift>Fractal_Length;shift--)
     {
      for(int side=0;side<2;side++)
        {
         bool high=(side==0);
         double sensitivity=(sensitive ? Setup_Sensitivity : 1.0);
         if(!IsFractal(rates,total,shift,high) ||
            !HasATRExcursion(rates,shift,high,atr[shift],sensitivity) ||
            !IsDepthExtreme(rates,total,shift,high))
            continue;

         SwingPoint candidate;
         candidate.time=rates[shift].time;
         candidate.price=high ? rates[shift].high : rates[shift].low;
         candidate.atr=atr[shift];
         candidate.shift=shift;
         candidate.is_high=high;
         candidate.fractal_confirmed=true;
         candidate.atr_confirmed=true;
         candidate.zigzag_confirmed=false;
         candidate.provisional=false;
         candidate.choch=false;
         candidate.choch_origin_time=0;
         candidate.choch_level=0.0;
         candidate.label="";

         int count=ArraySize(legs);
         if(count==0)
           {
            AppendSwing(legs,candidate);
            continue;
           }

         // A shallow two-leg cluster is noise rather than three separate
         // structure points. Keep its highest high/lowest low and discard the
         // small counter-pivot between it and the new candidate.
         if(count>=2 && legs[count-2].is_high==candidate.is_high &&
            (MathAbs(candidate.shift-legs[count-2].shift)<=Swing_Smoothing_Bars ||
             SameSwingArea(candidate,legs[count-2])))
           {
            bool more_extreme=high ? candidate.price>legs[count-2].price
                                   : candidate.price<legs[count-2].price;
            ArrayResize(legs,count-1);
            if(more_extreme)
               legs[count-2]=candidate;
            continue;
           }

         SwingPoint last=legs[count-1];
         if(last.is_high==candidate.is_high)
           {
            bool more_extreme=high ? candidate.price>last.price
                                   : candidate.price<last.price;
            // Backstep candidates may replace, but never duplicate, a leg.
            if(more_extreme)
               legs[count-1]=candidate;
            continue;
           }

         double distance=MathAbs(candidate.price-last.price)/_Point;
         int bar_spacing=MathAbs(candidate.shift-last.shift);
         double reversal=MathAbs(candidate.price-last.price);
         double required_reversal=SwingATRScale(candidate,last)*
                                  Minimum_Reversal_ATR*sensitivity;
         if(distance<ZigZag_Deviation || bar_spacing<ZigZag_Backstep ||
            reversal<required_reversal)
            continue;

         legs[count-1].zigzag_confirmed=true;
         AppendSwing(legs,candidate);
        }
     }

   // Publish the final leg as provisional and let the live candle extend it.
   // Historical legs stay locked, while the point nearest price remains useful
   // instead of lagging one complete ZigZag leg behind.
   int leg_count=ArraySize(legs);
   if(leg_count>0)
     {
      int last=leg_count-1;
      double live_price=legs[last].is_high ? rates[0].high : rates[0].low;
      bool extends=legs[last].is_high ? live_price>legs[last].price
                                     : live_price<legs[last].price;
      if(extends)
        {
         legs[last].price=live_price;
         legs[last].time=rates[0].time;
         legs[last].shift=0;
         legs[last].atr=atr[0];
        }
      legs[last].provisional=true;
     }
   for(int i=0;i<leg_count;i++)
      if(legs[i].zigzag_confirmed || i==leg_count-1)
         AppendSwing(confirmed,legs[i]);
   return ArraySize(confirmed);
  }

bool StructurallySeparated(const SwingPoint &point,const SwingPoint &reference)
  {
   return Minimum_Structure_Separation_Bars<=0 ||
          MathAbs(point.shift-reference.shift)>=Minimum_Structure_Separation_Bars;
  }

bool MeaningfullyAbove(const SwingPoint &point,const SwingPoint &reference)
  {
   double threshold=MathMax(point.atr,reference.atr)*Minimum_Structure_Change_ATR;
   return StructurallySeparated(point,reference) &&
          point.price-reference.price>threshold;
  }

bool MeaningfullyBelow(const SwingPoint &point,const SwingPoint &reference)
  {
   double threshold=MathMax(point.atr,reference.atr)*Minimum_Structure_Change_ATR;
   return StructurallySeparated(point,reference) &&
          reference.price-point.price>threshold;
  }

bool BreaksProtectedLevel(const SwingPoint &point,const SwingPoint &protected_point,
                          const bool upward)
  {
   double threshold=MathMax(point.atr,protected_point.atr)*CHoCH_Break_ATR;
   if(upward)
      return point.price-protected_point.price>threshold;
   return protected_point.price-point.price>threshold;
  }

void ClassifySwings(SwingPoint &swings[])
  {
   SwingPoint prior_high,prior_low;
   bool have_high=false,have_low=false;
   ENUM_STRUCTURE_TREND established=STRUCTURE_NEUTRAL;
   SwingPoint protected_high,protected_low;
   bool have_protected_high=false,have_protected_low=false;
   for(int i=0;i<ArraySize(swings);i++)
     {
      if(swings[i].is_high)
        {
         if(have_high)
           {
            if(MeaningfullyAbove(swings[i],prior_high)) swings[i].label="HH";
            else if(MeaningfullyBelow(swings[i],prior_high)) swings[i].label="LH";
            else swings[i].label="EQH";
           }
         prior_high=swings[i];
         have_high=true;
        }
      else
        {
         if(have_low)
           {
            if(MeaningfullyAbove(swings[i],prior_low)) swings[i].label="HL";
            else if(MeaningfullyBelow(swings[i],prior_low)) swings[i].label="LL";
            else swings[i].label="EQL";
           }
         prior_low=swings[i];
         have_low=true;
        }

      // A CHoCH is a break of the protected pullback which supported the
      // established trend.  It is not every newly classified LL or HH.  The
      // line is therefore anchored to the level where the counter-trend move
      // actually begins, rather than to the later breaking pivot.
      bool changed=false;
      if(established==STRUCTURE_BULLISH && !swings[i].is_high &&
         have_protected_low &&
         BreaksProtectedLevel(swings[i],protected_low,false))
        {
         swings[i].choch=true;
         swings[i].choch_origin_time=protected_low.time;
         swings[i].choch_level=protected_low.price;
         established=STRUCTURE_NEUTRAL;
         have_protected_low=false;
         changed=true;
        }
      else if(established==STRUCTURE_BEARISH && swings[i].is_high &&
              have_protected_high &&
              BreaksProtectedLevel(swings[i],protected_high,true))
        {
         swings[i].choch=true;
         swings[i].choch_origin_time=protected_high.time;
         swings[i].choch_level=protected_high.price;
         established=STRUCTURE_NEUTRAL;
         have_protected_high=false;
         changed=true;
        }

      if(!changed && have_high && have_low)
        {
         string high_label=prior_high.label;
         string low_label=prior_low.label;
         if(high_label=="HH" && low_label=="HL")
           {
            established=STRUCTURE_BULLISH;
            protected_low=prior_low;
            have_protected_low=true;
            have_protected_high=false;
           }
         else if(high_label=="LH" && low_label=="LL")
           {
            established=STRUCTURE_BEARISH;
            protected_high=prior_high;
            have_protected_high=true;
            have_protected_low=false;
           }
        }
     }
  }

StructureState ReadStructure(SwingPoint &swings[])
  {
   StructureState state;
   state.trend=STRUCTURE_NEUTRAL;
   state.ready=false;
   int highs=0,lows=0;
   for(int i=ArraySize(swings)-1;i>=0 && (highs<2 || lows<2);i--)
     {
      if(swings[i].is_high && highs<2)
        {
         if(highs==0) state.latest_high=swings[i];
         else         state.previous_high=swings[i];
         highs++;
        }
      if(!swings[i].is_high && lows<2)
        {
         if(lows==0) state.latest_low=swings[i];
         else        state.previous_low=swings[i];
         lows++;
        }
     }
   state.ready=(highs==2 && lows==2);
   if(!state.ready)
      return state;

   if(MeaningfullyAbove(state.latest_high,state.previous_high) &&
      MeaningfullyAbove(state.latest_low,state.previous_low))
      state.trend=STRUCTURE_BULLISH;
   else if(MeaningfullyBelow(state.latest_low,state.previous_low) &&
           MeaningfullyBelow(state.latest_high,state.previous_high))
      state.trend=STRUCTURE_BEARISH;
   return state;
  }

string TrendText(const ENUM_STRUCTURE_TREND trend)
  {
   if(trend==STRUCTURE_BULLISH) return "UPTREND (HH + HL)";
   if(trend==STRUCTURE_BEARISH) return "DOWNTREND (LL + LH)";
   return "CONSOLIDATION / TRANSITION";
  }

color LabelColor(const string label)
  {
   if(label=="HH") return HH_Color;
   if(label=="HL") return HL_Color;
   if(label=="LH") return LH_Color;
   if(label=="LL") return LL_Color;
   return clrSilver;
  }

// Score a setup pivot by the smaller of the price legs which lead into and out
// of it. A point needs strength on both sides to outrank a shallow fluctuation.
double SetupPointSignificance(const SwingPoint &swings[],const int index)
  {
   double before=0.0,after=0.0;
   for(int i=index-1;i>=0;i--)
      if(swings[i].is_high!=swings[index].is_high)
        {
         before=MathAbs(swings[i].price-swings[index].price);
         break;
        }
   for(int i=index+1;i<ArraySize(swings);i++)
      if(swings[i].is_high!=swings[index].is_high)
        {
         after=MathAbs(swings[i].price-swings[index].price);
         break;
        }
   if(before<=0.0 || after<=0.0)
      return 0.0;
   double scale=swings[index].atr;
   return (scale>0.0 ? MathMin(before,after)/scale : MathMin(before,after));
  }

// The setup timeframe supplies locations, not direction. Keep only the two
// strongest trend-compatible pullbacks from its last 50 closed bars.
int SelectSetupPoints(const SwingPoint &swings[],const ENUM_STRUCTURE_TREND trend,
                      SwingPoint &selected[])
  {
   ArrayResize(selected,0);
   if(trend==STRUCTURE_NEUTRAL)
      return 0;

   string required=(trend==STRUCTURE_BULLISH ? "HL" : "LH");
   int best_index[MAX_SETUP_POINTS];
   double best_score[MAX_SETUP_POINTS];
   for(int slot=0;slot<MAX_SETUP_POINTS;slot++)
     {
      best_index[slot]=-1;
      best_score[slot]=-1.0;
     }

   for(int i=0;i<ArraySize(swings);i++)
     {
      if(swings[i].shift<1 || swings[i].shift>SETUP_LOOKBACK_BARS ||
         swings[i].label!=required)
         continue;
      double score=SetupPointSignificance(swings,i);
      if(score<=0.0)
         continue;
      for(int slot=0;slot<MAX_SETUP_POINTS;slot++)
        {
         if(score>best_score[slot])
           {
            for(int move=MAX_SETUP_POINTS-1;move>slot;move--)
              {
               best_score[move]=best_score[move-1];
               best_index[move]=best_index[move-1];
              }
            best_score[slot]=score;
            best_index[slot]=i;
            break;
           }
        }
     }

   // Preserve chronological order for deterministic chart rendering.
   for(int i=0;i<ArraySize(swings);i++)
      for(int slot=0;slot<MAX_SETUP_POINTS;slot++)
         if(best_index[slot]==i)
            AppendSwing(selected,swings[i]);
   return ArraySize(selected);
  }

// Keep the structure layer visible even when the current market is neutral and
// therefore has no trend-compatible setup points. Setup points are added to the
// same chronological list, with duplicates removed when both timeframes happen
// to identify the same pivot.
void AddDisplayPoint(SwingPoint &display[],const SwingPoint &point)
  {
   int size=ArraySize(display);
   for(int i=0;i<size;i++)
      if(display[i].time==point.time && display[i].is_high==point.is_high)
         return; // Preserve structure metadata such as a CHoCH marker.

   int position=size;
   while(position>0 && display[position-1].time>point.time)
      position--;
   ArrayResize(display,size+1);
   for(int i=size;i>position;i--)
      display[i]=display[i-1];
   display[position]=point;
  }

void BuildDisplayPoints(const SwingPoint &structure_swings[],
                        const SwingPoint &setup_points[],SwingPoint &display[])
  {
   ArrayResize(display,0);
   for(int i=0;i<ArraySize(structure_swings);i++)
      AddDisplayPoint(display,structure_swings[i]);
   for(int i=0;i<ArraySize(setup_points);i++)
      AddDisplayPoint(display,setup_points[i]);
  }

void DrawLabels(const SwingPoint &swings[])
  {
   ObjectsDeleteAll(0,g_prefix+"SW_");
   ObjectsDeleteAll(0,g_prefix+"CH_");
   if(!Show_Structure_Labels)
      return;
   int drawn=0;
   datetime last_drawn=0;
   int chart_seconds=PeriodSeconds((ENUM_TIMEFRAMES)Period());
   int minimum_gap=(Avoid_Label_Overlap && chart_seconds>0
                    ? chart_seconds*Minimum_Label_Chart_Bars : 0);
   // Pick newest-first so the current point wins when several lower-timeframe
   // swings occupy one chart candle. Analysis still uses every loaded swing.
   for(int i=ArraySize(swings)-1;i>=0 && drawn<Maximum_Labels;i--)
     {
      if(swings[i].label=="")
         continue;
      if(!Show_Equal_Labels &&
         (swings[i].label=="EQH" || swings[i].label=="EQL"))
         continue;
      if(minimum_gap>0 && last_drawn>0 &&
         MathAbs((long)(last_drawn-swings[i].time))<minimum_gap)
         continue;
      string name=g_prefix+"SW_"+IntegerToString((int)swings[i].time)+
                  (swings[i].is_high ? "_H" : "_L");
      double offset=MathMax(swings[i].atr*0.12,10.0*_Point);
      double price=swings[i].price+(swings[i].is_high ? offset : -offset);
      if(!ObjectCreate(0,name,OBJ_TEXT,0,swings[i].time,price))
         continue;
      ObjectSetString(0,name,OBJPROP_TEXT,swings[i].label);
      ObjectSetInteger(0,name,OBJPROP_COLOR,LabelColor(swings[i].label));
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,Label_Font_Size);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,
                       swings[i].is_high ? ANCHOR_LOWER : ANCHOR_UPPER);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      last_drawn=swings[i].time;
      drawn++;

      if(Show_CHoCH && swings[i].choch)
        {
         string base=g_prefix+"CH_"+IntegerToString((int)swings[i].time);
         datetime origin_time=swings[i].choch_origin_time;
         double level=swings[i].choch_level;
         datetime minimum_end=origin_time+
                              (datetime)(PeriodSeconds(Setup_Timeframe)*CHoCH_Line_Bars);
         datetime end_time=(swings[i].time>minimum_end ? swings[i].time : minimum_end);
         if(ObjectCreate(0,base+"_LINE",OBJ_TREND,0,origin_time,
                         level,end_time,level))
           {
            ObjectSetInteger(0,base+"_LINE",OBJPROP_COLOR,clrRed);
            ObjectSetInteger(0,base+"_LINE",OBJPROP_WIDTH,2);
            ObjectSetInteger(0,base+"_LINE",OBJPROP_RAY_RIGHT,false);
            ObjectSetInteger(0,base+"_LINE",OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,base+"_LINE",OBJPROP_HIDDEN,true);
           }
         if(ObjectCreate(0,base+"_TEXT",OBJ_TEXT,0,end_time,level))
           {
            ObjectSetString(0,base+"_TEXT",OBJPROP_TEXT,"CHoCH");
            ObjectSetInteger(0,base+"_TEXT",OBJPROP_COLOR,clrRed);
            ObjectSetInteger(0,base+"_TEXT",OBJPROP_FONTSIZE,Label_Font_Size);
            ObjectSetInteger(0,base+"_TEXT",OBJPROP_ANCHOR,ANCHOR_LEFT);
            ObjectSetInteger(0,base+"_TEXT",OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,base+"_TEXT",OBJPROP_HIDDEN,true);
           }
        }
     }
  }

void DrawDashboard(const StructureState &structure,const int structure_swings,
                   const int setup_points)
  {
   string name=g_prefix+"DASHBOARD";
   if(!Show_Dashboard)
     {
      ObjectDelete(0,name);
      return;
     }
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   string text="ABC1  |  HYBRID STRUCTURE\n"+
               "Structure "+EnumToString(Structure_Timeframe)+": "+
               TrendText(structure.trend)+"  ["+
               IntegerToString(structure_swings)+" swings]\n"+
               "Setup "+EnumToString(Setup_Timeframe)+": "+
               IntegerToString(setup_points)+" significant "+
               (structure.trend==STRUCTURE_BULLISH ? "HL" :
                structure.trend==STRUCTURE_BEARISH ? "LH" : "points")+
               " (last 50 bars)";
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,12);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,18);
   ObjectSetInteger(0,name,OBJPROP_COLOR,
                    structure.trend!=STRUCTURE_NEUTRAL ? clrLimeGreen : clrSilver);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,10);
   ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
  }

bool EvaluateStructure()
  {
   SwingPoint structure_swings[],setup_swings[],setup_points[],display_points[];
   int structure_count=BuildHybridSwings(Structure_Timeframe,structure_swings);
   BuildHybridSwings(Setup_Timeframe,setup_swings,true);
   ClassifySwings(structure_swings);
   ClassifySwings(setup_swings);
   StructureState structure=ReadStructure(structure_swings);
   int setup_count=SelectSetupPoints(setup_swings,structure.trend,setup_points);
   BuildDisplayPoints(structure_swings,setup_points,display_points);
   DrawLabels(display_points);
   DrawDashboard(structure,structure_count,setup_count);
   ChartRedraw();

   if(!structure.ready)
      return false;

   datetime closed_bar=iTime(_Symbol,Structure_Timeframe,1);
   if(Alert_On_Structure_Trend && structure.trend!=STRUCTURE_NEUTRAL &&
      closed_bar>0 && closed_bar!=g_last_alert_bar)
     {
      Alert("ABC1 ",_Symbol," structure: ",TrendText(structure.trend));
      g_last_alert_bar=closed_bar;
     }
   return true;
  }

// History and indicator buffers can still be synchronizing immediately after
// attachment or a chart-timeframe change. Only acknowledge a bar after a
// successful evaluation so the timer can retry without waiting for a new bar.
void RefreshStructure(const bool force=false)
  {
   datetime current_bar=iTime(_Symbol,Setup_Timeframe,0);
   if(current_bar<=0 || (!force && current_bar==g_last_setup_bar))
      return;
   if(EvaluateStructure())
      g_last_setup_bar=current_bar;
  }

bool InputsAreValid()
  {
   return Bars_To_Scan>=100 && Fractal_Length>=1 && ATR_Period>=2 &&
          Minimum_Swing_ATR>=0.0 && Minimum_Structure_Change_ATR>=0.0 &&
          Minimum_Structure_Separation_Bars>=0 && CHoCH_Break_ATR>=0.0 &&
          ZigZag_Depth>=2 &&
          ZigZag_Deviation>=0 && ZigZag_Backstep>=1 &&
          ZigZag_Backstep<ZigZag_Depth && Swing_Smoothing_Bars>=0 &&
          Swing_Cluster_ATR>=0.0 && Swing_Cluster_Bars>=0 &&
          Minimum_Reversal_ATR>=0.0 && Setup_Sensitivity>0.0 &&
          Setup_Sensitivity<=1.0 &&
          CHoCH_Line_Bars>=1 && Maximum_Labels>=1 &&
          Minimum_Label_Chart_Bars>=1 &&
          Label_Font_Size>=6;
  }

int OnInit()
  {
   if(!InputsAreValid())
     {
      Print("ABC1: invalid input combination");
      return INIT_PARAMETERS_INCORRECT;
     }
   g_prefix="ABC1_"+IntegerToString((int)ChartID())+"_";
   g_atr_structure=iATR(_Symbol,Structure_Timeframe,ATR_Period);
   g_atr_setup=iATR(_Symbol,Setup_Timeframe,ATR_Period);
   if(g_atr_structure==INVALID_HANDLE || g_atr_setup==INVALID_HANDLE)
     {
      Print("ABC1: unable to create ATR handles");
      return INIT_FAILED;
     }
   g_last_setup_bar=0;
   EventSetTimer(2);
   RefreshStructure(true);
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   // The provisional point follows the live bar on every tick.
   RefreshStructure(true);
  }

void OnTimer()
  {
   RefreshStructure();
  }

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   if(id==CHARTEVENT_CHART_CHANGE)
      RefreshStructure(true);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(g_atr_structure!=INVALID_HANDLE)
      IndicatorRelease(g_atr_structure);
   if(g_atr_setup!=INVALID_HANDLE)
      IndicatorRelease(g_atr_setup);
   ObjectsDeleteAll(0,g_prefix);
   ChartRedraw();
  }
