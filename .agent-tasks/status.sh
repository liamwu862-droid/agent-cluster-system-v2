#!/bin/bash
# 查看所有任务状态

REPO_ROOT="/Users/clawd/.openclaw/workspace"
WORKTREE_BASE="$REPO_ROOT/worktrees"

echo "========================================"
echo "       Agent 集群任务状态"
echo "========================================"
echo ""

for worktree in "$WORKTREE_BASE"/feat-*; do
    [ -d "$worktree" ] || continue
    
    task_file="$worktree/.task.json"
    [ ! -f "$task_file" ] && continue
    
    id=$(jq -r '.id' "$task_file" 2>/dev/null || echo "?")
    agent=$(jq -r '.agent' "$task_file" 2>/dev/null || echo "?")
    desc=$(jq -r '.description' "$task_file" 2>/dev/null || echo "?")
    status=$(jq -r '.status' "$task_file" 2>/dev/null || echo "?")
    branch=$(jq -r '.branch' "$task_file" 2>/dev/null || echo "?")
    session=$(jq -r '.tmuxSession' "$task_file" 2>/dev/null || echo "?")
    
    # 状态颜色
    case $status in
        running) status_icon="🟢" ;;
        pr_created) status_icon="🟡" ;;
        completed) status_icon="✅" ;;
        failed) status_icon="❌" ;;
        retrying) status_icon="🔄" ;;
        *) status_icon="⚪" ;;
    esac
    
    echo "任务: $desc"
    echo "  ID: $id"
    echo "  Agent: $agent"
    echo "  状态: $status_icon $status"
    echo "  分支: $branch"
    echo "  会话: $session"
    
    # 检查 tmux 状态
    if tmux has-session -t "$session" 2>/dev/null; then
        echo "  tmux: 运行中"
    else
        echo "  tmux: 已结束"
    fi
    
    # 检查 PR
    pr_number=$(jq -r '.prNumber // "null"' "$task_file" 2>/dev/null)
    if [ "$pr_number" != "null" ] && [ -n "$pr_number" ]; then
        echo "  PR: #$pr_number"
    fi
    
    echo "----------------------------------------"
done

echo ""
echo "操作命令:"
echo "  ./create-task.sh \"描述\" [agent] [priority]  # 创建新任务"
echo "  ./monitor-agents.sh                           # 手动监控"
echo "  tmux attach -t <session>                      # 进入会话"
echo "  tmux ls                                       # 列出所有会话"
