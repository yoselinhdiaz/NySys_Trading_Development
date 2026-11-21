---
name: monte-carlo-trade-resampling-and-drawdown-distribution
description: 'Estima distribuciones de drawdown por remuestreo IID y por bloques cuando una simulación necesita sensibilidad al orden de las operaciones.'
---

> Adaptación NySys de Kryhr, MIT. Se ajustó la descripción, se enlazaron referencias al commit y se añadió esta nota de alcance. Aplica este método a diagnósticos estadísticos justificados. La regla de 2.000 secuencias del original se refiere a estimar una distribución para sizing, no a un requisito previo del tester nativo. Registra semilla, longitud de bloque y estabilidad de cuantiles. No hagas campañas históricas profundas por defecto. Limita el uso a simulación.

# Monte Carlo Trade Resampling and Drawdown Distribution

## Why this matters

A backtest's reported max drawdown is the max drawdown of one specific sequence of trades, in the specific order they happened to occur historically. If the exact same set of trades had occurred in a different order, purely by chance, the drawdown could easily have been meaningfully worse (or better). Sizing a strategy, or deciding it's safe to trade, based on the single historical drawdown figure is implicitly assuming that historical ordering was representative of what could happen, when it's really just one draw from a much wider range of possible outcomes.

## Do this

### Run a minimum of 2000 resampled trade sequences before trusting any drawdown or return statistic for sizing decisions

Resample the strategy's historical trade returns with replacement to build a new synthetic equity curve, repeat this a minimum of 2000 times, and compute the resulting distribution of outcomes (max drawdown, CAGR, time-to-recovery, and any other statistic being used for sizing or risk decisions). Two thousand runs is the floor, not a target to hit and stop at; the point is to have enough resampled paths that the tails of the distribution (the 1st and 99th percentiles, not just the median) are estimated with reasonable stability rather than being noisy themselves. Report the 5th, 25th, 50th, 75th, and 95th percentile outcomes, not just the mean or median, since sizing and risk decisions should be made against the pessimistic end of that distribution, not the central tendency.

### Use block bootstrap resampling in addition to simple resampling, to preserve autocorrelation

Simple resampling with replacement treats each trade's return as independent of the others, which understates risk for any strategy where returns are actually autocorrelated (losing trades tend to cluster, for instance, because a losing regime affects consecutive trades similarly). Block bootstrap resampling draws contiguous blocks of consecutive trades rather than individual trades, preserving whatever autocorrelation structure exists in the real data. Run both simple and block bootstrap resampling and compare the resulting distributions; a large difference between them is itself informative about how much the strategy's risk is understated by treating trades as independent.

### Check where the single historical backtest's actual result falls within the resampled distribution

If the historical backtest's max drawdown sits near the 5th percentile (a relatively favorable outcome) of the resampled distribution rather than near the median, that's a direct, quantified way of seeing that the single historical path was luckier than what the strategy's own return distribution implies is typical. This is a much more precise version of [overfitting-and-robustness-checks](https://github.com/Kryhr/26-quant-trading-skills/blob/80c2f860f322207526ce7f31901234313253f263/skills/overfitting-and-robustness-checks/SKILL.md)'s "does this equity curve look too smooth" heuristic, and should be checked explicitly rather than eyeballing the equity curve shape alone.

### Size positions and set risk limits against the resampled distribution's pessimistic percentiles, not the single historical result

Position sizing and maximum-drawdown risk limits should be set with reference to a pessimistic percentile of the resampled distribution (the 90th or 95th percentile drawdown, for instance), not the single historical backtest's max drawdown, since the single historical figure is one sample from a wider range of what could plausibly happen, and betting the account's risk tolerance on that one sample being representative is itself a form of overconfidence in the backtest.

### Re-run the resampling whenever the strategy or its underlying trade data materially changes

A resampled distribution computed once and never revisited becomes stale as the strategy is modified or as more real trading history accumulates. Re-run the full resampling process (at minimum the 2000-run standard) whenever the strategy's rules change materially or whenever a meaningful amount of new trade history becomes available, rather than treating one resampling run as a permanent, one-time result.

## Never do this

- Never rely on a single historical backtest's max drawdown as the figure used for position sizing or risk limits without first checking where it falls in a resampled distribution.
- Never run fewer than 2000 resampled trade sequences when building the distribution used for sizing or risk decisions; smaller sample counts leave the tail percentiles too noisy to trust.
- Never use only simple (independent) resampling without also checking block bootstrap results, especially for strategies where consecutive trade returns are plausibly correlated.
- Never size a strategy against the median or mean of a resampled distribution instead of a pessimistic tail percentile; risk limits exist for the bad outcomes, not the typical ones.
- Never treat a resampling run from an earlier version of the strategy as still valid after the strategy's rules have materially changed.

## Verification checklist

- [ ] At least 2000 resampled trade sequences were generated before any drawdown or return statistic was used for sizing or risk decisions
- [ ] Both simple (independent) resampling and block bootstrap resampling were run and compared, not simple resampling alone
- [ ] The full percentile range (at minimum 5th/25th/50th/75th/95th) of the resampled distribution was computed and reported, not just a mean or median
- [ ] The single historical backtest's actual max drawdown was checked against where it falls within the resampled distribution, not assumed to be representative
- [ ] Position sizing and risk limits are set against a pessimistic percentile of the resampled distribution, not the single historical result
- [ ] The resampling was re-run after any material change to the strategy's rules or a meaningful accumulation of new trade history
