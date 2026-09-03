---
name: agent-notify
description: 在 macOS 屏幕右下角弹出通知卡片并在菜单栏留下未读角标，用来告诉用户"任务做完了"或"需要你做决定/给输入"。当你完成一个耗时任务、需要用户确认某个方案、被权限或缺失信息卡住、或用户说过"做完通知我 / 别让我一直盯着"时使用。
---

# agent-notify

用户不会一直盯着终端。做完事或者卡住了，用这个命令弹一张卡片出来。

卡片出现在屏幕右下角，同时在菜单栏累计未读角标。用户按 Esc 收起卡片（仍算未读），点卡片才算已读。

## 命令

```bash
agent-notify send --agent <你的名字> --level <级别> \
  --title "<一句话说明发生了什么>" \
  --body "<任务描述：改了什么、还剩什么、需要用户干什么>" \
  --project "$PWD"
```

`agent-notify` 不在 PATH 时用绝对路径，二选一：

```bash
~/.local/bin/agent-notify
~/Applications/AgentNotify.app/Contents/MacOS/AgentNotify send ...
```

自检：`agent-notify doctor`（会打印 UI 进程状态、收件箱、弹出位置）。

## 级别

| level | 用在什么时候 | 行为 |
| --- | --- | --- |
| `success` | 任务正常做完 | 15 秒后自动消失 |
| `info` | 进度同步、顺带提一句 | 15 秒后自动消失 |
| `action` | 需要用户决定、确认、提供信息才能继续 | 不自动消失，等用户处理 |
| `error` | 失败了、卡住了、需要人来救 | 不自动消失 |

`action` 和 `error` 会一直挂在屏幕上，所以只在真的需要用户动手时才用。

## 什么时候发

发：
- 一个跑了较久的任务结束时（构建、测试、批量重构、长脚本）
- 需要用户在两个方案里选一个
- 缺 API key、缺权限、缺一个只有用户知道的决定
- 反复失败，需要用户介入
- 用户明确说了"完成后通知我"

不发：
- 一次任务里发多条。做完发一条，别每改一个文件发一次
- 纯粹为了刷存在感的"我开始干了"
- 用户就在旁边等着、马上就能看到回复的短任务

## 怎么写内容

`--title` 是用户瞟一眼就看到的那行，写结论，不写过程：

- 好：`任务完成：鉴权模块重构完，测试全过`
- 差：`我已经完成了你之前要求的那个任务`

`--body` 写任务描述，两三句话说清：动了什么、结果如何、需要用户做什么。控制在 200 字以内，超了会被截断。

`--project "$PWD"` 一定要带，卡片和菜单栏会显示目录名，用户同时开几个项目时靠这个区分。

## 例子

任务完成：

```bash
agent-notify send --agent kiro --level success \
  --title "重构完成：鉴权模块拆成 3 个文件" \
  --body "抽出了 TokenStore / SessionGuard / AuthRouter，补了 6 个单测，全部通过。src/auth/legacy.ts 里还有两处 TODO 没动，等你确认能不能删。" \
  --project "$PWD"
```

需要用户决定（卡片会一直留着）：

```bash
agent-notify send --agent claude-code --level action \
  --title "需要你选一个：数据库迁移方式" \
  --body "旧表有 1.2 万行。可以停机迁移（快，5 分钟不可用），也可以双写灰度（慢，但零停机）。你选哪个我就接着做。" \
  --project "$PWD"
```

失败需要介入：

```bash
agent-notify send --agent kiro --level error \
  --title "构建失败：缺 GOOGLE_API_KEY" \
  --body "本地和 .env 里都没有这个变量，Gemini 相关的 4 个测试跑不了。配好之后我重跑。" \
  --project "$PWD"
```

长文本可以走 stdin，省得处理引号转义：

```bash
some-command 2>&1 | tail -20 | agent-notify send --agent kiro --level error \
  --title "测试挂了 3 个" --body - --project "$PWD"
```
