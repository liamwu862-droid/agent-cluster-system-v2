#!/bin/bash
# 任务依赖管理系统
# 用法: ./task-deps.sh <command> [args]

REPO_ROOT="/Users/clawd/.openclaw/workspace"
WORKTREE_BASE="$REPO_ROOT/worktrees"
DEPS_FILE="$REPO_ROOT/.agent-tasks/task-deps.json"

# 初始化依赖文件
init_deps() {
    if [ ! -f "$DEPS_FILE" ]; then
        echo '{"dependencies": {}, "blocked": {}}' > "$DEPS_FILE"
    fi
}

# 添加任务依赖
add_dep() {
    local task_id="$1"
    local dep_id="$2"
    
    init_deps
    
    # 添加依赖关系
    jq --arg task "$task_id" --arg dep "$dep_id" \
        '.dependencies[$task] += [$dep]' "$DEPS_FILE" > "$DEPS_FILE.tmp" && \
        mv "$DEPS_FILE.tmp" "$DEPS_FILE"
    
    echo "✅ 任务 $task_id 现在依赖任务 $dep_id"
    
    # 标记为阻塞状态
    jq --arg task "$task_id" '.blocked[$task] = true' "$DEPS_FILE" > "$DEPS_FILE.tmp" && \
        mv "$DEPS_FILE.tmp" "$DEPS_FILE"
}

# 检查任务是否可启动
check_ready() {
    local task_id="$1"
    
    init_deps
    
    local deps=$(jq -r --arg task "$task_id" '.dependencies[$task] // [] | .[]' "$DEPS_FILE" 2>/dev/null)
    
    if [ -z "$deps" ]; then
        echo "true"
        return
    fi
    
    for dep in $deps; do
        local dep_completed=false
        
        # 检查依赖任务是否完成
        for worktree in "$WORKTREE_BASE"/feat-*; do
            [ -d "$worktree" ] || continue
            local task_file="$worktree/.task.json"
            [ ! -f "$task_file" ] && continue
            
            local id=$(jq -r '.id' "$task_file" 2>/dev/null)
            local status=$(jq -r '.status' "$task_file" 2>/dev/null)
            
            if [ "$id" = "$dep" ] && [ "$status" = "completed" ]; then
                dep_completed=true
                break
            fi
        done
        
        if [ "$dep_completed" = "false" ]; then
            echo "false"
            return
        fi
    done
    
    echo "true"
}

# 解锁任务（当依赖完成时）
unlock_task() {
    local completed_task="$1"
    
    init_deps
    
    # 查找所有依赖于此任务的任务
    local blocked_tasks=$(jq -r --arg dep "$completed_task" \
        '.dependencies | to_entries[] | select(.value | contains([$dep])) | .key' "$DEPS_FILE" 2>/dev/null)
    
    for task in $blocked_tasks; do
        if [ "$(check_ready "$task")" = "true" ]; then
            jq --arg task "$task" '.blocked[$task] = false' "$DEPS_FILE" > "$DEPS_FILE.tmp" && \
                mv "$DEPS_FILE.tmp" "$DEPS_FILE"
            
            echo "🔓 任务 $task 已解锁"
            
            # 发送通知
            local task_file=$(find "$WORKTREE_BASE" -name ".task.json" -exec grep -l "\"id\": \"$task\"" {} \; 2>/dev/null | head -1)
            if [ -n "$task_file" ]; then
                local desc=$(jq -r '.description' "$task_file" 2>/dev/null)
                echo "📢 任务可以启动了: $desc"
            fi
        fi
    done
}

# 列出所有阻塞的任务
list_blocked() {
    init_deps
    
    echo "阻塞中的任务："
    jq -r '.blocked | to_entries[] | select(.value == true) | .key' "$DEPS_FILE" 2>/dev/null | while read task_id; do
        local task_file=$(find "$WORKTREE_BASE" -name ".task.json" -exec grep -l "\"id\": \"$task_id\"" {} \; 2>/dev/null | head -1)
        if [ -n "$task_file" ]; then
            local desc=$(jq -r '.description' "$task_file" 2>/dev/null)
            local deps=$(jq -r --arg task "$task_id" '.dependencies[$task] // [] | join(", ")' "$DEPS_FILE")
            echo "  - $desc (依赖: $deps)"
        fi
    done
}

# 主命令处理
case "$1" in
    add)
        add_dep "$2" "$3"
        ;;
    check)
        check_ready "$2"
        ;;
    unlock)
        unlock_task "$2"
        ;;
    list)
        list_blocked
        ;;
    *)
        echo "用法: ./task-deps.sh <command> [args]"
        echo ""
        echo "命令:"
        echo "  add <task-id> <dep-id>    添加任务依赖"
        echo "  check <task-id>           检查任务是否就绪"
        echo "  unlock <completed-task>   解锁依赖于此任务的其他任务"
        echo "  list                      列出所有阻塞的任务"
        echo ""
        echo "示例:"
        echo "  ./task-deps.sh add task2 task1    # task2 依赖 task1"
        echo "  ./task-deps.sh check task2        # 检查 task2 是否可启动"
        ;;
esac
