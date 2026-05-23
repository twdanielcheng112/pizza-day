/*
 * maze_core — Unbounded Vision M1 pipeline
 *
 * Generates a random maze using recursive backtracker (DFS) and writes
 * the state to a JSON file consumed by the Godot MazeBridge.
 *
 * Usage:
 *   maze_core [output_path] [seed]
 *
 * Defaults: output_path = "maze_state.json" (cwd), seed = time(NULL).
 *
 * Grid dimensions are fixed at the R1 starting size from docs/style-bible.md §4
 * (initial 20x15 → using 21x15 to keep the odd-dim DFS carve clean).
 *
 * JSON schema (v1):
 *   {
 *     "version": 1,
 *     "width":  <int>,
 *     "height": <int>,
 *     "seed":   <uint>,
 *     "tiles":  [[<int>, ...], ...],  // 0 = floor, 1 = wall, row-major
 *     "objects": [{"type":"chest|key|vision_core", "x": <int>, "y": <int>}, ...]
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

#define CHEST_COUNT 2
#define KEY_COUNT 1
#define CORE_COUNT 3
#define MAX_OBJECTS 16

static int grid[MAZE_H][MAZE_W];

typedef struct {
    const char *type;
    int x;
    int y;
} MazeObject;

static MazeObject objects[MAX_OBJECTS];
static int object_count = 0;
static int occupied[MAZE_H][MAZE_W];

static const int DX[4] = { 0,  0,  1, -1};
static const int DY[4] = { 1, -1,  0,  0};

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

static int try_place_object(const char *type, int attempts) {
    for (int i = 0; i < attempts; ++i) {
        int x = rand() % MAZE_W;
        int y = rand() % MAZE_H;
        if (grid[y][x] != TILE_FLOOR) continue;
        if (occupied[y][x]) continue;
        if (x == 1 && y == 1) continue;
        if (object_count >= MAX_OBJECTS) return 0;
        objects[object_count++] = (MazeObject){type, x, y};
        occupied[y][x] = 1;
        return 1;
    }
    return 0;
}

static void place_objects(void) {
    object_count = 0;
    memset(occupied, 0, sizeof(occupied));
    occupied[1][1] = 1;

    for (int i = 0; i < CHEST_COUNT; ++i) {
        try_place_object("chest", 200);
    }
    for (int i = 0; i < KEY_COUNT; ++i) {
        try_place_object("key", 200);
    }
    for (int i = 0; i < CORE_COUNT; ++i) {
        try_place_object("vision_core", 200);
    }
}

static int write_json(const char *path, unsigned int seed) {
    FILE *f = fopen(path, "w");
    if (!f) {
        fprintf(stderr, "maze_core: cannot open %s for writing\n", path);
        return 1;
    }

    fprintf(f,
        "{\n"
        "  \"version\": 1,\n"
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

    fprintf(f, "  ],\n  \"objects\": [\n");
    for (int i = 0; i < object_count; ++i) {
        fprintf(f, "    {\"type\":\"%s\",\"x\":%d,\"y\":%d}",
            objects[i].type, objects[i].x, objects[i].y);
        if (i != object_count - 1) fputc(',', f);
        fputc('\n', f);
    }
    fprintf(f, "  ]\n}\n");
    fclose(f);
    return 0;
}

int main(int argc, char **argv) {
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
    place_objects();

    return write_json(out_path, seed);
}
