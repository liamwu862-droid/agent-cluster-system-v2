# Agent 集群系统使用示例

## 场景 1: 客户提出新需求

假设客户打电话来，希望添加"团队协作功能"。

```bash
# 1. 创建任务（交给 Codex 处理复杂后端逻辑）
cd .agent-tasks
./create-task.sh "实现团队协作功能，支持成员邀请和权限管理" codex high

# 2. 查看任务状态
./status.sh

# 输出示例:
# 任务: 实现团队协作功能，支持成员邀请和权限管理
#   ID: 1741083600
#   Agent: codex
#   状态: 🟢 running
#   分支: feat/实现团队协作功能-1741083600
#   会话: agent-实现团队协作功能-1741083600

# 3. 如果想干预，进入 tmux 会话
tmux attach -t agent-实现团队协作功能-1741083600

# 4. 或发送指令
tmux send-keys -t agent-实现团队协作功能-1741083600 '先做API层，UI后面再做' Enter
```

## 场景 2: 紧急 Bug 修复

```bash
# 高优先级任务
./create-task.sh "修复生产环境支付回调失败问题" codex critical

# Agent 会自动：
# - 创建独立 worktree
# - 分析代码
# - 修复 bug
# - 编写测试
# - 创建 PR
```

## 场景 3: UI 优化

```bash
# 交给 Gemini 做设计，Claude 实现
./create-task.sh "设计新的首页布局" gemini normal

# 等设计完成后
./create-task.sh "实现新的首页布局" claude normal
```

## 场景 4: 日常开发工作流

```bash
# 早上：批量创建任务
./create-task.sh "添加用户资料编辑功能" codex high
./create-task.sh "优化移动端导航栏" claude normal
./create-task.sh "设计新的图标系统" gemini low

# 查看所有任务
./status.sh

# 等待飞书通知 "PR 已准备好"
# 人工 Review 5-10 分钟
# 合并 PR
```

## 场景 5: 多 Agent 协作

复杂功能需要前后端配合：

```bash
# 后端（Codex）
./create-task.sh "实现模板系统API" codex high

# 前端（Claude）- 等后端API完成
./create-task.sh "实现模板选择UI" claude high

# 设计（Gemini）- 并行进行
./create-task.sh "设计模板预览组件" gemini normal
```

## 场景 6: 代码审查

```bash
# 对特定 PR 运行自动化审查
./review-pr.sh 341
```

## 场景 7: 主动发现任务（高级）

在 monitor-agents.sh 中添加主动扫描逻辑：

```bash
# 扫描 Sentry 错误 -> 自动创建修复任务
# 扫描 TODO 注释 -> 自动创建实现任务
# 扫描会议记录 -> 自动创建功能任务
```

## 常用命令速查

```bash
# 创建任务
./create-task.sh "描述" [codex|claude|gemini] [low|normal|high|critical]

# 查看状态
./status.sh

# 监控
./monitor-agents.sh

# 进入 tmux
tmux attach -t <session-name>
tmux ls

# 发送指令给 Agent
tmux send-keys -t <session> '消息' Enter

# 杀死会话
tmux kill-session -t <session>

# 查看日志
tail -f logs/monitor.log
```

## 最佳实践

1. **任务描述要清晰**: 包含业务背景和需求细节
2. **选择合适的 Agent**: 后端用 Codex，前端用 Claude，设计用 Gemini
3. **设置合理的优先级**: critical/high 会立即处理
4. **监控日志**: 定期查看 monitor.log 了解系统状态
5. **及时干预**: 如果 Agent 走偏，通过 tmux 发送指令
6. **保持 worktree 干净**: 系统会自动清理已完成任务
