//+------------------------------------------------------------------+
//|  Velocity_ALMA_ParityExport.mq5                                  |
//|  Export + comparación de paridad del port MQL5 de "Velocity ALMA" |
//|  v0.02 (Pine v5, 219 líneas). Read-only: nunca envía órdenes.     |
//|                                                                  |
//|  1) iCustom(...) = instancia NUEVA del indicador -> recalculo      |
//|     COMPLETO desde el inicio del historial. Escribe                |
//|     velocity_alma_full_<sym>_<tf>.csv (23 columnas: las 19 de       |
//|     paridad + dev, mad_raw, vol, vol_rank de diagnóstico).           |
//|  2) Compara ese archivo con velocity_alma_live_<sym>_<tf>.csv,     |
//|     que escribe el PROPIO INDICADOR adjunto al gráfico al cerrar    |
//|     cada vela (input InpDumpCsv = true) leyendo sus buffers        |
//|     INCREMENTALES. Esa es la única forma de ejercitar el camino    |
//|     incremental: iCustom siempre recalcula todo.                   |
//|  3) Comparación por time_server sobre las velas CERRADAS presentes  |
//|     en ambos archivos (ninguno de los dos exporta la vela viva).    |
//|     Criterio: 0 filas distintas EN EL CAMINO INCREMENTAL y >= 3      |
//|     velas comparadas ahí. El live publica en su cabecera            |
//|     #reset_time=<hora>;inc_bars=<n>; todo time_server posterior a   |
//|     reset_time vino del camino incremental (un recálculo completo   |
//|     reinicia el contador y reescribe el CSV: esas filas no cuentan). |
//|     Si no hay metadatos o hay < 3 filas incrementales -> INCONCLUSO. |
//|     Toda diferencia se reporta con hora y columna.                   |
//|                                                                  |
//|  Nota: ya NO se usa la huella FNV sobre "las primeras N filas":    |
//|  con InpBars fijo, dos corridas separadas por velas nuevas          |
//|  exportan ventanas desplazadas y esas filas no son las mismas       |
//|  velas. La comparación por time_server es la válida.                |
//+------------------------------------------------------------------+
#property script_show_inputs

#include <Nysys/VelocityAlmaCsv.mqh>

input int  InpBars    = 500;    // velas cerradas a exportar (ventana del full)
input bool InpCompare = true;   // comparar full vs live por time_server

// Copia un buffer del indicador en orden temporal (0 = vela más antigua)
bool CopyOne(const int handle, const int index, const int count, double &dst[])
{
   ArraySetAsSeries(dst, false);
   return(CopyBuffer(handle, index, 1, count, dst) == count);
}

// velocity_alma_<prefix>_<sym>_<tf>.csv
string CsvName(const string prefix)
{
   return(StringFormat("velocity_alma_%s_%s_%s.csv", prefix, _Symbol,
                       EnumToString((ENUM_TIMEFRAMES)_Period)));
}

//==================================================================== comparación
void CompareLive(const string liveName, const string fullName)
{
   string lt[], ll[], ft[], fl[];
   if(!ValmaCsvLoad(liveName, lt, ll))
   {
      PrintFormat("ALMA parity: no existe %s -> activa InpDumpCsv en el indicador, "
                  "dejalo >= 3 velas cerradas (o pulsa D en el grafico) y repite.",
                  liveName);
      return;
   }
   if(!ValmaCsvLoad(fullName, ft, fl))
   {
      PrintFormat("ALMA parity: no se pudo leer %s", fullName);
      return;
   }

   // Metadatos del live: desde qué vela (reset_time) y cuántas velas cerradas
   // lleva procesadas por el camino INCREMENTAL. Sin ellos no hay PASS posible.
   datetime resetTime = 0;
   int      incMeta   = -1;
   const bool   hasMeta  = ValmaCsvMeta(liveName, resetTime, incMeta);
   const string resetStr = (hasMeta && resetTime > 0
                            ? TimeToString(resetTime, TIME_DATE | TIME_MINUTES) : "");
   if(resetStr == "")
      Print("ALMA parity: el CSV live no trae #reset_time (dump de una version "
            "anterior del indicador): regeneralo antes de aceptar un PASS.");

   const int nl = ArraySize(lt), nf = ArraySize(ft);
   int colDiff[VALMA_CSV_COLUMNS];
   ArrayInitialize(colDiff, 0);

   int matched = 0, differing = 0, onlyLive = 0, onlyFull = 0;
   int incRows = 0, incDiff = 0;              // filas comparadas del camino incremental
   string firstT = "", firstCol = "", firstL = "", firstF = "";
   int i = 0, j = 0;

   // ambos archivos están en orden cronológico: merge por time_server
   while(i < nl && j < nf)
   {
      const int cmp = StringCompare(lt[i], ft[j]);   // lexicográfico = cronológico
      if(cmp == 0)
      {
         matched++;
         const bool inc = (resetStr != "" && StringCompare(lt[i], resetStr) > 0);
         if(inc) incRows++;
         if(ll[i] != fl[j])
         {
            if(inc) incDiff++;
            string a = "", b = "";
            const int c = ValmaCsvFirstDiff(ll[i], fl[j], a, b);
            if(c >= 0 && c < VALMA_CSV_COLUMNS) colDiff[c]++;
            differing++;
            if(firstT == "")
            {
               firstT   = lt[i];
               firstCol = (c >= 0 ? ValmaCsvColName(c) : "?");
               firstL   = a;
               firstF   = b;
            }
         }
         i++;
         j++;
      }
      else if(cmp < 0) { onlyLive++; i++; }
      else             { onlyFull++; j++; }
   }
   onlyLive += (nl - i);
   onlyFull += (nf - j);

   PrintFormat("ALMA parity: live=%s (%d filas) | full=%s (%d filas)",
               liveName, nl, fullName, nf);
   PrintFormat("ALMA parity: comparadas=%d distintas=%d solo_en_live=%d solo_en_full=%d "
               "(solo velas cerradas)", matched, differing, onlyLive, onlyFull);
   PrintFormat("ALMA parity: incrementales reset_time=%s inc_bars=%d comparadas_inc=%d "
               "distintas_inc=%d",
               (resetStr == "" ? "(sin metadatos)" : resetStr), incMeta, incRows, incDiff);
   if(differing > 0)
      PrintFormat("ALMA parity: primera diferencia time_server=%s columna=%s live=\"%s\" full=\"%s\"",
                  firstT, firstCol, firstL, firstF);

   string cols = "";
   for(int k = 0; k < VALMA_CSV_COLUMNS; k++)
      if(colDiff[k] > 0) cols += StringFormat("%s=%d ", ValmaCsvColName(k), colDiff[k]);
   if(StringLen(cols) > 0)
      Print("ALMA parity: diferencias por columna: ", cols);

   // PASS = 0 filas distintas EN EL CAMINO INCREMENTAL y al menos 3 velas
   // comparadas ahí. Con menos filas incrementales (indicador recién cargado o
   // un recalculo completo de por medio) el resultado no prueba nada.
   string verdict = "";
   if(matched == 0)
      verdict = "INCONCLUSO: no hay velas cerradas comunes (deja correr el indicador mas velas).";
   else if(differing > 0)
      verdict = "FAIL: ver hora y columna reportadas.";
   else if(resetStr == "")
      verdict = "INCONCLUSO: CSV live sin #reset_time, no se puede aislar el incremental.";
   else if(incRows < 3)
      verdict = "INCONCLUSO: menos de 3 velas comparadas por el camino incremental "
                "(recalculo completo durante la prueba o indicador recien cargado).";
   else
      verdict = "PASS: 0 filas distintas y >= 3 velas comparadas por el camino incremental.";
   Print("ALMA parity: RESULTADO ", verdict);
}

//==================================================================== export full
void OnStart()
{
   const string fullName = CsvName("full");
   const string liveName = CsvName("live");

   // iCustom con los defaults del script = defaults del Pine v0.02
   const int handle = iCustom(_Symbol, _Period, "Nysys\\Velocity_ALMA");
   if(handle == INVALID_HANDLE)
   {
      Print("ALMA parity: iCustom failed, error=", GetLastError());
      return;
   }

   int tries = 0;
   const int need = InpBars + 2;
   while(BarsCalculated(handle) < need && tries < 400)
   {
      Sleep(50);
      tries++;
   }
   if(BarsCalculated(handle) < need)
   {
      PrintFormat("ALMA parity: indicator calculated only %d of %d bars",
                  BarsCalculated(handle), need);
      IndicatorRelease(handle);
      return;
   }

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(_Symbol, _Period, 1, InpBars, rates);  // 1 = sin la viva
   if(copied <= 0)
   {
      Print("ALMA parity: CopyRates failed, error=", GetLastError());
      IndicatorRelease(handle);
      return;
   }

   // buffers documentados en la cabecera del indicador
   double bBC[], bBO[], bUP[], bLO[], bBuy[], bSell[], bTP1[], bTP2[], bSL[];
   double bEnt[], bSlv[], bTp1v[], bTp2v[], bDir[];
   // diagnóstico de la cadena de volatilidad (buffers de cálculo 43..46)
   double bDev[], bMadr[], bVol[], bRank[];
   if(!CopyOne(handle, 27, copied, bBC)  || !CopyOne(handle, 25, copied, bBO) ||
      !CopyOne(handle, 29, copied, bUP)  || !CopyOne(handle, 31, copied, bLO) ||
      !CopyOne(handle, 36, copied, bBuy) || !CopyOne(handle, 37, copied, bSell) ||
      !CopyOne(handle, 33, copied, bTP1) || !CopyOne(handle, 34, copied, bTP2) ||
      !CopyOne(handle, 35, copied, bSL)  ||
      !CopyOne(handle, 52, copied, bEnt) || !CopyOne(handle, 53, copied, bSlv) ||
      !CopyOne(handle, 54, copied, bTp1v) || !CopyOne(handle, 55, copied, bTp2v) ||
      !CopyOne(handle, 56, copied, bDir)  ||
      !CopyOne(handle, 43, copied, bDev)  || !CopyOne(handle, 44, copied, bMadr) ||
      !CopyOne(handle, 45, copied, bVol)  || !CopyOne(handle, 46, copied, bRank))
   {
      Print("ALMA parity: CopyBuffer incomplete, error=", GetLastError());
      IndicatorRelease(handle);
      return;
   }

   const int file = ValmaCsvOpen(fullName);
   if(file == INVALID_HANDLE)
   {
      PrintFormat("ALMA parity: FileOpen(%s) failed, error=%d", fullName, GetLastError());
      IndicatorRelease(handle);
      return;
   }

   ValmaCsvWrite(file, ValmaCsvHeader());
   double f[VC_FIELDS];
   int buys = 0, sells = 0, tp1 = 0, tp2 = 0, sl = 0;
   for(int i = 0; i < copied; i++)
   {
      buys  += (bBuy[i]  == 1.0 ? 1 : 0);
      sells += (bSell[i] == 1.0 ? 1 : 0);
      tp1   += (bTP1[i]  != EMPTY_VALUE ? 1 : 0);
      tp2   += (bTP2[i]  != EMPTY_VALUE ? 1 : 0);
      sl    += (bSL[i]   != EMPTY_VALUE ? 1 : 0);

      f[VC_OPEN]    = rates[i].open;
      f[VC_HIGH]    = rates[i].high;
      f[VC_LOW]     = rates[i].low;
      f[VC_CLOSE]   = rates[i].close;
      f[VC_BASIS_C] = bBC[i];
      f[VC_BASIS_O] = bBO[i];
      f[VC_UPPER]   = bUP[i];
      f[VC_LOWER]   = bLO[i];
      f[VC_BUY]     = bBuy[i];
      f[VC_SELL]    = bSell[i];
      f[VC_TP1H]    = bTP1[i];
      f[VC_TP2H]    = bTP2[i];
      f[VC_SLH]     = bSL[i];
      f[VC_ENTRY]   = bEnt[i];
      f[VC_SL]      = bSlv[i];
      f[VC_TP1]     = bTp1v[i];
      f[VC_TP2]     = bTp2v[i];
      f[VC_POSDIR]  = bDir[i];
      f[VC_DEV]     = bDev[i];
      f[VC_MADR]    = bMadr[i];
      f[VC_VOL]     = bVol[i];
      f[VC_RANK]    = bRank[i];
      ValmaCsvWrite(file, ValmaCsvRow(rates[i].time, f, VALMA_CSV_DECIMALS));
   }
   FileClose(file);
   IndicatorRelease(handle);

   PrintFormat("ALMA parity: full %s %s bars=%d buys=%d sells=%d tp1=%d tp2=%d sl=%d file=%s",
               _Symbol, EnumToString((ENUM_TIMEFRAMES)_Period), copied,
               buys, sells, tp1, tp2, sl, fullName);

   if(InpCompare) CompareLive(liveName, fullName);
}
