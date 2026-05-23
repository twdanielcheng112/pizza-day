/*
 * maze_core — Unbounded Vision M1 pipeline
 *
 * Generates a random maze using recursive backtracker (DFS) and writes
 * the state to a JSON file consumed by the Godot MazeBridge.
 *
 * Usage:
 *   maze_core [output_path] [seed]
 *   maze_core --stats output_path vision chests puzzles enemies explored
 *
 * Defaults: output_path = "maze_state.json" (cwd), seed = time(NULL).
 *
 * Grid dimensions are fixed at the R1 starting size from docs/style-bible.md §4
 * (initial 20x15 → using 21x15 to keep the odd-dim DFS carve clean).
 *
 * JSON schema (v2):
 *   {
 *     "version": 2,
 *     "width":  <int>,
 *     "height": <int>,
 *     "seed":   <uint>,
 *     "tiles":  [[<int>, ...], ...],  // 0 = floor, 1 = wall, row-major
 *     "stats":  { ... },
 *     "events": { ... }
 *   }
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define MAZE_W 21
#define MAZE_H 15
#define CELL_W ((MAZE_W - 1) / 2)
#define CELL_H ((MAZE_H - 1) / 2)

#define TILE_FLOOR 0
#define TILE_WALL  1

static int grid[MAZE_H][MAZE_W];

static const int DX[4] = { 0,  0,  1, -1};
static const int DY[4] = { 1, -1,  0,  0};

static int clamp_int(int value, int min_value, int max_value) {
    if (value < min_value) return min_value;
    if (value > max_value) return max_value;
    return value;
}

int calculate_instability(int vision, int chests, int puzzles, int enemies, int explored) {
    int value = 0;

    value += vision * 10;
    value += chests * 5;
    value += puzzles * 8;
    value += enemies * 3;
    value += explored / 10;

    return clamp_int(value, 0, 100);
}

static int get_instability_stage(int instability) {
    if (instability >= 81) return 3;
    if (instability >= 61) return 2;
    if (instability >= 31) return 1;
    return 0;
}

static void carve(int cx, int cy) {
    int order[4] = {0, 1, 2, 3};
    for (int i = 3; i > 0; --i) {
        int j = rand() % (i + 1);
        int tmp = order[i];
        order[i] = order[j];
        order[j] = tmp;
    }

    int x = cx * 2 + 1;
    int y = cy * 2 + 1;
    grid[y][x] = TILE_FLOOR;

    for (int i = 0; i < 4; ++i) {
        int d = order[i];
        int ncx = cx + DX[d];
        int ncy = cy + DY[d];
        if (ncx < 0 || ncx >= CELL_W || ncy < 0 || ncy >= CELL_H) continue;

        int nx = ncx * 2 + 1;
        int ny = ncy * 2 + 1;
        if (grid[ny][nx] == TILE_FLOOR) continue;

        grid[(y + ny) / 2][(x + nx) / 2] = TILE_FLOOR;
        carve(ncx, ncy);
    }
}

static int write_json(const char *path, unsigned int seed) {
    const int vision = 1;
    const int chests = 0;
    const int puzzles = 0;
    const int enemies = 0;
    const int explored = 0;
    const int instability = calculate_instability(vision, chests, puzzles, enemies, explored);
    const int instability_stage = get_instability_stage(instability);

    FILE *f = fopen(path, "w");
    if (!f) {
        fprintf(stderr, "maze_core: cannot open %s for writing\n", path);
        return 1;
    }

    fprintf(f,
        "{\n"
        "  \"version\": 2,\n"
        "  \"width\": %d,\n"
        "  \"height\": %d,\n"
        "  \"seed\": %u,\n"
        "  \"tiles\": [\n",
        MAZE_W, MAZE_H, seed);

    for (int y = 0; y < MAZE_H; ++y) {
        fprintf(f, "    [");
        for (int x = 0; x < MAZE_W; ++x) {
            fprintf(f, "%d", grid[y][x]);
            if (x != MAZE_W - 1) fputc(',', f);
        }
        fputc(']', f);
        if (y != MAZE_H - 1) fputc(',', f);
        fputc('\n', f);
    }

    fprintf(f,
        "  ],\n"
        "  \"stats\": {\n"
        "    \"vision\": %d,\n"
        "    \"chests\": %d,\n"
        "    \"puzzles\": %d,\n"
        "    \"enemies\": %d,\n"
        "    \"explored\": %d,\n"
        "    \"instability\": %d\n"
        "  },\n"
        "  \"events\": {\n"
        "    \"instability_stage\": %d\n"
        "  }\n"
        "}\n",
        vision, chests, puzzles, enemies, explored, instability, instability_stage);
    fclose(f);
    return 0;
}

static int write_stats_json(
    const char *path,
    int vision,
    int chests,
    int puzzles,
    int enemies,
    int explored
) {
    int instability = calculate_instability(vision, chests, puzzles, enemies, explored);
    int instability_stage = get_instability_stage(instability);

    FILE *f = fopen(path, "w");
    if (!f) {
        fprintf(stderr, "maze_core: cannot open %s for writing\n", path);
        return 1;
    }

    fprintf(f,
        "{\n"
        "  \"version\": 2,\n"
        "  \"stats\": {\n"
        "    \"vision\": %d,\n"
        "    \"chests\": %d,\n"
        "    \"puzzles\": %d,\n"
        "    \"enemies\": %d,\n"
        "    \"explored\": %d,\n"
        "    \"instability\": %d\n"
        "  },\n"
        "  \"events\": {\n"
        "    \"instability_stage\": %d\n"
        "  }\n"
        "}\n",
        vision, chests, puzzles, enemies, explored, instability, instability_stage);
    fclose(f);
    return 0;
}

int main(int argc, char **argv) {
    if (argc > 1 && strcmp(argv[1], "--stats") == 0) {
        if (argc < 8) {
            fprintf(stderr, "usage: maze_core --stats output_path vision chests puzzles enemies explored\n");
            return 1;
        }
        return write_stats_json(
            argv[2],
            atoi(argv[3]),
            atoi(argv[4]),
            atoi(argv[5]),
            atoi(argv[6]),
            atoi(argv[7])
        );
    }

    const char *out_path = (argc > 1) ? argv[1] : "maze_state.json";

    unsigned int seed;
    if (argc > 2) {
        seed = (unsigned int)strtoul(argv[2], NULL, 10);
    } else {
        seed = (unsigned int)time(NULL);
    }
    srand(seed);

    for (int y = 0; y < MAZE_H; ++y) {
        for (int x = 0; x < MAZE_W; ++x) {
            grid[y][x] = TILE_WALL;
        }
    }

    carve(0, 0);

    return write_json(out_path, seed);
}
