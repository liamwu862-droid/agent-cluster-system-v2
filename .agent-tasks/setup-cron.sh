#!/bin/bash
# OpenClaw Cron 集成脚本
# 将系统监控任务添加到 OpenClaw 的 cron 系统中

REPO_ROOT="/Users/clawd/.openclaw/workspace"
AGENT_DIR="$REPO_ROOT/.agent-tasks"

echo "🔗 集成 Agent 集群到 OpenClaw Cron"
echo "================================"
echo ""

# 检查 openclaw CLI
if ! command -v openclaw &> /dev/null; then
    echo "❌ 未找到 openclaw CLI"
    exit 1
fi

echo "📋 当前 OpenClaw cron 任务:"
openclaw cron list 2>/dev/null || echo "暂无任务"
echo ""

# 添加监控任务
echo "➕ 添加 Agent 监控任务（每10分钟）..."
openclaw cron add \
    --name "agent-cluster-monitor" \
    --schedule "every 10 minutes" \
    --command "$AGENT_DIR/monitor-agents.sh" \
    2>/dev/null || echo "⚠️  添加任务失败，可能已存在"

# 添加智能重试任务
echo "➕ 添加智能重试检查（每15分钟）..."
openclaw cron add \
    --name "agent-smart-retry" \
    --schedule "every 15 minutes" \
    --command "$AGENT_DIR/smart-retry.sh" \
    2>/dev/null || echo "⚠️  添加任务失败，可能已存在"

# 添加每日清理任务
echo "➕ 添加每日清理任务（凌晨2点）..."
openclaw cron add \
    --name "agent-daily-cleanup" \
    --schedule "0 2 * * *" \
    --command "$AGENT_DIR/cleanup.sh" \
    2>/dev/null || echo "⚠️  添加任务失败，可能已存在"

echo ""
echo "✅ OpenClaw Cron 集成完成"
echo ""
echo "📊 查看任务: openclaw cron list"
echo "📜 查看日志: openclaw cron logs"
