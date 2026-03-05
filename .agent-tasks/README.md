# Agent 集群系统

基于 OpenClaw + Claude Code/Codex 的双层架构 Agent 系统，实现从需求到 PR 的完整自动化流程。

## 架构

```
┌─────────────────────────────────────────────────────────┐
│                    编排层 (Orchestrator)                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │  任务分发   │  │  状态监控   │  │  失败重试/学习  │ │
│  └─────────────┘  └─────────────┘  └─────────────────┘ │
│                          │                              │
│  持有业务上下文：会议记录、客户数据、历史决策、成功案例    │
└──────────────────────────┼──────────────────────────────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
┌─────────▼────────┐ ┌─────▼──────┐ ┌───────▼────────┐
│   Codex Agent    │ │Claude Agent│ │  Gemini Agent  │
│   (后端/复杂)     │ │(前端/快速) │ │  (UI/设计)     │
└──────────────────┘ └────────────┘ └────────────────┘
          │                │                │
          └────────────────┼────────────────┘
                           │
                    ┌──────▼──────┐
                    │   Git/PR    │
                    └─────────────┘
```

## 快速开始

### 1. 安装

```bash
cd .agent-tasks
./install.sh
```

### 2. 创建任务

```bash
# 创建新任务
./create-task.sh "实现用户登录功能" codex high

# 使用模板创建
./create-from-template.sh backend-api "实现用户认证API"

# 参数说明:
# $1: 任务描述
# $2: Agent 类型 (codex | claude | gemini)
# $3: 优先级 (low | normal | high | critical)
```

### 3. 查看状态

```bash
./status.sh
```

### 4. 监控任务

```bash
# 手动运行监控
./monitor-agents.sh

# 或查看所有 tmux 会话
tmux ls

# 进入特定会话
tmux attach -t agent-<task-type>-<id>

# 向 Agent 发送指令
tmux send-keys -t agent-<task-type>-<id> '停一下，先做API层' Enter
```

## 工作流程

### 8步完整流程

1. **需求理解** - OpenClaw 读取会议记录/上下文，拆解需求
2. **启动 Agent** - 创建 git worktree + tmux 会话
3. **自动监控** - 每10分钟检查状态（tmux存活、PR创建、CI状态）
4. **Agent 工作** - 写代码、测试、提交、创建 PR
5. **Code Review** - 多 Agent 审查（Codex + Gemini）
6. **CI 测试** - lint、类型检查、单元测试、E2E
7. **人工 Review** - CI 通过后飞书通知
8. **合并清理** - 合并 PR，清理 worktree

### Agent 选择策略

| Agent | 适用场景 | 特点 |
|-------|---------|------|
| **Codex** | 后端逻辑、复杂bug、多文件重构 | 慢但彻底，占90%任务 |
| **Claude** | 前端工作、UI实现 | 速度快，权限问题少 |
| **Gemini** | UI/UX设计 | 设计审美好，生成规范 |

## 目录结构

```
.agent-tasks/
├── install.sh              # 安装脚本
├── create-task.sh          # 创建新任务
├── create-from-template.sh # 使用模板创建
├── run-agent.sh            # 启动 Agent
├── monitor-agents.sh       # 监控脚本
├── smart-retry.sh          # 智能重试系统
├── task-deps.sh            # 任务依赖管理
├── status.sh               # 查看任务状态
├── review-pr.sh            # PR 审查（基础版）
├── review-pr-v2.sh         # PR 审查（增强版）
├── batch-create.sh         # 批量创建任务
├── cleanup.sh              # 清理已完成任务
├── setup-cron.sh           # OpenClaw Cron 集成
├── quickstart.sh           # 快速启动菜单
├── config.json             # 配置文件
├── templates.json          # 任务模板
├── tasks.json              # 任务追踪
└── logs/                   # 日志目录

worktrees/                  # Git worktrees
├── feat-task1-123456/      # 每个任务的独立工作目录
├── feat-task2-123457/
└── ...
```

## 配置

编辑 `.agent-tasks/config.json`:

```json
{
  "agents": {
    "codex": { "command": "codex", ... },
    "claude": { "command": "claude", ... },
    "gemini": { "command": "gemini", ... }
  },
  "notifications": {
    "feishuWebhook": "your-webhook-url",
    "onCIPassed": true
  },
  "monitor": {
    "intervalMinutes": 10,
    "maxRetries": 3
  }
}
```

## 新增功能

### 1. 任务模板系统

预置常用任务模板，快速创建标准化任务：

```bash
# 查看可用模板
./create-from-template.sh

# 使用模板创建任务
./create-from-template.sh backend-api "实现用户认证API"
./create-from-template.sh frontend-page "添加用户设置页面"
./create-from-template.sh bug-fix "修复支付回调失败"
```

可用模板：
- `backend-api` - 后端 API 开发
- `frontend-page` - 前端页面开发
- `ui-design` - UI/UX 设计
- `bug-fix` - Bug 修复
- `refactor` - 代码重构
- `performance` - 性能优化

### 2. 智能重试系统

任务失败时自动分析原因并调整策略：

```bash
# 手动运行智能重试
./smart-retry.sh
```

功能：
- 分析失败类型（测试失败、合并冲突、超时等）
- 生成改进的 prompt
- 自动重试（最多3次）
- 通知失败任务

### 3. 任务依赖管理

支持任务之间的依赖关系：

```bash
# 添加依赖（task2 依赖 task1 完成）
./task-deps.sh add task2 task1

# 检查任务是否就绪
./task-deps.sh check task2

# 列出所有阻塞的任务
./task-deps.sh list

# 当 task1 完成时，解锁依赖它的任务
./task-deps.sh unlock task1
```

### 4. 批量任务创建

从 JSON 文件批量创建任务：

```bash
# 创建任务列表文件
cat > batch-tasks.json << 'EOF'
[
  {"desc": "实现登录API", "agent": "codex", "priority": "high"},
  {"desc": "实现登录页面", "agent": "claude", "priority": "high", "deps": ["task-1"]},
  {"desc": "设计登录样式", "agent": "gemini", "priority": "normal"}
]
EOF

# 批量创建
./batch-create.sh batch-tasks.json
```

### 5. OpenClaw Cron 集成

将监控任务添加到 OpenClaw 的 cron 系统：

```bash
./setup-cron.sh
```

这会添加：
- Agent 监控任务（每10分钟）
- 智能重试检查（每15分钟）
- 每日清理任务（凌晨2点）

### 6. 增强版 PR 审查

```bash
# 基础审查
./review-pr.sh 341

# 增强审查（多 Agent 视角）
./review-pr-v2.sh 341
```

## 关键特性

### 1. 改进版 Ralph Loop

不是静态 prompt，失败时 OpenClaw 会：
- 分析失败原因
- 重写 prompt 加入业务上下文
- 重试（最多3次）
- 记录成功案例

### 2. 安全边界

- 执行层 Agent **不接触**生产数据库
- 只拿到"完成任务需要的最小上下文"
- 敏感信息留在编排层

### 3. 资源隔离

- 每个 Agent 独立的 git worktree
- 独立的 node_modules
- 独立的 tmux 会话

### 4. 通知机制

| 事件 | 通知 |
|------|------|
| 任务启动 | ✅ |
| PR 创建 | ✅ |
| CI 通过 | ✅ |
| 任务失败 | ✅ |
| 任务解锁 | ✅ |

## 依赖

- `git` - 版本控制
- `tmux` - 后台会话管理 (`brew install tmux`)
- `gh` - GitHub CLI (`brew install gh`)
- `jq` - JSON 处理 (`brew install jq`)
- `codex/claude/gemini` - AI Agent CLI
- `openclaw` - OpenClaw CLI (用于 cron 集成)

## 监控日志

```bash
# 查看监控日志
tail -f .agent-tasks/logs/monitor.log

# 查看所有日志
ls -la .agent-tasks/logs/

# 快速启动菜单
./quickstart.sh
```

## 注意事项

1. **RAM 限制**: 每个 Agent 需要独立内存，Mac Mini 16GB 建议同时运行不超过 4-5 个 Agent
2. **GitHub Token**: 确保 `gh` 已登录并有 repo 权限
3. **Webhook**: 修改 `config.json` 中的飞书 webhook 地址
4. **CI 配置**: 确保仓库有 `.github/workflows/ci.yml`

## 示例

### 示例 1: 快速修复 Bug

```bash
./create-task.sh "修复登录页面的内存泄漏" codex high
```

### 示例 2: 前端新功能

```bash
./create-task.sh "添加用户仪表盘页面" claude normal
```

### 示例 3: UI 设计

```bash
./create-task.sh "设计新的导航栏组件" gemini normal
```

### 示例 4: 使用模板

```bash
./create-from-template.sh bug-fix "修复支付回调失败问题"
```

### 示例 5: 批量创建

```bash
./batch-create.sh batch-tasks.json
```

## 进阶用法

### 批量创建任务

```bash
# 从需求列表批量创建
for task in "任务1" "任务2" "任务3"; do
    ./create-task.sh "$task" codex normal
done
```

### 自定义 Agent 命令

修改 `.agent-tasks/run-agent.sh` 中的 `AGENT_CMD` 部分。

### 监控特定任务

```bash
# 查看任务输出
tmux capture-pane -p -t agent-taskname-id | tail -50

# 向 Agent 发送指令
tmux send-keys -t agent-taskname-id '请优化性能' Enter
```

## 参考

- 原始文章: Datawhale - 告别低效搬砖！OpenClaw + Claude Code 超强教程
- OpenClaw: https://openclaw.ai
- Codex: OpenAI Codex CLI
- Claude Code: Anthropic Claude CLI
