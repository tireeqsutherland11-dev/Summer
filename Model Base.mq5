#property copyright "PineScript conversion"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_plots 0
#property description "Model Base - MT5 conversion of Liquidity Swings [LuxAlgo]."

enum MODEL_SWING_AREA
  {
   MODEL_WICK_EXTREMITY=0,
   MODEL_FULL_RANGE=1
  };

enum MODEL_FILTER_MODE
  {
   MODEL_FILTER_COUNT=0,
   MODEL_FILTER_VOLUME=1
  };

enum MODEL_LABEL_SIZE
  {
   MODEL_TINY=7,
   MODEL_SMALL=9,
   MODEL_NORMAL=11
  };

input group "Settings"
input int               Pivot_Lookback=14;
input MODEL_SWING_AREA  Swing_Area=MODEL_WICK_EXTREMITY;
input bool              Intrabar_Precision=false;
input ENUM_TIMEFRAMES   Intrabar_Timeframe=PERIOD_M1;
input MODEL_FILTER_MODE Filter_Areas_By=MODEL_FILTER_COUNT;
input double            Filter_Value=0.0;
input int               Maximum_Bars=3000;

input group "Style"
input bool             Show_Swing_High=true;
input color            Swing_High_Color=clrRed;
input color            Swing_High_Area_Color=clrRed;
input bool             Show_Swing_Low=true;
input color            Swing_Low_Color=clrTeal;
input color            Swing_Low_Area_Color=clrTeal;
input MODEL_LABEL_SIZE Labels_Size=MODEL_TINY;

string g_prefix;

struct MODEL_SWING
  {
   bool active;
   bool crossed;
   bool qualified;
   int  serial;
   int  count;
   long volume;
   datetime start;
   double top;
   double bottom;
   string active_box;
   string zone;
   string level;
   string label;
  };

uint WithAlpha(const color value,const uchar alpha)
  {
   return ColorToARGB(value,alpha);
  }

datetime ProjectTime(const datetime value,const int bars)
  {
   int seconds=PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(seconds<=0) seconds=60;
   return value+(datetime)(bars*seconds);
  }

void SetCommonObject(const string name)
  {
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

void CreateRectangle(const string name,const datetime left,const double top,
                     const datetime right,const double bottom,const color colour,
                     const uchar alpha)
  {
   if(!ObjectCreate(0,name,OBJ_RECTANGLE,0,left,top,right,bottom)) return;
   ObjectSetInteger(0,name,OBJPROP_COLOR,WithAlpha(colour,alpha));
   ObjectSetInteger(0,name,OBJPROP_FILL,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   SetCommonObject(name);
  }

void CreateLevel(const string name,const datetime left,const double price)
  {
   if(!ObjectCreate(0,name,OBJ_TREND,0,left,price,left,price)) return;
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrNONE);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   SetCommonObject(name);
  }

string VolumeText(const long value)
  {
   double number=(double)value;
   if(number>=1000000000.0) return DoubleToString(number/1000000000.0,2)+"B";
   if(number>=1000000.0)    return DoubleToString(number/1000000.0,2)+"M";
   if(number>=1000.0)       return DoubleToString(number/1000.0,2)+"K";
   return IntegerToString(value);
  }

void CreateVolumeLabel(MODEL_SWING &swing,const bool high,const color colour)
  {
   double price=high?swing.top:swing.bottom;
   if(!ObjectCreate(0,swing.label,OBJ_TEXT,0,swing.start,price)) return;
   ObjectSetString(0,swing.label,OBJPROP_TEXT,VolumeText(swing.volume));
   ObjectSetString(0,swing.label,OBJPROP_FONT,"Arial");
   ObjectSetInteger(0,swing.label,OBJPROP_FONTSIZE,(int)Labels_Size);
   ObjectSetInteger(0,swing.label,OBJPROP_COLOR,colour);
   ObjectSetInteger(0,swing.label,OBJPROP_ANCHOR,high?ANCHOR_LOWER:ANCHOR_UPPER);
   SetCommonObject(swing.label);
  }

double Target(const MODEL_SWING &swing)
  {
   return Filter_Areas_By==MODEL_FILTER_COUNT?(double)swing.count:(double)swing.volume;
  }

bool IsPivotHigh(const MqlRates &rates[],const int total,const int index,const int length)
  {
   if(index-length<0 || index+length>=total) return false;
   for(int i=index-length;i<=index+length;i++)
      if(i!=index && rates[i].high>=rates[index].high) return false;
   return true;
  }

bool IsPivotLow(const MqlRates &rates[],const int total,const int index,const int length)
  {
   if(index-length<0 || index+length>=total) return false;
   for(int i=index-length;i<=index+length;i++)
      if(i!=index && rates[i].low<=rates[index].low) return false;
   return true;
  }

long OverlapVolume(const MqlRates &bar,const double top,const double bottom)
  {
   if(!Intrabar_Precision)
      return bar.low<top && bar.high>bottom?(long)bar.tick_volume:0;

   MqlRates lower[];
   ArraySetAsSeries(lower,false);
   datetime finish=bar.time+PeriodSeconds((ENUM_TIMEFRAMES)_Period)-1;
   int copied=CopyRates(_Symbol,Intrabar_Timeframe,bar.time,finish,lower);
   if(copied<=0) return 0;
   long result=0;
   for(int i=0;i<copied;i++)
      if(lower[i].low<top && lower[i].high>bottom)
         result+=(long)lower[i].tick_volume;
   return result;
  }

void StartSwing(MODEL_SWING &swing,const bool high,const MqlRates &pivot,
                const int serial,const color area_colour)
  {
   swing.active=true;
   swing.crossed=false;
   swing.qualified=false;
   swing.serial=serial;
   swing.count=0;
   swing.volume=0;
   swing.start=pivot.time;
   swing.top=high?pivot.high:(Swing_Area==MODEL_WICK_EXTREMITY?
                             MathMin(pivot.open,pivot.close):pivot.high);
   swing.bottom=high?(Swing_Area==MODEL_WICK_EXTREMITY?
                      MathMax(pivot.open,pivot.close):pivot.low):pivot.low;
   string side=high?"H_":"L_";
   string suffix=IntegerToString(serial);
   swing.active_box=g_prefix+side+"ACTIVE_"+suffix;
   swing.zone=g_prefix+side+"ZONE_"+suffix;
   swing.level=g_prefix+side+"LEVEL_"+suffix;
   swing.label=g_prefix+side+"LABEL_"+suffix;
   CreateRectangle(swing.active_box,swing.start,swing.top,swing.start,swing.bottom,
                   area_colour,45);
   CreateLevel(swing.level,swing.start,high?swing.top:swing.bottom);
  }

void UpdateSwing(MODEL_SWING &swing,const bool high,const MqlRates &current,
                 const MqlRates &counted_bar,const color line_colour,
                 const color area_colour)
  {
   if(!swing.active) return;

   bool overlaps=counted_bar.low<swing.top && counted_bar.high>swing.bottom;
   double previous=Target(swing);
   if(overlaps) swing.count++;
   swing.volume+=OverlapVolume(counted_bar,swing.top,swing.bottom);
   double target=Target(swing);

   if(!swing.qualified && previous<=Filter_Value && target>Filter_Value)
     {
      swing.qualified=true;
      datetime right=ProjectTime(swing.start,swing.count);
      CreateRectangle(swing.zone,swing.start,swing.top,right,swing.bottom,
                      area_colour,128);
      CreateVolumeLabel(swing,high,line_colour);
      ObjectSetInteger(0,swing.level,OBJPROP_COLOR,line_colour);
     }

   if(swing.qualified)
     {
      ObjectMove(0,swing.zone,1,ProjectTime(swing.start,swing.count),swing.bottom);
      ObjectSetString(0,swing.label,OBJPROP_TEXT,VolumeText(swing.volume));
     }

   if(!swing.crossed && ((high && current.close>swing.top) ||
                         (!high && current.close<swing.bottom)))
     {
      swing.crossed=true;
      ObjectMove(0,swing.level,1,current.time,high?swing.top:swing.bottom);
      ObjectSetInteger(0,swing.level,OBJPROP_STYLE,STYLE_DASH);
     }

   datetime active_right=swing.crossed?swing.start:ProjectTime(current.time,3);
   ObjectMove(0,swing.active_box,1,active_right,swing.bottom);
   if(!swing.crossed)
      ObjectMove(0,swing.level,1,ProjectTime(current.time,3),high?swing.top:swing.bottom);
  }

void DeleteModelObjects()
  {
   ObjectsDeleteAll(0,g_prefix);
  }

int OnInit()
  {
   if(Pivot_Lookback<1 || Maximum_Bars<2*Pivot_Lookback+2)
     {
      Print("Model Base: Pivot Lookback must be positive and Maximum Bars must provide a complete pivot window.");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(Intrabar_Precision && PeriodSeconds(Intrabar_Timeframe)>=PeriodSeconds((ENUM_TIMEFRAMES)_Period))
     {
      Print("Model Base: Intrabar Timeframe must be lower than the chart timeframe.");
      return INIT_PARAMETERS_INCORRECT;
     }
   g_prefix="ModelBase_"+IntegerToString(ChartID())+"_";
   IndicatorSetString(INDICATOR_SHORTNAME,"Model Base");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   DeleteModelObjects();
   ChartRedraw();
  }

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],
                const double &open[],const double &high[],const double &low[],
                const double &close[],const long &tick_volume[],const long &volume[],
                const int &spread[])
  {
   static datetime last_bar=0;
   if(rates_total<2*Pivot_Lookback+2) return 0;
   if(prev_calculated>0 && time[0]==last_bar) return rates_total;
   last_bar=time[0];

   int wanted=MathMin(Maximum_Bars,rates_total);
   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   int copied=CopyRates(_Symbol,(ENUM_TIMEFRAMES)_Period,0,wanted,rates);
   if(copied<2*Pivot_Lookback+2) return prev_calculated;

   DeleteModelObjects();
   MODEL_SWING ph,pl;
   ZeroMemory(ph);
   ZeroMemory(pl);
   int high_serial=0,low_serial=0;

   // A pivot becomes known Pivot_Lookback bars after its extremity. Counts use
   // that same delayed bar, matching Pine's low[length]/high[length] series.
   for(int now=2*Pivot_Lookback;now<copied;now++)
     {
      int pivot=now-Pivot_Lookback;
      bool new_high=IsPivotHigh(rates,copied,pivot,Pivot_Lookback);
      bool new_low=IsPivotLow(rates,copied,pivot,Pivot_Lookback);

      if(new_high && Show_Swing_High)
         StartSwing(ph,true,rates[pivot],++high_serial,Swing_High_Area_Color);
      else if(Show_Swing_High && ph.active)
         UpdateSwing(ph,true,rates[now],rates[pivot],Swing_High_Color,
                     Swing_High_Area_Color);

      if(new_low && Show_Swing_Low)
         StartSwing(pl,false,rates[pivot],++low_serial,Swing_Low_Area_Color);
      else if(Show_Swing_Low && pl.active)
         UpdateSwing(pl,false,rates[now],rates[pivot],Swing_Low_Color,
                     Swing_Low_Area_Color);
     }

   ChartRedraw();
   return rates_total;
  }
