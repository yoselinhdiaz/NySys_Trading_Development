//+------------------------------------------------------------------+
//|  VelocityAlmaCsv.mqh                                             |
//|  Serialización CSV compartida por las DOS salidas de paridad:    |
//|    · indicador Velocity_ALMA  -> velocity_alma_live_<sym>_<tf>   |
//|      (buffers mantenidos de forma INCREMENTAL, al cerrar vela)    |
//|    · script Velocity_ALMA_ParityExport -> velocity_alma_full_...  |
//|      (recalculo completo vía iCustom)                             |
//|  Ambas escriben la MISMA rejilla con el MISMO formato, de modo    |
//|  que comparar por time_server es una igualdad de texto exacta.    |
//|  Referencia de paridad: Pine v5 "Velocity ALMA" v0.02 (219 líneas)|
//|  columnas = 23: time_server + 22 campos                        |
//|  las 4 últimas (dev, mad_raw, vol, vol_rank) son DIAGNÓSTICO   |
//|  de la cadena de volatilidad y van AL FINAL: no mueven         |
//|  ninguna columna previa (un CSV viejo se lee por nombre).      |
//|  decimales: 6 en los precios (VALMA_CSV_DECIMALS) y 8 en las   |
//|  4 series de diagnóstico (VALMA_CSV_DIAG_DECIMALS). _Digits no |
//|  sirve: el redondeo a 0.01 del precio tapa el criterio 1e-6.   |
//|  el CSV live añade una línea previa de metadatos (prefijo '#'):   |
//|    #reset_time=<hora>;inc_bars=<n>                               |
//|  que permite separar las filas del camino incremental.           |
//+------------------------------------------------------------------+
#ifndef __VELOCITY_ALMA_CSV_MQH__
#define __VELOCITY_ALMA_CSV_MQH__

#define VALMA_CSV_COLUMNS 23          // columnas del CSV (incluida la hora)
// Decimales de los PRECIOS del CSV. NO se usa _Digits: el CSV es la evidencia
// de paridad y con 2 decimales (XAUUSD) el precio se redondea a 0.01, que tapa
// el criterio max|delta half| < 1e-6.
#define VALMA_CSV_DECIMALS 6
// Decimales de las 4 series de diagnóstico (dev, mad_raw, vol, vol_rank).
// Necesitan 8, no 6: half = 1.4826 * vol * mult propaga el redondeo de vol
// (5e-7 a 6 decimales) multiplicado por 1.4826 * 1.8 = 2.67 -> hasta 1.3e-6,
// por encima del criterio. Con 8 decimales el residuo de half es ~1e-8.
#define VALMA_CSV_DIAG_DECIMALS 8

// índices de f[] (los 22 campos posteriores a time_server)
#define VC_OPEN      0
#define VC_HIGH      1
#define VC_LOW       2
#define VC_CLOSE     3
#define VC_BASIS_C   4
#define VC_BASIS_O   5
#define VC_UPPER     6
#define VC_LOWER     7
#define VC_BUY       8                // 1 = señal BUY en la vela, 0 = no
#define VC_SELL      9                // 1 = señal SELL en la vela, 0 = no
#define VC_TP1H     10                // precio de la marca TP1 (vacío = sin toque)
#define VC_TP2H     11                // precio de la marca TP2
#define VC_SLH      12                // precio de la marca SL
#define VC_ENTRY    13                // niveles del trade vigente en la vela
#define VC_SL       14
#define VC_TP1      15
#define VC_TP2      16
#define VC_POSDIR   17                // 1 long, -1 short, 0 sin trade
// ---- diagnóstico de la cadena de volatilidad: SIEMPRE al final, para que las
// ---- 19 columnas históricas conserven su índice y su significado.
#define VC_DEV      18                // |close - SMA(close, VolLength)|  (Pine 73)
#define VC_MADR     19                // madRaw = SMA(dev, VolLength)    (Pine 73)
#define VC_VOL      20                // vol    = EMA(madRaw, VolSmooth) (Pine 74)
#define VC_RANK     21                // volRank 0..1 (Pine 77-84)
#define VC_FIELDS   22

//+------------------------------------------------------------------+
string ValmaCsvHeader(void)
{
   return("time_server,open,high,low,close,basis_close,basis_open,upper,lower,"
          "buy,sell,tp1_hit,tp2_hit,sl_hit,entry,sl,tp1,tp2,pos_dir,"
          "dev,mad_raw,vol,vol_rank");
}

//+------------------------------------------------------------------+
string ValmaCsvColName(const int idx)
{
   string n[VALMA_CSV_COLUMNS];
   n[0]  = "time_server"; n[1]  = "open";       n[2]  = "high";
   n[3]  = "low";         n[4]  = "close";      n[5]  = "basis_close";
   n[6]  = "basis_open";  n[7]  = "upper";      n[8]  = "lower";
   n[9]  = "buy";         n[10] = "sell";       n[11] = "tp1_hit";
   n[12] = "tp2_hit";     n[13] = "sl_hit";     n[14] = "entry";
   n[15] = "sl";          n[16] = "tp1";        n[17] = "tp2";
   n[18] = "pos_dir";
   n[19] = "dev";         n[20] = "mad_raw";    n[21] = "vol";
   n[22] = "vol_rank";
   if(idx < 0 || idx >= VALMA_CSV_COLUMNS) return("?");
   return(n[idx]);
}

//+------------------------------------------------------------------+
//| Precio -> celda. EMPTY_VALUE (na de Pine) y NaN se exportan vacíos|
//| decimals = decimales fijos del CSV (VALMA_CSV_DECIMALS = 6), NO     |
//| _Digits: ver el porque en el #define de arriba.                    |
string ValmaCsvNum(const double v, const int decimals)
{
   if(v == EMPTY_VALUE || !MathIsValidNumber(v)) return("");
   return(DoubleToString(v, decimals));
}

string ValmaCsvFlag(const double v) { return(v == 1.0 ? "1" : "0"); }
string ValmaCsvDir(const double v)  { return(IntegerToString((int)MathRound(v))); }

// Serie de diagnóstico -> celda con VALMA_CSV_DIAG_DECIMALS (8). El criterio de
// paridad de dev / mad_raw / vol / vol_rank es max|delta| < 1e-6, asi que el CSV
// tiene que conservar mas precision que los precios (ver el #define).
// Replica de referencia: MQL5\Scripts\Nysys\Tests\replica.py.
string ValmaCsvNumDiag(const double v)
{
   if(v == EMPTY_VALUE || !MathIsValidNumber(v)) return("");
   return(DoubleToString(v, VALMA_CSV_DIAG_DECIMALS));
}

//+------------------------------------------------------------------+
//| Fila completa. f[] = 22 campos; decimals = VALMA_CSV_DECIMALS (6).  |
string ValmaCsvRow(const datetime t, const double &f[], const int decimals)
{
   string s = TimeToString(t, TIME_DATE | TIME_MINUTES);
   s += "," + ValmaCsvNum(f[VC_OPEN],    decimals);
   s += "," + ValmaCsvNum(f[VC_HIGH],    decimals);
   s += "," + ValmaCsvNum(f[VC_LOW],     decimals);
   s += "," + ValmaCsvNum(f[VC_CLOSE],   decimals);
   s += "," + ValmaCsvNum(f[VC_BASIS_C], decimals);
   s += "," + ValmaCsvNum(f[VC_BASIS_O], decimals);
   s += "," + ValmaCsvNum(f[VC_UPPER],   decimals);
   s += "," + ValmaCsvNum(f[VC_LOWER],   decimals);
   s += "," + ValmaCsvFlag(f[VC_BUY]);
   s += "," + ValmaCsvFlag(f[VC_SELL]);
   s += "," + ValmaCsvNum(f[VC_TP1H],    decimals);
   s += "," + ValmaCsvNum(f[VC_TP2H],    decimals);
   s += "," + ValmaCsvNum(f[VC_SLH],     decimals);
   s += "," + ValmaCsvNum(f[VC_ENTRY],   decimals);
   s += "," + ValmaCsvNum(f[VC_SL],      decimals);
   s += "," + ValmaCsvNum(f[VC_TP1],     decimals);
   s += "," + ValmaCsvNum(f[VC_TP2],     decimals);
   s += "," + ValmaCsvDir(f[VC_POSDIR]);
   s += "," + ValmaCsvNumDiag(f[VC_DEV]);
   s += "," + ValmaCsvNumDiag(f[VC_MADR]);
   s += "," + ValmaCsvNumDiag(f[VC_VOL]);
   s += "," + ValmaCsvNumDiag(f[VC_RANK]);
   return(s);
}

//+------------------------------------------------------------------+
int ValmaCsvOpen(const string name)
{
   return(FileOpen(name, FILE_WRITE | FILE_TXT | FILE_ANSI));
}

bool ValmaCsvWrite(const int h, const string line)
{
   if(h == INVALID_HANDLE) return(false);
   return(FileWriteString(h, line + "\r\n") > 0);
}

//+------------------------------------------------------------------+
//| Primera columna distinta entre dos filas; -1 = iguales.           |
//| Devuelve el índice de columna y los dos valores en colA / colB.   |
int ValmaCsvFirstDiff(const string a, const string b, string &colA, string &colB)
{
   string pa[], pb[];
   const ushort sep = (ushort)44;                    // ','
   const int na = StringSplit(a, sep, pa);
   const int nb = StringSplit(b, sep, pb);
   const int n  = MathMin(na, nb);
   for(int k = 0; k < n; k++)
      if(pa[k] != pb[k])
      {
         colA = pa[k];
         colB = pb[k];
         return(k);
      }
   if(na != nb)
   {
      colA = "";
      colB = "";
      return(n);
   }
   return(-1);
}

//+------------------------------------------------------------------+
//| Línea de metadatos del CSV live (empieza por '#'), justo debajo   |
//| de la cabecera de columnas:                                       |
//|   #reset_time=<yyyy.mm.dd hh:mi>;inc_bars=<n>                     |
//| reset_time = última vela cerrada del último ResetAll. Las filas   |
//| con time_server > reset_time son las que pasaron por el camino    |
//| incremental (lo único que el test puede dar por válido).          |
string ValmaCsvMetaLine(const datetime resetTime, const int incBars)
{
   return("#reset_time=" + TimeToString(resetTime, TIME_DATE | TIME_MINUTES) +
          ";inc_bars=" + IntegerToString(incBars));
}

//+------------------------------------------------------------------+
//| Lee la línea de metadatos. false si el fichero no la tiene.       |
//| incBars = -1 cuando el campo no está presente.                    |
bool ValmaCsvMeta(const string name, datetime &resetTime, int &incBars)
{
   resetTime = 0;
   incBars   = -1;
   const int h = FileOpen(name, FILE_READ | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE) return(false);

   bool found = false;
   while(!FileIsEnding(h))
   {
      string ln = FileReadString(h);
      StringTrimRight(ln);
      StringTrimLeft(ln);
      if(StringLen(ln) == 0) continue;
      if(StringGetCharacter(ln, 0) != '#') break;         // ya empiezan las columnas
      const int pt = StringFind(ln, "#reset_time=");
      if(pt >= 0)
      {
         const int p0 = pt + StringLen("#reset_time=");
         const int p1 = StringFind(ln, ";", p0);
         const string ts = (p1 < 0 ? StringSubstr(ln, p0) : StringSubstr(ln, p0, p1 - p0));
         resetTime = StringToTime(ts);
         found = true;
      }
      const int pi = StringFind(ln, "inc_bars=");
      if(pi >= 0)
      {
         incBars = (int)StringToInteger(StringSubstr(ln, pi + StringLen("inc_bars=")));
         found = true;
      }
   }
   FileClose(h);
   return(found);
}

//+------------------------------------------------------------------+
//| Carga un CSV en memoria: hora (primer campo) y línea completa.    |
bool ValmaCsvLoad(const string name, string &times[], string &lines[])
{
   ArrayResize(times, 0);
   ArrayResize(lines, 0);
   const int h = FileOpen(name, FILE_READ | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE) return(false);

   int n = 0;
   while(!FileIsEnding(h))
   {
      string ln = FileReadString(h);
      StringTrimRight(ln);
      StringTrimLeft(ln);
      if(StringLen(ln) == 0) continue;
      if(StringGetCharacter(ln, 0) == '#') continue;         // metadatos
      if(StringFind(ln, "time_server") == 0) continue;       // cabecera
      const int c = StringFind(ln, ",");
      if(c <= 0) continue;
      string cells[];
      if(StringSplit(ln, (ushort)44, cells) != VALMA_CSV_COLUMNS)
         continue;                                   // línea truncada (escritura en curso)
      ArrayResize(times, n + 1);
      ArrayResize(lines, n + 1);
      times[n] = StringSubstr(ln, 0, c);
      lines[n] = ln;
      n++;
   }
   FileClose(h);
   return(n > 0);
}

#endif // __VELOCITY_ALMA_CSV_MQH__
//+------------------------------------------------------------------+
