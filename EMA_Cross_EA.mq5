//+------------------------------------------------------------------+
//|                                              EMA_Cross_EA.mq5 |
//|                                                                  |
//| Created by: @toz-panzmoravy                                      |
//| GitHub: https://github.com/toz-panzmoravy                        |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      "https://github.com/toz-panzmoravy"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

// Input parameters
input int      EMA_Fast_Period = 6;    // Fast EMA Period
input int      EMA_Slow_Period = 12;   // Slow EMA Period
input double   LotSize = 0.85;          // Trading lot size
input int      StopLoss = 100;         // Stop Loss in points
input int      TakeProfit = 200;       // Take Profit in points
input int      MFI_Period = 14;        // MFI period
input double   MFI_Low = 30.0;         // MFI low threshold
input double   MFI_High = 70.0;        // MFI high threshold

// Global variables
CTrade trade;                          // Trading object
int EMA_Fast_Handle;
int EMA_Slow_Handle;
int MFI_Handle;
double EMA_Fast_Buffer[];
double EMA_Slow_Buffer[];
double MFI_Buffer[];
bool isLongPosition = false;
bool isShortPosition = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize EMA indicators
    EMA_Fast_Handle = iMA(_Symbol, PERIOD_CURRENT, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
    EMA_Slow_Handle = iMA(_Symbol, PERIOD_CURRENT, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
    MFI_Handle = iMFI(_Symbol, PERIOD_CURRENT, MFI_Period, VOLUME_TICK);
    
    if(EMA_Fast_Handle == INVALID_HANDLE || EMA_Slow_Handle == INVALID_HANDLE || MFI_Handle == INVALID_HANDLE)
    {
        Print("Error creating indicators!");
        return(INIT_FAILED);
    }
    
    // Allocate memory for indicator buffers
    ArraySetAsSeries(EMA_Fast_Buffer, true);
    ArraySetAsSeries(EMA_Slow_Buffer, true);
    ArraySetAsSeries(MFI_Buffer, true);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release indicator handles
    IndicatorRelease(EMA_Fast_Handle);
    IndicatorRelease(EMA_Slow_Handle);
    IndicatorRelease(MFI_Handle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Copy indicator values
    CopyBuffer(EMA_Fast_Handle, 0, 0, 3, EMA_Fast_Buffer);
    CopyBuffer(EMA_Slow_Handle, 0, 0, 3, EMA_Slow_Buffer);
    CopyBuffer(MFI_Handle, 0, 0, 3, MFI_Buffer);
    
    // Check for open positions
    if(PositionsTotal() == 0)
    {
        // BUY ENTRY: EMA cross up, MFI low and rising
        if(EMA_Fast_Buffer[1] > EMA_Slow_Buffer[1] && EMA_Fast_Buffer[2] <= EMA_Slow_Buffer[2]
           && MFI_Buffer[1] <= MFI_Low && MFI_Buffer[1] > MFI_Buffer[2])
        {
            OpenLongPosition();
        }
        // SELL ENTRY: EMA cross down, MFI high and falling
        else if(EMA_Fast_Buffer[1] < EMA_Slow_Buffer[1] && EMA_Fast_Buffer[2] >= EMA_Slow_Buffer[2]
           && MFI_Buffer[1] >= MFI_High && MFI_Buffer[1] < MFI_Buffer[2])
        {
            OpenShortPosition();
        }
    }
    else
    {
        // Check for exit conditions based on MFI
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket))
            {
                // Close BUY if MFI is high and falling
                if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                {
                    if(MFI_Buffer[1] >= MFI_High && MFI_Buffer[1] < MFI_Buffer[2])
                    {
                        ClosePosition(ticket);
                    }
                }
                // Close SELL if MFI is low and rising
                else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                {
                    if(MFI_Buffer[1] <= MFI_Low && MFI_Buffer[1] > MFI_Buffer[2])
                    {
                        ClosePosition(ticket);
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Open long position                                               |
//+------------------------------------------------------------------+
void OpenLongPosition()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double sl = ask - StopLoss * _Point;
    double tp = ask + TakeProfit * _Point;
    
    trade.Buy(LotSize, _Symbol, ask, sl, tp, "EMA+MFI Cross Long");
}

//+------------------------------------------------------------------+
//| Open short position                                              |
//+------------------------------------------------------------------+
void OpenShortPosition()
{
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = bid + StopLoss * _Point;
    double tp = bid - TakeProfit * _Point;
    
    trade.Sell(LotSize, _Symbol, bid, sl, tp, "EMA+MFI Cross Short");
}

//+------------------------------------------------------------------+
//| Close position                                                   |
//+------------------------------------------------------------------+
void ClosePosition(ulong ticket)
{
    trade.PositionClose(ticket);
} 