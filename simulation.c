#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>
#include <unistd.h>

int ROWS, COLS;

typedef enum {
    NORMAL = 0,
    ADDICT = 1,
    CONVERTER = 2,
    RECOVERER = 3
} State;

char *stateToChar(State state) {
    switch (state) {
        case NORMAL:
            return "🧑🏾‍🦱";
        case ADDICT:
            return "🤢";
        case CONVERTER:
            return "😈";
        case RECOVERER:
            return "😇";
    }
}

float getInfluence(State state) {
    switch (state) {
        case NORMAL:
            return 1.0;
        case ADDICT:
            return 1.0;
        case CONVERTER:
            return 3.0;
        case RECOVERER:
            return 3.0;
    }
}

int isAddictType(State state) {
    return state == ADDICT || state == CONVERTER;
}

int isNormalType(State state) {
    return state == NORMAL || state == RECOVERER;
}

void fillGrid(State grid[ROWS][COLS], int seed) {
    srand(seed);
    for (int r = 0; r < ROWS; r++) {
        for (int c = 0; c < COLS; c++) {
            // Initially: 
            // - 70% NORMAL 
            // - 20% ADDICT 
            // - 5% RECOVERER
            // - 5% CONVERTER
            int rand_num = rand() % 100;
            if (rand_num < 70) {
                grid[r][c] = NORMAL;
            } 
            else if (rand_num < 90) {
                grid[r][c] = ADDICT;
            } 
            else if (rand_num < 95) {
                grid[r][c] = RECOVERER;
            } 
            else {
                grid[r][c] = CONVERTER;
            }
        }
    }
}

void printGrid(State grid[ROWS][COLS]) {
    for (int r = 0; r < ROWS; r++) {
        for (int c = 0; c < COLS; c++) {
            printf("%s", stateToChar(grid[r][c]));
        }
        printf("\n");
    }
}

void printStats(State grid[ROWS][COLS]) {
    int normal = 0; 
    int addict = 0; 
    int converter = 0;
    int recoverer = 0;
    int total = ROWS * COLS;

    for (int r = 0; r < ROWS; r++) {
        for (int c = 0; c < COLS; c++) {
            switch (grid[r][c]) {
                case NORMAL: 
                    normal++; 
                    break;
                case ADDICT: 
                    addict++; 
                    break;
                case CONVERTER: 
                    converter++; 
                    break;
                case RECOVERER: 
                    recoverer++; 
                    break;
            }
        }
    }

    printf("Stats:\n");
    printf("- Normal    = %4d (%5.2f%%)\n", normal, (normal * 100.0) / total);
    printf("- Addict    = %4d (%5.2f%%)\n", addict, (addict * 100.0) / total);
    printf("- Recoverer = %4d (%5.2f%%)\n", recoverer, (recoverer * 100.0) / total);
    printf("- Converter = %4d (%5.2f%%)\n", converter, (converter * 100.0) / total);
}

State checker(State grid[ROWS][COLS], int r, int c) {
    State current = grid[r][c];

    float addict_pressure = 0.0;
    float normal_pressure = 0.0;

    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            if (!(i == 0 && j == 0)) {
                int nr = (r + i + ROWS) % ROWS;
                int nc = (c + j + COLS) % COLS;

                State neighbor = grid[nr][nc];
                float influence = getInfluence(neighbor);

                if (isAddictType(neighbor)) {
                    addict_pressure += influence;
                } else {
                    normal_pressure += influence;
                }
            }
        }
    }

    // epislon is there to avoid dividing by zero
    float epsilon = 0.0001;
    float total_pressure = addict_pressure + normal_pressure + epsilon;
    float transition_prob;

    if (isAddictType(current)) {
        transition_prob = normal_pressure / total_pressure;
    } else {
        transition_prob = addict_pressure / total_pressure;
    }

    float rand_val = (float)rand() / RAND_MAX;
    if (rand_val < transition_prob) {
        // 8% chance to become special type (Converter/Recoverer)
        float promotion_rate = 0.08; 
        float promotion_roll = (float)rand() / RAND_MAX;

        if (isAddictType(current)) {
            if (promotion_roll < promotion_rate) {
                return RECOVERER;
            } else {
                return NORMAL;
            }
        } else {
            if (promotion_roll < promotion_rate) {
                return CONVERTER;
            } else {
                return ADDICT;
            }
        }
    }

    return current;
}

void clearScreen() {
    printf("\033[2J");
    printf("\033[H");
}

void moveCursorHome() {
    printf("\033[H");
}

int main(int argc, char *argv[])
{
    if (argc != 3) {
        printf("Usage: ./addiction rows cols\n");
        return 1;
    }

    ROWS = atoi(argv[1]);
    COLS = atoi(argv[2]);

    int seed, generations, delay_ms;

    printf("seed: ");
    scanf("%d", &seed);
    printf("generations: ");
    scanf("%d", &generations);
    printf("delay between frames: ");
    scanf("%d", &delay_ms);
    printf("\n");

    State (*oldGrid)[COLS] = malloc(ROWS * sizeof(*oldGrid));
    State (*newGrid)[COLS] = malloc(ROWS * sizeof(*newGrid));

    clearScreen();
    fillGrid(oldGrid, seed);
    printGrid(oldGrid);
    fflush(stdout);
    usleep(delay_ms * 100);
    //printf("\n");

    for (int i = 2; i <= generations; i++) {
        for (int r = 0; r < ROWS; r++ ) {
            for (int c = 0; c < COLS; c++ ) {
                newGrid[r][c] = checker(oldGrid, r, c);
            }
        }
        moveCursorHome();
        printGrid(newGrid);
        //printf("\n");
        fflush(stdout);
        usleep(delay_ms * 100);

        for (int r = 0; r < ROWS; r++) {
            for (int c = 0; c < COLS; c++) {
                oldGrid[r][c] = newGrid[r][c];
            }
        }
    }

    printStats(oldGrid);

    return 0;
}
