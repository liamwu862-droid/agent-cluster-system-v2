#!/bin/bash
# 安装 Agent 集群系统
# 运行: ./install.sh

set -e

REPO_ROOT="/Users/clawd/.openclaw/workspace"
AGENT_DIR="$REPO_ROOT/.agent-tasks"

echo "========================================"
echo "   Agent 集群系统安装"
echo "========================================"
echo ""

# 检查依赖
echo "检查依赖..."

# 检查 git
if ! command -v git &> /dev/null; then
    echo "❌ 未找到 git，请先安装"
    exit 1
fi

# 检查 tmux
if ! command -v tmux &> /dev/null; then
    echo "❌ 未找到 tmux，请先安装: brew install tmux"
    exit 1
fi

# 检查 GitHub CLI
if ! command -v gh &> /dev/null; then
    echo "❌ 未找到 gh，请先安装: brew install gh"
    exit 1
fi

# 检查 jq
if ! command -v jq &> /dev/null; then
    echo "❌ 未找到 jq，请先安装: brew install jq"
    exit 1
fi

echo "✅ 所有依赖已安装"
echo ""

# 创建目录结构
echo "创建目录结构..."
mkdir -p "$AGENT_DIR/logs"
mkdir -p "$REPO_ROOT/worktrees"
echo "✅ 目录创建完成"
echo ""

# 设置执行权限
echo "设置脚本权限..."
chmod +x "$AGENT_DIR"/*.sh
echo "✅ 权限设置完成"
echo ""

# 检查 GitHub 登录状态
echo "检查 GitHub CLI 登录状态..."
if ! gh auth status &> /dev/null; then
    echo "⚠️  GitHub CLI 未登录，请先运行: gh auth login"
fi

# 添加 cron 任务
echo "设置定时监控任务..."
CRON_JOB="*/10 * * * * cd $AGENT_DIR && ./monitor-agents.sh >> $AGENT_DIR/logs/cron.log 2>&1"

# 检查是否已存在
if crontab -l 2>/dev/null | grep -q "monitor-agents.sh"; then
    echo "✅ 定时任务已存在"
else
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "✅ 定时任务已添加（每10分钟监控一次）"
fi
echo ""

echo "========================================"
echo "   安装完成！"
echo "========================================"
echo ""
echo "使用指南:"
echo ""
echo "1. 创建新任务:"
echo "   cd $AGENT_DIR"
echo "   ./create-task.sh \"实现用户登录功能\" codex high"
echo ""
echo "2. 查看任务状态:"
echo "   ./status.sh"
echo ""
echo "3. 进入 Agent 会话:"
echo "   tmux attach -t agent-<task-type>-<id>"
echo ""
echo "4. 向 Agent 发送指令:"
echo "   tmux send-keys -t agent-<task-type>-<id> '停一下，先做API层' Enter"
echo ""
echo "5. 手动运行监控:"
echo "   ./monitor-agents.sh"
echo ""
echo "Agent 类型选择:"
echo "   codex   - 主力，后端逻辑、复杂bug、多文件重构"
echo "   claude  - 前端工作、速度型任务"
echo "   gemini  - 设计师、UI/UX 设计"
echo ""
echo "注意事项:"
echo "   - 每个 Agent 使用独立的 git worktree"
echo "   - Agent 通过 tmux 在后台运行"
echo "   - 监控脚本每10分钟检查一次状态"
echo "   - CI 通过后自动通知飞书"
echo "   - 每天凌晨2点自动清理已完成的任务"
