#!/bin/bash
# 创建新任务 - 编排层入口
# 用法: ./create-task.sh "任务描述" [agent-type] [priority]

TASK_DESC="$1"
AGENT_TYPE="${2:-codex}"
PRIORITY="${3:-normal}"

REPO_ROOT="/Users/clawd/.openclaw/workspace"
FEISHU_WEBHOOK="https://open.feishu.cn/open-apis/bot/v2/hook/02fdfc79-889b-497d-894d-ffd8af32da14"

if [ -z "$TASK_DESC" ]; then
    echo "用法: ./create-task.sh \"任务描述\" [agent-type] [priority]"
    echo "  agent-type: codex | claude | gemini"
    echo "  priority: low | normal | high | critical"
    exit 1
fi

# 生成任务 ID
TASK_ID=$(date +%s)
TASK_TYPE=$(echo "$TASK_DESC" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | cut -c1-30)

echo "创建新任务..."
echo "  描述: $TASK_DESC"
echo "  Agent: $AGENT_TYPE"
echo "  优先级: $PRIORITY"

# 启动 Agent
export TASK_ID="$TASK_ID"
export TASK_DESC="$TASK_DESC"
"$REPO_ROOT/.agent-tasks/run-agent.sh" "$TASK_TYPE" "$AGENT_TYPE" "$PRIORITY"

# 发送飞书通知
curl -s -X POST "$FEISHU_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "{
        \"msg_type\": \"post\",
        \"content\": {
            \"post\": {
                \"zh_cn\": {
                    \"title\": \"🚀 新任务已启动\",
                    \"content\": [[{\"tag\": \"text\", \"text\": \"任务: $TASK_DESC\nAgent: $AGENT_TYPE\n优先级: $PRIORITY\n\n任务已分配给 Agent，正在执行中...\"}]]
                }
            }
        }
    }" > /dev/null

echo ""
echo "✅ 任务已创建"
