#!/bin/bash
# 清理已完成的任务
# 可手动运行，也会由 cron 每天自动执行

REPO_ROOT="/Users/clawd/.openclaw/workspace"
WORKTREE_BASE="$REPO_ROOT/worktrees"
FEISHU_WEBHOOK=$(jq -r '.notifications.feishuWebhook' "$REPO_ROOT/.agent-tasks/config.json" 2>/dev/null)

echo "🧹 清理已完成的任务"
echo "=================="
echo ""

cleaned=0
failed=0

for worktree in "$WORKTREE_BASE"/feat-*; do
    [ -d "$worktree" ] || continue
    
    task_file="$worktree/.task.json"
    [ ! -f "$task_file" ] && continue
    
    status=$(jq -r '.status' "$task_file" 2>/dev/null)
    branch=$(jq -r '.branch' "$task_file" 2>/dev/null)
    desc=$(jq -r '.description' "$task_file" 2>/dev/null)
    pr_number=$(jq -r '.prNumber // "null"' "$task_file")
    
    # 清理已完成的任务（已合并）
    if [ "$status" = "completed" ]; then
        echo "✅ 清理已完成: $desc"
        cd "$REPO_ROOT"
        git worktree remove "$worktree" --force 2>/dev/null
        git branch -D "$branch" 2>/dev/null
        ((cleaned++))
        
    # 清理已失败且超过7天的任务
    elif [ "$status" = "failed" ]; then
        started_at=$(jq -r '.startedAt' "$task_file")
        now=$(date +%s)000
        days_old=$(( (now - started_at) / 86400000 ))
        
        if [ "$days_old" -gt 7 ]; then
            echo "🗑️  清理失败任务(>7天): $desc"
            cd "$REPO_ROOT"
            git worktree remove "$worktree" --force 2>/dev/null
            git branch -D "$branch" 2>/dev/null
            ((cleaned++))
        else
            echo "⏳ 保留失败任务(${days_old}天): $desc"
        fi
        
    # 清理已合并的 PR
    elif [ "$pr_number" != "null" ] && [ "$pr_number" != "" ]; then
        pr_state=$(gh pr view "$pr_number" --json state -q '.state' 2>/dev/null || echo "UNKNOWN")
        
        if [ "$pr_state" = "MERGED" ]; then
            echo "🎉 PR 已合并: $desc (#$pr_number)"
            
            # 更新状态
            jq '.status = "completed"' "$task_file" > "$task_file.tmp" && mv "$task_file.tmp" "$task_file"
            
            # 发送通知
            curl -s -X POST "$FEISHU_WEBHOOK" \
                -H "Content-Type: application/json" \
                -d "{
                    \"msg_type\": \"post\",
                    \"content\": {
                        \"post\": {
                            \"zh_cn\": {
                                \"title\": \"🎉 任务完成\",
                                \"content\": [[{\"tag\": \"text\", \"text\": \"任务: $desc\nPR: #$pr_number\n状态: 已合并 ✅\"}]]
                            }
                        }
                    }
                }" > /dev/null
            
            cd "$REPO_ROOT"
            git worktree remove "$worktree" --force 2>/dev/null
            git branch -D "$branch" 2>/dev/null
            ((cleaned++))
        fi
    fi
done

echo ""
echo "✅ 清理完成: $cleaned 个任务"

# 清理孤立的 worktree
echo ""
echo "🧹 检查孤立 worktree..."
cd "$REPO_ROOT"
git worktree prune

echo "✅ 完成"
