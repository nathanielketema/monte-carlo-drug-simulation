# Monte Carlo Drug Simulation

## Code

```c
typedef enum {
    NORMAL = 0,
    ADDICT = 1,
    CONVERTER = 2,
    RECOVERER = 3
} State;

State checker(State grid[ROWS][COLS], int r, int c) {
    if (r == 0 || r == ROWS - 1 || c == 0 || c == COLS - 1) {
        return NORMAL;
    }

    State current = grid[r][c];

    // Both converters and recoverers stay the same
    if (current == CONVERTER || current == RECOVERER) {
        return current;
    }

    int addict_count = 0;
    int converter_count = 0;
    int recoverer_count = 0;

    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            if (!(i == 0 && j == 0)) {
                int nr = r + i;
                int nc = c + j;

                switch (grid[nr][nc]) {
                    case ADDICT:
                        addict_count++;
                        break;
                    case CONVERTER:
                        converter_count++;
                        break;
                    case RECOVERER:
                        recoverer_count++;
                        break;
                }
            }
        }
    }

    // probability of converting
    int probability = (addict_count * 10) + (converter_count * 25) - (recoverer_count * 20);

    if (current == NORMAL) {
        if (probability > 50) {
            return ADDICT;
        }
        return NORMAL;
    }
    else {
        if (probability <= 55) {
            return NORMAL;
        }
        return ADDICT;
    }
}
```

## High level overview

We are trying to model a population where drug addiction spreads through peer pressure. We 
have four states that interact with each other and influence each others states. So 
basically we're trying to simulate how social groups affect the probability of being 
a drug addict.

The four states:

- Normal: people who are not addicted
- Addict: people who are addicted but don't have the power to influence their peers
- Converter: addicts who also influence their friends
- Recoverer: people who go out of their way to help and correct addiction

### Inital setup:

Distribution:

- 50% Normal
- 20% Addict
- 15% Converter
- 15% Recoverer

Influence:

- Addicts: 10% conversion probability per neighbor
- Converters: 25% conversion probability per neighbor
- Recoverers: 20% conversion probability per neighbor
- Transition threshold: 50% probability
