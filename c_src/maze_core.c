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
 *     "objects": [{"type":"chest|key|vision_core|exit", "exit_type":"false|true", "x": <int>, "y": <int>}, ...]
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
    const char *exit_type;
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

static int can_place_at(int x, int y) {
    if (x < 0 || y < 0 || x >= MAZE_W || y >= MAZE_H) return 0;
    if (grid[y][x] != TILE_FLOOR) return 0;
    if (occupied[y][x]) return 0;
    if (x == 1 && y == 1) return 0;
    return 1;
}

static int add_object_at(const char *type, const char *exit_type, int x, int y) {
    if (!can_place_at(x, y)) return 0;
    if (object_count >= MAX_OBJECTS) return 0;
    objects[object_count++] = (MazeObject){type, exit_type, x, y};
    occupied[y][x] = 1;
    return 1;
}

static int try_place_object(const char *type, const char *exit_type, int attempts) {
    for (int i = 0; i < attempts; ++i) {
        int x = rand() % MAZE_W;
        int y = rand() % MAZE_H;
        if (add_object_at(type, exit_type, x, y)) return 1;
    }
    return 0;
}

static int find_center_floor(int *out_x, int *out_y) {
    int cx = MAZE_W / 2;
    int cy = MAZE_H / 2;
    if (can_place_at(cx, cy)) {
        *out_x = cx;
        *out_y = cy;
        return 1;
    }

    int max_r = (MAZE_W > MAZE_H) ? MAZE_W : MAZE_H;
    for (int r = 1; r < max_r; ++r) {
        for (int dy = -r; dy <= r; ++dy) {
            for (int dx = -r; dx <= r; ++dx) {
                if (abs(dx) != r && abs(dy) != r) continue;
                int x = cx + dx;
                int y = cy + dy;
                if (can_place_at(x, y)) {
                    *out_x = x;
                    *out_y = y;
                    return 1;
                }
            }
        }
    }
    return 0;
}

static int find_border_floor(int *out_x, int *out_y) {
    int cx = MAZE_W / 2;
    int cy = MAZE_H / 2;
    int best_dist = -1;
    int best_x = 0;
    int best_y = 0;

    for (int x = 0; x < MAZE_W; ++x) {
        int y_top = 0;
        int y_bot = MAZE_H - 1;
        if (can_place_at(x, y_top)) {
            int dist = abs(x - cx) + abs(y_top - cy);
            if (dist > best_dist) { best_dist = dist; best_x = x; best_y = y_top; }
        }
        if (can_place_at(x, y_bot)) {
            int dist = abs(x - cx) + abs(y_bot - cy);
            if (dist > best_dist) { best_dist = dist; best_x = x; best_y = y_bot; }
        }
    }

    for (int y = 0; y < MAZE_H; ++y) {
        int x_left = 0;
        int x_right = MAZE_W - 1;
        if (can_place_at(x_left, y)) {
            int dist = abs(x_left - cx) + abs(y - cy);
            if (dist > best_dist) { best_dist = dist; best_x = x_left; best_y = y; }
        }
        if (can_place_at(x_right, y)) {
            int dist = abs(x_right - cx) + abs(y - cy);
            if (dist > best_dist) { best_dist = dist; best_x = x_right; best_y = y; }
        }
    }

    if (best_dist < 0) return 0;
    *out_x = best_x;
    *out_y = best_y;
    return 1;
}

static void place_exits(void) {
    int x = 0;
    int y = 0;
    if (find_center_floor(&x, &y)) {
        add_object_at("exit", "false", x, y);
    } else {
        try_place_object("exit", "false", 200);
    }

    if (find_border_floor(&x, &y)) {
        add_object_at("exit", "true", x, y);
    } else {
        try_place_object("exit", "true", 200);
    }
}

static void place_objects(void) {
    object_count = 0;
    memset(occupied, 0, sizeof(occupied));
    occupied[1][1] = 1;

    place_exits();

    for (int i = 0; i < CHEST_COUNT; ++i) {
        try_place_object("chest", NULL, 200);
    }
    for (int i = 0; i < KEY_COUNT; ++i) {
        try_place_object("key", NULL, 200);
    }
    for (int i = 0; i < CORE_COUNT; ++i) {
        try_place_object("vision_core", NULL, 200);
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
        fprintf(f, "    {\"type\":\"%s\"", objects[i].type);
        if (objects[i].exit_type != NULL) {
            fprintf(f, ",\"exit_type\":\"%s\"", objects[i].exit_type);
        }
        fprintf(f, ",\"x\":%d,\"y\":%d}", objects[i].x, objects[i].y);
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
