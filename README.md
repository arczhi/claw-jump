# Claw Jump / 爪跳

电子版 `USB-Clawd` / `claw-jump` 原型：当 Claude Code 完成一轮响应后，桌面右下角的小角色会弹跳一下，提醒你回来继续对话。

The electronic version of `USB-Clawd` / `claw-jump` prototype: When Claude Code completes a response, a small character in the bottom right corner of the desktop will jump to remind you to return to the conversation.

## 灵感来源 / Inspiration

本项目的灵感来源于 [Clawd MiniFax](https://benbyfax.substack.com/p/clawd-minifax)。

This project is inspired by [Clawd MiniFax](https://benbyfax.substack.com/p/clawd-minifax).

## 示例图片 / Example Images

| Claw Idle / 爪子静止 | Claw Jump Glow / 爪子跳跃发光 |
|----------------------|-------------------------------|
| ![Claw Idle](docs/images/claw-idle.png) | ![Claw Jump Glow](docs/images/claw-jump-glow.png) |

现在这版还支持：

The current version also supports:

1. 跳起时 claw 变成金色，并伴随一圈金光脉冲。
   When jumping, the claw turns golden with a pulse of golden light.
2. 点击 claw，尝试切回最近一次触发事件对应的 Claude Code 终端；在 `Terminal` / `iTerm` 下会优先恢复到具体 tab。
   Clicking the claw attempts to switch back to the Claude Code terminal corresponding to the most recent triggered event; in `Terminal` / `iTerm`, it prioritizes restoring to the specific tab.
3. 拖拽 claw 调整桌面位置，并记住你的放置点；默认锚在右下角。
   Dragging the claw adjusts its desktop position and remembers your placement; it defaults to the bottom right corner.

## 当前状态 / Current Status

仓库已经实现了 `Phase 1` 的最小骨架：

The repository has implemented the minimal skeleton for `Phase 1`:

1. `hooks/claw-jump-stop.sh`
   接 Claude Code `Stop` hook，把事件发给本地代理。
   Handles the Claude Code `Stop` hook and sends the event to the local agent.
2. `hooks/claw-jump-reset.sh`
   接 `UserPromptSubmit` hook，把桌面角色恢复到 idle。
   Handles the `UserPromptSubmit` hook and resets the desktop character to idle.
3. `hooks/claw-jump-notification.sh`
   接 `Notification` hook，在 Claude Code 需要你批准工具调用时也触发跳动。
   Handles the `Notification` hook and triggers a jump when Claude Code requires your approval for tool invocation.
4. `agent/`
   一个基于 `Objective-C + AppKit` 的轻量常驻代理，监听 `http://127.0.0.1:47653/event`。
   A lightweight resident agent based on `Objective-C + AppKit`, listening on `http://127.0.0.1:47653/event`.

## 构建 / Build

```bash
cd /Users/alex/coding/claw-jump/agent
make
```

二进制会生成在：
The binary will be generated at:

```bash
/Users/alex/coding/claw-jump/agent/.build/claw-jump-agent
```

## 启动代理 / Start the Agent

```bash
cd /Users/alex/coding/claw-jump/agent
./.build/claw-jump-agent
```

启动后，菜单栏会出现 `CJ`，桌面右下角会有一个低存在感的底座。

After starting, `CJ` will appear in the menu bar, and a low-profile base will appear in the bottom right corner of the desktop.

当 Claude Code 完成响应，或需要你批准工具调用时：

When Claude Code completes a response or requires your approval for tool invocation:

1. claw 会跳起。
   The claw will jump.
2. 本体会暂时变成金色。
   The body will temporarily turn golden.
3. 周围会扩散一圈金光，提醒感更强。
   A circle of golden light will spread around, enhancing the reminder effect.
4. 你可以直接点击 claw，尝试切回 Claude Code 所在终端。
   You can directly click the claw to try switching back to the terminal where Claude Code is located.

点击 claw 之后：

After clicking the claw:

1. claw 会立刻恢复原状，不再继续发光。
   The claw will immediately return to its original state and stop glowing.
2. agent 会尽量把最近一次触发事件对应的终端切回前台；在 `Terminal` / `iTerm` 下会优先按具体 `tty` 恢复到那一个 tab/session。
   The agent will try to bring the terminal corresponding to the most recent triggered event to the foreground; in `Terminal` / `iTerm`, it prioritizes restoring to the specific `tty` tab/session.
3. 如果没找到终端，会回退为打开最近一次工作的项目目录。
   If the terminal is not found, it will fall back to opening the project directory of the most recent work.

拖拽行为：

Dragging behavior:

1. 按住 claw 或底座可以拖动位置。
   Hold the claw or base to drag its position.
2. 位置会被记住。
   The position will be remembered.
3. 如果没有拖过，默认还是右下角。
   If not dragged, it defaults to the bottom right corner.

## 本地测试 / Local Testing

在另一个终端里执行：

Run the following in another terminal:

```bash
cd /Users/alex/coding/claw-jump/agent
./.build/claw-jump-agent emit test
./.build/claw-jump-agent emit reset
```

## Claude Code `settings.json` 最新配置 / Latest Configuration for Claude Code `settings.json`

推荐先把项目路径写进环境变量：

It is recommended to first write the project path into the environment variable:

```bash
echo 'export CLAW_JUMP_DIR="/Users/alex/coding/claw-jump"' >> ~/.zshrc && source ~/.zshrc
```

然后在 `~/.claude/settings.json` 里这样配。

Then configure it in `~/.claude/settings.json` as follows.

如果你已经有别的 Claude Code 配置，只需要把下面这段合并到现有 JSON 的 `hooks` 节点里：

If you already have other Claude Code configurations, just merge the following into the `hooks` node of the existing JSON:

```json
{
  "hooks": {
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAW_JUMP_DIR/hooks/claw-jump-notification.sh\"",
            "timeout": 3
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAW_JUMP_DIR/hooks/claw-jump-reset.sh\"",
            "timeout": 3
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAW_JUMP_DIR/hooks/claw-jump-stop.sh\"",
            "timeout": 3
          }
        ]
      }
    ]
  }
}
```

上面这份是当前仓库对应的最新推荐版：

The above is the latest recommended version corresponding to the current repository:

1. `Stop`
   Claude 完成一轮响应时跳一下。
   The claw jumps when Claude completes a response.
2. `Notification`
   Claude 需要你批准 Bash、QA tool 或其他工具调用时也跳一下。
   The claw jumps when Claude requires your approval for Bash, QA tools, or other tool invocations.
3. `UserPromptSubmit`
   你回到终端继续输入后，让 claw 立刻恢复原状。
   The claw immediately returns to its original state after you return to the terminal to continue typing.

`Notification` hook 会在两种情况下触发：

The `Notification` hook is triggered in two scenarios:

1. Claude Code 需要你批准工具调用，例如 Bash、某些 QA / external tool 调用。
   Claude Code requires your approval for tool invocations, such as Bash or certain QA/external tool calls.
2. Claude Code 等你输入超过 60 秒。
   Claude Code waits for your input for more than 60 seconds.

当前代理会把 `Notification` 的原始 `message` 显示在桌面气泡里。

The current agent displays the original `message` of the `Notification` in a desktop bubble.

## 模拟权限请求测试 / Simulate Permission Request Test

代理启动后，可以手动模拟一条“需要批准 Bash”的通知：

After starting the agent, you can manually simulate a notification that "requires Bash approval":

```bash
printf '%s' '{"hook_event_name":"Notification","message":"Claude needs your permission to use Bash","session_id":"demo-session","cwd":"'"$CLAW_JUMP_DIR"'"}' | bash "$CLAW_JUMP_DIR/hooks/claw-jump-notification.sh"
```

## 说明 / Notes

1. 点击 claw 目前是“best effort”聚焦最近一次触发事件对应的终端；`Terminal` 和 `iTerm` 会优先按 hook 记录下来的 `tty` 去恢复具体 tab/session，`WezTerm`、`Warp`、`Ghostty`、`kitty` 仍然先回到对应应用。
   Clicking the claw currently makes a "best effort" to focus on the terminal corresponding to the most recent triggered event; `Terminal` and `iTerm` prioritize restoring to the specific `tty` tab/session recorded by the hook, while `WezTerm`, `Warp`, `Ghostty`, and `kitty` still return to the corresponding application first.
2. 如果找不到对应终端，代理会回退到打开最近一次触发事件对应的项目目录。
   If the corresponding terminal is not found, the agent will fall back to opening the project directory of the most recent triggered event.
3. 当前视觉素材是代码绘制的简化版 mascot，没有接入正式 PNG 或 sprite。
   The current visual assets are simplified mascots drawn in code, without formal PNG or sprite integration.
4. 当前代理默认监听 `127.0.0.1:47653`。
   The current agent listens on `127.0.0.1:47653` by default.
