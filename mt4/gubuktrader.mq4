//+------------------------------------------------------------------+
//|                                      GubukTrader.mq4             |
//|                                      Copyright 2026, getbos      |
//|                                      https://www.mql5.com/getbos |
//+------------------------------------------------------------------+
#property copyright "Ringin Bambu © 2025, getbos"
#property link      "https://www.mql5.com/getbos"
#property version   "1.00"
#property strict
#property description "Robot Trading dengan sistem mengikuti sinyal Grafik Tabrani."
#property description "Menggunakan seluruh margin bebas untuk trading, cocok untuk BTCUSD."
#property description "Fitur: Panel kontrol dengan Start/Stop, Close All, Set SL, Update SL/TP, Trailing Stop."
#property description "Membuka posisi berdasarkan GT besar dan mendukung martingale."
#property description "PERINGATAN: EA ini hanya berlaku hingga 30 Agustus 2026."

//+------------------------------------------------------------------+
//| [1] Input Parameters                                             |
//+------------------------------------------------------------------+
input int MAGICMA = 123456;         // Magic Number
input double MarginUsage = 0.9;     // Persentase Margin Bebas yang Digunakan (90%)
input int StopLossPoints = 5000;    // Stop Loss Awal dalam Poin
input int TakeProfitPoints = 8000;  // Take Profit Awal dalam Poin
input double SLMultiplier = 1.1;    // Pengali SL untuk Martingale
input double TPMultiplier = 1.1;    // Pengali TP untuk Martingale
input int Slippage = 10;            // Slippage Maksimum dalam Poin
input int CandleSize = 50;          // Ukuran GT Minimum dalam Poin
input bool AlertON = true;          // Aktifkan Peringatan Suara
input double MartingaleMultiplier = 2.0; // Pengali Martingale untuk Lot
input int MaxMartingaleLevel = 10;  // Level Martingale Maksimum
input double MaxAbsoluteLot = 10.0; // Batas Maksimum Lot Absolut
input double EquityThreshold = 0.3; // Ambang Batas Ekuitas (30% dari saldo awal)
input int TrailingStopPoints = 2000;   // Jarak Trailing Stop dalam Poin
input int TrailingStartPoints = 1000;  // Keuntungan Minimum untuk Mulai Trailing Stop
input int TrailingStepPoints = 100;    // Langkah Minimum Pergeseran Trailing Stop
input int MaxRetryAttempts = 3;     // Jumlah Maksimum Percobaan OrderModify
input int RetryDelay = 100;         // Jeda antar Percobaan dalam Milidetik
input int DelayAfterSLTP = 50;      // Jeda setelah SL atau TP (dalam milidetik)

//+------------------------------------------------------------------+
//| [2] Global Variables                                             |
//+------------------------------------------------------------------+
datetime lastTradeTime = 0;
double myPoint;
int digits;
int martingaleLevel = 0;
double initialBalance = 0;
int lastOrderType = -1; // -1: tidak ada, 0: Sell, 1: Buy
int lastProcessedTicket = -1;
double positionSL[100], positionTP[100]; // Array untuk menyimpan SL/TP
int positionCount = 0;
int lastTicket = -1;
string lastPair = "";
double lastVolume = 0;
double lastProfit = 0;
double lastSL = 0;
double lastTP = 0;
bool eaActive = true;
bool trailingStopActive = true;
string panelName = "GubukTraderPanel";
string btnStartStop = "BtnStartStop";
string btnCloseAll = "BtnCloseAll";
string btnSetSL353 = "BtnSetSL353";
string btnSetSL11 = "BtnSetSL11";
string btnUpdateSLTP = "BtnUpdateSLTP";
string btnTrailingStop = "BtnTrailingStop";
string iconLabel = "IconLabel";

//+------------------------------------------------------------------+
//| [3] Expert initialization function                                |
//+------------------------------------------------------------------+
int OnInit()
{
   // Validasi tanggal kedaluwarsa
   datetime currentTime = TimeCurrent();
   datetime expirationDate = StrToTime("2026.08.30 23:59:59");
   if(currentTime > expirationDate)
   {
      Print("Error: EA ini telah kedaluwarsa! Tanggal kedaluwarsa: 30 Agustus 2026.");
      Alert("EA telah kedaluwarsa! Tanggal kedaluwarsa: 30 Agustus 2026");
      return(INIT_FAILED);
   }

   myPoint = Point;
   digits = (int)MarketInfo(Symbol(), MODE_DIGITS);
   initialBalance = AccountBalance();

   // Hapus objek GUI lama
   ObjectDelete(0, panelName);
   ObjectDelete(0, btnStartStop);
   ObjectDelete(0, btnCloseAll);
   ObjectDelete(0, btnSetSL353);
   ObjectDelete(0, btnSetSL11);
   ObjectDelete(0, btnUpdateSLTP);
   ObjectDelete(0, btnTrailingStop);
   ObjectDelete(0, iconLabel);
   string labels[] = {"OrderStatusLabel", "TicketLabel", "TypeLabel", "PairLabel", 
                      "VolumeLabel", "ProfitLabel", "EquityLabel", "SLLabel", "TPLabel",
                      "SpreadLabel", "WIBLabel", "ExpirationLabel", 
                      "OCLabel", "OHLabel", "OLLabel", "LHLabel", "CHLabel", "CLLabel"};
   for(int i = 0; i < ArraySize(labels); i++)
   {
      ObjectDelete(0, labels[i]);
      ObjectDelete(0, labels[i] + "_CellLabel");
      ObjectDelete(0, labels[i] + "_CellValue");
      ObjectDelete(0, labels[i] + "_Name");
   }

   // Buat panel kontrol
   if(!CreatePanel())
   {
      Print("Gagal membuat panel kontrol. EA dihentikan.");
      return(INIT_FAILED);
   }

   if(!IsTradeAllowed())
   {
      Print("Trading tidak diizinkan!");
      return(INIT_FAILED);
   }

   Print("Full Margin Bot diinisialisasi");
   Print("Saldo Awal: ", DoubleToString(initialBalance, 2), 
         ", Digit Simbol: ", digits, 
         ", Nilai Poin: ", DoubleToString(myPoint, digits));
   Print("EA berlaku hingga: ", CalculateDaysUntilExpiration());
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| [4] Expert deinitialization function                              |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   string labels[] = {"OrderStatusLabel", "TicketLabel", "TypeLabel", "PairLabel", 
                      "VolumeLabel", "ProfitLabel", "EquityLabel", "SLLabel", "TPLabel",
                      "SpreadLabel", "WIBLabel", "ExpirationLabel", 
                      "OCLabel", "OHLabel", "OLLabel", "LHLabel", "CHLabel", "CLLabel"};
   for(int i = 0; i < ArraySize(labels); i++)
   {
      ObjectDelete(0, labels[i]);
      ObjectDelete(0, labels[i] + "_CellLabel");
      ObjectDelete(0, labels[i] + "_CellValue");
      ObjectDelete(0, labels[i] + "_Name");
   }
   ObjectDelete(0, panelName);
   ObjectDelete(0, btnStartStop);
   ObjectDelete(0, btnCloseAll);
   ObjectDelete(0, btnSetSL353);
   ObjectDelete(0, btnSetSL11);
   ObjectDelete(0, btnUpdateSLTP);
   ObjectDelete(0, btnTrailingStop);
   ObjectDelete(0, iconLabel);
   Print("Full Margin Bot dinonaktifkan. Alasan: ", reason);
}

//+------------------------------------------------------------------+
//| [5] Expert tick function                                         |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!eaActive) return;

   CheckClosedOrders();
   Sleep(100);
   if(IsNewBar())
   {
      CheckAndOpenPosition(); // Panggil untuk membuka posisi baru setiap close GT
   }
   MonitorOpenOrders();
   UpdateFloatingProfit();
   UpdateGUILabels();
}

//+------------------------------------------------------------------+
//| [6] Function to calculate days until expiration                   |
//+------------------------------------------------------------------+
string CalculateDaysUntilExpiration()
{
   datetime currentTime = TimeCurrent();
   datetime expirationDate = StrToTime("2026.08.30 23:59:59");
   int daysLeft = (int)MathCeil((expirationDate - currentTime) / 86400);
   if(daysLeft > 0)
      return StringFormat("30 Agustus 2026 (%d hari lagi)", daysLeft);
   else if(daysLeft == 0)
      return "30 Agustus 2026 (Hari ini)";
   else
      return "30 Agustus 2026 (Sudah lewat)";
}

//+------------------------------------------------------------------+
//| [7] Function to calculate candle points                           |
//+------------------------------------------------------------------+
void CalculateCandlePoints(int &oc, int &oh, int &ol, int &lh, int &ch, int &cl, string &candleTime, int timeframe = PERIOD_CURRENT)
{
   double open = iOpen(Symbol(), timeframe, 1);
   double close = iClose(Symbol(), timeframe, 1);
   double high = iHigh(Symbol(), timeframe, 1);
   double low = iLow(Symbol(), timeframe, 1);
   
   if(open == 0 || close == 0 || high == 0 || low == 0)
   {
      Print("Error: Invalid price data for symbol ", Symbol(), " at timeframe ", timeframe);
      return;
   }
   
   oc = (int)((close - open) / myPoint);
   oh = (int)((high - open) / myPoint);
   ol = (int)((open - low) / myPoint);
   lh = (int)((high - low) / myPoint);
   ch = (int)((high - close) / myPoint);
   cl = (int)((close - low) / myPoint);
   
   candleTime = TimeToString(iTime(Symbol(), timeframe, 1) + 7 * 3600, TIME_DATE|TIME_MINUTES|TIME_SECONDS);
}

//+------------------------------------------------------------------+
//| [8] Function to calculate SL from balance percentage              |
//+------------------------------------------------------------------+
double CalculateSLFromBalance(double percentage)
{
   double balance = AccountBalance();
   double slValueUSD = balance * (percentage / 100.0);
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double slPoints = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MAGICMA && OrderSymbol() == Symbol())
         {
            double lotSize = OrderLots();
            slPoints = slValueUSD / (lotSize * tickValue);
            slPoints = NormalizeDouble(slPoints, 0);
            int stopLevel = (int)MarketInfo(Symbol(), MODE_STOPLEVEL);
            if(slPoints < stopLevel)
            {
               Print("SL terlalu kecil: ", slPoints, " poin. Menggunakan stop level minimum: ", stopLevel, " poin.");
               slPoints = stopLevel;
            }
            return slPoints;
         }
      }
   }
   Print("Tidak ada order terbuka untuk menghitung SL. Menggunakan SL default: ", StopLossPoints);
   return StopLossPoints;
}

//+------------------------------------------------------------------+
//| [9] Function to update SL for open orders                         |
//+------------------------------------------------------------------+
void UpdateOpenOrdersSL(double slPoints)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MAGICMA && OrderSymbol() == Symbol() && OrderType() <= OP_SELL)
         {
            double openPrice = OrderOpenPrice();
            double currentSL = OrderStopLoss();
            double currentTP = OrderTakeProfit();
            double newSL = 0;

            if(OrderType() == OP_BUY)
               newSL = NormalizeDouble(openPrice - slPoints * myPoint, digits);
            else if(OrderType() == OP_SELL)
               newSL = NormalizeDouble(openPrice + slPoints * myPoint, digits);

            if(MathAbs(currentSL - newSL) > myPoint)
            {
               if(ModifyOrderWithRetry(OrderTicket(), openPrice, newSL, currentTP))
               {
                  Print("SL diperbarui untuk order: ", OrderTicket(), ", SL baru: ", newSL);
                  if(AlertON) 
                  {
                     PlaySound("alert.wav");
                     Alert("SL diperbarui untuk order: ", OrderTicket());
                  }
               }
               else
               {
                  Print("Gagal memperbarui SL untuk order: ", OrderTicket());
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| [10] Function to create control panel                             |
//+------------------------------------------------------------------+
bool CreatePanel()
{
   Print("Memulai pembuatan panel kontrol...");

   // Buat panel background
   if(!ObjectCreate(0, panelName, OBJ_RECTANGLE_LABEL, 0, 0, 0))
   {
      Print("Gagal membuat panel background '", panelName, "'. Error: ", GetLastError());
      return false;
   }
   ObjectSetInteger(0, panelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, 30);
   ObjectSetInteger(0, panelName, OBJPROP_XSIZE, 350);
   ObjectSetInteger(0, panelName, OBJPROP_YSIZE, 600);
   ObjectSetInteger(0, panelName, OBJPROP_BGCOLOR, clrDarkSlateGray);
   ObjectSetInteger(0, panelName, OBJPROP_BORDER_TYPE, BORDER_RAISED);
   ObjectSetInteger(0, panelName, OBJPROP_BORDER_COLOR, clrSilver);
   ObjectSetString(0, panelName, OBJPROP_TOOLTIP, "Panel Kontrol Gubuk Trader Bot");
   Print("Panel background dibuat: ", panelName);

   // Daftar label untuk tabel
   string labels[] = {"OrderStatusLabel", "TicketLabel", "TypeLabel", "PairLabel",
                      "VolumeLabel", "ProfitLabel", "EquityLabel", "SLLabel", "TPLabel",
                      "SpreadLabel", "WIBLabel", "ExpirationLabel",
                      "OCLabel", "OHLabel", "OLLabel", "LHLabel", "CHLabel", "CLLabel"};
   string labelNames[] = {"Nama EA", "Ticket", "Tipe", "Pair", "Volume", "Profit",
                          "Ekuitas", "Stop Loss", "Take Profit", "Spread", "WIB",
                          "Kadaluwarsa", "Nilai", "Tinggi", "Rendah", "Jangkauan", "Atas", "Bawah"};
   string labelTooltips[] = {"Nama dan status EA saat ini", "Nomor tiket order terakhir",
                            "Tipe order terakhir", "Pasangan mata uang order",
                            "Volume order terakhir", "Profit order terakhir",
                            "Ekuitas akun", "Stop Loss order terakhir",
                            "Take Profit order terakhir", "Spread pasar saat ini",
                            "Waktu lokal (WIB)", "Tanggal kadaluwarsa EA",
                            "Jarak Open ke Close", "Jarak Open ke High",
                            "Jarak Open ke Low", "Jarak Low ke High",
                            "Jarak Close ke High", "Jarak Close ke Low"};
   int yDistances[] = {70, 90, 110, 130, 150, 170, 190, 210, 230, 250, 270, 290,
                       310, 330, 350, 370, 390, 410};

   // Buat sel tabel dan label
   for(int i = 0; i < ArraySize(labels); i++)
   {
      string cellNameLabel = labels[i] + "_CellLabel";
      if(!ObjectCreate(0, cellNameLabel, OBJ_RECTANGLE_LABEL, 0, 0, 0))
      {
         Print("Gagal membuat sel label '", cellNameLabel, "'. Error: ", GetLastError());
         return false;
      }
      ObjectSetInteger(0, cellNameLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, cellNameLabel, OBJPROP_XDISTANCE, 15);
      ObjectSetInteger(0, cellNameLabel, OBJPROP_YDISTANCE, yDistances[i]);
      ObjectSetInteger(0, cellNameLabel, OBJPROP_XSIZE, 130);
      ObjectSetInteger(0, cellNameLabel, OBJPROP_YSIZE, 20);
      ObjectSetInteger(0, cellNameLabel, OBJPROP_BGCOLOR, clrDarkSlateGray);
      ObjectSetInteger(0, cellNameLabel, OBJPROP_BORDER_TYPE, BORDER_RAISED);
      ObjectSetInteger(0, cellNameLabel, OBJPROP_BORDER_COLOR, clrSilver);
      Print("Sel label dibuat: ", cellNameLabel);

      string cellNameValue = labels[i] + "_CellValue";
      if(!ObjectCreate(0, cellNameValue, OBJ_RECTANGLE_LABEL, 0, 0, 0))
      {
         Print("Gagal membuat sel nilai '", cellNameValue, "'. Error: ", GetLastError());
         return false;
      }
      ObjectSetInteger(0, cellNameValue, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, cellNameValue, OBJPROP_XDISTANCE, 150);
      ObjectSetInteger(0, cellNameValue, OBJPROP_YDISTANCE, yDistances[i]);
      ObjectSetInteger(0, cellNameValue, OBJPROP_XSIZE, 190);
      ObjectSetInteger(0, cellNameValue, OBJPROP_YSIZE, 20);
      ObjectSetInteger(0, cellNameValue, OBJPROP_BGCOLOR, clrDarkSlateGray);
      ObjectSetInteger(0, cellNameValue, OBJPROP_BORDER_TYPE, BORDER_RAISED);
      ObjectSetInteger(0, cellNameValue, OBJPROP_BORDER_COLOR, clrSilver);
      Print("Sel nilai dibuat: ", cellNameValue);

      string labelName = labels[i] + "_Name";
      if(!ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0))
      {
         Print("Gagal membuat teks nama '", labelName, "'. Error: ", GetLastError());
         return false;
      }
      ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, yDistances[i] + 2);
      ObjectSetString(0, labelName, OBJPROP_TEXT, labelNames[i]);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
      ObjectSetString(0, labelName, OBJPROP_TOOLTIP, labelTooltips[i]);
      Print("Teks nama dibuat: ", labelName);

      if(!ObjectCreate(0, labels[i], OBJ_LABEL, 0, 0, 0))
      {
         Print("Gagal membuat teks nilai '", labels[i], "'. Error: ", GetLastError());
         return false;
      }
      ObjectSetInteger(0, labels[i], OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, labels[i], OBJPROP_XDISTANCE, 155);
      ObjectSetInteger(0, labels[i], OBJPROP_YDISTANCE, yDistances[i] + 2);
      ObjectSetInteger(0, labels[i], OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, labels[i], OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, labels[i], OBJPROP_FONT, "Arial");
      ObjectSetString(0, labels[i], OBJPROP_TOOLTIP, labelTooltips[i]);
      Print("Teks nilai dibuat: ", labels[i]);
   }

   // Inisialisasi teks awal untuk label
   bool success = true;
   success &= ObjectSetText("OrderStatusLabel", eaActive ? "Gubuk Trader Aktif" : "Gubuk Trader Nonaktif", 8, "Arial", clrWhite);
   success &= ObjectSetText("TicketLabel", "-", 8, "Arial", clrWhite);
   success &= ObjectSetText("TypeLabel", "Tidak ada", 8, "Arial", clrWhite);
   success &= ObjectSetText("PairLabel", "Tidak ada", 8, "Arial", clrWhite);
   success &= ObjectSetText("VolumeLabel", "0.00", 8, "Arial", clrWhite);
   success &= ObjectSetText("ProfitLabel", "0.00", 8, "Arial", clrWhite);
   success &= ObjectSetText("EquityLabel", StringFormat("%.2f", AccountEquity()), 8, "Arial", clrWhite);
   success &= ObjectSetText("SLLabel", "Tidak ada", 8, "Arial", clrWhite);
   success &= ObjectSetText("TPLabel", "Tidak ada", 8, "Arial", clrWhite);
   success &= ObjectSetText("SpreadLabel", StringFormat("%d poin", (int)MarketInfo(Symbol(), MODE_SPREAD)), 8, "Arial", clrWhite);
   success &= ObjectSetText("WIBLabel", TimeToString(TimeCurrent() + 7 * 3600, TIME_DATE|TIME_MINUTES|TIME_SECONDS), 8, "Arial", clrWhite);
   success &= ObjectSetText("ExpirationLabel", CalculateDaysUntilExpiration(), 8, "Arial", clrWhite);
   success &= ObjectSetText("OCLabel", "- poin", 8, "Arial", clrWhite);
   success &= ObjectSetText("OHLabel", "- poin", 8, "Arial", clrWhite);
   success &= ObjectSetText("OLLabel", "- poin", 8, "Arial", clrWhite);
   success &= ObjectSetText("LHLabel", "- poin", 8, "Arial", clrWhite);
   success &= ObjectSetText("CHLabel", "- poin", 8, "Arial", clrWhite);
   success &= ObjectSetText("CLLabel", "- poin", 8, "Arial", clrWhite);
   if(!success)
   {
      Print("Gagal mengatur teks awal untuk label tabel. Error: ", GetLastError());
      return false;
   }
   Print("Teks awal untuk label tabel diatur.");

   // Buat tombol Start/Stop
   if(!ObjectCreate(0, btnStartStop, OBJ_BUTTON, 0, 0, 0))
   {
      Print("Gagal membuat tombol '", btnStartStop, "'. Error: ", GetLastError());
      return false;
   }
   ObjectSetInteger(0, btnStartStop, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, btnStartStop, OBJPROP_XDISTANCE, 15);
   ObjectSetInteger(0, btnStartStop, OBJPROP_YDISTANCE, 440);
   ObjectSetInteger(0, btnStartStop, OBJPROP_XSIZE, 160);
   ObjectSetInteger(0, btnStartStop, OBJPROP_YSIZE, 30);
   ObjectSetString(0, btnStartStop, OBJPROP_TEXT, eaActive ? "Stop EA" : "Start EA");
   ObjectSetInteger(0, btnStartStop, OBJPROP_BGCOLOR, eaActive ? clrCrimson : clrLimeGreen);
   ObjectSetInteger(0, btnStartStop, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnStartStop, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, btnStartStop, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, btnStartStop, OBJPROP_ZORDER, 10);
   ObjectSetInteger(0, btnStartStop, OBJPROP_SELECTABLE, 1);
   ObjectSetInteger(0, btnStartStop, OBJPROP_SELECTED, 0);
   ObjectSetString(0, btnStartStop, OBJPROP_TOOLTIP, "Aktifkan atau nonaktifkan EA");
   Print("Tombol Start/Stop dibuat: ", btnStartStop);

   // Buat tombol Trailing Stop
   if(!ObjectCreate(0, btnTrailingStop, OBJ_BUTTON, 0, 0, 0))
   {
      Print("Gagal membuat tombol '", btnTrailingStop, "'. Error: ", GetLastError());
      return false;
   }
   ObjectSetInteger(0, btnTrailingStop, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, btnTrailingStop, OBJPROP_XDISTANCE, 185);
   ObjectSetInteger(0, btnTrailingStop, OBJPROP_YDISTANCE, 440);
   ObjectSetInteger(0, btnTrailingStop, OBJPROP_XSIZE, 160);
   ObjectSetInteger(0, btnTrailingStop, OBJPROP_YSIZE, 30);
   ObjectSetString(0, btnTrailingStop, OBJPROP_TEXT, trailingStopActive ? "Trailing Stop: ON" : "Trailing Stop: OFF");
   ObjectSetInteger(0, btnTrailingStop, OBJPROP_BGCOLOR, trailingStopActive ? clrLimeGreen : clrCrimson);
   ObjectSetInteger(0, btnTrailingStop, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnTrailingStop, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, btnTrailingStop, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, btnTrailingStop, OBJPROP_ZORDER, 10);
   ObjectSetInteger(0, btnTrailingStop, OBJPROP_SELECTABLE, 1);
   ObjectSetInteger(0, btnTrailingStop, OBJPROP_SELECTED, 0);
   ObjectSetString(0, btnTrailingStop, OBJPROP_TOOLTIP, "Aktifkan atau nonaktifkan Trailing Stop");
   Print("Tombol Trailing Stop dibuat: ", btnTrailingStop);

   // Buat tombol Close All
   if(!ObjectCreate(0, btnCloseAll, OBJ_BUTTON, 0, 0, 0))
   {
      Print("Gagal membuat tombol '", btnCloseAll, "'. Error: ", GetLastError());
      return false;
   }
   ObjectSetInteger(0, btnCloseAll, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, btnCloseAll, OBJPROP_XDISTANCE, 15);
   ObjectSetInteger(0, btnCloseAll, OBJPROP_YDISTANCE, 480);
   ObjectSetInteger(0, btnCloseAll, OBJPROP_XSIZE, 330);
   ObjectSetInteger(0, btnCloseAll, OBJPROP_YSIZE, 30);
   ObjectSetString(0, btnCloseAll, OBJPROP_TEXT, "Close All");
   ObjectSetInteger(0, btnCloseAll, OBJPROP_BGCOLOR, clrSlateGray);
   ObjectSetInteger(0, btnCloseAll, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnCloseAll, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, btnCloseAll, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, btnCloseAll, OBJPROP_ZORDER, 10);
   ObjectSetInteger(0, btnCloseAll, OBJPROP_SELECTABLE, 1);
   ObjectSetInteger(0, btnCloseAll, OBJPROP_SELECTED, 0);
   ObjectSetString(0, btnCloseAll, OBJPROP_TOOLTIP, "Tutup semua order dan order pending");
   Print("Tombol Close All dibuat: ", btnCloseAll);

   // Buat tombol Set SL 3.53%
   if(!ObjectCreate(0, btnSetSL353, OBJ_BUTTON, 0, 0, 0))
   {
      Print("Gagal membuat tombol '", btnSetSL353, "'. Error: ", GetLastError());
      return false;
   }
   ObjectSetInteger(0, btnSetSL353, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, btnSetSL353, OBJPROP_XDISTANCE, 15);
   ObjectSetInteger(0, btnSetSL353, OBJPROP_YDISTANCE, 520);
   ObjectSetInteger(0, btnSetSL353, OBJPROP_XSIZE, 160);
   ObjectSetInteger(0, btnSetSL353, OBJPROP_YSIZE, 30);
   ObjectSetString(0, btnSetSL353, OBJPROP_TEXT, "3.53%");
   ObjectSetInteger(0, btnSetSL353, OBJPROP_BGCOLOR, clrForestGreen);
   ObjectSetInteger(0, btnSetSL353, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnSetSL353, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, btnSetSL353, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, btnSetSL353, OBJPROP_ZORDER, 10);
   ObjectSetInteger(0, btnSetSL353, OBJPROP_SELECTABLE, 1);
   ObjectSetInteger(0, btnSetSL353, OBJPROP_SELECTED, 0);
   ObjectSetString(0, btnSetSL353, OBJPROP_TOOLTIP, "Atur Stop Loss ke 3.53% dari saldo akun");
   Print("Tombol Set SL 3.53% dibuat: ", btnSetSL353);

   // Buat tombol Set SL 11%
   if(!ObjectCreate(0, btnSetSL11, OBJ_BUTTON, 0, 0, 0))
   {
      Print("Gagal membuat tombol '", btnSetSL11, "'. Error: ", GetLastError());
      return false;
   }
   ObjectSetInteger(0, btnSetSL11, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, btnSetSL11, OBJPROP_XDISTANCE, 185);
   ObjectSetInteger(0, btnSetSL11, OBJPROP_YDISTANCE, 520);
   ObjectSetInteger(0, btnSetSL11, OBJPROP_XSIZE, 160);
   ObjectSetInteger(0, btnSetSL11, OBJPROP_YSIZE, 30);
   ObjectSetString(0, btnSetSL11, OBJPROP_TEXT, "11%");
   ObjectSetInteger(0, btnSetSL11, OBJPROP_BGCOLOR, clrOrangeRed);
   ObjectSetInteger(0, btnSetSL11, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnSetSL11, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, btnSetSL11, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, btnSetSL11, OBJPROP_ZORDER, 10);
   ObjectSetInteger(0, btnSetSL11, OBJPROP_SELECTABLE, 1);
   ObjectSetInteger(0, btnSetSL11, OBJPROP_SELECTED, 0);
   ObjectSetString(0, btnSetSL11, OBJPROP_TOOLTIP, "Atur Stop Loss ke 11% dari saldo akun");
   Print("Tombol Set SL 11% dibuat: ", btnSetSL11);

   // Buat tombol Ringin Bambu © 2026
   if(!ObjectCreate(0, btnUpdateSLTP, OBJ_BUTTON, 0, 0, 0))
   {
      Print("Gagal membuat tombol '", btnUpdateSLTP, "'. Error: ", GetLastError());
      return false;
   }
   ObjectSetInteger(0, btnUpdateSLTP, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, btnUpdateSLTP, OBJPROP_XDISTANCE, 15);
   ObjectSetInteger(0, btnUpdateSLTP, OBJPROP_YDISTANCE, 560);
   ObjectSetInteger(0, btnUpdateSLTP, OBJPROP_XSIZE, 330);
   ObjectSetInteger(0, btnUpdateSLTP, OBJPROP_YSIZE, 30);
   ObjectSetString(0, btnUpdateSLTP, OBJPROP_TEXT, "Ringin Bambu © 2026");
   ObjectSetInteger(0, btnUpdateSLTP, OBJPROP_BGCOLOR, clrRoyalBlue);
   ObjectSetInteger(0, btnUpdateSLTP, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, btnUpdateSLTP, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, btnUpdateSLTP, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, btnUpdateSLTP, OBJPROP_ZORDER, 10);
   ObjectSetInteger(0, btnUpdateSLTP, OBJPROP_SELECTABLE, 1);
   ObjectSetInteger(0, btnUpdateSLTP, OBJPROP_SELECTED, 0);
   ObjectSetString(0, btnUpdateSLTP, OBJPROP_TOOLTIP, "Tradernya lebih penting dari pada EAnya");
   Print("Tombol Update SL/TP dibuat: ", btnUpdateSLTP);

   Print("Panel kontrol berhasil dibuat.");
   ChartRedraw();
   return true;
}

//+------------------------------------------------------------------+
//| [11] Function to update GUI labels                                |
//+------------------------------------------------------------------+
void UpdateGUILabels()
{
   bool success = true;
   success &= ObjectSetText("OrderStatusLabel", eaActive ? "Gubuk Trader Aktif" : "Gubuk Trader Nonaktif", 8, "Arial", clrWhite);
   success &= ObjectSetText("TicketLabel", lastTicket == -1 ? "-" : IntegerToString(lastTicket), 8, "Arial", clrWhite);
   success &= ObjectSetText("TypeLabel", lastOrderType == -1 ? "Tidak ada" : (lastOrderType == OP_BUY ? "Buy" : "Sell"), 8, "Arial", clrWhite);
   success &= ObjectSetText("PairLabel", lastPair == "" ? "Tidak ada" : lastPair, 8, "Arial", clrWhite);
   success &= ObjectSetText("VolumeLabel", lastVolume == 0 ? "0.00" : DoubleToString(lastVolume, 2), 8, "Arial", clrWhite);
   success &= ObjectSetText("ProfitLabel", lastProfit == 0 ? "0.00" : DoubleToString(lastProfit, 2), 8, "Arial", clrWhite);
   success &= ObjectSetText("EquityLabel", StringFormat("%.2f", AccountEquity()), 8, "Arial", clrWhite);
   success &= ObjectSetText("SLLabel", lastSL == 0 ? "Tidak ada" : StringFormat("%.5f (%d poin)", lastSL, (int)(MathAbs(lastSL - (lastOrderType == OP_BUY ? Bid : Ask)) / myPoint)), 8, "Arial", clrWhite);
   success &= ObjectSetText("TPLabel", lastTP == 0 ? "Tidak ada" : StringFormat("%.5f (%d poin)", lastTP, (int)(MathAbs(lastTP - (lastOrderType == OP_BUY ? Bid : Ask)) / myPoint)), 8, "Arial", clrWhite);
   success &= ObjectSetText("SpreadLabel", StringFormat("%d poin", (int)MarketInfo(Symbol(), MODE_SPREAD)), 8, "Arial", clrWhite);
   success &= ObjectSetText("WIBLabel", TimeToString(TimeCurrent() + 7 * 3600, TIME_DATE|TIME_MINUTES|TIME_SECONDS), 8, "Arial", clrWhite);
   success &= ObjectSetText("ExpirationLabel", CalculateDaysUntilExpiration(), 8, "Arial", clrWhite);

   int oc, oh, ol, lh, ch, cl;
   string candleTime;
   CalculateCandlePoints(oc, oh, ol, lh, ch, cl, candleTime);
   success &= ObjectSetText("OCLabel", StringFormat("%d poin", oc), 8, "Arial", clrWhite);
   success &= ObjectSetText("OHLabel", StringFormat("%d poin", oh), 8, "Arial", clrWhite);
   success &= ObjectSetText("OLLabel", StringFormat("%d poin", ol), 8, "Arial", clrWhite);
   success &= ObjectSetText("LHLabel", StringFormat("%d poin", lh), 8, "Arial", clrWhite);
   success &= ObjectSetText("CHLabel", StringFormat("%d poin", ch), 8, "Arial", clrWhite);
   success &= ObjectSetText("CLLabel", StringFormat("%d poin", cl), 8, "Arial", clrWhite);

   if(!success)
   {
      Print("Gagal memperbarui label GUI. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| [12] Function to calculate SL and TP points                       |
//+------------------------------------------------------------------+
double CalculateSLPoints()
{
   double slPoints = StopLossPoints * MathPow(SLMultiplier, martingaleLevel);
   return slPoints;
}

double CalculateTPPoints()
{
   double tpPoints = TakeProfitPoints * MathPow(TPMultiplier, martingaleLevel);
   return tpPoints;
}

//+------------------------------------------------------------------+
//| [13] Function to check and open position on each candle close     |
//+------------------------------------------------------------------+
void CheckAndOpenPosition()
{
   if(!eaActive) return;
   if(!IsTradeAllowed()) return;

   // Periksa margin bebas
   double freeMargin = AccountFreeMargin();
   double lotSize = 0.01; // Lot tetap 0.01
   double contractSize = MarketInfo(Symbol(), MODE_LOTSIZE);
   double price = Ask;
   double leverage = AccountLeverage();
   double requiredMargin = (contractSize * lotSize * price) / leverage;

   if(freeMargin < requiredMargin)
   {
      Print("Margin bebas tidak cukup: ", DoubleToString(freeMargin, 2), 
            " < ", DoubleToString(requiredMargin, 2));
      if(AlertON)
      {
         PlaySound("alert.wav");
         Alert("Margin habis! Tidak dapat membuka posisi baru.");
      }
      return;
   }

   // Periksa volatilitas dengan ATR (opsional, untuk keamanan)
   double atr = iATR(Symbol(), PERIOD_M5, 14, 1);
   double avgAtr = iATR(Symbol(), PERIOD_M5, 14, 0);
   if(atr > avgAtr * 1.5)
   {
      Print("Volatilitas terlalu tinggi (ATR: ", DoubleToString(atr, digits), "). Menunda pembukaan posisi.");
      return;
   }

   // Validasi ukuran lot
   if(!CheckVolumeValue(lotSize))
   {
      Print("Ukuran lot tidak valid: ", DoubleToString(lotSize, 2));
      return;
   }

   // Hitung SL dan TP
   double currentSLPoints = CalculateSLPoints();
   double currentTPPoints = CalculateTPPoints();

   int stopLevel = (int)MarketInfo(Symbol(), MODE_STOPLEVEL);
   double spread = MarketInfo(Symbol(), MODE_SPREAD) * myPoint;
   if(currentSLPoints < stopLevel || currentTPPoints < stopLevel)
   {
      Print("SL/TP terlalu dekat dengan pasar. Stop Level Minimum: ", stopLevel, " poin");
      return;
   }

   // Tentukan arah berdasarkan candle sebelumnya
   double myOpen = iOpen(Symbol(), PERIOD_CURRENT, 1);
   double myClose = iClose(Symbol(), PERIOD_CURRENT, 1);

   if(myOpen < myClose) // Candle bullish
   {
      double price = Ask;
      double sl = NormalizeDouble(price - (currentSLPoints * myPoint), digits);
      double tp = NormalizeDouble(price + (currentTPPoints * myPoint), digits);

      if(MathAbs((price - sl) / myPoint) < stopLevel) sl = NormalizeDouble(price - (stopLevel * myPoint), digits);
      if(MathAbs((tp - price) / myPoint) < stopLevel) tp = NormalizeDouble(price + (stopLevel * myPoint), digits);

      int ticket = OrderSend(Symbol(), OP_BUY, lotSize, price, Slippage, sl, tp, 
                            "FM Buy Fixed Lot", MAGICMA, 0, clrGreen);
      if(ticket > 0)
      {
         SaveOrderSLTP(ticket, sl, tp);
         HandleOrderResult(ticket, price, sl, tp);
         lastOrderType = OP_BUY;
         lastTradeTime = iTime(Symbol(), PERIOD_CURRENT, 1); // Perbarui waktu perdagangan
         if(AlertON)
         {
            PlaySound("alert.wav");
            Alert("Posisi Buy dibuka pada close GT. Ticket: ", ticket, ", Lot: 0.01");
         }
      }
      else
      {
         Print("Gagal membuka posisi Buy. Error: ", GetLastError());
      }
   }
   else if(myOpen > myClose) // GT bearish
   {
      double price = Bid;
      double sl = NormalizeDouble(price + (currentSLPoints * myPoint), digits);
      double tp = NormalizeDouble(price - (currentTPPoints * myPoint), digits);

      if(MathAbs((sl - price) / myPoint) < stopLevel) sl = NormalizeDouble(price + (stopLevel * myPoint), digits);
      if(MathAbs((price - tp) / myPoint) < stopLevel) tp = NormalizeDouble(price - (stopLevel * myPoint), digits);
      if((tp + spread) > price) tp = NormalizeDouble(price - (stopLevel * myPoint) - spread, digits);

      int ticket = OrderSend(Symbol(), OP_SELL, lotSize, price, Slippage, sl, tp, 
                            "FM Sell Fixed Lot", MAGICMA, 0, clrRed);
      if(ticket > 0)
      {
         SaveOrderSLTP(ticket, sl, tp);
         HandleOrderResult(ticket, price, sl, tp);
         lastOrderType = OP_SELL;
         lastTradeTime = iTime(Symbol(), PERIOD_CURRENT, 1); // Perbarui waktu perdagangan
         if(AlertON)
         {
            PlaySound("alert.wav");
            Alert("Posisi Sell dibuka pada close GT. Ticket: ", ticket, ", Lot: 0.01");
         }
      }
      else
      {
         Print("Gagal membuka posisi Sell. Error: ", GetLastError());
      }
   }
   else
   {
      Print("GT doji (open = close). Tidak membuka posisi.");
   }
}

//+------------------------------------------------------------------+
//| [14] Function to place an instant order after SL                  |
//+------------------------------------------------------------------+
void PlacePendingOrder()
{
   if(!eaActive) return;
   if(OrdersTotal() > 0) return;
   if(!IsTradeAllowed()) return;

   double atr = iATR(Symbol(), PERIOD_M5, 14, 1);
   double avgAtr = iATR(Symbol(), PERIOD_M5, 14, 0);
   if(atr > avgAtr * 1.5)
   {
      Print("Volatilitas terlalu tinggi (ATR: ", DoubleToString(atr, digits), "). Menunda instant order.");
      return;
   }

   double currentLotSize = CalculateLotSize();
   if(!CheckVolumeValue(currentLotSize)) return;

   double currentSLPoints = CalculateSLPoints();
   double currentTPPoints = CalculateTPPoints();

   int stopLevel = (int)MarketInfo(Symbol(), MODE_STOPLEVEL);
   double spread = MarketInfo(Symbol(), MODE_SPREAD) * myPoint;
   if(currentSLPoints < stopLevel || currentTPPoints < stopLevel)
   {
      Print("SL/TP terlalu dekat dengan pasar. Stop Level Minimum: ", stopLevel, " poin");
      return;
   }

   int newOrderType = (lastOrderType == OP_SELL) ? OP_BUY : OP_SELL;

   if(newOrderType == OP_BUY)
   {
      double price = Ask;
      double sl = NormalizeDouble(price - (currentSLPoints * myPoint), digits);
      double tp = NormalizeDouble(price + (currentTPPoints * myPoint), digits);

      if(MathAbs((price - sl) / myPoint) < stopLevel) sl = NormalizeDouble(price - (stopLevel * myPoint), digits);
      if(MathAbs((tp - price) / myPoint) < stopLevel) tp = NormalizeDouble(price + (stopLevel * myPoint), digits);

      int ticket = OrderSend(Symbol(), OP_BUY, currentLotSize, price, Slippage, sl, tp, 
                            "GT Buy Lvl"+IntegerToString(martingaleLevel), MAGICMA, 0, clrGreen);
      if(ticket > 0)
      {
         SaveOrderSLTP(ticket, sl, tp);
         HandleOrderResult(ticket, price, sl, tp);
         lastOrderType = OP_BUY;
      }
      else
      {
         Print("Gagal menempatkan instant Buy. Error: ", GetLastError());
      }
   }
   else if(newOrderType == OP_SELL)
   {
      double price = Bid;
      double sl = NormalizeDouble(price + (currentSLPoints * myPoint), digits);
      double tp = NormalizeDouble(price - (currentTPPoints * myPoint), digits);

      if(MathAbs((sl - price) / myPoint) < stopLevel) sl = NormalizeDouble(price + (stopLevel * myPoint), digits);
      if(MathAbs((price - tp) / myPoint) < stopLevel) tp = NormalizeDouble(price - (stopLevel * myPoint), digits);
      if((tp + spread) > price) tp = NormalizeDouble(price - (stopLevel * myPoint) - spread, digits);

      int ticket = OrderSend(Symbol(), OP_SELL, currentLotSize, price, Slippage, sl, tp, 
                            "GT Sell Lvl"+IntegerToString(martingaleLevel), MAGICMA, 0, clrRed);
      if(ticket > 0)
      {
         SaveOrderSLTP(ticket, sl, tp);
         HandleOrderResult(ticket, price, sl, tp);
         lastOrderType = OP_SELL;
      }
      else
      {
         Print("Gagal menempatkan instant Sell. Error: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| [15] Function to place an instant order after TP                  |
//+------------------------------------------------------------------+
void PlaceOrderAfterTP()
{
   if(!eaActive) return;
   if(OrdersTotal() > 0) return;
   if(!IsTradeAllowed()) return;

   double atr = iATR(Symbol(), PERIOD_M5, 14, 1);
   double avgAtr = iATR(Symbol(), PERIOD_M5, 14, 0);
   if(atr > avgAtr * 1.5)
   {
      Print("Volatilitas terlalu tinggi (ATR: ", DoubleToString(atr, digits), "). Menunda instant order setelah TP.");
      return;
   }

   double currentLotSize = CalculateLotSize();
   if(!CheckVolumeValue(currentLotSize)) return;

   double currentSLPoints = CalculateSLPoints();
   double currentTPPoints = CalculateTPPoints();

   int stopLevel = (int)MarketInfo(Symbol(), MODE_STOPLEVEL);
   double spread = MarketInfo(Symbol(), MODE_SPREAD) * myPoint;
   if(currentSLPoints < stopLevel || currentTPPoints < stopLevel)
   {
      Print("SL/TP terlalu dekat dengan pasar. Stop Level Minimum: ", stopLevel, " poin");
      return;
   }

   if(lastOrderType == OP_BUY)
   {
      double price = Ask;
      double sl = NormalizeDouble(price - (currentSLPoints * myPoint), digits);
      double tp = NormalizeDouble(price + (currentTPPoints * myPoint), digits);

      if(MathAbs((price - sl) / myPoint) < stopLevel) sl = NormalizeDouble(price - (stopLevel * myPoint), digits);
      if(MathAbs((tp - price) / myPoint) < stopLevel) tp = NormalizeDouble(price + (stopLevel * myPoint), digits);

      int ticket = OrderSend(Symbol(), OP_BUY, currentLotSize, price, Slippage, sl, tp, 
                            "GT Buy Lvl"+IntegerToString(martingaleLevel), MAGICMA, 0, clrGreen);
      if(ticket > 0)
      {
         SaveOrderSLTP(ticket, sl, tp);
         HandleOrderResult(ticket, price, sl, tp);
         lastOrderType = OP_BUY;
      }
      else
      {
         Print("Gagal menempatkan instant Buy setelah TP. Error: ", GetLastError());
      }
   }
   else if(lastOrderType == OP_SELL)
   {
      double price = Bid;
      double sl = NormalizeDouble(price + (currentSLPoints * myPoint), digits);
      double tp = NormalizeDouble(price - (currentTPPoints * myPoint), digits);

      if(MathAbs((sl - price) / myPoint) < stopLevel) sl = NormalizeDouble(price + (stopLevel * myPoint), digits);
      if(MathAbs((price - tp) / myPoint) < stopLevel) tp = NormalizeDouble(price - (stopLevel * myPoint), digits);
      if((tp + spread) > price) tp = NormalizeDouble(price - (stopLevel * myPoint) - spread, digits);

      int ticket = OrderSend(Symbol(), OP_SELL, currentLotSize, price, Slippage, sl, tp, 
                            "GT Sell Lvl"+IntegerToString(martingaleLevel), MAGICMA, 0, clrRed);
      if(ticket > 0)
      {
         SaveOrderSLTP(ticket, sl, tp);
         HandleOrderResult(ticket, price, sl, tp);
         lastOrderType = OP_SELL;
      }
      else
      {
         Print("Gagal menempatkan instant Sell setelah TP. Error: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| [16] Function to save SL/TP of an order                          |
//+------------------------------------------------------------------+
void SaveOrderSLTP(int ticket, double sl, double tp)
{
   positionSL[positionCount % 100] = sl;
   positionTP[positionCount % 100] = tp;
   positionCount++;
}

//+------------------------------------------------------------------+
//| [17] Function to get SL/TP of an order                           |
//+------------------------------------------------------------------+
bool GetOrderSLTP(int ticket, double &sl, double &tp)
{
   for(int i = 0; i < positionCount; i++)
   {
      if(i == ticket % 100)
      {
         sl = positionSL[i];
         tp = positionTP[i];
         for(int j = i; j < positionCount - 1; j++)
         {
            positionSL[j] = positionSL[j + 1];
            positionTP[j] = positionTP[j + 1];
         }
         positionCount--;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| [18] Function to modify order with retry mechanism               |
//+------------------------------------------------------------------+
bool ModifyOrderWithRetry(int ticket, double openPrice, double sl, double tp)
{
   int stopLevel = (int)MarketInfo(Symbol(), MODE_STOPLEVEL);
   double currentPrice = (OrderType() == OP_BUY) ? Bid : Ask;
   double adjustedSL = sl;
   double adjustedTP = tp;

   for(int attempt = 1; attempt <= MaxRetryAttempts; attempt++)
   {
      if(OrderType() == OP_BUY)
      {
         double slDistance = MathAbs((currentPrice - sl) / myPoint);
         double tpDistance = MathAbs((currentPrice - tp) / myPoint);
         if(slDistance < stopLevel)
         {
            adjustedSL = NormalizeDouble(openPrice - (stopLevel * myPoint), digits);
         }
         if(tpDistance < stopLevel)
         {
            adjustedTP = NormalizeDouble(openPrice + (stopLevel * myPoint), digits);
         }
      }
      else if(OrderType() == OP_SELL)
      {
         double slDistance = MathAbs((currentPrice - sl) / myPoint);
         double tpDistance = MathAbs((currentPrice - tp) / myPoint);
         if(slDistance < stopLevel)
         {
            adjustedSL = NormalizeDouble(openPrice + (stopLevel * myPoint), digits);
         }
         if(tpDistance < stopLevel)
         {
            adjustedTP = NormalizeDouble(openPrice - (stopLevel * myPoint), digits);
         }
      }

      if(OrderSelect(ticket, SELECT_BY_TICKET) && OrderModify(ticket, openPrice, adjustedSL, adjustedTP, 0, clrBlack))
      {
         return true;
      }
      else
      {
         Print("Percobaan ke-", attempt, " gagal memodifikasi order. Ticket: ", ticket, 
               " Error: ", GetLastError());
         Sleep(RetryDelay);
         currentPrice = (OrderType() == OP_BUY) ? Bid : Ask;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| [19] Function to monitor open orders                              |
//+------------------------------------------------------------------+
void MonitorOpenOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MAGICMA && OrderSymbol() == Symbol())
         {
            double sl = OrderStopLoss();
            double tp = OrderTakeProfit();
            if(sl == 0 || tp == 0)
            {
               double actualOpen = OrderOpenPrice();
               double currentSLPoints = CalculateSLPoints();
               double currentTPPoints = CalculateTPPoints();
               double newSL, newTP;

               if(OrderType() == OP_BUY)
               {
                  newSL = NormalizeDouble(actualOpen - (currentSLPoints * myPoint), digits);
                  newTP = NormalizeDouble(actualOpen + (currentTPPoints * myPoint), digits);
                  if(ModifyOrderWithRetry(OrderTicket(), actualOpen, newSL, newTP))
                  {
                     Print("SL/TP berhasil disetel untuk Buy. Ticket: ", OrderTicket());
                  }
                  else
                  {
                     Print("Gagal menutup order Buy. Ticket: ", OrderTicket(), ", Error: ", GetLastError());
                  }
               }
               else if(OrderType() == OP_SELL)
               {
                  newSL = NormalizeDouble(actualOpen + (currentSLPoints * myPoint), digits);
                  newTP = NormalizeDouble(actualOpen - (currentTPPoints * myPoint), digits);
                  if(ModifyOrderWithRetry(OrderTicket(), actualOpen, newSL, newTP))
                  {
                     Print("SL/TP berhasil disetel untuk Sell. Ticket: ", OrderTicket());
                  }
                  else
                  {
                     Print("Gagal menutup order Sell. Ticket: ", OrderTicket(), ", Error: ", GetLastError());
                  }
               }
            }
         }
      }
   }
   ApplyTrailingStop();
}

//+------------------------------------------------------------------+
//| [20] Function to update floating profit for open orders           |
//+------------------------------------------------------------------+
void UpdateFloatingProfit()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MAGICMA && OrderSymbol() == Symbol())
         {
            double currentProfit = OrderProfit() + OrderSwap() + OrderCommission();
            double openPrice = OrderOpenPrice();
            double sl = OrderStopLoss();
            double tp = OrderTakeProfit();
            double volume = OrderLots();
            string pair = OrderSymbol();
            int ticket = OrderTicket();

            lastTicket = ticket;
            lastPair = pair;
            lastVolume = volume;
            lastProfit = currentProfit;
            lastSL = sl;
            lastTP = tp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| [21] Function to handle order execution result                    |
//+------------------------------------------------------------------+
void HandleOrderResult(int ticket, double openPrice, double sl, double tp)
{
   if(ticket > 0)
   {
      lastTradeTime = iTime(Symbol(), PERIOD_CURRENT, 1);
      
      if(OrderSelect(ticket, SELECT_BY_TICKET))
      {
         lastTicket = ticket;
         lastPair = Symbol();
         lastVolume = OrderLots();
         lastProfit = OrderProfit() + OrderSwap() + OrderCommission();
         lastSL = sl;
         lastTP = tp;
         
         UpdateGUILabels();

         if(AlertON)
         {
            PlaySound("alert.wav");
            Alert("Gubuk Trader Aktif - Posisi dibuka! Level: ", 
                  martingaleLevel, " Ticket: ", ticket,
                  ", Pair: ", lastPair,
                  ", Volume: ", DoubleToString(lastVolume, 2),
                  ", Harga Buka: ", DoubleToString(openPrice, digits),
                  ", Profit: ", DoubleToString(lastProfit, 2),
                  ", Ekuitas: ", DoubleToString(AccountEquity(), 2),
                  ", SL: ", DoubleToString(sl, digits),
                  ", TP: ", DoubleToString(tp, digits));
         }
         Print("Gubuk Trader Aktif - Posisi dibuka. Ticket: ", ticket,
               ", Level: ", martingaleLevel,
               ", Pair: ", lastPair,
               ", Volume: ", DoubleToString(lastVolume, 2),
               ", Harga Buka: ", DoubleToString(openPrice, digits),
               ", Profit: ", DoubleToString(lastProfit, 2),
               ", Ekuitas: ", DoubleToString(AccountEquity(), 2),
               ", SL: ", DoubleToString(sl, digits),
               ", TP: ", DoubleToString(tp, digits));
      }
      else
      {
         Print("Gagal memilih order. Ticket: ", ticket, ", Error: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| [22] Function to check closed orders                              |
//+------------------------------------------------------------------+
void CheckClosedOrders()
{
   static bool processedInThisTick = false;
   if(processedInThisTick) return;

   int latestTicket = -1;
   datetime latestCloseTime = 0;

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderMagicNumber() == MAGICMA && OrderSymbol() == Symbol() && 
            OrderCloseTime() > lastTradeTime && OrderTicket() != lastProcessedTicket)
         {
            if(OrderCloseTime() > latestCloseTime)
            {
               latestCloseTime = OrderCloseTime();
               latestTicket = OrderTicket();
            }
         }
      }
   }

   if(latestTicket != -1 && OrderSelect(latestTicket, SELECT_BY_TICKET, MODE_HISTORY))
   {
      lastTradeTime = OrderCloseTime();
      lastProcessedTicket = latestTicket;

      lastTicket = OrderTicket();
      lastPair = OrderSymbol();
      lastVolume = OrderLots();
      lastProfit = OrderProfit() + OrderSwap() + OrderCommission();
      lastSL = OrderStopLoss();
      lastTP = OrderTakeProfit();

      double totalProfit = lastProfit;
      double closePrice = OrderClosePrice();
      double openPrice = OrderOpenPrice();
      double slPrice = lastSL;
      double tpPrice = lastTP;

      bool hitSL = false;
      bool hitTP = false;

      if(OrderType() == OP_BUY)
      {
         if(slPrice != 0 && closePrice <= slPrice) hitSL = true;
         else if(tpPrice != 0 && closePrice >= tpPrice) hitTP = true;
      }
      else if(OrderType() == OP_SELL)
      {
         if(slPrice != 0 && closePrice >= slPrice) hitSL = true;
         else if(tpPrice != 0 && closePrice <= tpPrice) hitTP = true;
      }

      UpdateGUILabels();

      Print("Order ditutup. Ticket: ", lastTicket,
            ", Tipe: ", (OrderType() == OP_BUY ? "Buy" : "Sell"),
            ", Pair: ", lastPair,
            ", Volume: ", DoubleToString(lastVolume, 2),
            ", Profit: ", DoubleToString(totalProfit, 2),
            ", Ekuitas: ", DoubleToString(AccountEquity(), 2),
            ", Harga Buka: ", DoubleToString(openPrice, digits),
            ", Harga Tutup: ", DoubleToString(closePrice, digits),
            ", SL: ", DoubleToString(slPrice, digits),
            ", TP: ", DoubleToString(tpPrice, digits),
            ", SL Tercapai: ", (hitSL ? "Ya" : "Tidak"),
            ", TP Tercapai: ", (hitTP ? "Ya" : "Tidak"),
            ", Level Martingale: ", martingaleLevel);

      if(AlertON)
      {
         PlaySound("alert.wav");
         Alert("Gubuk Trader Aktif - Order ditutup. Ticket: ", lastTicket,
               ", Tipe: ", (OrderType() == OP_BUY ? "Buy" : "Sell"),
               ", Pair: ", lastPair,
               ", Volume: ", DoubleToString(lastVolume, 2),
               ", Profit: ", DoubleToString(totalProfit, 2),
               ", Ekuitas: ", DoubleToString(AccountEquity(), 2),
               ", SL: ", DoubleToString(slPrice, digits),
               ", TP: ", DoubleToString(tpPrice, digits));
      }

      if(hitSL)
      {
         double currentEquity = AccountEquity();
         double equityThresholdValue = initialBalance * EquityThreshold;
         if(martingaleLevel < MaxMartingaleLevel && currentEquity > equityThresholdValue)
         {
            martingaleLevel++; // Tingkatkan level martingale untuk SL/TP
            Print("Order mencapai SL. Level Martingale ditingkatkan ke: ", martingaleLevel);
         }
         else
         {
            martingaleLevel = 0;
            lastOrderType = -1;
            Print("Order mencapai SL. Mereset Martingale ke: ", martingaleLevel, 
                  ", Ekuitas: ", DoubleToString(currentEquity, 2), 
                  ", Ambang Batas Ekuitas: ", DoubleToString(equityThresholdValue, 2));
         }
      }
      else if(hitTP || totalProfit > 0)
      {
         martingaleLevel = 0; // Reset martingale untuk SL/TP
         Print("Order mencapai TP atau profit. Mereset Martingale ke: ", martingaleLevel);
      }
      else
      {
         martingaleLevel = 0;
         lastOrderType = -1;
         Print("Order ditutup manual. Mereset Martingale ke: ", martingaleLevel);
      }
      processedInThisTick = true;
   }
   processedInThisTick = false;
}

//+------------------------------------------------------------------+
//| [23] Function to calculate lot size                               |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double lot = 0.01; // Lot tetap 0.01
   lot = NormalizeLotSize(lot);
   
   Print("Ukuran lot tetap: ", DoubleToString(lot, 2));
   return lot;
}


//+------------------------------------------------------------------+
//| [24] Function to apply trailing stop                             |
//+------------------------------------------------------------------+
void ApplyTrailingStop()
{
   if(!trailingStopActive) return;
   static datetime lastAlertTime = 0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MAGICMA && OrderSymbol() == Symbol() && OrderType() <= OP_SELL)
         {
            double currentPrice = (OrderType() == OP_BUY) ? Bid : Ask;
            double openPrice = OrderOpenPrice();
            double currentSL = OrderStopLoss();
            double newSL = currentSL;
            int ticket = OrderTicket();
            string orderTypeStr = (OrderType() == OP_BUY) ? "Buy" : "Sell";

            double profitPoints = 0;
            if(OrderType() == OP_BUY)
               profitPoints = (currentPrice - openPrice) / myPoint;
            else if(OrderType() == OP_SELL)
               profitPoints = (openPrice - currentPrice) / myPoint;

            if(profitPoints >= TrailingStartPoints)
            {
               if(OrderType() == OP_BUY)
               {
                  newSL = NormalizeDouble(currentPrice - TrailingStopPoints * myPoint, digits);
                  if(newSL > currentSL + TrailingStepPoints * myPoint)
                  {
                     if(ModifyOrderWithRetry(ticket, openPrice, newSL, OrderTakeProfit()))
                     {
                        Print("Trailing Stop diperbarui untuk Buy. Ticket: ", ticket, ", SL Baru: ", newSL);
                        if(AlertON && TimeCurrent() - lastAlertTime >= 300)
                        {
                           PlaySound("alert.wav");
                           Alert("Gubuk Trader Aktif - Trailing Stop Buy diperbarui! Ticket: ", ticket,
                                 ", Pair: ", Symbol(),
                                 ", Volume: ", DoubleToString(OrderLots(), 2),
                                 ", SL Baru: ", DoubleToString(newSL, digits),
                                 ", Profit: ", DoubleToString(OrderProfit() + OrderSwap() + OrderCommission(), 2),
                                 ", Ekuitas: ", DoubleToString(AccountEquity(), 2));
                           lastAlertTime = TimeCurrent();
                        }
                        lastSL = newSL;
                     }
                     else
                     {
                        Print("Gagal memperbarui Trailing Stop untuk Buy. Ticket: ", ticket, ", Error: ", GetLastError());
                     }
                  }
               }
               else if(OrderType() == OP_SELL)
               {
                  newSL = NormalizeDouble(currentPrice + TrailingStopPoints * myPoint, digits);
                  if(currentSL == 0 || newSL < currentSL - TrailingStepPoints * myPoint)
                  {
                     if(ModifyOrderWithRetry(ticket, openPrice, newSL, OrderTakeProfit()))
                     {
                        Print("Trailing Stop diperbarui untuk Sell. Ticket: ", ticket, ", SL Baru: ", newSL);
                        if(AlertON && TimeCurrent() - lastAlertTime >= 300)
                        {
                           PlaySound("alert.wav");
                           Alert("Gubuk Trader Aktif - Trailing Stop Sell diperbarui! Ticket: ", ticket,
                                 ", Pair: ", Symbol(),
                                 ", Volume: ", DoubleToString(OrderLots(), 2),
                                 ", SL Baru: ", DoubleToString(newSL, digits),
                                 ", Profit: ", DoubleToString(OrderProfit() + OrderSwap() + OrderCommission(), 2),
                                 ", Ekuitas: ", DoubleToString(AccountEquity(), 2));
                           lastAlertTime = TimeCurrent();
                        }
                        lastSL = newSL;
                     }
                     else
                     {
                        Print("Gagal memperbarui Trailing Stop untuk Sell. Ticket: ", ticket, ", Error: ", GetLastError());
                     }
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| [25] Function to close all orders and pending orders              |
//+------------------------------------------------------------------+
void CloseAllOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MAGICMA && OrderSymbol() == Symbol())
         {
            if(OrderType() <= OP_SELL)
            {
               double closePrice = OrderType() == OP_BUY ? Bid : Ask;
               if(!OrderClose(OrderTicket(), OrderLots(), closePrice, Slippage, clrRed))
               {
                  Print("Gagal menutup order. Ticket: ", OrderTicket(), ", Error: ", GetLastError());
                  if(AlertON) Alert("Gagal menutup order. Ticket: ", OrderTicket(), ", Error: ", GetLastError());
               }
               else
               {
                  Print("Order ditutup. Ticket: ", OrderTicket());
               }
            }
            else
            {
               if(!OrderDelete(OrderTicket()))
               {
                  Print("Gagal menghapus order pending. Ticket: ", OrderTicket(), ", Error: ", GetLastError());
                  if(AlertON) Alert("Gagal menghapus order pending. Ticket: ", OrderTicket(), ", Error: ", GetLastError());
               }
               else
               {
                  Print("Order pending dihapus. Ticket: ", OrderTicket());
               }
            }
         }
      }
   }
   martingaleLevel = 0;
   lastOrderType = -1;
   lastTicket = -1;
   lastPair = "";
   lastVolume = 0.0;
   lastProfit = 0.0;
   lastSL = 0.0;
   lastTP = 0.0;
   positionCount = 0;
   ArrayFill(positionSL, 0, 100, 0);
   ArrayFill(positionTP, 0, 100, 0);
   UpdateGUILabels();
   Print("Semua order ditutup. Level Martingale direset ke: ", martingaleLevel);
   if(AlertON) Alert("Semua order ditutup. Level Martingale direset.");
}

//+------------------------------------------------------------------+
//| [26] Helper functions                                            |
//+------------------------------------------------------------------+
double NormalizeLotSize(double lots)
{
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   
   double normalized = MathRound(lots / lotStep) * lotStep;
   normalized = MathMin(MathMax(normalized, minLot), MathMin(maxLot, MaxAbsoluteLot));
   
   if(normalized >= MaxAbsoluteLot)
   {
      Print("Peringatan: Ukuran lot mencapai batas maksimum absolut: ", DoubleToString(MaxAbsoluteLot, 2));
      if(AlertON) Alert("Ukuran lot maksimum tercapai: ", DoubleToString(MaxAbsoluteLot, 2));
   }
   return normalized;
}

bool CheckVolumeValue(double volume)
{
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   
   if(volume < minLot || volume > maxLot || volume > MaxAbsoluteLot)
   {
      Print("Ukuran lot tidak valid: ", DoubleToString(volume, 2));
      return false;
   }
   return true;
}

bool IsNewBar()
{
   static datetime lastBar = 0;
   datetime currentBar = iTime(Symbol(), PERIOD_CURRENT, 0);
   if(currentBar != lastBar)
   {
      lastBar = currentBar;
      return true;
   }
   return false;
}


//+------------------------------------------------------------------+
//| [27] Chart event handler                                         |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   Print("Event terdeteksi: ID=", id, ", sparam=", sparam);
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      Print("Klik objek terdeteksi: sparam=", sparam);
      if(sparam == btnStartStop)
      {
         eaActive = !eaActive;
         ObjectSetInteger(0, btnStartStop, OBJPROP_STATE, 0);
         ObjectSetString(0, btnStartStop, OBJPROP_TEXT, eaActive ? "Stop EA" : "Start EA");
         ObjectSetInteger(0, btnStartStop, OBJPROP_BGCOLOR, eaActive ? clrCrimson : clrLimeGreen);
         ObjectSetText("OrderStatusLabel", eaActive ? "Gubuk Trader Aktif" : "Gubuk Trader Nonaktif", 8, "Arial", clrWhite);
         Print("EA ", eaActive ? "diaktifkan" : "dinonaktifkan");
         if(AlertON) Alert("EA ", eaActive ? "diaktifkan" : "dinonaktifkan");
         ObjectSetInteger(0, btnStartStop, OBJPROP_BGCOLOR, clrYellow);
         Sleep(200);
         ObjectSetInteger(0, btnStartStop, OBJPROP_BGCOLOR, eaActive ? clrCrimson : clrLimeGreen);
      }
      else if(sparam == btnCloseAll)
      {
         ObjectSetInteger(0, btnCloseAll, OBJPROP_BGCOLOR, clrYellow);
         CloseAllOrders();
         ObjectSetInteger(0, btnCloseAll, OBJPROP_STATE, 0);
         Print("Perintah Close All dieksekusi");
         if(AlertON) Alert("Perintah Close All dieksekusi");
         Sleep(200);
         ObjectSetInteger(0, btnCloseAll, OBJPROP_BGCOLOR, clrSlateGray);
      }
      else if(sparam == btnSetSL353)
      {
         double slPoints = CalculateSLFromBalance(3.53);
         UpdateOpenOrdersSL(slPoints);
         ObjectSetInteger(0, btnSetSL353, OBJPROP_STATE, 0);
         Print("Stop Loss diatur ke 3.53% dari saldo: ", slPoints, " poin");
         if(AlertON) Alert("Stop Loss diatur ke 3.53% dari saldo: ", slPoints, " poin");
         ObjectSetInteger(0, btnSetSL353, OBJPROP_BGCOLOR, clrYellow);
         Sleep(200);
         ObjectSetInteger(0, btnSetSL353, OBJPROP_BGCOLOR, clrForestGreen);
      }
            else if(sparam == btnSetSL11)
      {
         double slPoints = CalculateSLFromBalance(11.0);
         UpdateOpenOrdersSL(slPoints);
         ObjectSetInteger(0, btnSetSL11, OBJPROP_STATE, 0);
         Print("Stop Loss diatur ke 11% dari saldo: ", slPoints, " poin");
         if(AlertON) 
         {
            PlaySound("alert.wav");
            Alert("Stop Loss diatur ke 11% dari saldo: ", slPoints, " poin");
         }
         ObjectSetInteger(0, btnSetSL11, OBJPROP_BGCOLOR, clrYellow);
         Sleep(200);
         ObjectSetInteger(0, btnSetSL11, OBJPROP_BGCOLOR, clrOrangeRed);
      }
      else if(sparam == btnUpdateSLTP)
      {
         MonitorOpenOrders();
         ObjectSetInteger(0, btnUpdateSLTP, OBJPROP_STATE, 0);
         Print("SL/TP diperbarui untuk order yang sedang berjalan");
         if(AlertON) 
         {
            PlaySound("alert.wav");
            Alert("SL/TP diperbarui untuk order yang sedang berjalan");
         }
         ObjectSetInteger(0, btnUpdateSLTP, OBJPROP_BGCOLOR, clrYellow);
         Sleep(200);
         ObjectSetInteger(0, btnUpdateSLTP, OBJPROP_BGCOLOR, clrRoyalBlue);
      }
      else if(sparam == btnTrailingStop)
      {
         trailingStopActive = !trailingStopActive;
         ObjectSetInteger(0, btnTrailingStop, OBJPROP_STATE, 0);
         ObjectSetString(0, btnTrailingStop, OBJPROP_TEXT, trailingStopActive ? "Trailing Stop: ON" : "Trailing Stop: OFF");
         ObjectSetInteger(0, btnTrailingStop, OBJPROP_BGCOLOR, trailingStopActive ? clrLimeGreen : clrCrimson);
         Print("Trailing Stop ", trailingStopActive ? "diaktifkan" : "dinonaktifkan");
         if(AlertON) 
         {
            PlaySound("alert.wav");
            Alert("Trailing Stop ", trailingStopActive ? "diaktifkan" : "dinonaktifkan");
         }
         ObjectSetInteger(0, btnTrailingStop, OBJPROP_BGCOLOR, clrYellow);
         Sleep(200);
         ObjectSetInteger(0, btnTrailingStop, OBJPROP_BGCOLOR, trailingStopActive ? clrLimeGreen : clrCrimson);
      }
   }
}
