#!/bin/bash
# 智能重试系统 - 分析失败原因并调整策略

REPO_ROOT="/Users/clawd/.openclaw/workspace"
WORKTREE_BASE="$REPO_ROOT/worktrees"
AGENT_DIR="$REPO_ROOT/.agent-tasks"
FEISHU_WEBHOOK=$(jq -r '.notifications.feishuWebhook' "$AGENT_DIR/config.json" 2>/dev/null)

# 分析失败日志
analyze_failure() {
    local worktree_dir="$1"
    local task_file="$worktree_dir/.task.json"
    
    [ ! -f "$task_file" ] && return
    
    local retries=$(jq -r '.retries // 0' "$task_file")
    local agent=$(jq -r '.agent' "$task_file")
    local task_type=$(jq -r '.taskType' "$task_file")
    
    # 检查 tmux 日志（如果有）
    local session=$(jq -r '.tmuxSession' "$task_file")
    local tmux_log=""
    
    if [ -n "$session" ]; then
        tmux_log=$(tmux capture-pane -p -t "$session" 2>/dev/null | tail -100)
    fi
    
    # 分析失败类型
    local failure_type="unknown"
    local suggestion=""
    
    if echo "$tmux_log" | grep -qi "error\|failed\|exception"; then
        if echo "$tmux_log" | grep -qi "test"; then
            failure_type="test_failure"
            suggestion="测试未通过，请优先修复测试用例"
        elif echo "$tmux_log" | grep -qi "merge\|conflict"; then
            failure_type="merge_conflict"
            suggestion="存在代码冲突，请先解决冲突"
        elif echo "$tmux_log" | grep -qi "permission\|access"; then
            failure_type="permission_error"
            suggestion="权限问题，需要检查 GitHub 凭证"
        elif echo "$tmux_log" | grep -qi "timeout\|hang"; then
            failure_type="timeout"
            suggestion="任务超时，建议分解为更小的子任务"
        else
            failure_type="code_error"
            suggestion="代码存在错误，请仔细检查实现"
        fi
    fi
    
    # 根据失败类型和重试次数决定策略
    if [ "$retries" -lt 3 ]; then
        # 生成改进后的 prompt
        local improved_prompt=$(generate_improved_prompt "$worktree_dir" "$failure_type" "$suggestion")
        
        # 更新任务文件
        jq --arg type "$failure_type" \
           --arg suggestion "$suggestion" \
           --arg prompt "$improved_prompt" \
           '.failureType = $type | .lastSuggestion = $suggestion | .improvedPrompt = $prompt | .retries = '$((retries+1))'' \
           "$task_file" > "$task_file.tmp" && mv "$task_file.tmp" "$task_file"
        
        echo "failure_type: $failure_type"
        echo "suggestion: $suggestion"
        echo "retries: $((retries+1))"
        
        return 0
    else
        # 重试次数用尽
        jq '.status = "failed"' "$task_file" > "$task_file.tmp" && mv "$task_file.tmp" "$task_file"
        
        # 发送失败通知
        local desc=$(jq -r '.description' "$task_file")
        curl -s -X POST "$FEISHU_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{
                \"msg_type\": \"post\",
                \"content\": {
                    \"post\": {
                        \"zh_cn\": {
                            \"title\": \"❌ 任务失败\",
                            \"content\": [[{\"tag\": \"text\", \"text\": \"任务: $desc\nAgent: $agent\n失败类型: $failure_type\n重试次数: 3/3\n\n需要人工介入。\"}]]
                        }
                    }
                }
            }" > /dev/null
        
        return 1
    fi
}

# 生成改进的 prompt
generate_improved_prompt() {
    local worktree_dir="$1"
    local failure_type="$2"
    local suggestion="$3"
    
    local original_prompt="$worktree_dir/.agent-prompt.md"
    local task_desc=$(jq -r '.description' "$worktree_dir/.task.json")
    
    cat << EOF
# 任务说明（重试改进版）

**注意：这是第 $(($(jq -r '.retries // 0' "$worktree_dir/.task.json") + 1)) 次尝试**

任务描述: $task_desc

## 上一次失败分析
失败类型: $failure_type
建议: $suggestion

## 调整策略
EOF

    case "$failure_type" in
        test_failure)
            echo "1. 先运行现有测试，确保理解测试期望"
            echo "2. 修复代码使测试通过"
            echo "3. 再添加新功能"
            ;;
        merge_conflict)
            echo "1. 先执行 git status 查看冲突文件"
            echo "2. 解决所有冲突标记"
            echo "3. 测试后再提交"
            ;;
        timeout)
            echo "1. 将大任务分解为小步骤"
            echo "2. 每完成一个小步骤就提交"
            echo "3. 优先完成核心功能"
            ;;
        *)
            echo "1. 仔细阅读错误信息"
            echo "2. 从最简单的实现开始"
            echo "3. 频繁测试验证"
            ;;
    esac
    
    echo ""
    echo "## 原始需求"
    cat "$original_prompt" 2>/dev/null || echo "(无法读取原始 prompt)"
}

# 重试任务
retry_task() {
    local worktree_dir="$1"
    local task_file="$worktree_dir/.task.json"
    
    [ ! -f "$task_file" ] && return 1
    
    local session=$(jq -r '.tmuxSession' "$task_file")
    local agent=$(jq -r '.agent' "$task_file")
    local improved_prompt=$(jq -r '.improvedPrompt' "$task_file")
    
    # 停止旧的 tmux 会话
    if [ -n "$session" ] && tmux has-session -t "$session" 2>/dev/null; then
        tmux kill-session -t "$session" 2>/dev/null
    fi
    
    # 生成新的 prompt 文件
    echo "$improved_prompt" > "$worktree_dir/.agent-prompt-retry.md"
    
    # 启动新的 tmux 会话
    local new_session="${session}-retry-$(date +%s)"
    tmux new-session -d -s "$new_session" -c "$worktree_dir"
    
    # 选择 agent 命令
    local agent_cmd="$agent"
    case "$agent" in
        codex) agent_cmd="codex" ;;
        claude) agent_cmd="claude" ;;
        gemini) agent_cmd="gemini" ;;
    esac
    
    # 在 tmux 中启动
    tmux send-keys -t "$new_session" "cd $worktree_dir && cat .agent-prompt-retry.md && echo '---' && $agent_cmd" Enter
    
    # 更新任务文件
    jq --arg session "$new_session" \
       '.tmuxSession = $session | .status = "retrying"' \
       "$task_file" > "$task_file.tmp" && mv "$task_file.tmp" "$task_file"
    
    echo "✅ 任务已重试启动"
    echo "   新会话: $new_session"
}

# 处理单个任务
check_and_retry() {
    local worktree_dir="$1"
    local task_file="$worktree_dir/.task.json"
    
    [ ! -f "$task_file" ] && return
    
    local status=$(jq -r '.status' "$task_file")
    local session=$(jq -r '.tmuxSession' "$task_file")
    
    # 只处理 running 或 retrying 状态且会话已结束的任务
    if [ "$status" = "running" ] || [ "$status" = "retrying" ]; then
        if ! tmux has-session -t "$session" 2>/dev/null; then
            echo "检测到会话结束: $session"
            
            # 分析失败
            if analyze_failure "$worktree_dir"; then
                # 分析成功，执行重试
                retry_task "$worktree_dir"
            fi
        fi
    fi
}

# 主逻辑
echo "🔍 检查需要重试的任务..."

for worktree in "$WORKTREE_BASE"/feat-*; do
    [ -d "$worktree" ] || continue
    check_and_retry "$worktree"
done

echo "✅ 重试检查完成"
