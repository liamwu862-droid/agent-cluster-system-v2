#!/bin/bash
# Agent 监控系统
# 每 10 分钟运行一次，检查所有 Agent 状态

REPO_ROOT="/Users/clawd/.openclaw/workspace"
WORKTREE_BASE="$REPO_ROOT/worktrees"
LOG_FILE="$REPO_ROOT/.agent-tasks/monitor.log"
FEISHU_WEBHOOK="https://open.feishu.cn/open-apis/bot/v2/hook/02fdfc79-889b-497d-894d-ffd8af32da14"

mkdir -p "$WORKTREE_BASE" "$(dirname $LOG_FILE)"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 发送飞书通知
send_notification() {
    local title="$1"
    local content="$2"
    
    curl -s -X POST "$FEISHU_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "{
            \"msg_type\": \"post\",
            \"content\": {
                \"post\": {
                    \"zh_cn\": {
                        \"title\": \"🤖 [Agent集群] $title\",
                        \"content\": [[{\"tag\": \"text\", \"text\": \"$content\"}]]
                    }
                }
            }
        }" > /dev/null
}

# 检查单个 worktree 状态
check_worktree() {
    local worktree_dir="$1"
    local task_file="$worktree_dir/.task.json"
    
    [ ! -f "$task_file" ] && return
    
    local task_id=$(jq -r '.id' "$task_file" 2>/dev/null || echo "unknown")
    local session=$(jq -r '.tmuxSession' "$task_file" 2>/dev/null || echo "")
    local branch=$(jq -r '.branch' "$task_file" 2>/dev/null || echo "")
    local status=$(jq -r '.status' "$task_file" 2>/dev/null || echo "running")
    local desc=$(jq -r '.description' "$task_file" 2>/dev/null || echo "unknown")
    local agent=$(jq -r '.agent' "$task_file" 2>/dev/null || echo "unknown")
    
    log "检查任务: $task_id ($desc)"
    
    # 检查 tmux 会话是否存活
    if [ -n "$session" ] && ! tmux has-session -t "$session" 2>/dev/null; then
        log "  ⚠️ 会话已结束: $session"
        
        # 检查是否创建了 PR
        cd "$worktree_dir"
        local has_pr=$(gh pr list --head "$branch" --json number 2>/dev/null | jq 'length')
        
        if [ "$has_pr" -gt 0 ]; then
            log "  ✅ 已创建 PR"
            # 检查 PR 状态
            local pr_number=$(gh pr list --head "$branch" --json number -q '.[0].number')
            local pr_state=$(gh pr view "$pr_number" --json state -q '.state')
            local ci_status=$(gh pr checks "$pr_number" --json state -q '.[0].state' 2>/dev/null || echo "unknown")
            
            # 更新任务状态
            jq '.status = "pr_created" | .prNumber = '"$pr_number"' | .ciStatus = "'"$ci_status"'"' "$task_file" > "$task_file.tmp" && mv "$task_file.tmp" "$task_file"
            
            # 如果 CI 通过，通知人工 review
            if [ "$ci_status" = "SUCCESS" ] || [ "$ci_status" = "success" ]; then
                local notify_sent=$(jq -r '.notifySent // "false"' "$task_file")
                if [ "$notify_sent" != "true" ]; then
                    send_notification "PR 已准备好 Review" \
                        "任务: $desc\nAgent: $agent\nPR: #$pr_number\n状态: CI 通过 ✅\n\n请检查 PR 描述中的截图（如有 UI 改动），然后合并。"
                    jq '.notifySent = true' "$task_file" > "$task_file.tmp" && mv "$task_file.tmp" "$task_file"
                fi
            fi
        else
            # 检查是否失败（重试逻辑）
            local retries=$(jq -r '.retries // 0' "$task_file")
            if [ "$retries" -lt 3 ]; then
                log "  🔄 重试任务 (第 $((retries+1)) 次)"
                # 分析失败原因并调整 prompt（简化版）
                jq '.retries = '$((retries+1))' | .status = "retrying"' "$task_file" > "$task_file.tmp" && mv "$task_file.tmp" "$task_file"
                # 重新启动 agent（这里需要实现更智能的重启逻辑）
            else
                log "  ❌ 任务失败，重试次数已达上限"
                jq '.status = "failed"' "$task_file" > "$task_file.tmp" && mv "$task_file.tmp" "$task_file"
                send_notification "任务失败" "任务: $desc\nAgent: $agent\n状态: 已失败（重试3次）\n\n需要人工介入。"
            fi
        fi
    else
        log "  🟢 会话运行中: $session"
    fi
}

# 主循环
log "=== 开始监控 ==="

for worktree in "$WORKTREE_BASE"/feat-*; do
    [ -d "$worktree" ] || continue
    check_worktree "$worktree"
done

# 清理已完成的任务（每天一次）
if [ "$(date +%H:%M)" = "02:00" ]; then
    log "执行每日清理..."
    for worktree in "$WORKTREE_BASE"/feat-*; do
        [ -d "$worktree" ] || continue
        local task_file="$worktree/.task.json"
        if [ -f "$task_file" ]; then
            local status=$(jq -r '.status' "$task_file" 2>/dev/null || echo "running")
            if [ "$status" = "completed" ] || [ "$status" = "failed" ]; then
                local branch=$(jq -r '.branch' "$task_file" 2>/dev/null || echo "")
                log "清理已完成任务: $branch"
                cd "$REPO_ROOT"
                git worktree remove "$worktree" 2>/dev/null
                git branch -D "$branch" 2>/dev/null
            fi
        fi
    done
fi

log "=== 监控完成 ==="
