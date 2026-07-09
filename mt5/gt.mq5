//+------------------------------------------------------------------+
//|                                               GrafikTabranij.mq5 |
//|                                 Copyright 2026, MOCHAMAD TABRANI |
//|                                          https://cindo.pages.dev |
//+------------------------------------------------------------------+
#property copyright   "MOCHAMAD TABRANI (c) 2026, Ringin Bambu"
#property link        "https://cindo.pages.dev"
#property version     "0.01"
#property description "EA GT Trading - Komando Profit & Keamanan"
#property description "========================================================"
#property description "EA Trading ini beroperasi berdasarkan Sinyal GT Besar."
#property description "Didesain spesifik untuk volatilitas tinggi (BTCUSD, XAUUSD, GOLDmicro)."

//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Enum & Types                                                     |
//+------------------------------------------------------------------+
enum ENUM_THEME
{
    THEME_ONYX_GOLD,   // Classic Onyx & Gold
    THEME_NEON_BLUE,   // Cyberpunk Cyan
    THEME_MATRIX,      // Retro Green
    THEME_PURE_DARK    // Minimalist Grey
};

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+

//--- System Information
input string          _s0                  = "================= EA GT TRADING ================="; 
sinput string         Info_System          = "EA GT Trading "; 
sinput string         Info_Version         = "v0.01 [Grafik Tabranij]"; 
sinput string         Info_Author          = "MOCHAMAD TABRANI";                  
sinput string         Info_Support         = "cindo.pages.dev";   

//--- Dashboard Layout
input string          _s1                  = "================= DASHBOARD GEOMETRY =================";
input int             X_Offset             = 20;       // Horizontal Offset (Pixels)
input int             Y_Offset             = 40;       // Vertical Offset (Pixels)
input int             Panel_Width          = 600;      // Total Dashboard Width

//--- Trading Engine Settings
input string          _s2                  = "================= GRAFIK TABRANIJ ALGO STRATEGY =================";
input ENUM_TIMEFRAMES InpGTTimeframe       = PERIOD_H1;     // GT Besar Timeframe/durasi (Signal Basis)
input double          InpLot               = 0.01;          // Base Lot Volume
input double          InpMultiplier        = 2.0;           // Martingale Volume Multiplier
input int             InpMaxSteps          = 5;             // Max Martingale Iterations
input int             InpTP                = 300;           // Take Profit Distance (Points)
input int             InpSL                = 150;           // Stop Loss Distance (Points)
input int             InpMagic             = 888999;        // Algorithm Serial ID

//--- Theme & Color Settings
input string          _s5                  = "================= UI THEME & PALETTE =================";
input ENUM_THEME      InpTheme             = THEME_ONYX_GOLD;   // Active Visual Theme
input color           Label_Color          = clrGold;           // Primary Label Color
input color           Value_Color          = clrWhite;          // Numerical Value Color
input color           Live_Color           = C'255,225,100';    // Real-time Accent Color

//--- Chart Visualization
input string          _s6                  = "================= CHART VISUALIZATION =================";
input bool            InpShowGTChart       = true;              // Plot GT Mathematical Levels
input int             InpLevelWidth        = 1;                 // Level Line Thickness
input ENUM_LINE_STYLE InpLevelStyle        = STYLE_SOLID;       // Level Line Pattern
input bool            InpShowLabels        = true;              // Display Level Descriptions

//+------------------------------------------------------------------+
//| [2] Global Variables                                             |
//+------------------------------------------------------------------+
double   myPoint;
int      myDigits;
datetime lastBarTime = 0;
CTrade   trade;

// Sequential State Machine
double   g_lastLot      = 0;  // Volume dari posisi terakhir yang ditutup
int      g_lastDeal      = -1; // Ticket deal terakhir yang telah diproses
bool     g_isFirstTrade = true; // Flag untuk perdagangan pertama

#define PREFIX          "GUBUKTRADER"
#define COLOR_BG        C'10,10,10'    // Jet Black
#define COLOR_STRIPE    C'18,18,18'    // Subtle Stripe
#define COLOR_HDR_BG    C'35,35,35'    // Slate
#define COLOR_SUCCESS   C'0,255,140'   // Emerald
#define COLOR_DANGER    C'255,80,90'   // Ruby
#define COLOR_SILVER    C'180,180,180' // Muted Silver

#define ROW_H           30
#define FONT_MAIN       "Segoe UI"
#define FONT_SIZE       10
#define COLOR_COUNTDOWN C'255,200,50'   // Amber Gold (Countdown)
#define VIS_PREFIX      "GT_VIS_"

// Global State for UI Tabs
enum ENUM_TABS {
    TAB_DASHBOARD,
    TAB_ABOUT,
    TAB_TRADING,
    TAB_COLORS,
    TAB_VISUAL
};
ENUM_TABS currTab = TAB_DASHBOARD;

// Global Color Theme Variables
color gClrBg, gClrHdr, gClrStripe, gClrLabel, gClrValue, gClrAccent, gClrSuccess, gClrDanger;

// Runtime Modifiable Settings (Mirrored from Inputs)
ENUM_THEME   extTheme;
bool         extShowGTChart;

// Wall-clock synchronization
long         serverLocalOffset = 0;

void ApplyTheme()
{
   switch(extTheme)
   {
      case THEME_NEON_BLUE:
         gClrBg      = C'5,15,25';
         gClrHdr     = C'20,40,60';
         gClrStripe  = C'10,25,45';
         gClrLabel   = clrCyan;
         gClrValue   = clrWhite;
         gClrAccent  = clrDeepSkyBlue;
         gClrSuccess = clrSpringGreen;
         gClrDanger  = clrDeepPink;
         break;
      case THEME_MATRIX:
         gClrBg      = C'0,10,0';
         gClrHdr     = C'0,30,0';
         gClrStripe  = C'5,20,5';
         gClrLabel   = clrLimeGreen;
         gClrValue   = clrLime;
         gClrAccent  = clrGreen;
         gClrSuccess = clrWhite;
         gClrDanger  = clrRed;
         break;
      case THEME_PURE_DARK:
         gClrBg      = C'15,15,15';
         gClrHdr     = C'25,25,25';
         gClrStripe  = C'20,20,20';
         gClrLabel   = clrLightGray;
         gClrValue   = clrWhite;
         gClrAccent  = clrGray;
         gClrSuccess = clrAliceBlue;
         gClrDanger  = clrIndianRed;
         break;
      case THEME_ONYX_GOLD:
      default:
         gClrBg      = COLOR_BG;
         gClrHdr     = COLOR_HDR_BG;
         gClrStripe  = COLOR_STRIPE;
         gClrLabel   = Label_Color;
         gClrValue   = Value_Color;
         gClrAccent  = clrGold;
         gClrSuccess = COLOR_SUCCESS;
         gClrDanger  = COLOR_DANGER;
         break;
   }
}

//+------------------------------------------------------------------+
//| [3] Expert initialization function                               |
//+------------------------------------------------------------------+
int OnInit()
{
   myPoint  = _Point;
   myDigits = _Digits;
   
   extTheme = InpTheme;
   extShowGTChart = InpShowGTChart;
   
   // Calculate offset between Server Time and Local Machine Time
   serverLocalOffset = (long)TimeCurrent() - (long)TimeLocal();

   ApplyTheme();
   DeleteAllObjects();

   if(!CreateDashboard())
   {
      Print("Gagal membuat Quad-Bar Dashboard.");
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(InpMagic);
   EventSetTimer(1); // Update countdown setiap 1 detik
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { EventKillTimer(); DeleteAllObjects(); DeleteVisualization(); }
void OnTick()                    
{ 
   UpdateGUILabels(); 
   
   // Sequential State Machine - check every tick for empty position
   ExecuteTradingLogic();
   
   if(extShowGTChart) DrawGTLevels();
}
void OnTimer()                   { UpdateCountdown(); }

void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      // Tab Switching Logic
      if(sparam == PREFIX + "TAB_DB") { currTab = TAB_DASHBOARD; ResetDashboard(); }
      else if(sparam == PREFIX + "TAB_AB") { currTab = TAB_ABOUT;     ResetDashboard(); }
      else if(sparam == PREFIX + "TAB_TR") { currTab = TAB_TRADING;   ResetDashboard(); }
      else if(sparam == PREFIX + "TAB_CL") { currTab = TAB_COLORS;    ResetDashboard(); }
      else if(sparam == PREFIX + "TAB_VS") { currTab = TAB_VISUAL;    ResetDashboard(); }
      
      // Theme Switching Logic (from Colors Tab)
      else if(sparam == PREFIX + "THM_ONYX")  { extTheme = THEME_ONYX_GOLD; ApplyTheme(); ResetDashboard(); }
      else if(sparam == PREFIX + "THM_NEON")  { extTheme = THEME_NEON_BLUE; ApplyTheme(); ResetDashboard(); }
      else if(sparam == PREFIX + "THM_MATRIX") { extTheme = THEME_MATRIX;    ApplyTheme(); ResetDashboard(); }
      else if(sparam == PREFIX + "THM_DARK")   { extTheme = THEME_PURE_DARK;  ApplyTheme(); ResetDashboard(); }
      
      // Visual Toggles
      else if(sparam == PREFIX + "TOG_CHART") { extShowGTChart = !extShowGTChart; if(!extShowGTChart) DeleteVisualization(); ResetDashboard(); }
      
      // (No object-based logic in GubukTrader mode)
   }
}


bool IsNewBar()
{
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| [6] GUI Functions                                                |
//+------------------------------------------------------------------+
void DeleteAllObjects()
{
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, PREFIX) == 0) ObjectDelete(0, name);
   }
}

void DeleteVisualization()
{
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, VIS_PREFIX) == 0) ObjectDelete(0, name);
   }
}

void DrawGTLevels()
{
   double open  = iOpen(_Symbol, PERIOD_CURRENT, 0);
   double close = iClose(_Symbol, PERIOD_CURRENT, 0);
   double high  = iHigh(_Symbol, PERIOD_CURRENT, 0);
   double low   = iLow(_Symbol, PERIOD_CURRENT, 0);
   
   if(open == 0) return;

   double bH = MathMax(open, close), bL = MathMin(open, close);
   
   DrawHLine(VIS_PREFIX + "Tinggi", high,  gClrAccent, STYLE_DOT);
   DrawHLine(VIS_PREFIX + "Rendah", low,   gClrAccent, STYLE_DOT);
   DrawHLine(VIS_PREFIX + "Atas",   bH,    gClrLabel,  STYLE_SOLID);
   DrawHLine(VIS_PREFIX + "Bawah",  bL,    gClrLabel,  STYLE_SOLID);
   DrawHLine(VIS_PREFIX + "Awal",   open,  clrSilver,  STYLE_DASH);
   DrawHLine(VIS_PREFIX + "Inti",   close, gClrValue,  STYLE_SOLID, 2);
}

void DrawHLine(string name, double price, color clr, ENUM_LINE_STYLE style, int width = 1)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   else
      ObjectSetDouble(0, name, OBJPROP_PRICE, price);
      
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, InpLevelStyle == STYLE_SOLID ? style : InpLevelStyle);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width == 1 ? InpLevelWidth : width);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   if(InpShowLabels)
      ObjectSetString(0, name, OBJPROP_TEXT, " " + StringSubstr(name, StringLen(VIS_PREFIX)));
   else
      ObjectSetString(0, name, OBJPROP_TEXT, "");
}

bool CreateRect(string name, int x, int y, int w, int h, color bg, color border = clrNONE)
{
   if(!ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0)) return false;
   ObjectSetInteger(0, name, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,   x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,   y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,       w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,       h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,     bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   if(border != clrNONE) ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_BACK,        false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,  false);
   return true;
}

bool CreateLabel(string name, int x, int y, string text, color clr, int size = FONT_SIZE, string font = FONT_MAIN, ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER)
{
   if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0)) return false;
   ObjectSetInteger(0, name, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT,       text);
   ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  size);
   ObjectSetString(0, name, OBJPROP_FONT,       font);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR,    anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   return true;
}

void CreateQuadBarRow(string prefix, int y, string label)
{
   int textY = y + 8;
   int dataStart = 90; // Maximum proximity
   int colW      = (Panel_Width - dataStart) / 4;
   
   // Label column
   CreateLabel(prefix + "_lbl", X_Offset + 20, textY, label, gClrLabel);
   
   // 4 Value Columns (Ultra-Compact)
   CreateLabel(prefix + "_v3", X_Offset + dataStart + colW,     textY, "-", gClrValue, 9, FONT_MAIN, ANCHOR_RIGHT_UPPER);
   CreateLabel(prefix + "_v2", X_Offset + dataStart + colW*2,   textY, "-", gClrValue, 9, FONT_MAIN, ANCHOR_RIGHT_UPPER);
   CreateLabel(prefix + "_v1", X_Offset + dataStart + colW*3,   textY, "-", gClrValue, 9, FONT_MAIN, ANCHOR_RIGHT_UPPER);
   CreateLabel(prefix + "_v0", X_Offset + dataStart + colW*4,   textY, "-", gClrAccent,  9, FONT_MAIN, ANCHOR_RIGHT_UPPER);
}

void ResetDashboard() { DeleteAllObjects(); CreateDashboard(); }

bool CreateDashboard()
{
   int y = Y_Offset;
   int totalH = (currTab == TAB_DASHBOARD) ? 515 : 410;

   CreateRect(PREFIX + "Main", X_Offset, y, Panel_Width, totalH, gClrBg, clrDimGray);
   CreateCornerBrackets(X_Offset - 2, y - 2, Panel_Width + 4, totalH + 4, 15, gClrAccent);
   
   // Tab Navigation Bar
   int tabW = (Panel_Width - 20) / 5;
   int tabX = X_Offset + 10;
   int tabY = y + 10;
   
   CreateTabButton(PREFIX + "TAB_DB", tabX + (tabW/2),       tabY, tabW, 25, "DASHBOARD", currTab == TAB_DASHBOARD);
   CreateTabButton(PREFIX + "TAB_AB", tabX + (tabW + tabW/2), tabY, tabW, 25, "ABOUT",     currTab == TAB_ABOUT);
   CreateTabButton(PREFIX + "TAB_TR", tabX + (tabW*2 + tabW/2), tabY, tabW, 25, "TRADING",   currTab == TAB_TRADING);
   CreateTabButton(PREFIX + "TAB_CL", tabX + (tabW*3 + tabW/2), tabY, tabW, 25, "COLORS",    currTab == TAB_COLORS);
   CreateTabButton(PREFIX + "TAB_VS", tabX + (tabW*4 + tabW/2), tabY, tabW, 25, "VISUAL",    currTab == TAB_VISUAL);

   y += 45;
   
   if(currTab == TAB_DASHBOARD) CreateDashboardTab(y);
   else if(currTab == TAB_ABOUT) CreateAboutTab(y);
   else if(currTab == TAB_TRADING) CreateTradingTab(y);
   else if(currTab == TAB_COLORS) CreateColorsTab(y);
   else if(currTab == TAB_VISUAL) CreateVisualTab(y);

   ChartRedraw();
   return true;
}

void CreateDashboardTab(int y)
{
   // Header Area
   int centerX = X_Offset + (Panel_Width / 2);
   CreateRect(PREFIX + "Hdr", X_Offset + 4, y, Panel_Width - 8, 45, gClrHdr);
   CreateLabel(PREFIX + "Title", centerX, y + 15, "GT", gClrAccent, 11, FONT_MAIN, ANCHOR_CENTER);
   y += 50;
   
   // Column Titles
   int dataStart = 90;
   int colW      = (Panel_Width - dataStart) / 4;
   CreateLabel(PREFIX + "C3", X_Offset + dataStart + colW,     y, "[ GT3 ]", clrAqua, 8, FONT_MAIN, ANCHOR_RIGHT_UPPER);
   CreateLabel(PREFIX + "C2", X_Offset + dataStart + colW*2,   y, "[ GT2 ]", clrAqua, 8, FONT_MAIN, ANCHOR_RIGHT_UPPER);
   CreateLabel(PREFIX + "C1", X_Offset + dataStart + colW*3,   y, "[ GT1 ]", clrAqua, 8, FONT_MAIN, ANCHOR_RIGHT_UPPER);
   CreateLabel(PREFIX + "C0", X_Offset + dataStart + colW*4,   y, "[ LIVE ]", gClrAccent, 8, FONT_MAIN, ANCHOR_RIGHT_UPPER);
   CreateLabel(PREFIX + "CountdownIcon", X_Offset + dataStart + colW*4 - 55, y + 14, "p", COLOR_COUNTDOWN, 9, "Webdings", ANCHOR_RIGHT_UPPER);
   CreateLabel(PREFIX + "Countdown", X_Offset + dataStart + colW*4, y + 13, "00:00:00", COLOR_COUNTDOWN, 8, FONT_MAIN, ANCHOR_RIGHT_UPPER);
   y += 30;

   CreateQuadBarRow(PREFIX + "R_OH",    y, "Tinggi");    y += ROW_H;
   CreateQuadBarRow(PREFIX + "R_CH",    y, "Atas");      y += ROW_H;
   CreateQuadBarRow(PREFIX + "R_CL",    y, "Bawah");     y += ROW_H;
   CreateQuadBarRow(PREFIX + "R_OL",    y, "Rendah");    y += ROW_H;
   CreateQuadBarRow(PREFIX + "R_Awal",  y, "Awal");      y += ROW_H;
   CreateQuadBarRow(PREFIX + "R_OC",    y, "Neto");     y += ROW_H;
   CreateQuadBarRow(PREFIX + "R_LH",    y, "Inti");      y += ROW_H;
   CreateQuadBarRow(PREFIX + "R_Range", y, "Jangkauan"); y += ROW_H + 5;

   UpdateInfoSectionOnDashboard(y);
}

void UpdateInfoSectionOnDashboard(int y)
{
   CreateRect(PREFIX + "InfoBg", X_Offset + 4, y, Panel_Width - 8, 135, gClrStripe);
   int infoY = y + 10;
   
   // Row 1: Balance & Equity
   CreateLabel(PREFIX + "Acc_Bal", X_Offset + 20, infoY, "Saldo:", gClrLabel, 8);
   CreateLabel(PREFIX + "Acc_BalVal", X_Offset + 130, infoY, "0.00", gClrValue, 8);
   CreateLabel(PREFIX + "Acc_Eq", X_Offset + Panel_Width/2, infoY, "Equity:", gClrLabel, 8);
   CreateLabel(PREFIX + "Acc_EqVal", X_Offset + Panel_Width - 20, infoY, "0.00", gClrValue, 8, FONT_MAIN, ANCHOR_RIGHT_UPPER);
   
   // Row 2: Spread & Symbol P/L
   infoY += 22;
   CreateLabel(PREFIX + "Sym_Spread", X_Offset + 20, infoY, "Spread:", gClrLabel, 8);
   CreateLabel(PREFIX + "Sym_SpreadVal", X_Offset + 130, infoY, "0", gClrValue, 8);
   CreateLabel(PREFIX + "Sym_PL", X_Offset + Panel_Width/2, infoY, "Symbol P/L:", gClrLabel, 8);
   CreateLabel(PREFIX + "Sym_PLVal", X_Offset + Panel_Width - 20, infoY, "0.00", gClrAccent, 8, FONT_MAIN, ANCHOR_RIGHT_UPPER);

   // Row 3: Buy Exposure & Margin Level
   infoY += 22;
   CreateLabel(PREFIX + "Sym_BuyExp", X_Offset + 20, infoY, "Buy Exp:", gClrLabel, 8);
   CreateLabel(PREFIX + "Sym_BuyExpVal", X_Offset + 130, infoY, "0.00 Lots", gClrValue, 8);
   CreateLabel(PREFIX + "Acc_ML", X_Offset + Panel_Width/2, infoY, "Margin Level:", gClrLabel, 8);
   CreateLabel(PREFIX + "Acc_MLVal", X_Offset + Panel_Width - 20, infoY, "0.00%", gClrValue, 8, FONT_MAIN, ANCHOR_RIGHT_UPPER);

   // Row 4: Sell Exposure & Eq to SO
   infoY += 22;
   CreateLabel(PREFIX + "Sym_SellExp", X_Offset + 20, infoY, "Sell Exp:", gClrLabel, 8);
   CreateLabel(PREFIX + "Sym_SellExpVal", X_Offset + 130, infoY, "0.00 Lots", gClrValue, 8);
   CreateLabel(PREFIX + "Acc_SOEq", X_Offset + Panel_Width/2, infoY, "Eq to SO:", gClrLabel, 8);
   CreateLabel(PREFIX + "Acc_SOEqVal", X_Offset + Panel_Width - 20, infoY, "0.00", gClrValue, 8, FONT_MAIN, ANCHOR_RIGHT_UPPER);

   // Row 5: SO Price & Pts to SO
   infoY += 22;
   CreateLabel(PREFIX + "Sym_SOPrice", X_Offset + 20, infoY, "SO Price:", gClrLabel, 8);
   CreateLabel(PREFIX + "Sym_SOPriceVal", X_Offset + 130, infoY, "-", gClrValue, 8);
   CreateLabel(PREFIX + "Sym_SOPts", X_Offset + Panel_Width/2, infoY, "Pts to SO:", gClrLabel, 8);
   CreateLabel(PREFIX + "Sym_SOPtsVal", X_Offset + Panel_Width - 20, infoY, "0 pts", gClrValue, 8, FONT_MAIN, ANCHOR_RIGHT_UPPER);
}

void CreateAboutTab(int y)
{
   int contentX = X_Offset + 20;
   int contentW = Panel_Width - 40;
   CreateRect(PREFIX + "AboutBg", X_Offset + 4, y, Panel_Width - 8, 340, gClrStripe);
   
   int lineY = y + 20;
   CreateLabel(PREFIX + "Ab_Title", contentX, lineY, "UNTUK MENJADI BAHAGIA DALAM TRADING", gClrAccent, 11);
   lineY += 30;
   CreateLabel(PREFIX + "Ab_Desc1", contentX, lineY, "Anda harus menghilangkan dua hal:", clrWhite, 9);
   lineY += 20;
   CreateLabel(PREFIX + "Ab_Desc2", contentX, lineY, "Ketakutan akan masa depan yang buruk dan kenangan akan masa lalu yang buruk", clrWhite, 9);
   
   lineY += 40;
   CreateLabel(PREFIX + "Ab_DevLabel", contentX, lineY, "Developed by:", gClrLabel, 8);
   CreateLabel(PREFIX + "Ab_DevVal", contentX + 120, lineY, "MOCHAMAD TABRANI", gClrValue, 8);
   lineY += 20;
   CreateLabel(PREFIX + "Ab_VerLabel", contentX, lineY, "Version:", gClrLabel, 8);
   CreateLabel(PREFIX + "Ab_VerVal", contentX + 120, lineY, "0.01 Professional", gClrValue, 8);
   lineY += 20;
   CreateLabel(PREFIX + "Ab_Method", contentX, lineY, "Methodology:", gClrLabel, 8);
   CreateLabel(PREFIX + "Ab_MethodVal", contentX + 120, lineY, "Grafik Tabranij (GT) Matematika Pasar", gClrValue, 8);
   
   lineY += 50;
   CreateRect(PREFIX + "Ab_Box", contentX, lineY, contentW, 100, gClrBg, clrSilver);
   CreateLabel(PREFIX + "Ab_Status", contentX + 10, lineY + 10, "STATUS SISTEM: OPERASIONAL", gClrSuccess, 9);
   CreateLabel(PREFIX + "Ab_Lince", contentX + 10, lineY + 30, "License: RINGIN BAMBU Juli 2026", clrSilver, 8);
   CreateLabel(PREFIX + "Ab_Support", contentX + 10, lineY + 70, "Support: mql5.com/getbos | t.me/ringinbambu", gClrAccent, 8);
}

void CreateTradingTab(int y)
{
   CreateRect(PREFIX + "TradBg", X_Offset + 4, y, Panel_Width - 8, 340, gClrStripe);
   int lineY = y + 20;
   int contentX = X_Offset + 20;
   
   CreateLabel(PREFIX + "Tr_Title", contentX, lineY, "RINGKASAN PENGATURAN ALGORITMA", gClrAccent, 10);
   lineY += 40;
   
   CreateLabel(PREFIX + "Tr_StratL", contentX, lineY, "Durasi GT:", gClrLabel, 9);
   CreateLabel(PREFIX + "Tr_StratV", contentX + 150, lineY, EnumToString(InpGTTimeframe), gClrValue, 9);
   lineY += 25;
   CreateLabel(PREFIX + "Tr_LotL", contentX, lineY, "Volume:", gClrLabel, 9);
   CreateLabel(PREFIX + "Tr_LotV", contentX + 150, lineY, DoubleToString(InpLot, 2), gClrValue, 9);
   lineY += 25;
   CreateLabel(PREFIX + "Tr_StepL", contentX, lineY, "Martingale x:", gClrLabel, 9);
   CreateLabel(PREFIX + "Tr_StepV", contentX + 150, lineY, DoubleToString(InpMultiplier, 1) + "x / Max " + IntegerToString(InpMaxSteps), gClrValue, 9);
   lineY += 25;
   CreateLabel(PREFIX + "Tr_TPL", contentX, lineY, "TP / SL:", gClrLabel, 9);
   CreateLabel(PREFIX + "Tr_TPV", contentX + 150, lineY, IntegerToString(InpTP) + " / " + IntegerToString(InpSL) + " pts", gClrValue, 9);
   
   lineY += 50;
   CreateLabel(PREFIX + "Tr_Note", contentX, lineY, "Catatan: Untuk mengubah nilai ini, silakan gunakan standar", clrSilver, 8);
   lineY += 15;
   CreateLabel(PREFIX + "Tr_Note2", contentX, lineY, "Expert Advisor Properties (F7 -> Inputs).", clrSilver, 8);
}

void CreateColorsTab(int y)
{
   CreateRect(PREFIX + "ColBg", X_Offset + 4, y, Panel_Width - 8, 340, gClrStripe);
   int lineY = y + 20;
   int centerX = X_Offset + Panel_Width/2;
   
   CreateLabel(PREFIX + "Cl_Title", centerX, lineY, "PILIH TAMPILAN TEMA", gClrAccent, 11, FONT_MAIN, ANCHOR_CENTER);
   lineY += 50;
   
   int btnW = 180, btnH = 35;
   CreateButton(PREFIX + "THM_ONYX", centerX, lineY, btnW, btnH, "ONYX & GOLD", clrWhite, C'35,35,35');
   lineY += 50;
   CreateButton(PREFIX + "THM_NEON", centerX, lineY, btnW, btnH, "NEON BLUE", clrWhite, C'20,40,60');
   lineY += 50;
   CreateButton(PREFIX + "THM_MATRIX", centerX, lineY, btnW, btnH, "RETRO MATRIX", clrWhite, C'10,50,10');
   
   lineY += 60;
   CreateLabel(PREFIX + "Cl_Note", centerX, lineY, "Perubahan tema yang langsung diterapkan di semua tab (halaman/lembar kerja).", clrSilver, 8, FONT_MAIN, ANCHOR_CENTER);
}

void CreateVisualTab(int y)
{
   CreateRect(PREFIX + "VisBg", X_Offset + 4, y, Panel_Width - 8, 340, gClrStripe);
   int lineY = y + 20;
   int centerX = X_Offset + Panel_Width/2;
   
   CreateLabel(PREFIX + "Vs_Title", centerX, lineY, "PENGATURAN TAMPILAN GT", gClrAccent, 11, FONT_MAIN, ANCHOR_CENTER);
   lineY += 60;
   
   string toggleText = extShowGTChart ? "MENONAKTIFKAN LEVEL GT" : "MENGAKTIFKAN LEVEL GT";
   color toggleBg = extShowGTChart ? gClrDanger : gClrSuccess;
   
   CreateButton(PREFIX + "TOG_CHART", centerX, lineY, 220, 40, toggleText, clrWhite, toggleBg);
   
   lineY += 80;
   CreateLabel(PREFIX + "Vs_Desc", centerX, lineY, "Mengaktifkan/menonaktifkan tampilan garis GT secara langsung", clrWhite, 9, FONT_MAIN, ANCHOR_CENTER);
   lineY += 20;
   CreateLabel(PREFIX + "Vs_Desc2", centerX, lineY, "(Tinggi, Rendah, Awal, Inti) di grafik tabranij.", clrWhite, 9, FONT_MAIN, ANCHOR_CENTER);
}

bool CreateTabButton(string name, int x, int y, int w, int h, string text, bool active)
{
   if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0)) return false;
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x - (w/2));
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w - 4);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_COLOR, active ? clrWhite : clrSilver);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, active ? gClrAccent : gClrHdr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, active ? clrWhite : clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   return true;
}


bool CreateButton(string name, int x, int y, int w, int h, string text, color txtClr, color bgClr)
{
   if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0)) return false;
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x - (w/2));
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y - (h/2));
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, txtClr);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgClr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrSilver);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   return true;
}

void CreateCornerBrackets(int x, int y, int w, int h, int size, color clr)
{
   CreateRect(PREFIX+"TL1", x, y, size, 2, clr); CreateRect(PREFIX+"TL2", x, y, 2, size, clr);
   CreateRect(PREFIX+"TR1", x + w - size, y, size, 2, clr); CreateRect(PREFIX+"TR2", x + w - 2, y, 2, size, clr);
   CreateRect(PREFIX+"BL1", x, y + h - 2, size, 2, clr); CreateRect(PREFIX+"BL2", x, y + h - size, 2, size, clr);
   CreateRect(PREFIX+"BR1", x + w - size, y + h - 2, size, 2, clr); CreateRect(PREFIX+"BR2", x + w - 2, y + h - size, 2, size, clr);
}

//+------------------------------------------------------------------+
//| [7] Logic Functions                                              |
//+------------------------------------------------------------------+
void UpdateGUILabels()
{
   UpdateBarData(3, "_v3", gClrValue);
   UpdateBarData(2, "_v2", gClrValue);
   UpdateBarData(1, "_v1", gClrValue);
   UpdateBarData(0, "_v0", gClrAccent);
   
   UpdateInfoSection();
   ChartRedraw();
}

void UpdateInfoSection()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   int    spread  = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   
   double symbolPL = 0;
   double buyLots = 0;
   double sellLots = 0;
   double buyPriceSum = 0;
   double sellPriceSum = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            double lots = PositionGetDouble(POSITION_VOLUME);
            double price = PositionGetDouble(POSITION_PRICE_OPEN);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            if(posType == POSITION_TYPE_BUY)
            {
               buyLots += lots;
               buyPriceSum += price * lots;
            }
            else if(posType == POSITION_TYPE_SELL)
            {
               sellLots += lots;
               sellPriceSum += price * lots;
            }
               
            symbolPL += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);
         }
      }
   }
   
   double avgBuyPrice = (buyLots > 0) ? buyPriceSum / buyLots : 0;
   double avgSellPrice = (sellLots > 0) ? sellPriceSum / sellLots : 0;
   
   SetVal(PREFIX + "Acc_BalVal", DoubleToString(balance, 2), gClrValue);
   SetVal(PREFIX + "Acc_EqVal", DoubleToString(equity, 2), gClrValue);
   SetVal(PREFIX + "Sym_SpreadVal", IntegerToString(spread), gClrValue);

   // Calculate point value total early
   double netLots = buyLots - sellLots;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double pointValuePerLot = (tickSize > 0) ? tickValue * (myPoint / tickSize) : myPoint;
   double pointValueTotal = MathAbs(netLots) * pointValuePerLot;

   double ptsFloating = 0;
   if(pointValueTotal > 0)
      ptsFloating = symbolPL / pointValueTotal;

   // Format Symbol P/L dynamically with signs, unicode indicators, and neutral state color
   string plStr = "";
   color plColor = gClrValue;
   
   if(symbolPL > 0.005)
   {
      plColor = gClrSuccess;
      if(buyLots > 0 || sellLots > 0)
      {
         if(pointValueTotal > 0)
            plStr = StringFormat("▲ +%.2f (+%d pts)", symbolPL, (int)MathRound(ptsFloating));
         else
            plStr = StringFormat("▲ +%.2f (Hedged)", symbolPL);
      }
      else
         plStr = StringFormat("▲ +%.2f (0 pts)", symbolPL);
   }
   else if(symbolPL < -0.005)
   {
      plColor = gClrDanger;
      if(buyLots > 0 || sellLots > 0)
      {
         if(pointValueTotal > 0)
            plStr = StringFormat("▼ %.2f (%d pts)", symbolPL, (int)MathRound(ptsFloating));
         else
            plStr = StringFormat("▼ %.2f (Hedged)", symbolPL);
      }
      else
         plStr = StringFormat("▼ %.2f (0 pts)", symbolPL);
   }
   else
   {
      plColor = gClrValue;
      plStr = "0.00 (0 pts)";
   }
   SetVal(PREFIX + "Sym_PLVal", plStr, plColor);

   // Risk Analysis Calculations
   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   double stopOutLevel = AccountInfoDouble(ACCOUNT_MARGIN_SO_SO);
   long stopOutMode = AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE);

   string buyExpStr = "0.00 Lots";
   string sellExpStr = "0.00 Lots";
   string ptsToSOStr = "-";
   string eqToSOStr = "-";
   string marginLevelStr = "0.00%";
   string stopOutPriceStr = "-";
   color riskColor = gClrValue;

   int dispDigits = (myDigits > 4) ? 4 : myDigits;
   string buyPriceStr = DoubleToString(avgBuyPrice, dispDigits);
   string sellPriceStr = DoubleToString(avgSellPrice, dispDigits);

   if(buyLots > 0)
      buyExpStr = StringFormat("%.2f @ %s", buyLots, buyPriceStr);
   if(sellLots > 0)
      sellExpStr = StringFormat("%.2f @ %s", sellLots, sellPriceStr);

   if(buyLots > 0 || sellLots > 0)
   {
      if(margin > 0)
      {
         marginLevelStr = StringFormat("%.1f%% (SO: %.1f%%)", marginLevel, stopOutLevel);
         
         if(marginLevel < 150.0)
            riskColor = gClrDanger;
         else if(marginLevel < 300.0)
            riskColor = clrOrange;

         double equitySO = 0;
         if(stopOutMode == ACCOUNT_STOPOUT_MODE_PERCENT)
            equitySO = (stopOutLevel * margin) / 100.0;
         else
            equitySO = stopOutLevel;

         double equityToSO = equity - equitySO;
         eqToSOStr = DoubleToString(equityToSO, 2);

         if(pointValueTotal > 0)
         {
            double ptsToSO = equityToSO / pointValueTotal;
            ptsToSOStr = StringFormat("%d pts", (int)MathMax(0, MathRound(ptsToSO)));
            
            double stopOutPrice = 0;
            if(netLots > 0)
               stopOutPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID) - ptsToSO * myPoint;
            else // netLots < 0
               stopOutPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + ptsToSO * myPoint;
               
            stopOutPriceStr = DoubleToString(stopOutPrice, dispDigits);
         }
         else
         {
            ptsToSOStr = "Hedged";
            stopOutPriceStr = "Hedged";
         }
      }
   }

   SetVal(PREFIX + "Sym_BuyExpVal", buyExpStr, buyLots > 0 ? gClrSuccess : gClrValue);
   SetVal(PREFIX + "Sym_SellExpVal", sellExpStr, sellLots > 0 ? gClrDanger : gClrValue);
   SetVal(PREFIX + "Acc_MLVal", marginLevelStr, riskColor);
   SetVal(PREFIX + "Acc_SOEqVal", eqToSOStr, riskColor);
   SetVal(PREFIX + "Sym_SOPriceVal", stopOutPriceStr, riskColor);
   SetVal(PREFIX + "Sym_SOPtsVal", ptsToSOStr, riskColor);
}

void UpdateBarData(int shift, string suffix, color baseClr)
{
   double open  = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double close = iClose(_Symbol, PERIOD_CURRENT, shift);
   double high  = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double low   = iLow(_Symbol, PERIOD_CURRENT, shift);
   
   if(open == 0) return;

   int oc = (int)((close - open) / myPoint);
   int lh = (int)((high - low) / myPoint);
   double bH = MathMax(open, close), bL = MathMin(open, close);
   int ch = (int)((high - bH) / myPoint), cl = (int)((bL - low) / myPoint);

   SetVal(PREFIX + "R_OH" + suffix, DoubleToString(high, myDigits), baseClr);
   SetVal(PREFIX + "R_CH" + suffix, StringFormat("%d", ch), baseClr);
   SetVal(PREFIX + "R_CL" + suffix, StringFormat("%d", cl), baseClr);
   SetVal(PREFIX + "R_OL" + suffix, DoubleToString(low, myDigits), baseClr);
   SetVal(PREFIX + "R_Awal" + suffix, DoubleToString(open, myDigits), baseClr);
   SetVal(PREFIX + "R_OC" + suffix, StringFormat("%d", oc), oc >= 0 ? gClrSuccess : gClrDanger);
   SetVal(PREFIX + "R_LH" + suffix, DoubleToString(close, myDigits), baseClr);
   SetVal(PREFIX + "R_Range" + suffix, StringFormat("%d", lh), baseClr);
}

void SetVal(string name, string txt, color clr)
{
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
//| [8] Countdown Timer - Hitung Mundur GT Live                      |
//+------------------------------------------------------------------+
void UpdateCountdown()
{
   ENUM_TIMEFRAMES tf = Period();
   int periodSeconds = PeriodSeconds(tf);
   
   // Gunakan waktu lokal + offset untuk mendapatkan "Server Time" yang presisi per detik
   datetime serverTimeLive = (datetime)((long)TimeLocal() + serverLocalOffset);
   
   datetime barOpenTime = iTime(_Symbol, tf, 0);
   int elapsed   = (int)(serverTimeLive - barOpenTime);
   int remaining = periodSeconds - elapsed;
   
   if(remaining < 0) remaining = 0;
   
   int hours   = remaining / 3600;
   int minutes = (remaining % 3600) / 60;
   int seconds = remaining % 60;
   
   string countdownText;
   if(hours > 0)
      countdownText = StringFormat("%02d:%02d:%02d", hours, minutes, seconds);
   else
      countdownText = StringFormat("%02d:%02d", minutes, seconds);
   
   // Efek pulse: warna berkedip saat mendekati penutupan (< 60 detik)
   color cdColor;
   if(remaining <= 10)
      cdColor = clrRed;               // Merah solid - detik-detik terakhir
   else if(remaining <= 60)
   {
      // Berwarna-warni (Rainbow Pulse) - Expanded with Red, Blue, Green
      color rainbow[] = {clrCyan, clrMagenta, clrYellow, clrLime, clrOrange, clrWhite, clrRed, clrBlue, clrGreen, clrAqua};
      cdColor = rainbow[seconds % ArraySize(rainbow)];
   }
   else
      cdColor = COLOR_COUNTDOWN;       // Amber Gold normal
   
   SetVal(PREFIX + "CountdownIcon", "p", cdColor);
   SetVal(PREFIX + "Countdown", countdownText, cdColor);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| [9] EA Trading Logic - Sequential State Machine                  |
//+------------------------------------------------------------------+

//--- Helper: Count active EA positions on this symbol
int CountMyPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == (long)InpMagic)
            count++;
   }
   return count;
}

//--- Helper: Get last closed deal from history (EXIT deals only)
// Returns: ticket of the last closed deal, or 0 if none
ulong GetLastClosedDeal(double &outProfit, ENUM_POSITION_TYPE &outType)
{
   HistorySelect(TimeCurrent() - 7*24*3600, TimeCurrent());
   int total = HistoryDealsTotal();
   
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC)  != (long)InpMagic) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL)  != _Symbol) continue;
      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) continue; // only closing deals
      
      outProfit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + 
                  HistoryDealGetDouble(ticket, DEAL_SWAP)   + 
                  HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      
      ENUM_DEAL_TYPE dtype = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
      // DEAL_TYPE_SELL = closing a BUY, DEAL_TYPE_BUY = closing a SELL
      outType = (dtype == DEAL_TYPE_SELL) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      return ticket;
   }
   return 0;
}

//--- Place a market order with SL/TP
bool PlaceOrder(ENUM_POSITION_TYPE type, double lot, string comment)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double price, sl, tp;
   bool result = false;
   
   if(type == POSITION_TYPE_BUY)
   {
      price = ask;
      sl    = (InpSL > 0) ? NormalizeDouble(price - InpSL * myPoint, myDigits) : 0;
      tp    = (InpTP > 0) ? NormalizeDouble(price + InpTP * myPoint, myDigits) : 0;
      result = trade.Buy(lot, _Symbol, price, sl, tp, comment);
   }
   else
   {
      price = bid;
      sl    = (InpSL > 0) ? NormalizeDouble(price + InpSL * myPoint, myDigits) : 0;
      tp    = (InpTP > 0) ? NormalizeDouble(price - InpTP * myPoint, myDigits) : 0;
      result = trade.Sell(lot, _Symbol, price, sl, tp, comment);
   }
   
   if(result)
      Print("Escindo EA: Order open [", (type == POSITION_TYPE_BUY ? "BUY" : "SELL"),
            "] Lot:", DoubleToString(lot,2), " | ", comment);
   else
      Print("Escindo EA: Order FAILED â€“ ", trade.ResultRetcodeDescription());
   
   return result;
}

//--- Main Logic: Sequential State Machine
void ExecuteTradingLogic()
{
   // If we already have an open position, do nothing. Let broker SL/TP handle it.
   if(CountMyPositions() > 0) return;
   
   // --------------- No open position: decide next action ---------------
   double lastProfit = 0;
   ENUM_POSITION_TYPE lastType = POSITION_TYPE_BUY;
   ulong lastDealTicket = GetLastClosedDeal(lastProfit, lastType);
   
   double nextLot;
   ENUM_POSITION_TYPE nextType;
   
   if(lastDealTicket == 0 || lastDealTicket == (ulong)g_lastDeal)
   {
      // ========== FIRST TRADE ever (or already processed) ==========
      // Read GT Neto from the InpGTTimeframe last closed bar
      double lastOpen  = iOpen(_Symbol,  InpGTTimeframe, 1);
      double lastClose = iClose(_Symbol, InpGTTimeframe, 1);
      
      if(lastOpen == 0 || lastClose == 0) return;
      
      // If g_isFirstTrade is false, it means the last deal was already processed
      if(!g_isFirstTrade) return;
      
      if(lastClose > lastOpen)
         nextType = POSITION_TYPE_BUY;
      else if(lastClose < lastOpen)
         nextType = POSITION_TYPE_SELL;
      else
         return; // doji GT â€“ no signal
      
      nextLot = InpLot;
      g_isFirstTrade = false;
   }
   else
   {
      // ========== Kita baru saja menyelesaikan kesepakatan ====================
      // Tandai itu sebagai sudah diproses/selesai supaya kita tidak mengirim/menjalankan dua kali
      if(lastDealTicket == (ulong)g_lastDeal) return;
      g_lastDeal = (int)lastDealTicket;
      
      // Tentukan besarnya langkah Martingale berdasarkan dari rentetan kekalahan
      // Lihat ke belakang dari transaksi terakhir hingga menemukan transaksi yang menguntungkan untuk menghitung kerugian beruntun
      HistorySelect(TimeCurrent() - 30*24*3600, TimeCurrent());
      int total         = HistoryDealsTotal();
      int lossStreak    = 0;
      double runLot     = InpLot;
      
      for(int i = total - 1; i >= 0; i--)
      {
         ulong tk = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(tk, DEAL_MAGIC)  != (long)InpMagic) continue;
         if(HistoryDealGetString(tk, DEAL_SYMBOL)  != _Symbol) continue;
         ENUM_DEAL_ENTRY ent = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(tk, DEAL_ENTRY);
         if(ent != DEAL_ENTRY_OUT && ent != DEAL_ENTRY_INOUT) continue;
         
         double p = HistoryDealGetDouble(tk, DEAL_PROFIT) + 
                    HistoryDealGetDouble(tk, DEAL_SWAP)   +
                    HistoryDealGetDouble(tk, DEAL_COMMISSION);
         if(p < 0)
         {
            lossStreak++;
            if(lossStreak >= InpMaxSteps) break;
         }
         else
            break; // profitable deal found â†’ reset streak
      }
      
      if(lastProfit >= 0)
      {
         // ========== After TP: same direction, reset lot ===========
         nextType = lastType;
         nextLot  = InpLot;
      }
      else
      {
         // ========== After SL: reverse direction, apply Martingale ==
         nextType = (lastType == POSITION_TYPE_BUY) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
         
         // Calculate Martingale lot
         if(lossStreak > 0 && lossStreak < InpMaxSteps)
            nextLot = NormalizeDouble(InpLot * MathPow(InpMultiplier, lossStreak), 2);
         else
         {
            // Max steps reached â†’ reset
            nextLot = InpLot;
            Print("GT EA: Max Martingale Steps reached â€“ resetting to base lot.");
         }
      }
   }
   
   // Enforce minimum lot constraints
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   nextLot = MathMax(nextLot, minLot);
   nextLot = NormalizeDouble(MathRound(nextLot / stepLot) * stepLot, 2);
   
   string comment = StringFormat("GT|Step%d|Lot%.2f", lossStreak_or_new(), nextLot);
   PlaceOrder(nextType, nextLot, comment);
}

// Lightweight helper used only for the comment string (avoids code duplication)
int lossStreak_or_new() { return g_isFirstTrade ? 0 : -1; }

//+------------------------------------------------------------------+
//| [10] Close All Positions                                         |
//+------------------------------------------------------------------+
void CloseAllPositions(bool pos, bool pend)
{
   if(pos)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
               PositionGetInteger(POSITION_MAGIC) == (long)InpMagic)
               trade.PositionClose(ticket);
      }
   }
   
   if(pend)
   {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(OrderSelect(ticket))
            if(OrderGetString(ORDER_SYMBOL) == _Symbol && 
               OrderGetInteger(ORDER_MAGIC) == (long)InpMagic)
               trade.OrderDelete(ticket);
      }
   }
}
//+------------------------------------------------------------------+
