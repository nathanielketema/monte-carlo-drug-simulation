# Monte Carlo Drug Simulation

A monte carlo simulation to model a population where drug addiction spreads through peer pressure.
There are four states that interact with each other and influence each others states. This
simulates how social groups affect the probability of being a drug addict.

The four states:

- Normal: people who are not addicted
- Addict: people who are addicted but don't have the power to influence their peers
- Converter: addicts who also influence their friends
- Recoverer: people who go out of their way to help and correct addiction

## Inital setup:

Distribution:

- 70% Normal
- 20% Addict
- 5% Converter
- 5% Recoverer

Influence Weight:

- Normal: 1.0
- Addicts: 1.0
- Converters: 3.0
- Recoverers: 3.0

## Getting started

1. Navigate to src:

   ```console
   cd src/
   ```

2. Compile and run:
   - Sequential
     ```console
     gcc simulation.c -o sequential
     ./sequential row_size col_size
     ```
   - Parallel
     ```console
     gcc simulation_omp.c -fopenmp -o parallel
     ./parallel row_size col_size
     ```
