#property copyright "ABC1"
#property version   "1.00"
#property strict
#property description "ABC1 multi-timeframe, non-repainting hybrid market-structure EA"

enum ENUM_STRUCTURE_TREND
  {
   STRUCTURE_NEUTRAL=0,
   STRUCTURE_BULLISH=1,
   STRUCTURE_BEARISH=-1
  };

input group "Timeframes"
input ENUM_TIMEFRAMES Higher_Timeframe=PERIOD_H1;
input ENUM_TIMEFRAMES Structure_Timeframe=PERIOD_M15;
input int              Bars_To_Scan=1000;

input group "Hybrid Swing Engine"
input int    Fractal_Length=3;
input bool   ATR_Filter=true;
input int    ATR_Period=14;
input double Minimum_Swing_ATR=1.5;
input int    ZigZag_Depth=12;
input int    ZigZag_Deviation=5;
input int    ZigZag_Backstep=3;

input group "Display and alerts"
input bool  Show_Structure_Labels=true;
input bool  Show_Dashboard=true;
input int   Maximum_Labels=40;
input color HH_Color=clrLimeGreen;
input color HL_Color=clrDeepSkyBlue;
input color LH_Color=clrOrange;
input color LL_Color=clrTomato;
input int   Label_Font_Size=9;
input bool  Alert_On_Aligned_Trend=false;

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
datetime g_last_structure_bar=0;
datetime g_last_alert_bar=0;
int      g_atr_higher=INVALID_HANDLE;
int      g_atr_structure=INVALID_HANDLE;

// Rates are series arrays: index zero is the live bar. Every candidate and
// confirmation below deliberately ends at index one or older.
bool LoadRates(const ENUM_TIMEFRAMES timeframe,const int requested,MqlRates &rates[])
  {
   ArraySetAsSeries(rates,true);
   int available=Bars(_Symbol,timeframe);
   int count=MathMin(requested,available);
   if(count<MathMax(ATR_Period+Fractal_Length*2+10,ZigZag_Depth+10))
      return false;
   return CopyRates(_Symbol,timeframe,0,count,rates)==count;
  }

bool LoadATR(const ENUM_TIMEFRAMES timeframe,const int count,double &values[])
  {
   ArraySetAsSeries(values,true);
   int handle=(timeframe==Higher_Timeframe ? g_atr_higher : g_atr_structure);
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
bool HasATRExcursion(const MqlRates &rates[],const int shift,const bool high,const double atr)
  {
   if(!ATR_Filter)
      return true;
   if(atr<=0.0 || Minimum_Swing_ATR<=0.0)
      return false;

   double required=atr*Minimum_Swing_ATR;
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

// Produces an alternating ZigZag. The last leg remains provisional and is
// removed, so signals already exposed to the rest of the EA cannot repaint.
int BuildHybridSwings(const ENUM_TIMEFRAMES timeframe,SwingPoint &confirmed[])
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
         if(!IsFractal(rates,total,shift,high) ||
            !HasATRExcursion(rates,shift,high,atr[shift]) ||
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
         candidate.label="";

         int count=ArraySize(legs);
         if(count==0)
           {
            AppendSwing(legs,candidate);
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
         if(distance<ZigZag_Deviation || bar_spacing<ZigZag_Backstep)
            continue;

         legs[count-1].zigzag_confirmed=true;
         AppendSwing(legs,candidate);
        }
     }

   // The final leg has no subsequent opposite pivot and is intentionally not
   // published. This is the non-repainting completion rule.
   int leg_count=ArraySize(legs);
   for(int i=0;i<leg_count-1;i++)
      if(legs[i].zigzag_confirmed)
         AppendSwing(confirmed,legs[i]);
   return ArraySize(confirmed);
  }

void ClassifySwings(SwingPoint &swings[])
  {
   double prior_high=0.0,prior_low=0.0;
   bool have_high=false,have_low=false;
   for(int i=0;i<ArraySize(swings);i++)
     {
      if(swings[i].is_high)
        {
         if(have_high)
            swings[i].label=swings[i].price>prior_high ? "HH" : "LH";
         prior_high=swings[i].price;
         have_high=true;
        }
      else
        {
         if(have_low)
            swings[i].label=swings[i].price>prior_low ? "HL" : "LL";
         prior_low=swings[i].price;
         have_low=true;
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

   if(state.latest_high.price>state.previous_high.price &&
      state.latest_low.price>state.previous_low.price)
      state.trend=STRUCTURE_BULLISH;
   else if(state.latest_low.price<state.previous_low.price &&
           state.latest_high.price<state.previous_high.price)
      state.trend=STRUCTURE_BEARISH;
   return state;
  }

string TrendText(const ENUM_STRUCTURE_TREND trend)
  {
   if(trend==STRUCTURE_BULLISH) return "BULLISH (HH + HL)";
   if(trend==STRUCTURE_BEARISH) return "BEARISH (LL + LH)";
   return "NEUTRAL / TRANSITION";
  }

color LabelColor(const string label)
  {
   if(label=="HH") return HH_Color;
   if(label=="HL") return HL_Color;
   if(label=="LH") return LH_Color;
   return LL_Color;
  }

void DrawLabels(const SwingPoint &swings[])
  {
   ObjectsDeleteAll(0,g_prefix+"SW_");
   if(!Show_Structure_Labels)
      return;
   int first=MathMax(0,ArraySize(swings)-Maximum_Labels);
   for(int i=first;i<ArraySize(swings);i++)
     {
      if(swings[i].label=="")
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
     }
  }

void DrawDashboard(const StructureState &higher,const StructureState &local,
                   const int higher_swings,const int local_swings)
  {
   string name=g_prefix+"DASHBOARD";
   if(!Show_Dashboard)
     {
      ObjectDelete(0,name);
      return;
     }
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   bool aligned=(higher.trend!=STRUCTURE_NEUTRAL && higher.trend==local.trend);
   string text="ABC1  |  HYBRID STRUCTURE\n"+
               EnumToString(Higher_Timeframe)+": "+TrendText(higher.trend)+
               "  ["+IntegerToString(higher_swings)+" swings]\n"+
               EnumToString(Structure_Timeframe)+": "+TrendText(local.trend)+
               "  ["+IntegerToString(local_swings)+" swings]\n"+
               "MTF alignment: "+(aligned ? "YES" : "NO");
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,12);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,18);
   ObjectSetInteger(0,name,OBJPROP_COLOR,aligned ? clrLimeGreen : clrSilver);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,10);
   ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
  }

void EvaluateStructure()
  {
   SwingPoint higher_swings[],local_swings[];
   int higher_count=BuildHybridSwings(Higher_Timeframe,higher_swings);
   int local_count=BuildHybridSwings(Structure_Timeframe,local_swings);
   ClassifySwings(higher_swings);
   ClassifySwings(local_swings);
   StructureState higher=ReadStructure(higher_swings);
   StructureState local=ReadStructure(local_swings);
   DrawLabels(local_swings);
   DrawDashboard(higher,local,higher_count,local_count);
   ChartRedraw();

   bool aligned=(higher.trend!=STRUCTURE_NEUTRAL && higher.trend==local.trend);
   datetime closed_bar=iTime(_Symbol,Structure_Timeframe,1);
   if(Alert_On_Aligned_Trend && aligned && closed_bar>0 && closed_bar!=g_last_alert_bar)
     {
      Alert("ABC1 ",_Symbol," MTF structure aligned: ",TrendText(local.trend));
      g_last_alert_bar=closed_bar;
     }
  }

bool InputsAreValid()
  {
   return Bars_To_Scan>=100 && Fractal_Length>=1 && ATR_Period>=2 &&
          Minimum_Swing_ATR>=0.0 && ZigZag_Depth>=2 &&
          ZigZag_Deviation>=0 && ZigZag_Backstep>=1 &&
          ZigZag_Backstep<ZigZag_Depth && Maximum_Labels>=1 &&
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
   g_atr_higher=iATR(_Symbol,Higher_Timeframe,ATR_Period);
   g_atr_structure=iATR(_Symbol,Structure_Timeframe,ATR_Period);
   if(g_atr_higher==INVALID_HANDLE || g_atr_structure==INVALID_HANDLE)
     {
      Print("ABC1: unable to create ATR handles");
      return INIT_FAILED;
     }
   g_last_structure_bar=iTime(_Symbol,Structure_Timeframe,0);
   EvaluateStructure();
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   datetime current_bar=iTime(_Symbol,Structure_Timeframe,0);
   if(current_bar>0 && current_bar!=g_last_structure_bar)
     {
      g_last_structure_bar=current_bar;
      EvaluateStructure();
     }
  }

void OnDeinit(const int reason)
  {
   if(g_atr_higher!=INVALID_HANDLE)
      IndicatorRelease(g_atr_higher);
   if(g_atr_structure!=INVALID_HANDLE)
      IndicatorRelease(g_atr_structure);
   ObjectsDeleteAll(0,g_prefix);
   ChartRedraw();
  }
