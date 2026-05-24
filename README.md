# Pizza Day — 《失控視界 Unbounded Vision》

一個用 Godot 4.6 開發的 2D 迷宮遊戲，主軸是**反向獎勵**：你越積極探索、開寶箱、擴張視野，世界的 **Instability（失穩值）** 就越高，也越靠近壞結局。真正的勝利條件是 — **學會停止擴張**。

- 三個核心數值：Vision（視野半徑）、Achievement（互動次數）、Instability（失穩值）
- 三種結局：Bad（Instability ≥ 100）、Normal（走向顯眼的假出口）、True（低 Instability 找到真出口）

完整的故事與關卡設計見 [`game-plan.html`](./game-plan.html)。

## Play

如果你只想直接玩，下載這個 zip：

👉 [pizzaday_stable.zip (Google Drive)](https://drive.google.com/file/d/1IL4wFLMu6goeRNbEKxh-i8os4kgrenXM/view?usp=sharing)

> **注意**：這個 zip 是在 macOS 上壓的，Linux 解開後可能會多出 `__MACOSX/` 資料夾或 `.DS_Store` 之類的雜檔，可以直接刪掉或無視。

解壓後在資料夾根目錄：

```bash
cd c_src
make                # 編譯 maze_core，產生 ../maze_core
cd ..
chmod +x index.x86_64 maze_core
./index.x86_64      # 開始遊戲
```

`maze_core` 必須跟 `index.x86_64` 同層，主程式才找得到它（這是一個 C 寫的迷宮生成 + 失穩值計算模組，由 Godot 端定期呼叫）。沒有它的話遊戲會直接在啟動時報錯。

## Setup (development)

1. Clone the repo and open `project.godot` in Godot 4.6.

2. Install the Godot MCP server so Claude Code can interact with the editor directly:

   ```bash
   claude mcp add godot --scope local -- npx @coding-solo/godot-mcp
   ```

   Then restart your Claude Code session. You should see `godot` listed when you run `claude mcp list`.
