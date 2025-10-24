# Monte Carlo Drug Simulation

A monte carlo simulation to model a population where drug addiction spreads through peer pressure.
There are four states that interact with each other and influence each others states. This
simulates how social groups affect the probability of being a drug addict.

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
