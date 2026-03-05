#!/bin/bash
# Agent 启动脚本
# 用法: ./run-agent.sh <task-type> <agent-type> <priority>
# 示例: ./run-agent.sh templates codex high

TASK_TYPE=$1
AGENT_TYPE=${2:-"codex"}  # codex, claude, gemini
PRIORITY=${3:-"normal"}   # low, normal, high, critical

# 配置
REPO_ROOT="/Users/clawd/.openclaw/workspace"
WORKTREE_BASE="$REPO_ROOT/worktrees"
TASKS_FILE="$REPO_ROOT/.agent-tasks/tasks.json"
LOG_DIR="$REPO_ROOT/.agent-tasks/logs"

mkdir -p "$WORKTREE_BASE" "$LOG_DIR"

# 读取任务上下文（如果有）
TASK_ID="${TASK_ID:-$(date +%s)}"
TASK_DESC="${TASK_DESC:-$TASK_TYPE}"

echo "启动 Agent: $AGENT_TYPE | 任务: $TASK_TYPE | 优先级: $PRIORITY"

# 根据 Agent 类型选择命令
case $AGENT_TYPE in
    codex)
        AGENT_CMD="codex"
        ;;
    claude)
        AGENT_CMD="claude"
        ;;
    gemini)
        AGENT_CMD="gemini"
        ;;
    *)
        AGENT_CMD="codex"
        ;;
esac

# 使用安全的标识符（避免中文和特殊字符）
SAFE_TASK_ID="task-$TASK_ID"
WORKTREE_DIR="$WORKTREE_BASE/feat-$SAFE_TASK_ID"
BRANCH_NAME="feat/$SAFE_TASK_ID"

# 创建 git worktree
cd "$REPO_ROOT"
git fetch origin main 2>/dev/null || true
git worktree add "$WORKTREE_DIR" -b "$BRANCH_NAME" origin/main 2>/dev/null || \
    git worktree add "$WORKTREE_DIR" "$BRANCH_NAME" 2>/dev/null || \
    (git branch -D "$BRANCH_NAME" 2>/dev/null; git worktree add "$WORKTREE_DIR" -b "$BRANCH_NAME" origin/main)

# 安装依赖
cd "$WORKTREE_DIR"
if [ -f "package.json" ]; then
    pnpm install 2>/dev/null || npm install 2>/dev/null || yarn install 2>/dev/null
fi

# 构建任务上下文
PROMPT_FILE="$WORKTREE_DIR/.agent-prompt.md"
cat > "$PROMPT_FILE" << 'EOF'
# 任务说明
EOF

echo "任务类型: $TASK_TYPE" >> "$PROMPT_FILE"
echo "任务描述: $TASK_DESC" >> "$PROMPT_FILE"
echo "优先级: $PRIORITY" >> "$PROMPT_FILE"
echo "" >> "$PROMPT_FILE"
echo "# 上下文信息" >> "$PROMPT_FILE"
echo "- 工作目录: $WORKTREE_DIR" >> "$PROMPT_FILE"
echo "- 分支: $BRANCH_NAME" >> "$PROMPT_FILE"
echo "" >> "$PROMPT_FILE"
echo "# 执行要求" >> "$PROMPT_FILE"
echo "1. 在 worktree 目录中完成所有修改" >> "$PROMPT_FILE"
echo "2. 编写完整的单元测试" >> "$PROMPT_FILE"
echo "3. 确保所有测试通过" >> "$PROMPT_FILE"
echo "4. 提交代码并创建 PR" >> "$PROMPT_FILE"
echo "5. 如果有 UI 改动，在 PR 描述中附上截图说明" >> "$PROMPT_FILE"

# 启动 tmux 会话
SESSION_NAME="agent-$SAFE_TASK_ID"
tmux new-session -d -s "$SESSION_NAME" -c "$WORKTREE_DIR"

# 在 tmux 中启动 Agent
tmux send-keys -t "$SESSION_NAME" "cd $WORKTREE_DIR && cat .agent-prompt.md && echo '---' && $AGENT_CMD" Enter

# 记录任务
TASK_JSON=$(cat << EOF
{
  "id": "$TASK_ID",
  "tmuxSession": "$SESSION_NAME",
  "agent": "$AGENT_TYPE",
  "taskType": "$TASK_TYPE",
  "description": "$TASK_DESC",
  "repo": "$(basename $REPO_ROOT)",
  "worktree": "$WORKTREE_DIR",
  "branch": "$BRANCH_NAME",
  "startedAt": $(date +%s)000,
  "status": "running",
  "priority": "$PRIORITY",
  "notifyOnComplete": true
}
EOF
)

echo "$TASK_JSON" > "$WORKTREE_DIR/.task.json"

echo "✅ Agent 已启动"
echo "   会话: $SESSION_NAME"
echo "   工作目录: $WORKTREE_DIR"
echo "   分支: $BRANCH_NAME"
echo "   任务文件: $WORKTREE_DIR/.task.json"
echo ""
echo "监控命令:"
echo "  tmux attach -t $SESSION_NAME    # 进入会话"
echo "  tmux send-keys -t $SESSION_NAME '消息' Enter  # 发送指令"
