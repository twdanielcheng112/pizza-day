/*
 * maze_core — Unbounded Vision M1 pipeline
 *
 * Generates a random maze using recursive backtracker (DFS) and writes
 * the state to a JSON file consumed by the Godot MazeBridge.
 *
 * Usage:
 *   maze_core [output_path] [seed]
 *   maze_core --stats output_path vision chests puzzles enemies explored
 *   maze_core --expand output_path seed player_x player_y
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
 *     "expansion_level": <int>,
 *     "expanded_this_frame": <bool>,
 *     "player": {"x": <int>, "y": <int>},
 *     "tiles":  [[<int>, ...], ...],  // 0 = floor, 1 = wall, row-major
 *     "objects": [{"type":"chest|key|vision_core|exit", "exit_type":"false|true", "x": <int>, "y": <int>}, ...],
 *     "stats":  { ... },
 *     "events": { ... }
 *   }
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define BASE_MAZE_W 21
#define BASE_MAZE_H 15
#define EXPANSION_OFFSET 2
#define MAX_MAZE_W (BASE_MAZE_W + EXPANSION_OFFSET * 2)
#define MAX_MAZE_H (BASE_MAZE_H + EXPANSION_OFFSET * 2)

#define TILE_FLOOR 0
#define TILE_WALL  1

#define CHEST_COUNT 2
#define KEY_COUNT 1
#define CORE_COUNT 3
#define MAX_OBJECTS 16

static int grid[MAX_MAZE_H][MAX_MAZE_W];
static int maze_w = BASE_MAZE_W;
static int maze_h = BASE_MAZE_H;
static int cell_w = (BASE_MAZE_W - 1) / 2;
static int cell_h = (BASE_MAZE_H - 1) / 2;

typedef struct {
    const char *type;
    const char *exit_type;
    int x;
    int y;
} MazeObject;

static MazeObject objects[MAX_OBJECTS];
static int object_count = 0;
static int occupied[MAX_MAZE_H][MAX_MAZE_W];

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
        if (ncx < 0 || ncx >= cell_w || ncy < 0 || ncy >= cell_h) continue;

        int nx = ncx * 2 + 1;
        int ny = ncy * 2 + 1;
        if (grid[ny][nx] == TILE_FLOOR) continue;

        grid[(y + ny) / 2][(x + nx) / 2] = TILE_FLOOR;
        carve(ncx, ncy);
    }
}

static int can_place_at(int x, int y) {
    if (x < 0 || y < 0 || x >= maze_w || y >= maze_h) return 0;
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
        int x = rand() % maze_w;
        int y = rand() % maze_h;
        if (add_object_at(type, exit_type, x, y)) return 1;
    }
    return 0;
}

static int find_center_floor(int *out_x, int *out_y) {
    int cx = maze_w / 2;
    int cy = maze_h / 2;
    if (can_place_at(cx, cy)) {
        *out_x = cx;
        *out_y = cy;
        return 1;
    }

    int max_r = (maze_w > maze_h) ? maze_w : maze_h;
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
    int cx = maze_w / 2;
    int cy = maze_h / 2;
    int best_dist = -1;
    int best_x = 0;
    int best_y = 0;

    for (int x = 0; x < maze_w; ++x) {
        int y_top = 0;
        int y_bot = maze_h - 1;
        if (can_place_at(x, y_top)) {
            int dist = abs(x - cx) + abs(y_top - cy);
            if (dist > best_dist) { best_dist = dist; best_x = x; best_y = y_top; }
        }
        if (can_place_at(x, y_bot)) {
            int dist = abs(x - cx) + abs(y_bot - cy);
            if (dist > best_dist) { best_dist = dist; best_x = x; best_y = y_bot; }
        }
    }

    for (int y = 0; y < maze_h; ++y) {
        int x_left = 0;
        int x_right = maze_w - 1;
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

static void init_base_maze(void) {
    maze_w = BASE_MAZE_W;
    maze_h = BASE_MAZE_H;
    cell_w = (BASE_MAZE_W - 1) / 2;
    cell_h = (BASE_MAZE_H - 1) / 2;

    for (int y = 0; y < MAX_MAZE_H; ++y) {
        for (int x = 0; x < MAX_MAZE_W; ++x) {
            grid[y][x] = TILE_WALL;
        }
    }

    carve(0, 0);
    place_objects();
}

static void expand_maze(int *player_x, int *player_y) {
    int old_w = maze_w;
    int old_h = maze_h;
    int new_w = old_w + EXPANSION_OFFSET * 2;
    int new_h = old_h + EXPANSION_OFFSET * 2;
    int expanded_grid[MAX_MAZE_H][MAX_MAZE_W];

    for (int y = 0; y < MAX_MAZE_H; ++y) {
        for (int x = 0; x < MAX_MAZE_W; ++x) {
            expanded_grid[y][x] = TILE_WALL;
        }
    }

    for (int y = 0; y < old_h; ++y) {
        for (int x = 0; x < old_w; ++x) {
            expanded_grid[y + EXPANSION_OFFSET][x + EXPANSION_OFFSET] = grid[y][x];
        }
    }

    int top_y = 1;
    int bottom_y = new_h - 2;
    int left_x = 1;
    int right_x = new_w - 2;
    for (int x = left_x; x <= right_x; ++x) {
        expanded_grid[top_y][x] = TILE_FLOOR;
        expanded_grid[bottom_y][x] = TILE_FLOOR;
    }
    for (int y = top_y; y <= bottom_y; ++y) {
        expanded_grid[y][left_x] = TILE_FLOOR;
        expanded_grid[y][right_x] = TILE_FLOOR;
    }

    for (int y = top_y; y <= EXPANSION_OFFSET + 1; ++y) {
        expanded_grid[y][EXPANSION_OFFSET + 1] = TILE_FLOOR;
    }
    for (int x = EXPANSION_OFFSET + old_w - 2; x <= right_x; ++x) {
        expanded_grid[EXPANSION_OFFSET + old_h - 2][x] = TILE_FLOOR;
    }

    for (int y = 0; y < new_h; ++y) {
        for (int x = 0; x < new_w; ++x) {
            grid[y][x] = expanded_grid[y][x];
        }
    }

    for (int i = 0; i < object_count; ++i) {
        objects[i].x += EXPANSION_OFFSET;
        objects[i].y += EXPANSION_OFFSET;
    }
    *player_x += EXPANSION_OFFSET;
    *player_y += EXPANSION_OFFSET;

    maze_w = new_w;
    maze_h = new_h;
    cell_w = (maze_w - 1) / 2;
    cell_h = (maze_h - 1) / 2;
}

static int write_json(
    const char *path,
    unsigned int seed,
    int expansion_level,
    int expanded_this_frame,
    int player_x,
    int player_y
) {
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
        "  \"expansion_level\": %d,\n"
        "  \"expanded_this_frame\": %s,\n"
        "  \"player\": {\"x\": %d, \"y\": %d},\n"
        "  \"tiles\": [\n",
        maze_w,
        maze_h,
        seed,
        expansion_level,
        expanded_this_frame ? "true" : "false",
        player_x,
        player_y);

    for (int y = 0; y < maze_h; ++y) {
        fprintf(f, "    [");
        for (int x = 0; x < maze_w; ++x) {
            fprintf(f, "%d", grid[y][x]);
            if (x != maze_w - 1) fputc(',', f);
        }
        fputc(']', f);
        if (y != maze_h - 1) fputc(',', f);
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

    if (argc > 1 && strcmp(argv[1], "--expand") == 0) {
        if (argc < 6) {
            fprintf(stderr, "usage: maze_core --expand output_path seed player_x player_y\n");
            return 1;
        }

        const char *out_path = argv[2];
        unsigned int seed = (unsigned int)strtoul(argv[3], NULL, 10);
        int player_x = atoi(argv[4]);
        int player_y = atoi(argv[5]);

        srand(seed);
        init_base_maze();
        expand_maze(&player_x, &player_y);
        return write_json(out_path, seed, 1, 1, player_x, player_y);
    }

    const char *out_path = (argc > 1) ? argv[1] : "maze_state.json";

    unsigned int seed;
    if (argc > 2) {
        seed = (unsigned int)strtoul(argv[2], NULL, 10);
    } else {
        seed = (unsigned int)time(NULL);
    }
    srand(seed);

    init_base_maze();

    return write_json(out_path, seed, 0, 0, 1, 1);
}
