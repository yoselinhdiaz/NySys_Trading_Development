//+------------------------------------------------------------------+
//|  Velocity_ALMA.mq5  ·  Velocity ALMA v0.02 (Nysys)                |
//|  Port a MQL5 del Pine v5 "Velocity ALMA" v0.02 (219 lineas), copia |
//|  local docs/Velocity_ALMA_v0.02.pine.                             |
//|                                                                   |
//|  Cabecera Pine (linea 24) y su equivalente aqui:                   |
//|    indicator("Velocity ALMA", shorttitle = "Velocity", overlay...) |
//|      -> el nombre visible es el del archivo (Velocity_ALMA.mq5) y  |
//|         el short title no existe en MQL5: se documenta y punto.    |
//|    overlay = true          -> #property indicator_chart_window     |
//|    max_bars_back = 300     -> sin equivalente: el motor recalcula   |
//|                               completo si el broker recarga historia|
//|    max_labels_count = 500  -> MQL5 no limita OBJ_TEXT; el port usa  |
//|    max_lines_count  = 500     solo 6 objetos por trade (cajas/líneas|
//|                               + etiquetas), borrados al siguiente.  |
//|  Indicador de ventana de gráfico (overlay) — canal Velocity.      |
//|                                                                   |
//|  Cálculo (idéntico al Pine; arrays NO-series: i = vela actual,     |
//|  i-1 = vela anterior):                                            |
//|   · basisClose = EMA(ALMA(close, BasisLength, Offset, Sigma),      |
//|                        BasisSmooth)                                |
//|   · basisOpen  = idem sobre open                                   |
//|   · vol  = EMA(SMA(|close - SMA(close, VolLength)|, VolLength),     |
//|                VolSmooth)                                          |
//|   · volRank = #{k = 1..RankLookback : vol[i-k] <= vol[i]} / N      |
//|   · half = MadScale * vol * (Adaptive ? MinMult +                  |
//|              (MaxMult - MinMult) * volRank : MinMult)              |
//|   · ATR = RMA(TrueRange) con semilla SMA (Wilder). NO se usa       |
//|     iATR(): el ATR nativo de MT5 promedia simple y rompe paridad.  |
//|   · Cruce del cierre contra la banda en vela CERRADA -> trend 1/-1 |
//|     BUY cuando trend[i-1] != 1, SELL cuando trend[i-1] != -1       |
//|   · Niveles: R = ATR(SlAtrLen) * SlAtrMult desde el cierre de la   |
//|     señal, TP1 = R * Tp1RR, TP2 = R * Tp2RR, SL = R                |
//|                                                                   |
//|  Buffers (orden de dibujo, de atrás a adelante):                   |
//|    P0..P3   degradado UP  precio<->basis  4 x DRAW_FILLING   0..7  |
//|    P4..P7   degradado DN  precio<->basis  4 x DRAW_FILLING   8..15 |
//|    P8       velas coloreadas   DRAW_COLOR_CANDLES          16..20  |
//|    P9       relleno cinta (basis O<->C) UP  DRAW_FILLING       21..22|
//|    P10      relleno cinta (basis O<->C) DN  DRAW_FILLING       23..24|
//|    P11      Basis Open         DRAW_COLOR_LINE (up/dn/gris) 25..26 |
//|    P12      Basis Close        DRAW_COLOR_LINE (up/dn/gris) 27..28 |
//|    P13      Upper Band         DRAW_COLOR_LINE (up/dn/gris) 29..30 |
//|    P14      Lower Band         DRAW_COLOR_LINE (up/dn/gris) 31..32 |
//|    P15      TP1 hit            DRAW_ARROW (Wingdings 108)      33  |
//|    P16      TP2 hit            DRAW_ARROW (Wingdings 108)      34  |
//|    P17      SL hit             DRAW_ARROW (Wingdings 251)      35  |
//|    P18      "Buy Signal"       DRAW_NONE  1/0  -> BUFFER 36        |
//|    P19      "Sell Signal"      DRAW_NONE  1/0  -> BUFFER 37        |
//|    38..51   INDICATOR_CALCULATIONS (series base + estado)          |
//|    52..56   INDICATOR_CALCULATIONS (niveles del trade, por vela)   |
//|    52 entry, 53 SL, 54 TP1, 55 TP2, 56 posición (1 / -1 / 0)       |
//|                                                                   |
//|  iCustom (índices de buffer que lee un EA):                        |
//|    36 Buy Signal, 37 Sell Signal, 27 Basis Close, 25 Basis Open,   |
//|    29 Upper Band, 31 Lower Band, 33 TP1 hit, 34 TP2 hit, 35 SL hit |
//|    52 entry, 53 SL, 54 TP1, 55 TP2, 56 posición del trade vigente  |
//|    43 dev, 44 mad_raw, 45 vol, 46 vol_rank (diagnóstico del CSV)   |
//|                                                                   |
//|  Objetos (prefijo VALMA_, todos se borran en OnDeinit):            |
//|   · VALMA_buy_/sell_  flecha + texto BUY / SELL (persisten)        |
//|   · VALMA_lv_*  cajas y líneas: SOLO el trade vigente, y se        |
//|     borran al llegar la señal siguiente. Es paridad exacta con la  |
//|     v0.02 (box.delete / line.delete en 181-186): no se acumulan    |
//|     cajas de trades anteriores.                                    |
//|   · VALMA_ar_*/lb_*  precio a la derecha (solo trade activo; la    |
//|     v0.02 también caduca estas etiquetas al cerrar el trade)       |
//|                                                                   |
//|  Orden de evaluación por vela CERRADA (idéntico al Pine v0.02):    |
//|   1) hits del trade vigente (SL -> TP1 -> TP2). El 'return' de SL  |
//|      sale solo del motor de hits: la señal de la MISMA vela se     |
//|      evalúa después y puede abrir trade nuevo en esa vela.         |
//|   2) tendencia / señal (cruce de cierre vs banda) y apertura.      |
//|  Las marcas TP1/TP2/SL se pintan en la vela del toque y persisten  |
//|  (plotshape del Pine); no se borran al abrir el trade siguiente.   |
//|
//|  Mapa de paridad contra la v0.02 (números de línea del Pine):
//|    69-70   basisClose / basisOpen = EMA(ALMA(x), BasisSmooth)
//|    73-74   madRaw = SMA(|close - SMA(close, VolLength)|, VolLength)
//|            vol    = EMA(madRaw, VolSmooth)
//|            (dos SMA encadenadas: la exterior es obligatoria)
//|            sin ella vol se adelanta ~2 velas (ver replica.py en
//|            MQL5\Scripts\Nysys\Tests\)
//|    77-84   volRank = #{k = 1..N : vol[i-k] <= vol[i], no na} / N
//|    87-90   adaptFactor, bandHalf, upperBand, lowerBand
//|    93-103  cruces (close vs banda y cierre previo vs banda previa)
//|            + máquina de tendencia (trend != 1 / trend != -1)
//|   108-109  "Buy Signal" / "Sell Signal": plots de datos (DRAW_NONE)
//|   113-115  cinta = relleno entre Basis Open y Basis Close (showRibbon);
//|            el plot conserva sus valores aunque no se dibuje
//|   120-123  degradado precio<->basisClose y bandas (showBands)
//|   124      barcolor(colorCandles and trend != 0)
//|   145-158  hits del trade vigente: SL -> (si no SL) TP1 -> TP2
//|   170-179  señal: niveles desde el cierre (entry, SL, TP1, TP2)
//|   180-192  cajas/líneas: borra las previas y dibuja sólo la nueva
//|   202-212  etiquetas de precio del trade activo
//|   214-216  plotshape de marcas TP1/TP2/SL + OBJ_TEXT gris
//|   218-219  alertcondition BUY / SELL (título y mensaje replicados)
//|  No existen en la v0.02 y por tanto NO se portan: useEmaFilter,
//|  useSession, useDates, exitMode y contratos (TP1/TP2 siempre activos).
//|  Extras sólo-MT5, documentados: buffer 56 pos_dir (auditoría) y los
//|  CSV de paridad (live del indicador + full del script).
//|                                                                   |
//|  Sin repintado: las señales solo se evalúan con vela cerrada; la   |
//|  vela en formación únicamente mueve cinta, bandas y degradado.     |
//|                                                                   |
//|  Diferencias inevitables con TradingView:                          |
//|   · MT5 no dibuja rellenos con alfa: cada color se pre-mezcla con  |
//|     el fondo del gráfico (Blend) y se repinta si el fondo cambia.  |
//|   · Con ColorCandles activo se pone CHART_FOREGROUND = false para  |
//|     que las velas recoloreadas queden por encima de los rellenos   |
//|     (con true, MT5 dibuja el gráfico encima de los plots). El      |
//|     valor original del gráfico se guarda en OnInit y se restaura   |
//|     en OnDeinit.                                                   |
//|   · OBJ_TEXT no admite saltos de línea: las etiquetas de la        |
//|     derecha muestran "TP2 (1.5R) 2318.40" en una sola línea.       |
//|   · El degradado del Pine lleva alfa continuo (45% en el           |
//|     precio, 0% en la basis); MT5 no dibuja alfa, así que se        |
//|     usan 4 capas DRAW_FILLING pre-mezcladas con el fondo; cada     |
//|     capa toma la opacidad del punto medio de su tramo:             |
//|     GradOpacity*(k+0.5)/4 (0.056/0.169/0.281/0.394 con el          |
//|     default 0.45); el lado basis queda en 0.056, no en 0.          |
//|   · STYLE_DASH y STYLE_DOT sólo se dibujan con width = 1: la       |
//|     entrada (Pine 189, style_dashed, width 2) va discontinua       |
//|     de 1 px; con width 2 MT5 la pinta sólida.                      |
//|   · DRAW_FILLING exige DOS índices de color (0 si buf1>buf2, 1 si  |
//|     buf1<buf2): los rellenos declaran 2 y ApplyColors deja ambos   |
//|     con el mismo color para que el relleno no cambie de color.     |
//|   · Con trend = 0 (solo antes de la primera señal) no se dibuja    |
//|     cinta ni degradado: el Pine los pinta en gris. Las líneas de   |
//|     basis / bandas sí salen en gris (índice de color 2).           |
//|   · DRAW_ARROW no admite texto: glifo Wingdings 108 = círculo      |
//|     relleno (TP1/TP2, como TV) y 251 = aspa (SL). El texto va en   |
//|     un OBJ_TEXT gris junto a la marca, con el mismo límite de      |
//|     VALMA_LABEL_BARS velas y el mismo ENUM_HIT_KIND que el buffer. |
//|   · D6: el tipo de dibujo de un plot es FIJO. Cambiarlo en runtime |
//|     cambia cuantos buffers consume el plot y MT5 reasigna los de   |
//|     todos los siguientes: DRAW_COLOR_LINE ocupa valor+color y      |
//|     DRAW_NONE solo valor. Con ShowBands=false el plot TP1 leia la  |
//|     banda inferior y el plot SL los toques TP1 (puntos y aspas     |
//|     falsos). Se oculta con clrNONE (HidePlot) y OnInit aborta si   |
//|     el mapa plot->buffer no da 33/34/35 y 36/37 (Log Expertos).    |
//|  Correcciones:                                                     |
//|   26/11/2026  bandas: el port hacia vol = EMA(dev) y omitia la SMA |
//|   exterior de madRaw (Pine 73). Con eso vol y bandHalf se          |
//|   adelantaban ~2 velas y half se desviaba hasta 35 (XAUUSD M15).   |
//|   Corregido: max|delta half| 0.0047 contra la replica (era el      |
//|   redondeo a 2 decimales del CSV; ahora el CSV va a 6 decimales).  |
//|   Paridad 11/11 senales en la misma vela vs la v0.02 en TV         |
//|   (OANDA:XAUUSD 15m, 24-26 nov); TP1 11:30 y 15:30 coinciden.      |
//|   Incremental: 0 dif en 3 velas vivas (SELL 18:15 server).         |
//|  (c) Nysys Market Solutions. Solo con fines educativos.            |
//+------------------------------------------------------------------+
#property copyright   "Nysys Market Solutions"
#define  VALMA_VERSION  "0.02"
#property version     "1.00"
#property description "Velocity ALMA (shorttitle Velocity) v0.02 Nysys: basis ALMA + bandas adaptativas, degradado, velas, TP/SL y alertas"
#property indicator_chart_window
#property indicator_buffers 57
#property indicator_plots   20

#define PFX              "VALMA_"
#define TV_GRAY          C'128,128,128'
#define TV_ORANGE        C'255,152,0'
#define VALMA_LABEL_BARS 3000            // velas de historial con flechas BUY / SELL

#include <Nysys/VelocityAlmaCsv.mqh>     // CSV de paridad (live + full)

//==================================================================== Inputs
// Etiquetas, textos de grupo y defaults son los de la v0.02 (27-66),
// caracter por caracter ("senales" sin ñ, como el original). MQL5 no
// tiene minval/step/tooltip: el rango util de cada input va comentado
// aqui y se valida en OnInit (INIT_PARAMETERS_INCORRECT).
input group "Basis"
input int    InpBasisLength   = 34;        // Basis Length (short-term)   [min 1]
input double InpAlmaOffset    = 0.65;      // ALMA Offset                  [0..1, paso 0.01]
input double InpAlmaSigma     = 20.0;      // ALMA Sigma                   [min 0.1, paso 0.5]
input int    InpBasisSmooth   = 4;         // Basis Smoothing EMA          [min 1]

input group "Volatility"
input int    InpVolLength     = 5;         // Vol Length (short-term)      [min 1]
input int    InpVolSmooth     = 5;         // Vol Smoothing EMA            [min 1]
input int    InpRankLookback  = 100;       // Volatility Rank Lookback     [min 2]
// MAD to standard-deviation scale: 1.4826 = 1 / Phi^-1(0.75)  [min 0.0001, paso 0.0001]
input double InpMadScale      = 1.4826;    // MAD scale (MAD to sigma)     [min 0.0001]

input group "Bands"
input double InpMinMult       = 0.8;       // Min Multiplier               [min 0.001, paso 0.1]
input double InpMaxMult       = 1.8;       // Max Multiplier               [min 0.001, paso 0.1]
// ON: el multiplicador escala entre Min y Max con el volRank. OFF: solo Min.
input bool   InpAdaptive      = true;      // Adaptive Bands

input group "Display (solo visual, no cambia senales)"
input bool   InpColorCandles  = false;     // Color candles by trend
// Show basis ribbon: degradado + cinta (en Pine todo va dentro de este flag)
input bool   InpShowRibbon    = true;      // Show basis ribbon
input bool   InpShowBands     = false;     // Show adaptive bands
input bool   InpShowSignals   = true;      // Show BUY / SELL labels
input color  InpUpColor       = C'0,230,0';    // Up color      (Pine #00e600)
input color  InpDnColor       = C'255,30,86';  // Down color    (Pine #ff1e56)
input int    InpLabelAtrLen   = 14;        // ATR Length (label offset)    [min 1]
input double InpLabelAtrOff   = 0.25;      // ATR Offset (label multiplier) [paso 0.05]
input double InpGradOpacity   = 0.45;      // Opacidad del degradado (solo MT5: punto medio del tramo)

input group "TP1 / TP2 / Stop Loss (solo visual)"
input bool   InpShowLevels    = true;      // Show Trade Levels
input bool   InpShowLvlLabels = true;      // Show Level Price Labels
input bool   InpShowHitMarks  = true;      // Show Level Hit Markers
input int    InpSlAtrLen      = 14;        // SL ATR Length                [min 1]
input double InpSlAtrMult     = 1.8;       // ATR Multiplier               [paso 0.1]
input double InpTp1RR         = 0.5;       // TP1 Risk/Reward              [paso 0.1]
input double InpTp2RR         = 1.5;       // TP2 Risk/Reward              [paso 0.1]

input group "Alerts"
input bool   InpAlertPopup    = true;      // Alert() al cerrar una señal
input bool   InpAlertPush     = false;     // SendNotification() (MetaQuotes ID)

input group "Diagnóstico"
input bool   InpDebugLog      = false;     // Log de recálculo incremental (Experts)
input bool   InpDumpCsv       = false;     // Volcar CSV live al cerrar cada vela
input int    InpDumpBars      = 500;       // Velas cerradas en el CSV live

//==================================================================== Plots
#define PL_UPG0    0                      // degradado UP, capa 1..4
#define PL_UPG1    1
#define PL_UPG2    2
#define PL_UPG3    3
#define PL_DNG0    4                      // degradado DN, capa 1..4
#define PL_DNG1    5
#define PL_DNG2    6
#define PL_DNG3    7
#define PL_CDL     8                      // velas coloreadas
#define PL_RIBU    9                      // relleno cinta UP
#define PL_RIBD   10                      // relleno cinta DN
#define PL_BO     11                      // Basis Open
#define PL_BC     12                      // Basis Close
#define PL_UPB    13                      // Upper Band
#define PL_LOB    14                      // Lower Band
#define PL_TP1M   15                      // marca TP1 alcanzado
#define PL_TP2M   16                      // marca TP2 alcanzado
#define PL_SLM    17                      // marca SL alcanzado
#define PL_BUYS   18                      // "Buy Signal"  (buffer 36)
#define PL_SELLS  19                      // "Sell Signal" (buffer 37)
#define PL_TOTAL  20

//==================================================================== Buffers
#define B_UPG0A    0                      // P0
#define B_UPG0B    1
#define B_UPG1A    2                      // P1
#define B_UPG1B    3
#define B_UPG2A    4                      // P2
#define B_UPG2B    5
#define B_UPG3A    6                      // P3
#define B_UPG3B    7
#define B_DNG0A    8                      // P4
#define B_DNG0B    9
#define B_DNG1A   10                      // P5
#define B_DNG1B   11
#define B_DNG2A   12                      // P6
#define B_DNG2B   13
#define B_DNG3A   14                      // P7
#define B_DNG3B   15
#define B_CDL_O   16                      // P8
#define B_CDL_H   17
#define B_CDL_L   18
#define B_CDL_C   19
#define B_CDL_CLR 20
#define B_RIBU_A  21                      // P9
#define B_RIBU_B  22
#define B_RIBD_A  23                      // P10
#define B_RIBD_B  24
#define B_BO      25                      // P11
#define B_BO_CLR  26
#define B_BC      27                      // P12
#define B_BC_CLR  28
#define B_UPBAND  29                      // P13
#define B_UPBAND_CLR 30
#define B_LOBAND  31                      // P14
#define B_LOBAND_CLR 32
#define B_MK_TP1  33                      // P15
#define B_MK_TP2  34                      // P16
#define B_MK_SL   35                      // P17
#define B_BUYSIG  36                      // P18  <- iCustom 36
#define B_SELLSIG 37                      // P19  <- iCustom 37

// buffers de cálculo (no se dibujan)
#define C_ALMA_C  38
#define C_ALMA_O  39
#define C_BASIS_C 40
#define C_BASIS_O 41
#define C_SMA_C   42
#define C_DEV     43
#define C_MAD     44
#define C_VOL     45
#define C_RANK    46
#define C_UPB     47
#define C_LOB     48
#define C_ATR_LBL 49
#define C_ATR_SL  50
#define C_TREND   51
// niveles del trade vigente en cada vela (iCustom 52..56 / auditoría CSV)
#define C_LVL_E   52                      // entry
#define C_LVL_SL  53
#define C_LVL_TP1 54
#define C_LVL_TP2 55
#define C_POSDIR  56                      // 1 long, -1 short, 0 sin trade
#define B_TOTAL   57

//==================================================================== Arrays de buffer
double bUpg0a[], bUpg0b[], bUpg1a[], bUpg1b[], bUpg2a[], bUpg2b[], bUpg3a[], bUpg3b[];
double bDng0a[], bDng0b[], bDng1a[], bDng1b[], bDng2a[], bDng2b[], bDng3a[], bDng3b[];
double bCdlO[], bCdlH[], bCdlL[], bCdlC[], bCdlClr[];
double bRibUa[], bRibUb[], bRibDa[], bRibDb[];
double bBO[], bBOClr[], bBC[], bBCClr[], bUp[], bUpClr[], bLo[], bLoClr[];
double bMkTP1[], bMkTP2[], bMkSL[];
double bBuy[], bSell[];
double bAlmaC[], bAlmaO[], bBasisC[], bBasisO[], bSmaC[], bDev[], bMad[], bVol[];
double bRank[], bUpB[], bLoB[], bAtrLbl[], bAtrSL[], bTrend[];
double bLvlE[], bLvlSl[], bLvlTp1[], bLvlTp2[], bPosDir[];

//==================================================================== Estado del motor
double   gAlmaW[];                       // pesos del ALMA (calculados en OnInit)
double   gAlmaSum    = 1.0;
double   gAlphaBasis = 0.4;              // 2 / (BasisSmooth + 1)
double   gAlphaVol   = 0.3333333333;     // 2 / (VolSmooth + 1)
int      gMinBars    = 200;              // historia mínima para calcular
color    gBg         = clrBlack;         // fondo del gráfico (para Blend)
bool     gFgOrig     = true;             // CHART_FOREGROUND original del gráfico
bool     gFgSaved    = false;            // se guardó el valor original en OnInit

int      gDir        = 0;                // 1 long, -1 short, 0 sin trade
bool     gHasTrade   = false;
bool     gDone       = true;             // trade cerrado por SL / TP2
bool     gTp1Hit     = false;
double   gEntry      = 0.0, gSl = 0.0, gTp1 = 0.0, gTp2 = 0.0;
int      gEntryBar   = -1, gEndBar = -1;
int      gTp1Bar     = -1, gTp2Bar = -1, gSlBar = -1;
int      gProcBar    = -1;               // última vela cerrada procesada por el motor
int      gLastDrawBar = -1;              // última vela cerrada con objetos redibujados
datetime gEntryTime  = 0;
datetime gLastAlert  = 0;
datetime gLastDump   = 0;                // vela cerrada ya volcada al CSV live
bool     gDumpNow    = false;            // tecla D: fuerza el volcado en el próximo pase
int      gIncBars    = 0;                // velas cerradas procesadas por el camino incremental
datetime gResetTime  = 0;                // hora de la última vela cerrada en el último ResetAll
string   gPlotLabel[PL_TOTAL];           // etiqueta de cada plot (la fija SetPlot)

//==================================================================== Utilidades
bool IsNa(const double v) { return(v == EMPTY_VALUE); }

// Una vela a la derecha del último precio (tiempo futuro para las etiquetas)
datetime TimeAt(const int k, const datetime &time[], const int rates_total)
{
   int last = rates_total - 1;
   if(k < 0) return(time[0]);
   if(k <= last) return(time[k]);
   return(time[last] + (datetime)((k - last) * PeriodSeconds()));
}

// Mezcla c sobre bg con transparencia a (0..1 = opacidad de c), como color.new(c, a)
color Blend(const color c, const color bg, const double a)
{
   double al = MathMax(0.0, MathMin(1.0, a));
   int r1 = (int)(c & 0xFF),  g1 = (int)((c >> 8) & 0xFF),  b1 = (int)((c >> 16) & 0xFF);
   int r0 = (int)(bg & 0xFF), g0 = (int)((bg >> 8) & 0xFF), b0 = (int)((bg >> 16) & 0xFF);
   return((color)((int)MathRound(r0 + (r1 - r0) * al) |
                  ((int)MathRound(g0 + (g1 - g0) * al) << 8) |
                  ((int)MathRound(b0 + (b1 - b0) * al) << 16)));
}

// Número corto para las etiquetas: 1.5 -> "1.5", 1.0 -> "1"
string ShortNum(const double v)
{
   string s = DoubleToString(v, 4);
   while(StringLen(s) > 0 && StringGetCharacter(s, StringLen(s) - 1) == '0')
      s = StringSubstr(s, 0, StringLen(s) - 1);
   if(StringLen(s) > 0 && StringGetCharacter(s, StringLen(s) - 1) == '.')
      s = StringSubstr(s, 0, StringLen(s) - 1);
   return(s);
}

//==================================================================== Cálculo base (paridad Pine)
// ta.sma(src, len); si algún valor del tramo es na -> na
double SmaAt(const double &src[], const int i, const int len)
{
   if(len < 1 || i < len - 1) return(EMPTY_VALUE);
   double s = 0.0;
   for(int k = 0; k < len; k++)
   {
      if(src[i - k] == EMPTY_VALUE) return(EMPTY_VALUE);
      s += src[i - k];
   }
   return(s / len);
}

// ta.ema(src, len): semilla = SMA de los primeros len valores validos
double EmaSeeded(const double &src[], const double &out[], const int i, const int len, const double alpha)
{
   if(src[i] == EMPTY_VALUE) return(EMPTY_VALUE);
   if(i > 0 && out[i - 1] != EMPTY_VALUE) return(alpha * src[i] + (1.0 - alpha) * out[i - 1]);
   return(SmaAt(src, i, len));
}

// True Range de Pine
double TrAt(const int i, const double &high[], const double &low[], const double &close[])
{
   if(i <= 0) return(high[0] - low[0]);
   double hl = high[i] - low[i];
   double hc = MathAbs(high[i] - close[i - 1]);
   double lc = MathAbs(low[i]  - close[i - 1]);
   return(MathMax(hl, MathMax(hc, lc)));
}

// ta.atr(len) = ta.rma(ta.tr, len): Wilder con semilla SMA.
// Deliberadamente NO se usa iATR(): el ATR nativo de MT5 es una SMA
// y desviaria los niveles TP1 / TP2 / SL respecto a TradingView.
double RmaTr(const int i, const int len, const double &atr[],
             const double &high[], const double &low[], const double &close[])
{
   if(len < 1 || i < len - 1) return(EMPTY_VALUE);
   double tr = TrAt(i, high, low, close);
   if(i > 0 && atr[i - 1] != EMPTY_VALUE)
      return(atr[i - 1] + (tr - atr[i - 1]) / len);
   double s = 0.0;
   for(int k = 0; k < len; k++)
      s += TrAt(i - len + 1 + k, high, low, close);
   return(s / len);
}

// ta.alma(series, length, offset, sigma)
double AlmaAt(const double &src[], const int i)
{
   int len = ArraySize(gAlmaW);
   if(len < 1 || i < len - 1 || gAlmaSum == 0.0) return(EMPTY_VALUE);
   double s = 0.0;
   for(int k = 0; k < len; k++)
      s += src[i - (len - 1 - k)] * gAlmaW[k];
   return(s / gAlmaSum);
}

//==================================================================== Limpieza y degradado
void ClearUp(const int i)
{
   bUpg0a[i]=EMPTY_VALUE; bUpg0b[i]=EMPTY_VALUE;
   bUpg1a[i]=EMPTY_VALUE; bUpg1b[i]=EMPTY_VALUE;
   bUpg2a[i]=EMPTY_VALUE; bUpg2b[i]=EMPTY_VALUE;
   bUpg3a[i]=EMPTY_VALUE; bUpg3b[i]=EMPTY_VALUE;
}

void ClearDn(const int i)
{
   bDng0a[i]=EMPTY_VALUE; bDng0b[i]=EMPTY_VALUE;
   bDng1a[i]=EMPTY_VALUE; bDng1b[i]=EMPTY_VALUE;
   bDng2a[i]=EMPTY_VALUE; bDng2b[i]=EMPTY_VALUE;
   bDng3a[i]=EMPTY_VALUE; bDng3b[i]=EMPTY_VALUE;
}

// Deja vacios todos los plots de una vela (los de color a indice 0)
void ClearPlots(const int i)
{
   ClearUp(i);
   ClearDn(i);

   bCdlO[i]=EMPTY_VALUE; bCdlH[i]=EMPTY_VALUE; bCdlL[i]=EMPTY_VALUE; bCdlC[i]=EMPTY_VALUE;
   bCdlClr[i]=0.0;

   bRibUa[i]=EMPTY_VALUE; bRibUb[i]=EMPTY_VALUE; bRibDa[i]=EMPTY_VALUE; bRibDb[i]=EMPTY_VALUE;

   bBO[i]=EMPTY_VALUE;    bBOClr[i]=0.0;
   bBC[i]=EMPTY_VALUE;    bBCClr[i]=0.0;
   bUp[i]=EMPTY_VALUE;    bUpClr[i]=0.0;
   bLo[i]=EMPTY_VALUE;    bLoClr[i]=0.0;

   bMkTP1[i]=EMPTY_VALUE; bMkTP2[i]=EMPTY_VALUE; bMkSL[i]=EMPTY_VALUE;
   bBuy[i]=0.0;           bSell[i]=0.0;
}

// Vacía el rango [from, to) de los tres buffers de marcas. Es un GUARD defensivo,
// NO la causa de los puntos/aspas espurias de la ronda 6: aquellas las producía el
// reparto de buffers al cambiar PLOT_DRAW_TYPE (ver la cabecera y HidePlot). Se
// mantiene porque estas tres series no se reescriben en la fase de dibujo y MT5 no
// documenta que las posiciones nuevas de un buffer estén inicializadas.
// Se llama en cada pase antes de que el motor marque los toques reales.
void ClearHitMarks(const int from, const int to)
{
   const int a = MathMax(from, 0);
   const int b = MathMin(to, ArraySize(bMkSL));
   for(int i = a; i < b; i++)
   {
      bMkTP1[i] = EMPTY_VALUE;
      bMkTP2[i] = EMPTY_VALUE;
      bMkSL[i]  = EMPTY_VALUE;
   }
}

// Degradado de 4 capas entre la basis (capa 0) y el precio (capa 3)
void GradUp(const int i, const double px, const double basis)
{
   double d = (px - basis) / 4.0;
   bUpg0a[i] = basis;          bUpg0b[i] = basis + d;
   bUpg1a[i] = basis + d;      bUpg1b[i] = basis + 2.0 * d;
   bUpg2a[i] = basis + 2.0*d;  bUpg2b[i] = basis + 3.0 * d;
   bUpg3a[i] = basis + 3.0*d;  bUpg3b[i] = px;
}

void GradDn(const int i, const double px, const double basis)
{
   double d = (px - basis) / 4.0;
   bDng0a[i] = basis;          bDng0b[i] = basis + d;
   bDng1a[i] = basis + d;      bDng1b[i] = basis + 2.0 * d;
   bDng2a[i] = basis + 2.0*d;  bDng2b[i] = basis + 3.0 * d;
   bDng3a[i] = basis + 3.0*d;  bDng3b[i] = px;
}

//==================================================================== Motor de señales / niveles
void ResetTrade()
{
   gDir = 0; gHasTrade = false; gDone = true; gTp1Hit = false;
   gEntry = 0.0; gSl = 0.0; gTp1 = 0.0; gTp2 = 0.0;
   gEntryBar = -1; gEndBar = -1;
   gTp1Bar = -1; gTp2Bar = -1; gSlBar = -1;
   gEntryTime = 0;
}

// Tipo de marca de toque. Enumerado único para MarkHit (buffer), HitLabel (texto)
// y los plots: el orden de los plots es TP1, TP2, SL (buffers 33/34/35) mientras
// que los glifos no siguen ese orden, y el Pine llama a su plotshape con el nivel
// correspondiente. Con enteros sueltos, invertir dos números cruza el texto con el
// glifo (una etiqueta "TP1" junto a un aspa de SL) sin que el compilador avise.
enum ENUM_HIT_KIND
{
   HIT_SL  = 0,                    // aspa, color Dn
   HIT_TP1 = 1,                    // círculo, Blend(Up, 0.70)
   HIT_TP2 = 2                     // círculo, Up
};

// Nivel del trade vigente que corresponde a la marca
double HitPrice(const ENUM_HIT_KIND kind)
{
   if(kind == HIT_SL)  return(gSl);
   if(kind == HIT_TP1) return(gTp1);
   return(gTp2);
}

// Marcadores TP/SL: se pintan en la vela del toque y PERSISTEN (plotshape del Pine).
// No se borran al abrir el trade siguiente: en la vela con SL + señal nueva el Pine
// dibuja la marca del SL y además abre el trade (ver cabecera, orden de evaluación).
// El valor se escribe SIEMPRE (aunque el flag de Display esté apagado: el plot
// conserva su tipo y sólo se oculta con clrNONE), para que el CSV de paridad no
// dependa de la configuración visual.
void MarkHit(const int i, const ENUM_HIT_KIND kind)
{
   if(i < 0 || i >= ArraySize(bMkSL)) return;
   if(kind == HIT_SL)  { bMkSL[i]  = gSl;  return; }
   if(kind == HIT_TP1) { bMkTP1[i] = gTp1; return; }
   bMkTP2[i] = gTp2;
}

// Nueva señal: niveles desde el cierre de la vela cerrada
void OpenTrade(const int i, const int dir, const double px, const datetime t)
{
   if(dir == 0) return;
   double atr = bAtrSL[i];
   if(IsNa(atr) || atr <= 0.0) return;          // sin ATR no hay niveles (na en Pine)
   gHasTrade  = true;
   gDone      = false;
   gTp1Hit    = false;
   gDir       = dir;
   gEntry     = px;
   gEntryBar  = i;
   gEntryTime = t;
   double r   = atr * InpSlAtrMult;
   gSl        = px - dir * r;
   gTp1       = px + dir * r * InpTp1RR;
   gTp2       = px + dir * r * InpTp2RR;
   gEndBar = -1; gTp1Bar = -1; gTp2Bar = -1; gSlBar = -1;
}

// SL primero; si no toco stop: TP1 (una vez) y TP2.
// El 'return' sale SOLO de este motor: la señal de la misma vela se evalúa después.
void CheckHits(const int i, const double &high[], const double &low[])
{
   if(gDir > 0)
   {
      if(low[i] <= gSl) { gDone = true; gSlBar = i; gEndBar = i; MarkHit(i, HIT_SL); return; }
      if(!gTp1Hit && high[i] >= gTp1) { gTp1Hit = true; gTp1Bar = i; MarkHit(i, HIT_TP1); }
      if(high[i] >= gTp2) { gDone = true; gTp2Bar = i; gEndBar = i; MarkHit(i, HIT_TP2); return; }
   }
   else if(gDir < 0)
   {
      if(high[i] >= gSl) { gDone = true; gSlBar = i; gEndBar = i; MarkHit(i, HIT_SL); return; }
      if(!gTp1Hit && low[i] <= gTp1) { gTp1Hit = true; gTp1Bar = i; MarkHit(i, HIT_TP1); }
      if(low[i] <= gTp2) { gDone = true; gTp2Bar = i; gEndBar = i; MarkHit(i, HIT_TP2); return; }
   }
}

// Flecha + texto BUY / SELL (se crean una vez y persisten)
void SignalLabel(const int i, const int dir, const datetime &time[], const double &high[], const double &low[])
{
   double atr = bAtrLbl[i];
   double off = (IsNa(atr) ? 0.0 : atr) * InpLabelAtrOff;
   // Separación texto-flecha: 0.35 ATR. Con 0.10 el texto se montaba sobre el glifo
   // de la flecha (el texto se ancla en el punto, no en el borde del glifo).
   double gap = (IsNa(atr) ? 0.0 : atr) * 0.35;
   string tag = IntegerToString((long)time[i]);
   string id  = PFX + (dir > 0 ? "buy_" : "sell_") + tag;
   string na  = id + "_a";
   string nt  = id + "_t";
   color  c   = (dir > 0 ? InpUpColor : InpDnColor);

   ObjectDelete(0, na);
   double pa = (dir > 0 ? low[i] - off : high[i] + off);
   if(ObjectCreate(0, na, OBJ_ARROW, 0, time[i], pa))
   {
      ObjectSetInteger(0, na, OBJPROP_ARROWCODE, dir > 0 ? 233 : 234);   // flechas ↑ / ↓
      ObjectSetInteger(0, na, OBJPROP_ANCHOR, dir > 0 ? ANCHOR_TOP : ANCHOR_BOTTOM);
      ObjectSetInteger(0, na, OBJPROP_COLOR, c);
      ObjectSetInteger(0, na, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, na, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, na, OBJPROP_HIDDEN, true);
   }

   ObjectDelete(0, nt);
   double pt = (dir > 0 ? low[i] - off - gap : high[i] + off + gap);
   if(ObjectCreate(0, nt, OBJ_TEXT, 0, time[i], pt))
   {
      ObjectSetString(0, nt, OBJPROP_TEXT, dir > 0 ? "BUY" : "SELL");
      // OBJ_TEXT no tiene flag de negrita: el peso lo da la familia "Arial Black".
      ObjectSetString(0, nt, OBJPROP_FONT, "Arial Black");
      ObjectSetInteger(0, nt, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, nt, OBJPROP_COLOR, c);
      // BUY: texto por DEBAJO de la flecha; SELL: por ENCIMA.
      ObjectSetInteger(0, nt, OBJPROP_ANCHOR, dir > 0 ? ANCHOR_UPPER : ANCHOR_LOWER);
      ObjectSetInteger(0, nt, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nt, OBJPROP_HIDDEN, true);
   }
}

// Etiqueta de periodo equivalente a {{interval}} de TradingView: 15, 60, D, W, M
string TfText()
{
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)Period();
   if(tf == PERIOD_MN1) return("M");
   if(tf == PERIOD_W1)  return("W");
   if(tf == PERIOD_D1)  return("D");
   return(IntegerToString(PeriodSeconds(tf) / 60));
}

// Réplica del alertcondition de la v0.02 (218-219):
//   title   "Nysys Adaptive ALMA BUY"  /  "Nysys Adaptive ALMA SELL"
//   message "Nysys Adaptive ALMA: BUY {{ticker}} {{interval}} close={{close}}"
// {{ticker}} -> _Symbol · {{interval}} -> TfText() · {{close}} -> _Digits
void FireAlert(const int dir, const double px)
{
   const string side = (dir > 0 ? "BUY" : "SELL");
   const string msg  = "Nysys Adaptive ALMA: " + side + " " + _Symbol + " " +
                       TfText() + " close=" + DoubleToString(px, _Digits);
   if(InpAlertPopup) Alert(msg);
   if(InpAlertPush)  SendNotification(msg);
   Print(msg);
}

//==================================================================== Objetos del último trade
void Txt(const string n, const datetime t, const double p, const string text,
         const color c, const int size, const ENUM_ANCHOR_POINT anchor)
{
   ObjectDelete(0, n);
   if(!ObjectCreate(0, n, OBJ_TEXT, 0, t, p)) return;
   ObjectSetString(0, n, OBJPROP_TEXT, text);
   ObjectSetString(0, n, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, n, OBJPROP_COLOR, c);
   ObjectSetInteger(0, n, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
}

// Texto de las marcas TP1 / TP2 / SL. En la v0.02 el texto va DENTRO del plotshape
// (214-216, text = "TP1" / "TP2" / "SL"); DRAW_ARROW no admite texto, así que se
// añade un OBJ_TEXT gris junto a la marca. Se crea en la vela del toque: el motor
// procesa cada vela cerrada una única vez, así que un pase incremental sólo añade
// las marcas nuevas (no duplica); un recálculo completo borra los objetos por
// prefijo en ResetAll y los reconstruye dentro de la ventana VALMA_LABEL_BARS.
void HitLabel(const int i, const ENUM_HIT_KIND kind, const int dir,
              const datetime &time[], const int rates_total)
{
   if(!InpShowHitMarks) return;                       // Pine 214-216: showHitMarkers
   if(i < 0 || i >= rates_total) return;
   if(i < rates_total - VALMA_LABEL_BARS) return;     // mismo límite que BUY / SELL
   double px = HitPrice(kind);
   if(px <= 0.0) return;
   double atr = bAtrLbl[i];
   double gap = (IsNa(atr) ? 0.0 : atr) * 0.10;       // separa el texto de la marca
   // SL en long y TP en short quedan por DEBAJO del precio -> texto bajo la marca
   bool   below = (kind == HIT_SL ? (dir > 0) : (dir < 0));
   double py    = (below ? px - gap : px + gap);
   string txt   = (kind == HIT_SL ? "SL" : (kind == HIT_TP1 ? "TP1" : "TP2"));
   string n     = PFX + "hm_" + IntegerToString((long)time[i]) + "_" + IntegerToString((int)kind);
   Txt(n, time[i], py, txt, TV_GRAY, 7, (below ? ANCHOR_UPPER : ANCHOR_LOWER));
}

void HLine(const string n, const datetime t1, const datetime t2, const double p,
           const color c, const ENUM_LINE_STYLE st, const int w)
{
   ObjectDelete(0, n);
   if(!ObjectCreate(0, n, OBJ_TREND, 0, t1, p, t2, p)) return;
   ObjectSetInteger(0, n, OBJPROP_COLOR, c);
   ObjectSetInteger(0, n, OBJPROP_STYLE, st);
   ObjectSetInteger(0, n, OBJPROP_WIDTH, w);
   ObjectSetInteger(0, n, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
}

void Rect(const string n, const datetime t1, const double p1, const datetime t2,
          const double p2, const color c)
{
   ObjectDelete(0, n);
   if(!ObjectCreate(0, n, OBJ_RECTANGLE, 0, t1, p1, t2, p2)) return;
   ObjectSetInteger(0, n, OBJPROP_COLOR, c);           // relleno = borde: sin borde visible
   ObjectSetInteger(0, n, OBJPROP_FILL, true);
   ObjectSetInteger(0, n, OBJPROP_BACK, true);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
}

void RightPrice(const string n, const datetime t, const double p, const color c)
{
   ObjectDelete(0, n);
   if(!ObjectCreate(0, n, OBJ_ARROW_RIGHT_PRICE, 0, t, p)) return;
   ObjectSetInteger(0, n, OBJPROP_COLOR, c);
   ObjectSetInteger(0, n, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, n, OBJPROP_BACK, false);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
}

void DeleteLevels()
{
   string names[14] = {"lv_win","lv_loss","lv_e","lv_t1","lv_t2","lv_sl",
                       "ar_t2","ar_t1","ar_e","ar_sl","lb_t2","lb_t1","lb_e","lb_sl"};
   for(int k = 0; k < 14; k++) ObjectDelete(0, PFX + names[k]);
}

// Cajas, líneas y etiquetas del ÚLTIMO trade (reemplazan al anterior)
void DrawTradeObjects(const int lastClosed, const datetime &time[], const int rates_total)
{
   DeleteLevels();
   if(!gHasTrade || !InpShowLevels) return;

   datetime x1 = gEntryTime;
   datetime x2;
   if(gDone && gEndBar >= 0 && gEndBar < rates_total)
      x2 = time[gEndBar] + (datetime)PeriodSeconds();   // borde congelado en TP2 / SL
   else
      x2 = TimeAt(lastClosed + 2, time, rates_total);   // se estira con la vela viva
   if(x2 <= x1) x2 = x1 + (datetime)PeriodSeconds();

   double hi = MathMax(gEntry, gTp2);
   double lo = MathMin(gEntry, gTp2);
   Rect(PFX + "lv_win", x1, hi, x2, lo, Blend(InpUpColor, gBg, 0.12));
   hi = MathMax(gEntry, gSl);
   lo = MathMin(gEntry, gSl);
   Rect(PFX + "lv_loss", x1, hi, x2, lo, Blend(InpDnColor, gBg, 0.12));

   // Pine 189: style_dashed, width 2. En MT5 STYLE_DASH / STYLE_DOT sólo se
   // dibujan con width = 1 (con width 2 la línea sale sólida): desviación visual.
   HLine(PFX + "lv_e",  x1, x2, gEntry, TV_ORANGE, STYLE_DASH, 1);
   HLine(PFX + "lv_t1", x1, x2, gTp1, Blend(InpUpColor, gBg, 0.60), STYLE_SOLID, 1);
   HLine(PFX + "lv_t2", x1, x2, gTp2, InpUpColor, STYLE_SOLID, 1);
   HLine(PFX + "lv_sl", x1, x2, gSl, InpDnColor, STYLE_SOLID, 1);

   // etiquetas del lado derecho: solo mientras el trade sigue activo
   if(!InpShowLvlLabels || gDone) return;

   datetime xa = TimeAt(lastClosed + 2, time, rates_total);
   datetime xt = TimeAt(lastClosed + 3, time, rates_total);
   color    c1 = Blend(InpUpColor, gBg, 0.60);
   RightPrice(PFX + "ar_t2", xa, gTp2, InpUpColor);
   RightPrice(PFX + "ar_t1", xa, gTp1, c1);
   RightPrice(PFX + "ar_e",  xa, gEntry, TV_ORANGE);
   RightPrice(PFX + "ar_sl", xa, gSl, InpDnColor);
   Txt(PFX + "lb_t2", xt, gTp2, "TP2 (" + ShortNum(InpTp2RR) + "R) " + DoubleToString(gTp2, _Digits),
       InpUpColor, 7, ANCHOR_LEFT);
   Txt(PFX + "lb_t1", xt, gTp1, "TP1 (" + ShortNum(InpTp1RR) + "R) " + DoubleToString(gTp1, _Digits),
       c1, 7, ANCHOR_LEFT);
   Txt(PFX + "lb_e", xt, gEntry, "ENTRY " + DoubleToString(gEntry, _Digits), TV_ORANGE, 7, ANCHOR_LEFT);
   Txt(PFX + "lb_sl", xt, gSl, "STOP LOSS " + DoubleToString(gSl, _Digits), InpDnColor, 7, ANCHOR_LEFT);
}

//==================================================================== Configuración de plots
void SetPlot(const int plot, const ENUM_DRAW_TYPE type, const string label,
             const int colors, const int width, const bool show_data)
{
   PlotIndexSetInteger(plot, PLOT_DRAW_TYPE, (int)type);
   PlotIndexSetString(plot, PLOT_LABEL, label);
   gPlotLabel[plot] = label;               // MQL5 no tiene PlotIndexGetString
   PlotIndexSetInteger(plot, PLOT_LINE_WIDTH, MathMax(1, width));
   PlotIndexSetDouble(plot, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   if(colors > 0) PlotIndexSetInteger(plot, PLOT_COLOR_INDEXES, colors);
   PlotIndexSetInteger(plot, PLOT_SHOW_DATA, show_data);
}

// Deja un plot invisible SIN tocar su tipo de dibujo: pinta con clrNONE todos sus
// índices de color. Cambiar PLOT_DRAW_TYPE a DRAW_NONE haría que el plot consuma un
// buffer menos y MT5 reasignaría los buffers de todos los plots siguientes (D6).
void HidePlot(const int plot)
{
   const int n = (int)MathMax(PlotIndexGetInteger(plot, PLOT_COLOR_INDEXES), 1);
   for(int k = 0; k < n; k++)
      PlotIndexSetInteger(plot, PLOT_LINE_COLOR, k, clrNONE);
}

// Buffers que consume un plot en el gráfico según su tipo de dibujo: DRAW_COLOR_*
// ocupa valor + índice(s) de color, DRAW_FILLING / DRAW_ZIGZAG dos valores y
// DRAW_NONE uno (por eso DRAW_NONE también desplaza el reparto, aunque no dibuje).
int PlotBufferCount(const ENUM_DRAW_TYPE type)
{
   switch(type)
   {
      case DRAW_NONE:             return(1);
      case DRAW_LINE:             return(1);
      case DRAW_SECTION:          return(1);
      case DRAW_HISTOGRAM:        return(1);
      case DRAW_ARROW:            return(1);
      case DRAW_HISTOGRAM2:       return(2);
      case DRAW_ZIGZAG:           return(2);
      case DRAW_FILLING:          return(2);
      case DRAW_COLOR_LINE:       return(2);
      case DRAW_COLOR_SECTION:    return(2);
      case DRAW_COLOR_HISTOGRAM:  return(2);
      case DRAW_COLOR_ARROW:      return(2);
      case DRAW_COLOR_HISTOGRAM2: return(3);
      case DRAW_COLOR_ZIGZAG:     return(3);
      case DRAW_BARS:             return(4);
      case DRAW_CANDLES:          return(4);
      case DRAW_COLOR_BARS:       return(5);
      case DRAW_COLOR_CANDLES:    return(5);
   }
   return(0);                              // tipo no contemplado -> la aserción falla
}

// Aserción del reparto plot -> buffer: acumula en orden los buffers que consume
// cada plot (como los asigna MT5) y comprueba los índices que lee el EA por
// iCustom, P15/P16/P17 = 33/34/35 (marcas) y P18/P19 = 36/37 (señales). Imprime el
// mapa completo en el log de Expertos para auditarlo con cualquier combinación de
// inputs: con los tipos fijos el mapa NO depende de los inputs.
bool CheckPlotBufferMap()
{
   int want[PL_TOTAL], first[PL_TOTAL], count[PL_TOTAL];
   for(int p = 0; p < PL_TOTAL; p++) { want[p] = -1; first[p] = 0; count[p] = 0; }
   want[PL_TP1M]  = B_MK_TP1;
   want[PL_TP2M]  = B_MK_TP2;
   want[PL_SLM]   = B_MK_SL;
   want[PL_BUYS]  = B_BUYSIG;
   want[PL_SELLS] = B_SELLSIG;

   bool ok  = true;
   int  cur = 0;
   for(int p = 0; p < PL_TOTAL; p++)
   {
      first[p] = cur;
      count[p] = PlotBufferCount((ENUM_DRAW_TYPE)PlotIndexGetInteger(p, PLOT_DRAW_TYPE));
      if(count[p] <= 0) ok = false;
      cur += count[p];
   }

   PrintFormat("ALMA plot map: %d plots / %d buffers (%d de datos + %d de calculo)",
               PL_TOTAL, B_TOTAL, C_ALMA_C, B_TOTAL - C_ALMA_C);
   for(int p = 0; p < PL_TOTAL; p++)
   {
      const ENUM_DRAW_TYPE t   = (ENUM_DRAW_TYPE)PlotIndexGetInteger(p, PLOT_DRAW_TYPE);
      const bool           chk = (want[p] >= 0);
      const bool           hit = (chk && first[p] == want[p]);
      string               exp = "";
      if(chk) exp = StringFormat(hit ? "  esperado %d OK" : "  ESPERADO %d MISMATCH", want[p]);
      if(chk && !hit) ok = false;
      PrintFormat("ALMA  P%-2d %-21s %-21s buf %2d..%2d%s", p,
                  gPlotLabel[p], EnumToString(t),
                  first[p], first[p] + (count[p] > 0 ? count[p] - 1 : 0), exp);
   }
   if(cur != C_ALMA_C)
   {
      PrintFormat("ALMA plot map: %d buffers de datos, se esperaban %d", cur, C_ALMA_C);
      ok = false;
   }
   if(!ok) Print("ALMA: mapa plot->buffer INCORRECTO (PLOT_DRAW_TYPE debe ser fijo)");
   else    Print("ALMA: mapa plot->buffer OK");
   return(ok);
}


// Colores dependientes del fondo del gráfico (MT5 no dibuja alfa)
void ApplyColors()
{
   for(int k = 0; k < 4; k++)
   {
      // Pine 120-121: alfa lineal (45% en el precio -> 0% en la basis). MT5 no
      // dibuja alfa: cada capa toma la opacidad del PUNTO MEDIO de su tramo.
      double a = InpGradOpacity * (k + 0.5) / 4.0;
      color  cu = Blend(InpUpColor, gBg, a);
      color  cd = Blend(InpDnColor, gBg, a);
      // DRAW_FILLING usa el índice 0 o 1 segun el orden de los buffers: ambos iguales
      PlotIndexSetInteger(PL_UPG0 + k, PLOT_LINE_COLOR, 0, cu);
      PlotIndexSetInteger(PL_UPG0 + k, PLOT_LINE_COLOR, 1, cu);
      PlotIndexSetInteger(PL_DNG0 + k, PLOT_LINE_COLOR, 0, cd);
      PlotIndexSetInteger(PL_DNG0 + k, PLOT_LINE_COLOR, 1, cd);
   }
   PlotIndexSetInteger(PL_CDL,  PLOT_LINE_COLOR, 0, InpUpColor);
   PlotIndexSetInteger(PL_CDL,  PLOT_LINE_COLOR, 1, InpDnColor);
   // DRAW_FILLING elige el indice 0/1 segun cual buffer es mayor (OnInit declara
   // PLOT_COLOR_INDEXES = 2 para estos dos plots): los dos indices llevan el MISMO
   // color, si no el caso buf1<buf2 cae en el relleno negro por defecto.
   PlotIndexSetInteger(PL_RIBU, PLOT_LINE_COLOR, 0, InpUpColor);
   PlotIndexSetInteger(PL_RIBU, PLOT_LINE_COLOR, 1, InpUpColor);
   PlotIndexSetInteger(PL_RIBD, PLOT_LINE_COLOR, 0, InpDnColor);
   PlotIndexSetInteger(PL_RIBD, PLOT_LINE_COLOR, 1, InpDnColor);

   for(int p = PL_BO; p <= PL_LOB; p++)          // up / dn / gris (sin tendencia)
   {
      PlotIndexSetInteger(p, PLOT_LINE_COLOR, 0, InpUpColor);
      PlotIndexSetInteger(p, PLOT_LINE_COLOR, 1, InpDnColor);
      PlotIndexSetInteger(p, PLOT_LINE_COLOR, 2, TV_GRAY);
   }
   PlotIndexSetInteger(PL_TP1M, PLOT_LINE_COLOR, 0, Blend(InpUpColor, gBg, 0.70));
   PlotIndexSetInteger(PL_TP2M, PLOT_LINE_COLOR, 0, InpUpColor);
   PlotIndexSetInteger(PL_SLM,  PLOT_LINE_COLOR, 0, InpDnColor);
}

// Recalculo completo: buffers, objetos y estado
void ResetAll(const int rates_total)
{
   // barrido explícito de los buffers de marcas, además de ClearPlots(v) por vela:
   // el terminal no garantiza el contenido inicial de un buffer recién creado.
   ArrayInitialize(bMkTP1, EMPTY_VALUE);
   ArrayInitialize(bMkTP2, EMPTY_VALUE);
   ArrayInitialize(bMkSL,  EMPTY_VALUE);
   for(int i = 0; i < rates_total; i++)
   {
      ClearPlots(i);
      bAlmaC[i]=EMPTY_VALUE;  bAlmaO[i]=EMPTY_VALUE;
      bBasisC[i]=EMPTY_VALUE; bBasisO[i]=EMPTY_VALUE;
      bSmaC[i]=EMPTY_VALUE;   bDev[i]=EMPTY_VALUE;
      bMad[i]=EMPTY_VALUE;    bVol[i]=EMPTY_VALUE;
      bRank[i]=EMPTY_VALUE;   bUpB[i]=EMPTY_VALUE;   bLoB[i]=EMPTY_VALUE;
      bAtrLbl[i]=EMPTY_VALUE; bAtrSL[i]=EMPTY_VALUE;
      bTrend[i]=0.0;
      bLvlE[i]=EMPTY_VALUE;  bLvlSl[i]=EMPTY_VALUE;
      bLvlTp1[i]=EMPTY_VALUE; bLvlTp2[i]=EMPTY_VALUE;
      bPosDir[i]=0.0;
   }
   ObjectsDeleteAll(0, PFX);
   ResetTrade();
   gProcBar     = -1;
   gLastDrawBar = -1;
   gLastAlert   = 0;
   gLastDump    = 0;                        // recalculo completo -> reescribe el CSV live
   gDumpNow     = false;
   gIncBars     = 0;                        // el pase completo no es camino incremental
   gResetTime   = 0;                        // lo fija OnCalculate con la hora de la vela
}

//==================================================================== OnInit
int OnInit()
{
   // ---- validaciones (minval del Pine 27-66; MQL5 inputs no los tienen)
   // basisLength>=1 · almaOffset 0..1 · almaSigma>=0.1 · basisSmoothing>=1
   // volLength>=1 · volSmoothLength>=1 · volRankLookback>=2 · madScale>=0.0001
   // minMult>=0.001 · maxMult>=0.001 · labelAtrLen>=1 · slAtrLen>=1
   // Extras de seguridad del port (el Pine no los restringe): TP2 >= TP1,
   // ATR mult > 0, RR > 0, opacidad 0..1.
   if(InpBasisLength < 1 || InpBasisSmooth < 1 || InpVolLength < 1 || InpVolSmooth < 1 ||
      InpRankLookback < 2 || InpLabelAtrLen < 1 || InpSlAtrLen < 1 ||
      InpAlmaOffset < 0.0 || InpAlmaOffset > 1.0 || InpAlmaSigma < 0.1 ||
      InpMadScale < 0.0001 || InpMinMult < 0.001 || InpMaxMult < 0.001 ||
      InpMaxMult < InpMinMult || InpSlAtrMult <= 0.0 ||
      InpTp1RR <= 0.0 || InpTp2RR < InpTp1RR ||
      InpLabelAtrOff < 0.0 || InpGradOpacity < 0.0 || InpGradOpacity > 1.0)
   {
      Print("Velocity ALMA: parametros invalidos (offset 0..1, sigma >= 0.1, ",
            "MAD >= 0.0001, mult >= 0.001, longitudes >= 1, TP2 >= TP1, opacidad 0..1)");
      return(INIT_PARAMETERS_INCORRECT);
   }

   // ---- pesos del ALMA: w[k] = exp(-(k - m)^2 / (2 s^2)), m = offset*(len-1), s = len/sigma
   // m SIN floor: ta.alma de TradingView no redondea (verificado con FX:EURUSD 1D:
   // el modelo con floor se desvia 1.1e-3, el modelo sin floor coincide a 1e-13).
   int L = InpBasisLength;
   ArrayResize(gAlmaW, L);
   gAlmaSum = 0.0;
   double mm = InpAlmaOffset * (L - 1);
   double ss = (double)L / InpAlmaSigma;
   for(int k = 0; k < L; k++)
   {
      double x = (double)k - mm;
      gAlmaW[k] = MathExp(-(x * x) / (2.0 * ss * ss));
      gAlmaSum += gAlmaW[k];
   }
   gAlphaBasis = 2.0 / (InpBasisSmooth + 1.0);
   gAlphaVol   = 2.0 / (InpVolSmooth + 1.0);
   gMinBars    = MathMax(L + InpBasisSmooth,
                         2 * InpVolLength - 1 + InpVolSmooth)
                 + InpRankLookback + MathMax(InpLabelAtrLen, InpSlAtrLen) + 4;

   // ---- buffers de dibujo (el orden fija el índice de plot: 0..19)
   SetIndexBuffer(B_UPG0A,   bUpg0a,   INDICATOR_DATA);
   SetIndexBuffer(B_UPG0B,   bUpg0b,   INDICATOR_DATA);
   SetIndexBuffer(B_UPG1A,   bUpg1a,   INDICATOR_DATA);
   SetIndexBuffer(B_UPG1B,   bUpg1b,   INDICATOR_DATA);
   SetIndexBuffer(B_UPG2A,   bUpg2a,   INDICATOR_DATA);
   SetIndexBuffer(B_UPG2B,   bUpg2b,   INDICATOR_DATA);
   SetIndexBuffer(B_UPG3A,   bUpg3a,   INDICATOR_DATA);
   SetIndexBuffer(B_UPG3B,   bUpg3b,   INDICATOR_DATA);
   SetIndexBuffer(B_DNG0A,   bDng0a,   INDICATOR_DATA);
   SetIndexBuffer(B_DNG0B,   bDng0b,   INDICATOR_DATA);
   SetIndexBuffer(B_DNG1A,   bDng1a,   INDICATOR_DATA);
   SetIndexBuffer(B_DNG1B,   bDng1b,   INDICATOR_DATA);
   SetIndexBuffer(B_DNG2A,   bDng2a,   INDICATOR_DATA);
   SetIndexBuffer(B_DNG2B,   bDng2b,   INDICATOR_DATA);
   SetIndexBuffer(B_DNG3A,   bDng3a,   INDICATOR_DATA);
   SetIndexBuffer(B_DNG3B,   bDng3b,   INDICATOR_DATA);
   SetIndexBuffer(B_CDL_O,   bCdlO,    INDICATOR_DATA);
   SetIndexBuffer(B_CDL_H,   bCdlH,    INDICATOR_DATA);
   SetIndexBuffer(B_CDL_L,   bCdlL,    INDICATOR_DATA);
   SetIndexBuffer(B_CDL_C,   bCdlC,    INDICATOR_DATA);
   SetIndexBuffer(B_CDL_CLR, bCdlClr,  INDICATOR_COLOR_INDEX);
   SetIndexBuffer(B_RIBU_A,  bRibUa,   INDICATOR_DATA);
   SetIndexBuffer(B_RIBU_B,  bRibUb,   INDICATOR_DATA);
   SetIndexBuffer(B_RIBD_A,  bRibDa,   INDICATOR_DATA);
   SetIndexBuffer(B_RIBD_B,  bRibDb,   INDICATOR_DATA);
   SetIndexBuffer(B_BO,      bBO,      INDICATOR_DATA);
   SetIndexBuffer(B_BO_CLR,  bBOClr,   INDICATOR_COLOR_INDEX);
   SetIndexBuffer(B_BC,      bBC,      INDICATOR_DATA);
   SetIndexBuffer(B_BC_CLR,  bBCClr,   INDICATOR_COLOR_INDEX);
   SetIndexBuffer(B_UPBAND,  bUp,      INDICATOR_DATA);
   SetIndexBuffer(B_UPBAND_CLR, bUpClr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(B_LOBAND,  bLo,      INDICATOR_DATA);
   SetIndexBuffer(B_LOBAND_CLR, bLoClr, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(B_MK_TP1,  bMkTP1,   INDICATOR_DATA);
   SetIndexBuffer(B_MK_TP2,  bMkTP2,   INDICATOR_DATA);
   SetIndexBuffer(B_MK_SL,   bMkSL,    INDICATOR_DATA);
   SetIndexBuffer(B_BUYSIG,  bBuy,     INDICATOR_DATA);
   SetIndexBuffer(B_SELLSIG, bSell,    INDICATOR_DATA);

   // ---- buffers de cálculo
   SetIndexBuffer(C_ALMA_C,  bAlmaC,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(C_ALMA_O,  bAlmaO,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(C_BASIS_C, bBasisC,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(C_BASIS_O, bBasisO,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(C_SMA_C,   bSmaC,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(C_DEV,     bDev,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(C_MAD,     bMad,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(C_VOL,     bVol,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(C_RANK,    bRank,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(C_UPB,     bUpB,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(C_LOB,     bLoB,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(C_ATR_LBL, bAtrLbl,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(C_ATR_SL,  bAtrSL,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(C_TREND,   bTrend,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(C_LVL_E,   bLvlE,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(C_LVL_SL,  bLvlSl,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(C_LVL_TP1, bLvlTp1,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(C_LVL_TP2, bLvlTp2,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(C_POSDIR,  bPosDir,  INDICATOR_CALCULATIONS);

   // ---- configuración de plots. El TIPO de cada plot es FIJO: cambiarlo en
   // runtime cambia cuántos buffers consume el plot y MT5 reasigna los buffers de
   // todos los siguientes (ver D6 en la cabecera). La visibilidad se resuelve por
   // color (HidePlot), nunca con DRAW_NONE.
   SetPlot(PL_UPG0, DRAW_FILLING, "Gradient Up 1",   2, 1, false);
   SetPlot(PL_UPG1, DRAW_FILLING, "Gradient Up 2",   2, 1, false);
   SetPlot(PL_UPG2, DRAW_FILLING, "Gradient Up 3",   2, 1, false);
   SetPlot(PL_UPG3, DRAW_FILLING, "Gradient Up 4",   2, 1, false);
   SetPlot(PL_DNG0, DRAW_FILLING, "Gradient Dn 1",   2, 1, false);
   SetPlot(PL_DNG1, DRAW_FILLING, "Gradient Dn 2",   2, 1, false);
   SetPlot(PL_DNG2, DRAW_FILLING, "Gradient Dn 3",   2, 1, false);
   SetPlot(PL_DNG3, DRAW_FILLING, "Gradient Dn 4",   2, 1, false);

   SetPlot(PL_CDL,  DRAW_COLOR_CANDLES, "Candle color", 2, 1, false);

   // DRAW_FILLING necesita DOS índices de color: el 0 cuando buf1 > buf2 y el 1
   // cuando buf1 < buf2. Con colors = 0 el plot se queda con un único índice, el
   // índice 1 no existe y ese caso se pinta en negro -> la cinta parece un hueco
   // negro entre dos líneas. ApplyColors() deja los DOS índices con el color de
   // la tendencia (P9 = Up, P10 = Dn), así que el relleno ya no cambia de color.
   SetPlot(PL_RIBU, DRAW_FILLING, "Ribbon fill Up",   2, 1, false);
   SetPlot(PL_RIBD, DRAW_FILLING, "Ribbon fill Dn",   2, 1, false);

   SetPlot(PL_BO,   DRAW_COLOR_LINE, "Basis Open",   3, 4, true);   // Pine: linewidth = 4
   SetPlot(PL_BC,   DRAW_COLOR_LINE, "Basis Close",  3, 4, true);   // Pine: linewidth = 4
   SetPlot(PL_UPB,  DRAW_COLOR_LINE, "Upper Band",   3, 1, true);
   SetPlot(PL_LOB,  DRAW_COLOR_LINE, "Lower Band",   3, 1, true);

   // Pine 113-114 / 122-123: el color pasa a na con el flag apagado, pero el
   // plot CONSERVA sus valores (Data Window: "Outputs for other scripts").
   // En MT5 eso se hace con clrNONE (HidePlot, tras ApplyColors), NUNCA con
   // DRAW_NONE: cambiar el tipo en runtime mueve el reparto de buffers (D6).

   SetPlot(PL_TP1M, DRAW_ARROW, "TP1 Hit Marker",      0, 1, false);
   SetPlot(PL_TP2M, DRAW_ARROW, "TP2 Hit Marker",      0, 1, false);
   SetPlot(PL_SLM,  DRAW_ARROW, "Stop Loss Hit Marker", 0, 1, false);
   // Pine 214-216: showHitMarkers apaga la marca (na), no el estado del trade.
   // La marca se apaga por COLOR (HidePlot); el tipo del plot DRAW_ARROW es fijo.
   // Glifos Wingdings: 108 = círculo relleno (marca de TP1/TP2, como el plotshape
   // de TV), 251 = aspa (SL). El texto lo pone HitLabel con el mismo ENUM_HIT_KIND.
   PlotIndexSetInteger(PL_TP1M, PLOT_ARROW, 108);
   PlotIndexSetInteger(PL_TP2M, PLOT_ARROW, 108);
   PlotIndexSetInteger(PL_SLM,  PLOT_ARROW, 251);

   SetPlot(PL_BUYS,  DRAW_NONE, "Buy Signal",        0, 1, true);
   SetPlot(PL_SELLS, DRAW_NONE, "Sell Signal",       0, 1, true);

   // ---- fondo, colores y encabezado
   gBg = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   ApplyColors();
   // ---- visibilidad: SIEMPRE después de ApplyColors (que fija los colores) ----
   // Ocultar = pintar con clrNONE. El tipo de dibujo y el buffer no cambian: el
   // valor sigue en Data Window / iCustom / CSV, como el color na del Pine.
   if(!InpShowRibbon)   { HidePlot(PL_BO);  HidePlot(PL_BC); }
   if(!InpShowBands)    { HidePlot(PL_UPB); HidePlot(PL_LOB); }
   if(!InpShowHitMarks) { HidePlot(PL_TP1M); HidePlot(PL_TP2M); HidePlot(PL_SLM); }
   // Con ColorCandles el indicador debe ir SOBRE el gráfico para que se vean las velas
   // recoloreadas; sin él el gráfico va encima de los plots (rellenos detrás del precio).
   // El valor original del gráfico se guarda y se devuelve tal cual en OnDeinit.
   gFgOrig  = (bool)ChartGetInteger(0, CHART_FOREGROUND);
   gFgSaved = true;
   ChartSetInteger(0, CHART_FOREGROUND, InpColorCandles ? false : true);

   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("Nysys Adaptive ALMA v%s (%d,%.2f,%.1f | %d/%d | %d,%.2f)",
                   VALMA_VERSION, InpBasisLength, InpAlmaOffset, InpAlmaSigma,
                   InpBasisSmooth, InpVolLength, InpVolSmooth, InpSlAtrMult, InpTp1RR));
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   // Aserción del reparto plot -> buffer (D6): si el mapa no es el esperado el
   // indicador no carga, en vez de dibujar una serie con el plot de otra.
   if(!CheckPlotBufferMap()) return(INIT_FAILED);

   return(INIT_SUCCEEDED);
}

//==================================================================== OnDeinit
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, PFX);
   // devuelve el gráfico como estaba antes de cargar el indicador
   if(gFgSaved) ChartSetInteger(0, CHART_FOREGROUND, gFgOrig);
   gFgSaved = false;
   ChartRedraw(0);
}

//==================================================================== CSV live de paridad
// Escribe velocity_alma_live_<sym>_<tf>.csv con las MISMAS 19 columnas que el
// script Velocity_ALMA_ParityExport (velocity_alma_full_<sym>_<tf>.csv).
// Los valores salen de los buffers que este indicador mantiene de forma
// INCREMENTAL, de modo que comparar por time_server verifica el camino
// incremental contra el recálculo completo. Nunca se exporta la vela viva.
void DumpLiveCsv(const int rates_total, const datetime &time[], const double &open[],
                 const double &high[], const double &low[], const double &close[])
{
   const int last = rates_total - 2;                  // última vela CERRADA
   if(last < 0) return;
   const int bars = MathMax(InpDumpBars, 2);
   const int from = MathMax(0, last - bars + 1);
   const string name = StringFormat("velocity_alma_live_%s_%s.csv", _Symbol,
                                    EnumToString((ENUM_TIMEFRAMES)Period()));
   const int h = ValmaCsvOpen(name);
   if(h == INVALID_HANDLE)
   {
      PrintFormat("ALMA dump: FileOpen(%s) failed, error=%d", name, GetLastError());
      return;
   }
   ValmaCsvWrite(h, ValmaCsvHeader());
   // Metadatos del camino incremental: el script sólo puede declarar PASS si
   // las filas comparadas posteriores a reset_time llegan a 3.
   ValmaCsvWrite(h, ValmaCsvMetaLine(gResetTime, gIncBars));
   double f[VC_FIELDS];
   for(int i = from; i <= last; i++)
   {
      f[VC_OPEN]    = open[i];
      f[VC_HIGH]    = high[i];
      f[VC_LOW]     = low[i];
      f[VC_CLOSE]   = close[i];
      f[VC_BASIS_C] = bBasisC[i];
      f[VC_BASIS_O] = bBasisO[i];
      f[VC_UPPER]   = bUpB[i];
      f[VC_LOWER]   = bLoB[i];
      f[VC_BUY]     = bBuy[i];
      f[VC_SELL]    = bSell[i];
      f[VC_TP1H]    = bMkTP1[i];
      f[VC_TP2H]    = bMkTP2[i];
      f[VC_SLH]     = bMkSL[i];
      f[VC_ENTRY]   = bLvlE[i];
      f[VC_SL]      = bLvlSl[i];
      f[VC_TP1]     = bLvlTp1[i];
      f[VC_TP2]     = bLvlTp2[i];
      f[VC_POSDIR]  = bPosDir[i];
      // diagnóstico de la cadena de volatilidad (columnas al final)
      f[VC_DEV]     = bDev[i];
      f[VC_MADR]    = bMad[i];
      f[VC_VOL]     = bVol[i];
      f[VC_RANK]    = bRank[i];
      ValmaCsvWrite(h, ValmaCsvRow(time[i], f, VALMA_CSV_DECIMALS));
   }
   FileClose(h);
   PrintFormat("ALMA dump: %s rows=%d (%s .. %s) reset=%s inc_bars=%d", name, last - from + 1,
               TimeToString(time[from], TIME_DATE | TIME_MINUTES),
               TimeToString(time[last], TIME_DATE | TIME_MINUTES),
               TimeToString(gResetTime, TIME_DATE | TIME_MINUTES), gIncBars);
}

// Tecla D sobre el gráfico: fuerza el volcado en el siguiente pase de OnCalculate
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(!InpDumpCsv || id != CHARTEVENT_KEYDOWN) return;
   if(sparam == "D" || sparam == "d") gDumpNow = true;
}

//==================================================================== OnCalculate
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[], const double &close[],
                const long &tick_volume[], const long &volume[], const int &spread[])
{
   if(rates_total < gMinBars)
   {
      ClearHitMarks(0, rates_total);   // historial corto: guard, ver ClearHitMarks
      return(0);
   }

   // primer pase, historial recargado o desplazado -> recalculo completo.
   // Un reset invalida el camino incremental: se avisa en el log y el CSV live
   // lo publica en su línea de metadatos (#reset_time / inc_bars).
   bool didReset = false;
   if(prev_calculated <= 0 || prev_calculated > rates_total)
   {
      ResetAll(rates_total);
      didReset   = true;
      gResetTime = time[rates_total - 2];              // hora de la última vela cerrada
      Print("ALMA RESET at ", TimeToString(gResetTime, TIME_DATE | TIME_MINUTES));
   }

   int start = (prev_calculated > 0 ? MathMax(prev_calculated - 1, 0) : 0);
   int lastClosed = rates_total - 2;                 // última vela CERRADA

   // Guard de marcas (ver ClearHitMarks). INVARIANTE: el motor sólo repasa
   // [gProcBar+1, lastClosed]; una marca escrita en una vela <= gProcBar no se
   // vuelve a escribir en este pase, así que el barrido arranca en
   // max(start, gProcBar+1) —gProcBar se lee ANTES de avanzar el motor— para no
   // borrar marcas de velas ya procesadas que el motor no va a repasar.
   ClearHitMarks(MathMax(start, gProcBar + 1), rates_total);

   // ================= fase 1: series base =================
   for(int i = start; i < rates_total; i++)
   {
      // cadena de volatilidad del Pine v0.02 (73-74) EN ESTE ORDEN:
      //   dev    = |close - SMA(close, VolLength)|   (SMA interior)
      //   madRaw = SMA(dev, VolLength)               (SMA exterior, Pine 73)
      //   vol    = EMA(madRaw, VolSmooth)            (Pine 74)
      // La SMA exterior NO es opcional: sin ella vol (y con el la mitad de banda)
      // se adelanta ~2 velas y las bandas dejan de coincidir con TradingView.
      double sma  = SmaAt(close, i, InpVolLength);
      bSmaC[i]    = sma;
      bDev[i]     = (sma == EMPTY_VALUE ? EMPTY_VALUE : MathAbs(close[i] - sma));
      bMad[i]     = SmaAt(bDev, i, InpVolLength);          // madRaw
      bVol[i]     = EmaSeeded(bMad, bVol, i, InpVolSmooth, gAlphaVol);

      bAlmaC[i]   = AlmaAt(close, i);
      bAlmaO[i]   = AlmaAt(open,  i);
      bBasisC[i]  = EmaSeeded(bAlmaC, bBasisC, i, InpBasisSmooth, gAlphaBasis);
      bBasisO[i]  = EmaSeeded(bAlmaO, bBasisO, i, InpBasisSmooth, gAlphaBasis);

      bAtrLbl[i]  = RmaTr(i, InpLabelAtrLen, bAtrLbl, high, low, close);
      bAtrSL[i]   = RmaTr(i, InpSlAtrLen,   bAtrSL,  high, low, close);

      // volRank = fracción de las últimas RankLookback volatilidades que son <= vol[i]
      if(bVol[i] == EMPTY_VALUE || i < InpRankLookback)
         bRank[i] = EMPTY_VALUE;
      else
      {
         int cnt = 0;
         for(int k = 1; k <= InpRankLookback; k++)
            if(bVol[i - k] != EMPTY_VALUE && bVol[i - k] <= bVol[i]) cnt++;
         bRank[i] = (double)cnt / (double)InpRankLookback;
      }

      // bandas adaptativas: half = MadScale * vol * multiplicador (Pine 87-88)
      if(bBasisC[i] == EMPTY_VALUE || bVol[i] == EMPTY_VALUE || bRank[i] == EMPTY_VALUE)
      {
         bUpB[i] = EMPTY_VALUE;
         bLoB[i] = EMPTY_VALUE;
      }
      else
      {
         double mult = InpMinMult;
         if(InpAdaptive) mult = InpMinMult + (InpMaxMult - InpMinMult) * bRank[i];
         double half = InpMadScale * bVol[i] * mult;
         bUpB[i] = bBasisC[i] + half;
         bLoB[i] = bBasisC[i] - half;
      }
   }

   // ========== fase 2: tendencia, niveles y señales (SOLO velas cerradas) ==========
   int procFrom = MathMax(gProcBar + 1, gMinBars);
   if(InpDebugLog)
      PrintFormat("ALMA inc: prev=%d rates=%d procFrom=%d lastClosed=%d dir=%d done=%d tp1Bar=%d tp2Bar=%d slBar=%d",
                  prev_calculated, rates_total, procFrom, lastClosed, gDir, (int)gDone,
                  gTp1Bar, gTp2Bar, gSlBar);
   int processed = 0;
   for(int i = procFrom; i <= lastClosed; i++)
   {
      processed++;
      // upCross / dnCross del Pine: el cierre cruza la banda y la banda de la vela
      // anterior existe (not na(band[1])). Sin cruce se conserva la tendencia previa.
      bool upX = (bUpB[i] != EMPTY_VALUE && bUpB[i - 1] != EMPTY_VALUE &&
                  close[i] > bUpB[i] && close[i - 1] <= bUpB[i - 1]);
      bool dnX = (bLoB[i] != EMPTY_VALUE && bLoB[i - 1] != EMPTY_VALUE &&
                  close[i] < bLoB[i] && close[i - 1] >= bLoB[i - 1]);
      double tr = bTrend[i - 1];
      if(upX)      tr =  1.0;
      else if(dnX) tr = -1.0;
      bTrend[i] = tr;

      // 1) el rango de ESTA vela puede tocar los niveles del trade vigente.
      //    Pine 145: 'bar_index > tBar' -> nunca en la vela de entrada.
      //    El 'return' interno de SL sale solo de CheckHits.
      if(gHasTrade && !gDone && i > gEntryBar) CheckHits(i, high, low);

      // texto de las marcas del plotshape (Pine 214-216). Se crea en la vela del
      // toque: el motor procesa cada vela cerrada una única vez, así que el pase
      // incremental sólo añade marcas nuevas (no duplica) y el recálculo completo
      // las reconstruye todas (ResetAll borra los objetos por prefijo PFX).
      if(gSlBar  == i) HitLabel(i, HIT_SL,  gDir, time, rates_total);
      if(gTp1Bar == i) HitLabel(i, HIT_TP1, gDir, time, rates_total);
      if(gTp2Bar == i) HitLabel(i, HIT_TP2, gDir, time, rates_total);

      // 2) la señal de la MISMA vela se evalúa siempre, aunque el hit haya cerrado
      //    el trade anterior: el trade nuevo abre en esta vela (orden del Pine v0.02).
      bool buy  = (tr ==  1.0 && bTrend[i - 1] !=  1.0);
      bool sell = (tr == -1.0 && bTrend[i - 1] != -1.0);
      bBuy[i]  = (buy  ? 1.0 : 0.0);
      bSell[i] = (sell ? 1.0 : 0.0);

      if(buy || sell)
      {
         int dir = (buy ? 1 : -1);
         OpenTrade(i, dir, close[i], time[i]);
         if(InpShowSignals && i >= rates_total - VALMA_LABEL_BARS)
            SignalLabel(i, dir, time, high, low);
         // alertas solo en vivo: el historial ya calculado no avisa
         if(prev_calculated > 0 && time[i] != gLastAlert)
         {
            gLastAlert = time[i];
            FireAlert(dir, close[i]);
         }
      }

      // 3) niveles del trade que cubre esta vela (incluye la vela donde cierra)
      if(gHasTrade && i >= gEntryBar && (gEndBar < 0 || i <= gEndBar))
      {
         bLvlE[i]   = gEntry;
         bLvlSl[i]  = gSl;
         bLvlTp1[i] = gTp1;
         bLvlTp2[i] = gTp2;
         bPosDir[i] = (gDone ? 0.0 : (double)gDir);
      }
      else
      {
         bLvlE[i] = EMPTY_VALUE;  bLvlSl[i]  = EMPTY_VALUE;
         bLvlTp1[i] = EMPTY_VALUE; bLvlTp2[i] = EMPTY_VALUE;
         bPosDir[i] = 0.0;
      }
   }
   gProcBar = lastClosed;
   // Velas cerradas por el camino INCREMENTAL: el pase que hizo ResetAll no cuenta
   // (recalculó todo el historial de golpe).
   if(didReset) gIncBars = 0;
   else         gIncBars += processed;
   if(InpDebugLog && processed > 0)
      PrintFormat("ALMA inc: %d velas procesadas (%s .. %s) dir=%d done=%d inc_bars=%d",
                  processed, TimeToString(time[procFrom], TIME_DATE | TIME_MINUTES),
                  TimeToString(time[lastClosed], TIME_DATE | TIME_MINUTES), gDir, (int)gDone,
                  gIncBars);

   // ========== CSV live: una vez por vela cerrada (o al pulsar D) ==========
   if(InpDumpCsv && (gDumpNow || time[lastClosed] != gLastDump))
   {
      DumpLiveCsv(rates_total, time, open, high, low, close);
      gLastDump = time[lastClosed];
      gDumpNow  = false;
   }

   // ========== fase 3: dibujo (la vela viva solo mueve degradado, cinta y bandas) ==========
   for(int i = start; i < rates_total; i++)
   {
      double bc = bBasisC[i];
      double bo = bBasisO[i];
      double px = close[i];
      double tr = bTrend[i];
      // la vela en formación aún no tiene tendencia evaluada: hereda el color
      if(i > lastClosed && i > 0) tr = bTrend[i - 1];
      bool   ok = (bc != EMPTY_VALUE);

      ClearUp(i);
      ClearDn(i);
      if(InpShowRibbon && ok && tr != 0.0)
      {
         if(tr > 0.0) GradUp(i, px, bc);
         else         GradDn(i, px, bc);
      }

      // velas recoloreadas (tapan a las del gráfico). Pine 124:
      // barcolor(colorCandles and trend != 0)
      if(InpColorCandles && tr != 0.0)
      {
         bCdlO[i] = open[i]; bCdlH[i] = high[i]; bCdlL[i] = low[i]; bCdlC[i] = px;
         bCdlClr[i] = (tr > 0.0 ? 0.0 : 1.0);
      }
      else
      {
         bCdlO[i]=EMPTY_VALUE; bCdlH[i]=EMPTY_VALUE;
         bCdlL[i]=EMPTY_VALUE; bCdlC[i]=EMPTY_VALUE;
         bCdlClr[i]=0.0;
      }

      // cinta: relleno entre Basis Open y Basis Close del color de la tendencia
      // (Pine 113-115). Sólo existe si las dos basis están calculadas.
      if(InpShowRibbon && tr != 0.0 && bo != EMPTY_VALUE && ok)
      {
         bool u = (tr > 0.0);
         bRibUa[i] = (u ? bo : EMPTY_VALUE);
         bRibUb[i] = (u ? bc : EMPTY_VALUE);
         bRibDa[i] = (u ? EMPTY_VALUE : bo);
         bRibDb[i] = (u ? EMPTY_VALUE : bc);
      }
      else
      {
         bRibUa[i]=EMPTY_VALUE; bRibUb[i]=EMPTY_VALUE;
         bRibDa[i]=EMPTY_VALUE; bRibDb[i]=EMPTY_VALUE;
      }

      // líneas: índice 0 = up, 1 = dn, 2 = gris (sin tendencia).
      // Los valores se escriben siempre (Data Window / CSV de paridad); si el
      // flag de Display está apagado el plot se oculta con clrNONE (HidePlot).
      double ci = (tr > 0.0 ? 0.0 : (tr < 0.0 ? 1.0 : 2.0));
      bBO[i] = (bo == EMPTY_VALUE ? EMPTY_VALUE : bo);  bBOClr[i] = ci;
      bBC[i] = (ok ? bc : EMPTY_VALUE);                 bBCClr[i] = ci;
      bUp[i] = (bUpB[i] == EMPTY_VALUE ? EMPTY_VALUE : bUpB[i]); bUpClr[i] = ci;
      bLo[i] = (bLoB[i] == EMPTY_VALUE ? EMPTY_VALUE : bLoB[i]); bLoClr[i] = ci;

      // Las marcas TP1/TP2/SL se escriben en el motor de hits (fase 2) y PERSISTEN.
      // Aquí no se tocan: borrarlas eliminaría el historial de toques (plotshape Pine).
   }

   // ========== fase 4: objetos del último trade (solo al cerrar vela) ==========
   if(lastClosed != gLastDrawBar)
   {
      DrawTradeObjects(lastClosed, time, rates_total);
      gLastDrawBar = lastClosed;
   }

   return(rates_total);
}












