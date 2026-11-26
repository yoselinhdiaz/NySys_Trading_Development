#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Replica literal de "Velocity ALMA" v0.02 (Pine v5) sobre un CSV de paridad.

Uso:
    python replica.py <csv> [--rows 300] [--chain pine|legacy]
                            [--print-series] [--at "2026.11.26 07:00"]

El CSV lo escriben el indicador Velocity_ALMA.mq5 (live, incremental) y el
script Velocity_ALMA_ParityExport.mq5 (full, iCustom). Este modulo NO lee
buffers: recalcula la cadena del Pine desde OHLC y la compara serie a serie
contra las columnas del CSV.

Cadena del Pine v0.02 (lineas 69-90):

    basisClose = ta.ema(ta.alma(close, 34, 0.65, 20), 4)
    dev        = math.abs(close - ta.sma(close, 5))             // Pine 73
    madRaw     = ta.sma(dev, 5)                                // Pine 73
    vol        = ta.ema(madRaw, 5)                             // Pine 74
    volRank    = #{k=1..100 : not na(vol[i-k]) and vol[i-k] <= vol[i]} / 100
    mult       = 0.8 + (1.8 - 0.8) * volRank                   // Pine 87
    bandHalf   = 1.4826 * vol * mult                           // Pine 88
    upperBand  = basisClose + bandHalf ; lowerBand = basisClose - bandHalf

--chain pine   (default) = semantica del Pine (lo que debe hacer el port).
--chain legacy           = lo que hacia el port ANTES del arreglo, para poder
                           reproducir el defecto: vol = EMA(dev) sin la SMA
                           exterior, y mad = vol * 1.4826.

Salida: primera vela y primera serie que diverge, max|delta| por serie en las
ultimas N velas, y veredicto PASS/FAIL con el criterio max|delta half| < 1e-6.
"""

from __future__ import annotations

import argparse
import math
import sys

EMPTY = None

# ---- defaults del Pine v0.02 (= inputs del port MQL5) ----------------------
BASIS_LENGTH  = 34
ALMA_OFFSET   = 0.65
ALMA_SIGMA    = 20.0
BASIS_SMOOTH  = 4
VOL_LENGTH    = 5
VOL_SMOOTH    = 5
RANK_LOOKBACK = 100
MAD_SCALE     = 1.4826
MIN_MULT      = 0.8
MAX_MULT      = 1.8
ADAPTIVE      = True

ALPHA_BASIS = 2.0 / (BASIS_SMOOTH + 1.0)
ALPHA_VOL   = 2.0 / (VOL_SMOOTH + 1.0)

TOL_DIAG  = 1e-6     # criterio de paridad de las series internas y de half
TOL_PRICE = 5.1e-3   # columnas de precio: se escriben con _Digits (2 en XAUUSD)

DIAG_SERIES = ("dev", "mad_raw", "vol", "vol_rank")


# --------------------------------------------------------------------- helpers
def sma_at(src, i, length):
    """ta.sma exacto: devuelve None si el tramo no esta completo o hay na."""
    if length < 1 or i < length - 1:
        return EMPTY
    s = 0.0
    for k in range(length):          # mismo orden de suma que SmaAt() en MQL5
        v = src[i - k]
        if v is EMPTY:
            return EMPTY
        s += v
    return s / length


def ema_seeded(src, out, i, length, alpha):
    """ta.ema con semilla SMA (EmaSeeded() del .mq5)."""
    if src[i] is EMPTY:
        return EMPTY
    if i > 0 and out[i - 1] is not EMPTY:
        return alpha * src[i] + (1.0 - alpha) * out[i - 1]
    return sma_at(src, i, length)


def alma_weights(length=BASIS_LENGTH, offset=ALMA_OFFSET, sigma=ALMA_SIGMA):
    """w[k] = exp(-(k-m)^2 / (2 s^2)), m = offset*(len-1) SIN floor, s = len/sigma."""
    m = offset * (length - 1)
    s = length / sigma
    w = []
    total = 0.0
    for k in range(length):
        x = k - m
        wk = math.exp(-(x * x) / (2.0 * s * s))
        w.append(wk)
        total += wk
    return w, total


ALMA_W, ALMA_SUM = alma_weights()


def alma_at(src, i, w=None, total=None):
    """ta.alma(series, length, offset, sigma) = suma ponderada / suma de pesos."""
    w = ALMA_W if w is None else w
    total = ALMA_SUM if total is None else total
    n = len(w)
    if n < 1 or i < n - 1 or total == 0.0:
        return EMPTY
    s = 0.0
    for k in range(n):
        s += src[i - (n - 1 - k)] * w[k]
    return s / total


def ema_series(src, length, alpha):
    out = [EMPTY] * len(src)
    for i in range(len(src)):
        out[i] = ema_seeded(src, out, i, length, alpha)
    return out

def compute_chain(close, open_, chain="pine"):
    """Series del Pine v0.02 a partir de OHLC (None = na)."""
    n = len(close)

    alma_c = [alma_at(close, i) for i in range(n)]
    alma_o = [alma_at(open_, i) for i in range(n)]
    basis_c = ema_series(alma_c, BASIS_SMOOTH, ALPHA_BASIS)
    basis_o = ema_series(alma_o, BASIS_SMOOTH, ALPHA_BASIS)

    # dev = |close - SMA(close, VolLength)|                        (Pine 73)
    sma_c = [sma_at(close, i, VOL_LENGTH) for i in range(n)]
    dev = [EMPTY if sma_c[i] is EMPTY else abs(close[i] - sma_c[i]) for i in range(n)]

    if chain == "legacy":
        # defecto reproducido: vol = EMA(dev) y bMad = vol * MadScale
        vol = ema_series(dev, VOL_SMOOTH, ALPHA_VOL)
        mad_raw = [EMPTY if v is EMPTY else v * MAD_SCALE for v in vol]
    else:
        # madRaw = SMA(dev, VolLength) ; vol = EMA(madRaw, VolSmooth)  (Pine 73-74)
        mad_raw = [sma_at(dev, i, VOL_LENGTH) for i in range(n)]
        vol = ema_series(mad_raw, VOL_SMOOTH, ALPHA_VOL)

    # volRank sobre las RankLookback velas ANTERIORES, na omitidas (Pine 77-84)
    rank = [EMPTY] * n
    for i in range(n):
        if i < RANK_LOOKBACK or vol[i] is EMPTY:
            continue
        cnt = 0
        vi = vol[i]
        for k in range(1, RANK_LOOKBACK + 1):
            vk = vol[i - k]
            if vk is not EMPTY and vk <= vi:
                cnt += 1
        rank[i] = cnt / RANK_LOOKBACK

    # bandas adaptativas (Pine 87-90)
    mult = [EMPTY] * n
    half = [EMPTY] * n
    upper = [EMPTY] * n
    lower = [EMPTY] * n
    for i in range(n):
        if rank[i] is EMPTY:
            continue
        m = MIN_MULT + (MAX_MULT - MIN_MULT) * rank[i] if ADAPTIVE else MIN_MULT
        mult[i] = m
        if vol[i] is EMPTY:
            continue
        h = MAD_SCALE * vol[i] * m
        half[i] = h
        if basis_c[i] is not EMPTY:
            upper[i] = basis_c[i] + h
            lower[i] = basis_c[i] - h

    return {
        "basis_close": basis_c,
        "basis_open": basis_o,
        "dev": dev,
        "mad_raw": mad_raw,
        "vol": vol,
        "vol_rank": rank,
        "mult": mult,
        "half": half,
        "upper": upper,
        "lower": lower,
    }


# ------------------------------------------------------------------------- CSV
def read_csv(path):
    """Devuelve (cabecera, columnas, meta). Tolera CSV de 19 (viejos) o 23 columnas."""
    header = None
    meta = {}
    rows = []
    with open(path, "r", encoding="utf-8-sig", errors="replace") as fh:
        for raw in fh:
            line = raw.strip()
            if not line:
                continue
            if line.startswith("#"):
                for part in line[1:].split(";"):
                    if "=" in part:
                        k, v = part.split("=", 1)
                        meta[k.strip()] = v.strip()
                continue
            cells = [c.strip() for c in line.split(",")]
            if header is None:
                header = cells
                continue
            if len(cells) != len(header):
                continue
            rows.append(cells)
    if header is None:
        raise SystemExit("CSV sin cabecera: %s" % path)
    cols = {}
    for idx, name in enumerate(header):
        vals = []
        for r in rows:
            txt = r[idx]
            if txt in ("", None):
                vals.append(EMPTY)
                continue
            try:
                vals.append(float(txt))
            except ValueError:
                vals.append(txt)          # time_server: se guarda como texto
        cols[name] = vals
    return header, cols, meta


# -------------------------------------------------------------------- informe
def series_stats(csv_vals, rep_vals, tol, start):
    """Metricas de una serie frente a la replica.

    Devuelve (n_ok, n_na, max|delta|, i_na, motivo_na, i_delta, delta), donde
    i_na es la primera fila con na en un solo lado (tipico warm-up de la
    replica sobre una ventana recortada) e i_delta la primera fila con un
    delta numerico por encima de la tolerancia (esa es la divergencia real).
    """
    n = len(rep_vals)
    n_ok = n_na = 0
    max_abs = 0.0
    i_na = -1
    kind_na = ""
    i_delta = -1
    delta = 0.0
    for i in range(start, n):
        a = csv_vals[i] if i < len(csv_vals) else EMPTY
        b = rep_vals[i]
        if a is EMPTY and b is EMPTY:
            n_na += 1
            continue
        if a is EMPTY or b is EMPTY:
            n_na += 1
            if i_na < 0:
                i_na = i
                kind_na = "na en %s" % ("csv" if a is EMPTY else "replica")
            continue
        d = abs(a - b)
        n_ok += 1
        if d > max_abs:
            max_abs = d
        if d > tol and i_delta < 0:
            i_delta = i
            delta = d
    return n_ok, n_na, max_abs, i_na, kind_na, i_delta, delta


def fmt_row(label, st, times, tol):
    n_ok, n_na, max_abs, i_na, kind_na, i_delta, delta = st
    flag = "ok  " if (max_abs <= tol and i_delta < 0) else "DIFF"
    first = "-" if i_delta < 0 else "%s (#%d, %.3e)" % (times[i_delta], i_delta, delta)
    na = "" if i_na < 0 else "  [na: %s #%d]" % (times[i_na], i_na)
    return "%-12s %s ok=%-4d na=%-4d max|d|=%.3e  1a delta: %s%s" % (
        label, flag, n_ok, n_na, max_abs, first, na)


def half_from_bands(upper, lower):
    n = len(upper)
    out = [EMPTY] * n
    for i in range(n):
        u, l = upper[i], lower[i]
        if u is not EMPTY and l is not EMPTY:
            out[i] = (u - l) / 2.0
    return out


def half_from_cols(vol, rank):
    n = len(vol)
    out = [EMPTY] * n
    for i in range(n):
        v, r = vol[i], rank[i]
        if v is EMPTY or r is EMPTY:
            continue
        m = MIN_MULT + (MAX_MULT - MIN_MULT) * r if ADAPTIVE else MIN_MULT
        out[i] = MAD_SCALE * v * m
    return out


def lag_scan(csv_vals, rep_vals, start, max_lag=4):
    """Error medio de half para desfases -max_lag..+max_lag (sintoma de lookahead)."""
    n = len(rep_vals)
    out = []
    for lag in range(-max_lag, max_lag + 1):
        tot = 0.0
        cnt = 0
        for i in range(start, n):
            j = i + lag
            if j < 0 or j >= n:
                continue
            a, b = csv_vals[i], rep_vals[j]
            if a is EMPTY or b is EMPTY:
                continue
            tot += abs(a - b)
            cnt += 1
        out.append((lag, tot / cnt if cnt else float("nan"), cnt))
    return out


def print_detail(times, cols, rep, idx):
    need = ("close", "basis_close", "upper", "lower", "dev", "mad_raw", "vol", "vol_rank")
    print("\nDetalle vela %s (#%d):" % (times[idx], idx))
    print("  %-10s %16s %16s %14s" % ("serie", "csv", "replica", "delta"))
    for s in need:
        a = cols.get(s, [EMPTY] * len(times))[idx]
        b = rep.get(s, [EMPTY] * len(times))[idx]
        if a is EMPTY and b is EMPTY:
            continue
        sa = "-" if a is EMPTY else "%.8f" % a
        sb = "-" if b is EMPTY else "%.8f" % b
        sd = "-" if (a is EMPTY or b is EMPTY) else "%.3e" % (a - b)
        print("  %-10s %16s %16s %14s" % (s, sa, sb, sd))


def pick_half(cols, present):
    """half del CSV: por columnas de diagnostico si existen, si no por bandas."""
    if present:
        return half_from_cols(cols["vol"], cols["vol_rank"]), TOL_DIAG
    return half_from_bands(cols["upper"], cols["lower"]), TOL_PRICE


def main(argv=None):
    ap = argparse.ArgumentParser(description="Replica literal de Velocity ALMA v0.02")
    ap.add_argument("csv", help="velocity_alma_live_<sym>_<tf>.csv")
    ap.add_argument("--rows", type=int, default=300, help="velas finales a evaluar")
    ap.add_argument("--chain", choices=("pine", "legacy"), default="pine",
                    help="pine = semantica correcta; legacy = defecto reproducido")
    ap.add_argument("--tol", type=float, default=TOL_DIAG)
    ap.add_argument("--print-series", action="store_true",
                    help="volcar la tabla alrededor de la primera divergencia")
    ap.add_argument("--at", help="detalle de una vela, formato 'YYYY.MM.DD HH:MM'")
    args = ap.parse_args(argv)

    header, cols, meta = read_csv(args.csv)
    times = cols.get("time_server")
    if not times:
        raise SystemExit("el CSV no tiene columna time_server")
    close, open_ = cols["close"], cols["open"]
    n = len(times)
    rows = min(args.rows, n)
    start = n - rows

    rep = compute_chain(close, open_, args.chain)
    present = [s for s in DIAG_SERIES if s in cols]
    half_csv, half_tol = pick_half(cols, present)

    print("CSV      : %s" % args.csv)
    print("velas    : %d   ventana evaluada: ultimas %d (desde %s)" % (n, rows, times[start]))
    print("columnas : %d %s" % (len(header),
                                "con diagnostico" if present else "SIN diagnostico (CSV viejo)"))
    if meta:
        print("meta     : " + ", ".join("%s=%s" % kv for kv in meta.items()))
    print("cadena   : %s   tol series=%.1e" % (args.chain, args.tol))

    checks = []
    for s in ("basis_close",) + tuple(present):
        checks.append((s, cols[s], TOL_PRICE if s.startswith("basis") else args.tol))
    checks.append(("half", half_csv, half_tol))

    print("\nVentana evaluada (ultimas %d velas, desde %s):" % (rows, times[start]))
    global_first = None
    worst = {}
    for label, cvals, tol in checks:
        st = series_stats(cvals, rep[label], tol, start)
        worst[label] = (st[2], st[5], tol)
        print("  " + fmt_row(label, st, times, tol))
        if st[5] >= 0 and (global_first is None or st[5] < global_first[0]):
            global_first = (st[5], label, st[6])
    print("  (las %d velas anteriores del CSV son warm-up de la replica: no tienen" % start)
    print("   historia previa, una diferencia ahi NO es divergencia de la cadena)")

    # factor implicito y desfase: el sintoma que reporto el usuario
    fmin = fmax = None
    for i in range(start, n):
        hb, vr = half_csv[i], rep["vol"][i]
        if hb is EMPTY or vr is EMPTY or vr == 0.0:
            continue
        f = hb / (MAD_SCALE * vr)
        fmin = f if fmin is None or f < fmin else fmin
        fmax = f if fmax is None or f > fmax else fmax
    print("\nfactor implicito half/(1.4826*vol_replica): %s .. %s  (esperado %.2f..%.2f)" % (
        "n/d" if fmin is None else "%.3f" % fmin,
        "n/d" if fmax is None else "%.3f" % fmax, MIN_MULT, MAX_MULT))
    print("desfase: " + "  ".join("lag%+d=%.3f" % (lg, me)
                                  for lg, me, _ in lag_scan(half_csv, rep["half"], start)))

    print("")
    crit = worst["half"][0]
    if present:
        diag_ok = all(worst[s][0] <= args.tol for s in present)
        ok = diag_ok and crit < args.tol
        print("RESULTADO %s: max|delta half|=%.3e (criterio <%.0e); series: %s"
              % ("PASS" if ok else "FAIL", crit, args.tol,
                 " ".join("%s=%.1e" % (s, worst[s][0]) for s in present)))
    elif crit > TOL_PRICE:
        print("RESULTADO FAIL: max|delta half|=%.3f (bandas del CSV a 2 decimales). "
              "Sin columnas dev/mad_raw/vol/vol_rank no se puede medir el criterio 1e-6."
              % crit)
    else:
        print("RESULTADO INCONCLUSO: bandas dentro del redondeo (max|delta half|=%.4f), "
              "pero sin columnas de diagnostico no se resuelve 1e-6." % crit)

    if global_first is not None:
        idx, label, delta = global_first
        print("Primera serie que diverge: %s en %s (#%d), delta=%.3e"
              % (label, times[idx], idx, delta))

    if args.at:
        for i, t in enumerate(times):
            if t == args.at:
                print_detail(times, cols, rep, i)
                break
        else:
            print("\nvela %s no esta en el CSV" % args.at)

    if args.print_series:
        anchor = global_first[0] if global_first else n - 1
        lo, hi = max(0, anchor - 3), min(n, anchor + 4)
        print("\nSeries alrededor de #%d:" % anchor)
        heads = ["time", "close"] + present + ["half_rep", "half_csv"]
        print("  ".join("%-20s" % h for h in heads))
        for i in range(lo, hi):
            cells = [times[i], "%.2f" % close[i]]
            for s in present:
                cells.append("-" if rep[s][i] is EMPTY else "%.8f" % rep[s][i])
            cells.append("-" if rep["half"][i] is EMPTY else "%.6f" % rep["half"][i])
            cells.append("-" if half_csv[i] is EMPTY else "%.6f" % half_csv[i])
            print("  ".join("%-20s" % c for c in cells))
    return 0


if __name__ == "__main__":
    sys.exit(main())
