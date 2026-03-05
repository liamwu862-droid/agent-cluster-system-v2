#!/bin/bash
# 使用模板创建任务
# 用法: ./create-from-template.sh <template> "任务描述"

REPO_ROOT="/Users/clawd/.openclaw/workspace"
AGENT_DIR="$REPO_ROOT/.agent-tasks"
TEMPLATES_FILE="$AGENT_DIR/templates.json"

TEMPLATE="$1"
TASK_DESC="$2"

if [ -z "$TEMPLATE" ] || [ -z "$TASK_DESC" ]; then
    echo "用法: ./create-from-template.sh <template> \"任务描述\""
    echo ""
    echo "可用模板:"
    jq -r '.templates | to_entries[] | "  \(.key) - \(.value.name)"' "$TEMPLATES_FILE" 2>/dev/null || echo "  (无法读取模板)"
    echo ""
    echo "示例:"
    echo "  ./create-from-template.sh backend-api \"实现用户认证API\""
    echo "  ./create-from-template.sh frontend-page \"添加用户设置页面\""
    exit 1
fi

# 读取模板配置
agent=$(jq -r ".templates[\"$TEMPLATE\"].agent" "$TEMPLATES_FILE" 2>/dev/null)
additions=$(jq -r ".templates[\"$TEMPLATE\"].prompt_additions[]" "$TEMPLATES_FILE" 2>/dev/null)

if [ "$agent" = "null" ] || [ -z "$agent" ]; then
    echo "❌ 未知模板: $TEMPLATE"
    exit 1
fi

echo "📋 使用模板: $TEMPLATE"
echo "🤖 Agent: $agent"
echo "📝 任务: $TASK_DESC"
echo ""

# 创建临时任务描述（包含模板提示）
full_desc="$TASK_DESC

模板要求:
$additions"

# 创建任务
cd "$AGENT_DIR"
./create-task.sh "$full_desc" "$agent" "normal"
