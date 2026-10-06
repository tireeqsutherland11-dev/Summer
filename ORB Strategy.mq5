#property copyright "ORB Strategy (Opening Range Breakout)"
#property version   "1.00"
#property strict
#property description "Opening Range Breakout: trades the first break of the session's opening range, with the stop on the other side of the range, one trade a day, closed at a set time."
#property description "Defaults: the London open (08:00-09:00 London time), a 1R target. Trades only in the Strategy Tester by default."

#include <Trade\Trade.mqh>

// The clock the session times are written in.  London and New York follow
// their own daylight saving; the broker's server clock is converted with
// Server_GMT_Offset and Server_DST.
enum ORB_CLOCK
  {
   ORB_CLOCK_LONDON=0,      // London time
   ORB_CLOCK_NEW_YORK=1,    // New York time
   ORB_CLOCK_SERVER=2       // Broker server time (as on the chart)
  };
// The broker server's daylight saving rule.  Most MT5 brokers run GMT+2 in
// winter and GMT+3 in summer on the US rule (New York 17:00 = 00:00 server).
enum ORB_DST
  {
   ORB_DST_US=0,            // US rule (most brokers)
   ORB_DST_EU=1,            // EU rule
   ORB_DST_NONE=2           // None
  };
enum ORB_ENTRY
  {
   ORB_ENTRY_BREAK=0,       // The price breaks the range
   ORB_ENTRY_CLOSE=1        // A candle closes beyond the range
  };
enum ORB_STOP
  {
   ORB_STOP_OPPOSITE=0,     // The other side of the range
   ORB_STOP_MIDDLE=1        // The middle of the range
  };
// Where the strategy may open positions.
enum ORB_TRADE_MODE
  {
   ORB_TRADING_OFF=0,       // Off (signals only)
   ORB_TRADING_TESTER=1,    // Strategy Tester only
   ORB_TRADING_LIVE=2       // Strategy Tester and live charts
  };
// What OnTester returns for the Strategy Tester's "Custom max" optimization.
enum ORB_CRITERION
  {
   ORB_CRITERION_WIN_RATE=0,      // Win rate (only when the average R is positive)
   ORB_CRITERION_EXPECTANCY=1,    // Average R per trade
   ORB_CRITERION_PROFIT_FACTOR=2  // Profit factor
  };

input group "Session (times on the Session Clock)"
input ORB_CLOCK Session_Clock=ORB_CLOCK_LONDON;     // Session Clock
input string Range_Start="08:00";                  // Opening Range Start
input string Range_End="09:00";                    // Opening Range End (entries from here)
input string Last_Entry="12:00";                   // No New Entries From
input string Close_Time="16:00";                   // Close Open Trades At
input int    Server_GMT_Offset=2;                  // Broker Server GMT Offset (winter)
input ORB_DST Server_DST=ORB_DST_US;               // Broker Server Daylight Saving

input group "Entry"
input ORB_ENTRY Entry_Mode=ORB_ENTRY_BREAK;        // Entry
input ENUM_TIMEFRAMES Close_Timeframe=PERIOD_M15;  // Candle Timeframe (close entries)
input double Breakout_Buffer_Percent=0.0;          // Breakout Buffer (% of the range)
input double Max_Range_ADR_Percent=0.0;            // Skip Ranges Wider Than (% of 10-day ADR, 0 = off)
input double Min_Stop_Spreads=4.0;                 // Skip When The Stop Is Within N Spreads

input group "Exits"
input ORB_STOP Stop_Loss_At=ORB_STOP_OPPOSITE;     // Stop Loss At
input double Take_Profit_R=1.0;                    // Take Profit (R, 0 = hold to Close Time)
input double Partial_Close_R=0.0;                  // Partial Close At (R, 0 = off)
input double Partial_Close_Percent=50.0;           // Partial Close Size (%), then the stop to breakeven

input group "Risk"
input ORB_TRADE_MODE Trade_Mode=ORB_TRADING_TESTER;
input double Risk_Percent=1.0;                     // Risk (%) Per Trade
input ulong  Magic_Number=20261006;

input group "Optimization (Strategy Tester, Custom max)"
input ORB_CRITERION Optimization_Criterion=ORB_CRITERION_WIN_RATE;
input int    Minimum_Trades=30;                    // Minimum Trades For The Criterion

input group "Chart"
input bool   Show_Ranges=true;                     // Show The Opening Ranges
input bool   Show_Panel=true;                      // Show The Panel
input bool   Enable_Alerts=false;                  // Popup Alerts (entries)

// ------------------------------------------------------------------ state
enum ORB_STATE
  {
   ORB_WAITING=0,           // before the end of the opening range
   ORB_ARMED=1,             // the range is known; waiting for the first break
   ORB_DONE=2               // traded, or skipped, for the day
  };

// One session day.  Times are server times (the chart's).
struct ORB_DAY
  {
   datetime day;            // 00:00 of the session day on the Session Clock
   datetime range_from;     // first M1 candle of the range
   datetime range_to;       // the range ends (and entries start) here
   datetime last_entry;
   datetime close_at;
   int      state;
   bool     have_range;
   double   high;
   double   low;
   double   adr;            // 10-day average daily range (0 when unavailable)
   int      direction;      // the traded break: 1 buy, -1 sell, 0 none
   string   status;         // what happened today, for the panel and the journal
  };

struct ORB_RESULTS
  {
   int    trades;
   int    wins;
   double sum_r;            // sum of R over the trades with a known risk
   int    r_trades;
   double gross_profit;
   double gross_loss;
  };

CTrade   g_trade;
ORB_DAY  g_day;
string   g_prefix="";
int      g_range_start=0,g_range_end=0,g_last_entry=0,g_close_time=0;   // minutes on the clock
datetime g_last_close_bar=0;       // latest Close_Timeframe candle seen (close entries)
datetime g_run_from=0;             // results count positions opened from here
ulong    g_partial_ticket=0;       // the position whose partial close is done
ulong    g_breakeven_failed=0;
string   g_last_journal="";

// ------------------------------------------------------------------ time
// "HH:MM" -> minutes after midnight, or -1.
int ParseMinutes(const string text)
  {
   string parts[];
   if(StringSplit(text,':',parts)!=2) return -1;
   if(StringLen(parts[0])<1 || StringLen(parts[0])>2 || StringLen(parts[1])!=2) return -1;
   for(int p=0;p<2;p++)
      for(int i=0;i<StringLen(parts[p]);i++)
        {
         ushort c=StringGetCharacter(parts[p],i);
         if(c<'0' || c>'9') return -1;
        }
   int h=(int)StringToInteger(parts[0]);
   int m=(int)StringToInteger(parts[1]);
   if(h>23 || m>59) return -1;
   return h*60+m;
  }

string MinutesText(const int minutes)
  {
   int h=minutes/60,m=minutes%60;
   return (h<10?"0":"")+(string)h+":"+(m<10?"0":"")+(string)m;
  }

datetime DayStart(const datetime t) { return t-(t%86400); }

datetime FirstOfMonth(const int year,const int month)
  {
   MqlDateTime s;
   ZeroMemory(s);
   s.year=year;
   s.mon=month;
   s.day=1;
   return StructToTime(s);
  }

// The n-th Sunday (n >= 1) of a month, 00:00.
datetime NthSunday(const int year,const int month,const int n)
  {
   datetime first=FirstOfMonth(year,month);
   MqlDateTime s;
   TimeToStruct(first,s);
   return first+((7-s.day_of_week)%7+7*(n-1))*86400;
  }

// The last Sunday of a month, 00:00.
datetime LastSunday(const int year,const int month)
  {
   datetime last=(month==12?FirstOfMonth(year+1,1):FirstOfMonth(year,month+1))-86400;
   MqlDateTime s;
   TimeToStruct(last,s);
   return last-s.day_of_week*86400;
  }

// The daylight saving changes of one year, kept because every tick converts
// times: US from the second Sunday of March 02:00 EST (07:00 UTC) to the
// first Sunday of November 02:00 EDT (06:00 UTC); EU from the last Sunday of
// March 01:00 UTC to the last Sunday of October 01:00 UTC.
datetime g_dst_year_from=0,g_dst_year_to=0;
datetime g_us_start=0,g_us_end=0,g_eu_start=0,g_eu_end=0;

void LoadDstYear(const datetime utc)
  {
   if(utc>=g_dst_year_from && utc<g_dst_year_to) return;
   MqlDateTime s;
   TimeToStruct(utc,s);
   g_dst_year_from=FirstOfMonth(s.year,1);
   g_dst_year_to=FirstOfMonth(s.year+1,1);
   g_us_start=NthSunday(s.year,3,2)+7*3600;
   g_us_end=NthSunday(s.year,11,1)+6*3600;
   g_eu_start=LastSunday(s.year,3)+3600;
   g_eu_end=LastSunday(s.year,10)+3600;
  }

bool UsDst(const datetime utc)
  {
   LoadDstYear(utc);
   return utc>=g_us_start && utc<g_us_end;
  }

bool EuDst(const datetime utc)
  {
   LoadDstYear(utc);
   return utc>=g_eu_start && utc<g_eu_end;
  }

bool ServerDst(const datetime utc)
  {
   if(Server_DST==ORB_DST_US) return UsDst(utc);
   if(Server_DST==ORB_DST_EU) return EuDst(utc);
   return false;
  }

datetime UtcToServer(const datetime utc)
  {
   return utc+Server_GMT_Offset*3600+(ServerDst(utc)?3600:0);
  }

datetime ServerToUtc(const datetime server)
  {
   datetime utc=server-Server_GMT_Offset*3600;
   if(ServerDst(utc-3600)) utc-=3600;
   return utc;
  }

datetime UtcToClock(const datetime utc)
  {
   if(Session_Clock==ORB_CLOCK_LONDON) return utc+(EuDst(utc)?3600:0);
   if(Session_Clock==ORB_CLOCK_NEW_YORK) return utc-5*3600+(UsDst(utc)?3600:0);
   return UtcToServer(utc);
  }

datetime ClockToUtc(const datetime clock)
  {
   if(Session_Clock==ORB_CLOCK_LONDON)
     {
      datetime summer=clock-3600;
      return EuDst(summer)?summer:clock;
     }
   if(Session_Clock==ORB_CLOCK_NEW_YORK)
     {
      datetime summer=clock+4*3600;
      return UsDst(summer)?summer:clock+5*3600;
     }
   return ServerToUtc(clock);
  }

datetime ServerToClock(const datetime server)
  {
   if(Session_Clock==ORB_CLOCK_SERVER) return server;
   return UtcToClock(ServerToUtc(server));
  }

datetime ClockToServer(const datetime clock)
  {
   if(Session_Clock==ORB_CLOCK_SERVER) return clock;
   return UtcToServer(ClockToUtc(clock));
  }

string ClockName()
  {
   if(Session_Clock==ORB_CLOCK_LONDON) return "London";
   if(Session_Clock==ORB_CLOCK_NEW_YORK) return "New York";
   return "server";
  }

// The Close Time of the session day a server time belongs to.
datetime CloseTimeOf(const datetime server)
  {
   return ClockToServer(DayStart(ServerToClock(server))+g_close_time*60);
  }

// ------------------------------------------------------------- utilities
bool TradingActive()
  {
   if(Trade_Mode==ORB_TRADING_OFF) return false;
   if(MQLInfoInteger(MQL_TESTER)!=0) return true;
   return Trade_Mode==ORB_TRADING_LIVE;
  }

bool DrawingEnabled()
  {
   return MQLInfoInteger(MQL_TESTER)==0 || MQLInfoInteger(MQL_VISUAL_MODE)!=0;
  }

string PriceText(const double price) { return DoubleToString(price,_Digits); }

bool FindPosition(ulong &ticket)
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong candidate=PositionGetTicket(i);
      if(candidate==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC)==Magic_Number)
        {
         ticket=candidate;
         return true;
        }
     }
   return false;
  }

// Aligns a price to the symbol's tick size: direction 1 rounds up, -1 rounds
// down and 0 rounds to the nearest tick.
double AlignPrice(const double price,const int direction)
  {
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tick<=0.0) tick=_Point;
   double steps=price/tick;
   if(direction>0) steps=MathCeil(steps-1e-8);
   else if(direction<0) steps=MathFloor(steps+1e-8);
   else steps=MathRound(steps);
   return NormalizeDouble(steps*tick,_Digits);
  }

// The broker's minimum distance between the market and a stop.
double MinimumStopDistance()
  {
   long level=MathMax(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),
                      SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL));
   return (double)(level+1)*_Point;
  }

// The initial risk stored in an entry's comment ("ORB buy r=123", in
// points), 0 when absent.
double CommentRisk(const string comment)
  {
   int at=StringFind(comment,"r=");
   if(at<0) return 0.0;
   return (double)StringToInteger(StringSubstr(comment,at+2))*_Point;
  }

// Volume that loses `risk_money` at the stop, rounded down to the volume
// step; 0 below the symbol's minimum, capped at its maximum.
double RiskVolume(const bool sell,const double entry,const double sl,const double risk_money)
  {
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double minimum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maximum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double limit=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_LIMIT);
   if(limit>0.0) maximum=MathMin(maximum,limit);
   double loss=0.0;
   if(!OrderCalcProfit(sell?ORDER_TYPE_SELL:ORDER_TYPE_BUY,_Symbol,1.0,entry,sl,loss) || loss>=0.0)
      return 0.0;
   double lots=risk_money/(-loss);
   if(step>0.0)
     {
      lots=MathFloor(lots/step+1e-8)*step;
      lots=NormalizeDouble(lots,(int)MathMax(0.0,MathCeil(-MathLog10(step)-1e-8)));
     }
   if(lots<minimum) return 0.0;
   if(maximum>0.0 && lots>maximum) return maximum;
   return lots;
  }

// A volume rounded down to the symbol's step.
double StepVolume(const double volume)
  {
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(step<=0.0) return volume;
   return NormalizeDouble(MathFloor(volume/step+1e-8)*step,(int)MathMax(0.0,MathCeil(-MathLog10(step)-1e-8)));
  }

void Journal(const string text)
  {
   if(text==g_last_journal) return;
   g_last_journal=text;
   Print("ORB Strategy: ",text);
  }

void Notify(const string text)
  {
   Journal(text);
   if(Enable_Alerts && MQLInfoInteger(MQL_TESTER)==0) Alert("ORB Strategy ",_Symbol,": ",text);
  }

// ------------------------------------------------------------- the day
void StartDay(const datetime day)
  {
   g_day.day=day;
   g_day.range_from=ClockToServer(day+g_range_start*60);
   g_day.range_to=ClockToServer(day+g_range_end*60);
   g_day.last_entry=ClockToServer(day+g_last_entry*60);
   g_day.close_at=ClockToServer(day+g_close_time*60);
   g_day.state=ORB_WAITING;
   g_day.have_range=false;
   g_day.high=0.0;
   g_day.low=0.0;
   g_day.adr=0.0;
   g_day.direction=0;
   g_day.status="waiting for the opening range ("+MinutesText(g_range_start)+"-"+MinutesText(g_range_end)+" "+
                ClockName()+")";
  }

void SkipDay(const string reason)
  {
   g_day.state=ORB_DONE;
   g_day.status="no trade today: "+reason;
   Journal(TimeToString(g_day.day,TIME_DATE)+" "+g_day.status);
  }

// The average high-low range of the 10 daily candles before today.
double AverageDailyRange()
  {
   double sum=0.0;
   for(int shift=1;shift<=10;shift++)
     {
      double h=iHigh(_Symbol,PERIOD_D1,shift),l=iLow(_Symbol,PERIOD_D1,shift);
      if(h<=0.0 || l<=0.0) return 0.0;
      sum+=h-l;
     }
   return sum/10.0;
  }

double BreakoutBuffer() { return Breakout_Buffer_Percent/100.0*(g_day.high-g_day.low); }

// At the end of the opening range: its high and low from the M1 candles
// that opened inside it, then the filters.  A range with fewer M1 candles
// than half its minutes (a holiday, a late open) is not traded, nor one
// that price already broke before the EA could arm it (attached late).
void BuildRange()
  {
   datetime now=TimeCurrent();
   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   int count=CopyRates(_Symbol,PERIOD_M1,g_day.range_from,g_day.range_to-1,rates);
   int minutes=g_range_end-g_range_start;
   if(count<=0 || count*2<minutes)
     {
      SkipDay("the opening range has too few prices ("+(string)MathMax(count,0)+" M1 candles in "+
              (string)minutes+" minutes)");
      return;
     }
   if(now>=g_day.last_entry)
     {
      SkipDay("the entry window had passed when the EA started");
      return;
     }
   double high=rates[0].high,low=rates[0].low;
   for(int i=1;i<count;i++)
     {
      high=MathMax(high,rates[i].high);
      low=MathMin(low,rates[i].low);
     }
   g_day.have_range=true;
   g_day.high=high;
   g_day.low=low;
   g_day.adr=AverageDailyRange();
   if(high<=low)
     {
      SkipDay("the opening range is flat");
      return;
     }
   if(Max_Range_ADR_Percent>0.0)
     {
      if(g_day.adr<=0.0)
        {
         SkipDay("the 10-day average daily range is unavailable");
         return;
        }
      if(high-low>Max_Range_ADR_Percent/100.0*g_day.adr)
        {
         SkipDay("the range is "+DoubleToString(100.0*(high-low)/g_day.adr,0)+"% of the average daily range "+
                 "(more than "+DoubleToString(Max_Range_ADR_Percent,0)+"%)");
         return;
        }
     }
   // Closed M1 candles since the range ended must not have broken it yet.
   double buffer=BreakoutBuffer();
   MqlRates after[];
   ArraySetAsSeries(after,false);
   int closed=now-60>=g_day.range_to?CopyRates(_Symbol,PERIOD_M1,g_day.range_to,now-60,after):0;
   for(int i=0;i<closed;i++)
      if(after[i].time+60<=now && (after[i].high>=high+buffer || after[i].low<=low-buffer))
        {
         SkipDay("the range was broken before the EA could arm it");
         return;
        }
   g_day.state=ORB_ARMED;
   g_day.status="armed: buy above "+PriceText(high+buffer)+", sell below "+PriceText(low-buffer)+" until "+
                MinutesText(g_last_entry)+" "+ClockName();
   g_last_close_bar=iTime(_Symbol,Close_Timeframe,0);
   Journal(TimeToString(g_day.day,TIME_DATE)+" range "+PriceText(low)+" - "+PriceText(high)+"; "+g_day.status);
   if(DrawingEnabled()) DrawDay();
  }

// ------------------------------------------------------------- entries
// One attempt a day: the first break decides, whether or not it can trade.
void Enter(const int direction,const MqlTick &tick)
  {
   g_day.state=ORB_DONE;
   g_day.direction=direction;
   bool buy=direction>0;
   string side=buy?"buy":"sell";
   string what=side+" break of the "+PriceText(buy?g_day.high:g_day.low)+" range "+(buy?"high":"low");
   if(!TradingActive())
     {
      g_day.status=what+" (not traded: Trade Mode)";
      Notify(g_day.status);
      return;
     }
   ulong open_ticket=0;
   if(FindPosition(open_ticket))
     {
      g_day.status=what+" (not traded: a position is still open)";
      Journal(g_day.status);
      return;
     }
   double spread=tick.ask-tick.bid;
   double entry=buy?tick.ask:tick.bid;
   double anchor=Stop_Loss_At==ORB_STOP_OPPOSITE?(buy?g_day.low:g_day.high):0.5*(g_day.high+g_day.low);
   // A sell's stop and target are hit on the ask, so the stop carries the spread.
   double sl=buy?AlignPrice(anchor,-1):AlignPrice(anchor+spread,1);
   double risk=buy?entry-sl:sl-entry;
   string reason="";
   if(risk<=0.0) reason="the price is already beyond the stop";
   else if(risk<Min_Stop_Spreads*spread) reason="the stop is within "+DoubleToString(Min_Stop_Spreads,1)+" spreads";
   else if(risk<MinimumStopDistance()) reason="the stop is closer than the broker allows";
   double tp=0.0;
   if(reason=="" && Take_Profit_R>0.0)
      tp=buy?AlignPrice(entry+Take_Profit_R*risk,0):AlignPrice(entry-Take_Profit_R*risk,0);
   double lots=0.0;
   if(reason=="")
     {
      lots=RiskVolume(!buy,entry,sl,AccountInfoDouble(ACCOUNT_BALANCE)*Risk_Percent/100.0);
      double margin=0.0;
      if(lots<=0.0) reason="the position size is below the symbol's minimum";
      else if(OrderCalcMargin(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,lots,entry,margin) &&
              margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE))
         reason="insufficient free margin";
     }
   if(reason=="" && MQLInfoInteger(MQL_TESTER)==0 &&
      (TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)==0 || MQLInfoInteger(MQL_TRADE_ALLOWED)==0))
      reason="Algo Trading is disabled";
   if(reason!="")
     {
      g_day.status=what+" (not traded: "+reason+")";
      Journal(g_day.status);
      return;
     }
   string comment="ORB "+side+" r="+(string)(long)MathRound(risk/_Point);
   bool sent=buy?g_trade.Buy(lots,_Symbol,0.0,sl,tp,comment):g_trade.Sell(lots,_Symbol,0.0,sl,tp,comment);
   uint retcode=g_trade.ResultRetcode();
   if(sent && (retcode==TRADE_RETCODE_DONE || retcode==TRADE_RETCODE_PLACED))
     {
      g_day.status=side+" "+DoubleToString(lots,2)+" lots at "+PriceText(entry)+", SL "+PriceText(sl)+
                   (tp>0.0?", TP "+PriceText(tp):", no TP")+" (close at "+MinutesText(g_close_time)+" "+
                   ClockName()+")";
      Notify(g_day.status);
     }
   else
     {
      g_day.status=what+" (the order failed: "+g_trade.ResultRetcodeDescription()+")";
      Journal(g_day.status);
     }
  }

// Break entries: the chart price (bid) reaches the range high (low) plus
// the buffer.  Close entries: a closed Close_Timeframe candle that opened
// at or after the range end closed beyond it.
void CheckEntry()
  {
   if(g_day.state!=ORB_ARMED) return;
   datetime now=TimeCurrent();
   if(now>=g_day.last_entry)
     {
      SkipDay("no break before "+MinutesText(g_last_entry)+" "+ClockName());
      return;
     }
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0.0 || tick.ask<=0.0) return;
   double buffer=BreakoutBuffer();
   if(Entry_Mode==ORB_ENTRY_BREAK)
     {
      if(tick.bid>=g_day.high+buffer) Enter(1,tick);
      else if(tick.bid<=g_day.low-buffer) Enter(-1,tick);
      return;
     }
   datetime current=iTime(_Symbol,Close_Timeframe,0);
   if(current==0 || current==g_last_close_bar) return;
   g_last_close_bar=current;
   datetime opened=iTime(_Symbol,Close_Timeframe,1);
   if(opened<g_day.range_to) return;
   double close=iClose(_Symbol,Close_Timeframe,1);
   if(close>g_day.high+buffer) Enter(1,tick);
   else if(close<g_day.low-buffer) Enter(-1,tick);
  }

// ------------------------------------------------------------- exits
// Every tick: the position closes at the Close Time of the day it opened;
// before that, a partial close at Partial_Close_R moves the stop to
// breakeven.
void ManagePosition()
  {
   ulong ticket=0;
   if(!FindPosition(ticket)) return;
   datetime opened=(datetime)PositionGetInteger(POSITION_TIME);
   if(TimeCurrent()>=CloseTimeOf(opened))
     {
      if(g_trade.PositionClose(ticket)) Journal("position closed at the Close Time ("+MinutesText(g_close_time)+" "+
                                                ClockName()+")");
      else Print("ORB Strategy: closing the position failed - ",g_trade.ResultRetcodeDescription());
      return;
     }
   if(Partial_Close_R<=0.0) return;
   double open=PositionGetDouble(POSITION_PRICE_OPEN);
   double sl=PositionGetDouble(POSITION_SL);
   double tp=PositionGetDouble(POSITION_TP);
   double volume=PositionGetDouble(POSITION_VOLUME);
   double risk=CommentRisk(PositionGetString(POSITION_COMMENT));
   bool buy=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
   bool at_breakeven=sl>0.0 && (buy?sl>=open:sl<=open);
   if(at_breakeven || risk<=0.0 || ticket==g_breakeven_failed) return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick)) return;
   double progress=buy?tick.bid-open:open-tick.ask;
   if(ticket!=g_partial_ticket)
     {
      if(progress<Partial_Close_R*risk) return;
      double part=StepVolume(volume*Partial_Close_Percent/100.0);
      double minimum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
      if(part>=minimum && volume-part>=minimum)
        {
         if(!g_trade.PositionClosePartial(ticket,part))
           {
            Print("ORB Strategy: the partial close failed - ",g_trade.ResultRetcodeDescription());
            return;
           }
         Journal("closed "+DoubleToString(part,2)+" lots at "+DoubleToString(Partial_Close_R,2)+"R");
        }
      g_partial_ticket=ticket;
      if(!PositionSelectByTicket(ticket)) return;
     }
   // The stop to the entry once there is room for it.
   double room=buy?tick.bid-open:open-tick.ask;
   if(room<MinimumStopDistance()) return;
   if(!g_trade.PositionModify(ticket,open,tp))
     {
      g_breakeven_failed=ticket;
      Print("ORB Strategy: moving the stop to breakeven failed - ",g_trade.ResultRetcodeDescription());
     }
   else Journal("stop moved to breakeven at "+PriceText(open));
  }

// ------------------------------------------------------------- results
// The EA's closed positions on this symbol opened from `from`: a win has a
// positive net result (profit, swap and commission); R is the price move
// (volume-weighted over partial closes) over the initial risk stored in
// the entry's comment.
void ReadResults(ORB_RESULTS &r,const datetime from)
  {
   r.trades=0;
   r.wins=0;
   r.sum_r=0.0;
   r.r_trades=0;
   r.gross_profit=0.0;
   r.gross_loss=0.0;
   if(!HistorySelect(from,TimeCurrent()+86400)) return;
   long ids[];
   double opens[],risks[],volumes[],closed[],moves[],money[];
   bool buys[];
   int total=HistoryDealsTotal();
   for(int i=0;i<total;i++)
     {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0 || HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol ||
         (ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=Magic_Number) continue;
      long entry=HistoryDealGetInteger(deal,DEAL_ENTRY);
      long position=HistoryDealGetInteger(deal,DEAL_POSITION_ID);
      if(entry==DEAL_ENTRY_IN)
        {
         int n=ArraySize(ids);
         ArrayResize(ids,n+1,16);
         ArrayResize(opens,n+1,16);
         ArrayResize(risks,n+1,16);
         ArrayResize(volumes,n+1,16);
         ArrayResize(closed,n+1,16);
         ArrayResize(moves,n+1,16);
         ArrayResize(money,n+1,16);
         ArrayResize(buys,n+1,16);
         ids[n]=position;
         opens[n]=HistoryDealGetDouble(deal,DEAL_PRICE);
         risks[n]=CommentRisk(HistoryDealGetString(deal,DEAL_COMMENT));
         volumes[n]=HistoryDealGetDouble(deal,DEAL_VOLUME);
         closed[n]=0.0;
         moves[n]=0.0;
         money[n]=0.0;
         buys[n]=HistoryDealGetInteger(deal,DEAL_TYPE)==DEAL_TYPE_BUY;
         continue;
        }
      if(entry!=DEAL_ENTRY_OUT && entry!=DEAL_ENTRY_OUT_BY) continue;
      for(int k=ArraySize(ids)-1;k>=0;k--)
         if(ids[k]==position)
           {
            double price=HistoryDealGetDouble(deal,DEAL_PRICE);
            double volume=HistoryDealGetDouble(deal,DEAL_VOLUME);
            closed[k]+=volume;
            moves[k]+=(buys[k]?price-opens[k]:opens[k]-price)*volume;
            money[k]+=HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_SWAP)+
                      HistoryDealGetDouble(deal,DEAL_COMMISSION);
            break;
           }
     }
   for(int k=0;k<ArraySize(ids);k++)
     {
      if(volumes[k]<=0.0 || closed[k]<volumes[k]-1e-8) continue;    // still open
      r.trades++;
      if(money[k]>0.0)
        {
         r.wins++;
         r.gross_profit+=money[k];
        }
      else r.gross_loss-=money[k];
      if(risks[k]>0.0)
        {
         r.sum_r+=moves[k]/volumes[k]/risks[k];
         r.r_trades++;
        }
     }
  }

double WinRate(const ORB_RESULTS &r) { return r.trades>0?100.0*r.wins/r.trades:0.0; }
double AverageR(const ORB_RESULTS &r) { return r.r_trades>0?r.sum_r/r.r_trades:0.0; }
double ProfitFactor(const ORB_RESULTS &r)
  {
   if(r.gross_loss>0.0) return r.gross_profit/r.gross_loss;
   return r.gross_profit>0.0?99.0:0.0;
  }

string ResultsText(const ORB_RESULTS &r)
  {
   if(r.trades==0) return "no closed trades yet";
   return (string)r.trades+" trades, win rate "+DoubleToString(WinRate(r),1)+"%, average "+
          (AverageR(r)>=0.0?"+":"")+DoubleToString(AverageR(r),2)+"R, profit factor "+
          DoubleToString(ProfitFactor(r),2);
  }

// The Strategy Tester's "Custom max": the win rate counts only with at
// least Minimum_Trades trades and a positive average R, so the optimizer
// cannot buy win rate with a losing system.
double OnTester()
  {
   ORB_RESULTS r;
   ReadResults(r,0);
   if(r.trades<Minimum_Trades) return 0.0;
   if(Optimization_Criterion==ORB_CRITERION_EXPECTANCY) return AverageR(r);
   if(Optimization_Criterion==ORB_CRITERION_PROFIT_FACTOR) return ProfitFactor(r);
   return AverageR(r)>0.0?WinRate(r):0.0;
  }

// ------------------------------------------------------------- chart
const int PANEL_FONT_SIZE=10;
const int PANEL_ROW_HEIGHT=18;
const color PANEL_TEXT_COLOR=clrBlack;
const color RANGE_COLOR=clrDodgerBlue;

void PanelText(const string name,const int x,const int y,const string text,const color clr,const bool bold)
  {
   if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_LABEL,0,0,0)) return;
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,PANEL_FONT_SIZE);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetString(0,name,OBJPROP_FONT,bold?"Arial Bold":"Arial");
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,"\n");
  }

// Redrawn at most once a second.  The results are read from the deal
// history only at the start and after a position closes.
datetime g_panel_time=0;
bool g_panel_results=false;
bool g_panel_had_position=false;
ORB_RESULTS g_panel_run;
void DrawPanel()
  {
   if(!Show_Panel || !DrawingEnabled() || TimeCurrent()==g_panel_time) return;
   g_panel_time=TimeCurrent();
   string labels[6];
   string values[6];
   labels[0]="ORB Strategy";
   values[0]=_Symbol;
   labels[1]="Session:";
   values[1]="range "+MinutesText(g_range_start)+"-"+MinutesText(g_range_end)+", entries until "+
             MinutesText(g_last_entry)+", close "+MinutesText(g_close_time)+" ("+ClockName()+" time)";
   labels[2]="Range:";
   if(g_day.have_range)
     {
      values[2]=PriceText(g_day.low)+" - "+PriceText(g_day.high)+" ("+
                DoubleToString((g_day.high-g_day.low)/_Point,0)+" points";
      if(g_day.adr>0.0) values[2]+=", "+DoubleToString(100.0*(g_day.high-g_day.low)/g_day.adr,0)+"% of ADR";
      values[2]+=")";
     }
   else values[2]="-";
   labels[3]="Today:";
   values[3]=g_day.status;
   labels[4]="Position:";
   ulong ticket=0;
   bool has_position=FindPosition(ticket);
   if(has_position)
     {
      bool buy=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
      double tp=PositionGetDouble(POSITION_TP);
      values[4]=(buy?"buy ":"sell ")+DoubleToString(PositionGetDouble(POSITION_VOLUME),2)+" at "+
                PriceText(PositionGetDouble(POSITION_PRICE_OPEN))+", SL "+PriceText(PositionGetDouble(POSITION_SL))+
                (tp>0.0?", TP "+PriceText(tp):"");
     }
   else values[4]="none";
   labels[5]="Results:";
   if(!g_panel_results || (g_panel_had_position && !has_position))
     {
      ReadResults(g_panel_run,g_run_from);
      g_panel_results=true;
     }
   g_panel_had_position=has_position;
   values[5]=ResultsText(g_panel_run);
   for(int i=0;i<6;i++)
     {
      PanelText(g_prefix+"PANEL_"+(string)i,10,10+i*PANEL_ROW_HEIGHT,labels[i],PANEL_TEXT_COLOR,true);
      PanelText(g_prefix+"PANEL_"+(string)i+"_VALUE",110,10+i*PANEL_ROW_HEIGHT,values[i],PANEL_TEXT_COLOR,i==0);
     }
  }

void DrawRectangle(const string name,const datetime from,const datetime to,const double top,const double bottom)
  {
   if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_RECTANGLE,0,from,top,to,bottom)) return;
   ObjectMove(0,name,0,from,top);
   ObjectMove(0,name,1,to,bottom);
   ObjectSetInteger(0,name,OBJPROP_COLOR,RANGE_COLOR);
   ObjectSetInteger(0,name,OBJPROP_FILL,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,"\n");
  }

void DrawLevel(const string name,const datetime from,const datetime to,const double price,const color clr)
  {
   if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_TREND,0,from,price,to,price)) return;
   ObjectMove(0,name,0,from,price);
   ObjectMove(0,name,1,to,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DASH);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,"\n");
  }

// Today's range box and its break levels until the Close Time; the boxes
// of the last 30 session days stay on the chart (older ones are removed a
// week at a time, so weekends without a box leave nothing behind).
void DrawDay()
  {
   if(!Show_Ranges || !g_day.have_range) return;
   string id=g_prefix+"RANGE_"+TimeToString(g_day.day,TIME_DATE)+"_";
   DrawRectangle(id+"BOX",g_day.range_from,g_day.range_to,g_day.high,g_day.low);
   double buffer=BreakoutBuffer();
   DrawLevel(id+"HIGH",g_day.range_to,g_day.close_at,g_day.high+buffer,clrGreen);
   DrawLevel(id+"LOW",g_day.range_to,g_day.close_at,g_day.low-buffer,clrRed);
   for(int age=30;age<37;age++)
      ObjectsDeleteAll(0,g_prefix+"RANGE_"+TimeToString(g_day.day-age*86400,TIME_DATE)+"_");
  }

// ------------------------------------------------------------- events
string InputProblem()
  {
   if(g_range_start<0 || g_range_end<0 || g_last_entry<0 || g_close_time<0)
      return "the session times must be written HH:MM (00:00 to 23:59)";
   if(g_range_end<=g_range_start) return "Range_End must be after Range_Start";
   if(g_last_entry<=g_range_end) return "Last_Entry must be after Range_End";
   if(g_close_time<g_last_entry) return "Close_Time must be at or after Last_Entry";
   if(Server_GMT_Offset<-12 || Server_GMT_Offset>14) return "Server_GMT_Offset must be -12 to 14";
   if(Breakout_Buffer_Percent<0.0 || Max_Range_ADR_Percent<0.0 || Min_Stop_Spreads<0.0)
      return "the entry filters cannot be negative";
   if(Take_Profit_R<0.0 || Partial_Close_R<0.0) return "the take profit and partial close cannot be negative";
   if(Partial_Close_R>0.0 && Take_Profit_R>0.0 && Partial_Close_R>=Take_Profit_R)
      return "Partial_Close_R must be below Take_Profit_R";
   if(Partial_Close_Percent<=0.0 || Partial_Close_Percent>=100.0) return "Partial_Close_Percent must be above 0 and below 100";
   if(Risk_Percent<=0.0 || Risk_Percent>100.0) return "Risk_Percent must be above 0 and at most 100";
   if(Minimum_Trades<1) return "Minimum_Trades must be at least 1";
   return "";
  }

int OnInit()
  {
   g_range_start=ParseMinutes(Range_Start);
   g_range_end=ParseMinutes(Range_End);
   g_last_entry=ParseMinutes(Last_Entry);
   g_close_time=ParseMinutes(Close_Time);
   string problem=InputProblem();
   if(problem!="")
     {
      Print("ORB Strategy: invalid input - ",problem,".");
      return INIT_PARAMETERS_INCORRECT;
     }
   g_prefix="ORB_"+(string)ChartID()+"_";
   g_trade.SetExpertMagicNumber(Magic_Number);
   g_trade.SetDeviationInPoints(20);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trade.LogLevel(LOG_LEVEL_ERRORS);
   g_run_from=TimeCurrent();
   g_partial_ticket=0;
   g_breakeven_failed=0;
   g_last_journal="";
   g_panel_time=0;
   g_panel_results=false;
   g_panel_had_position=false;
   g_day.day=0;
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   ORB_RESULTS r;
   ReadResults(r,g_run_from);
   Print("ORB Strategy run summary (",_Symbol,"): ",ResultsText(r),".");
   ObjectsDeleteAll(0,g_prefix);
  }

void OnTick()
  {
   datetime now=TimeCurrent();
   if(now<=0) return;
   datetime day=DayStart(ServerToClock(now));
   if(day!=g_day.day) StartDay(day);
   if(TradingActive()) ManagePosition();
   if(g_day.state==ORB_WAITING && now>=g_day.range_to) BuildRange();
   CheckEntry();
   if(DrawingEnabled()) DrawPanel();
  }
