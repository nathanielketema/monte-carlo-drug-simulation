
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>
#include <omp.h>

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
            return "🙂";
        case ADDICT:
            return "🤕";
        case CONVERTER:
            return "😈";
        case RECOVERER:
            return "😇";
    }
}

void fillGrid(State grid[ROWS][COLS], int seed) {
    srand(seed);
    for (int r = 0; r < ROWS; r++) {
        for (int c = 0; c < COLS; c++) {
            if (r == 0 || r == ROWS - 1 || c == 0 || c == COLS - 1) {
                grid[r][c] = NORMAL;
            }
            else {
                // Initially (we could change this to see the difference): 
                // - 50% NORMAL 
                // - 20% ADDICT 
                // - 15% CONVERTER
                // - 15% RECOVERER
                int rand_num = rand() % 100;
                if (rand_num < 50) {
                    grid[r][c] = NORMAL;
                } 
                else if (rand_num < 70) {
                    grid[r][c] = ADDICT;
                } 
                else if (rand_num < 85) {
                    grid[r][c] = CONVERTER;
                } 
                else {
                    grid[r][c] = RECOVERER;
                }
            }
        }
    }
}

void printGrid(State grid[ROWS][COLS]) {
    for (int r = 1; r < ROWS - 1; r++) {
        for (int c = 1; c < COLS - 1; c++) {
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

    for (int r = 1; r < ROWS - 1; r++) {
        for (int c = 1; c < COLS - 1; c++) {
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
    printf("- Normal = %d\n", normal);
    printf("- Addict = %d\n", addict);
    printf("- Converter = %d\n", converter);
    printf("- Recoverer = %d\n", recoverer);
}

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

int main(int argc, char *argv[])
{
    if (argc != 3) {
        printf("Usage: ./addiction rows cols\n");
        return 1;
    }

    ROWS = atoi(argv[1]) + 2;
    COLS = atoi(argv[2]) + 2;

    int seed, generations;

    printf("seed: ");
    scanf("%d", &seed);
    printf("generations: ");
    scanf("%d", &generations);
    printf("\n");

    State oldGrid[ROWS][COLS];
    State newGrid[ROWS][COLS];

    printf("Generation 1\n");
    printf("------------\n");
    fillGrid(oldGrid, seed);
    printGrid(oldGrid);
    printStats(oldGrid);
    printf("\n");

    for (int i = 2; i <= generations; i++) {
        printf("Generation %d\n", i);
        printf("------------\n");

        #pragma omp parallel for schedule(dynamic)
        for (int r = 0; r < ROWS; r++ ) {
            for (int c = 0; c < COLS; c++ ) {
                newGrid[r][c] = checker(oldGrid, r, c);
            }
        }

        printGrid(newGrid);
        printStats(newGrid);
        printf("\n");

        // update grid
        #pragma omp parallel for schedule(dynamic)
        for (int r = 0; r < ROWS; r++) {
            for (int c = 0; c < COLS; c++) {
                oldGrid[r][c] = newGrid[r][c];
            }
        }
    }

    return 0;
}
