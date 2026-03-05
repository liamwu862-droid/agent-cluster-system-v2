#!/bin/bash
# 批量创建任务
# 用法: ./batch-create.sh <tasks-file>
# 任务文件格式（JSON）:
# [
#   {"desc": "任务1", "agent": "codex", "priority": "high"},
#   {"desc": "任务2", "agent": "claude", "priority": "normal"}
# ]

REPO_ROOT="/Users/clawd/.openclaw/workspace"
AGENT_DIR="$REPO_ROOT/.agent-tasks"

TASKS_FILE="${1:-$AGENT_DIR/batch-tasks.json}"

if [ ! -f "$TASKS_FILE" ]; then
    echo "❌ 任务文件不存在: $TASKS_FILE"
    echo ""
    echo "创建示例任务文件:"
    cat > "$AGENT_DIR/batch-tasks-example.json" << 'EOF'
[
  {
    "desc": "实现用户登录API",
    "agent": "codex",
    "priority": "high",
    "deps": []
  },
  {
    "desc": "实现登录页面UI",
    "agent": "claude",
    "priority": "high",
    "deps": ["task-1"]
  },
  {
    "desc": "设计登录页样式",
    "agent": "gemini",
    "priority": "normal",
    "deps": []
  }
]
EOF
    echo "✅ 示例文件已创建: $AGENT_DIR/batch-tasks-example.json"
    exit 1
fi

echo "📋 批量创建任务"
echo "==============="
echo ""

# 读取任务列表
tasks=$(jq -c '.[]' "$TASKS_FILE")

# 存储任务ID映射
declare -A task_id_map

# 第一轮：创建所有任务（标记依赖）
echo "🚀 第一轮：创建任务..."
echo "$tasks" | while read task; do
    desc=$(echo "$task" | jq -r '.desc')
    agent=$(echo "$task" | jq -r '.agent // "codex"')
    priority=$(echo "$task" | jq -r '.priority // "normal"')
    deps=$(echo "$task" | jq -r '.deps // [] | @json')
    
    echo "  创建: $desc ($agent, $priority)"
    
    # 创建任务并捕获输出
    output=$(cd "$AGENT_DIR" && ./create-task.sh "$desc" "$agent" "$priority" 2>&1)
    
    # 提取任务ID（从输出中）
    task_id=$(echo "$output" | grep -oP 'feat-[^-]+-\K[0-9]+' | head -1)
    
    if [ -n "$task_id" ]; then
        echo "    ✅ 任务ID: $task_id"
        
        # 如果有依赖，记录到依赖系统
        if [ "$deps" != "[]" ]; then
            echo "    📌 将在依赖完成后启动"
            # 这里可以添加依赖记录逻辑
        fi
    else
        echo "    ❌ 创建失败"
    fi
    
    echo ""
done

echo "✅ 批量任务创建完成"
echo ""
echo "查看状态: $AGENT_DIR/status.sh"
