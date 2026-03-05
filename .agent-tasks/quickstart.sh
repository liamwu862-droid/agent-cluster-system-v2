#!/bin/bash
# 快速启动 Agent 集群系统

REPO_ROOT="/Users/clawd/.openclaw/workspace"
AGENT_DIR="$REPO_ROOT/.agent-tasks"

cd "$AGENT_DIR"

echo "🚀 Agent 集群系统"
echo "=================="
echo ""

# 显示当前状态
echo "📊 当前任务状态:"
echo "----------------"
./status.sh 2>/dev/null || echo "暂无运行中的任务"
echo ""

# 显示菜单
echo "操作选项:"
echo "  1) 创建新任务"
echo "  2) 查看所有任务"
echo "  3) 手动运行监控"
echo "  4) 查看日志"
echo "  5) 查看帮助"
echo "  q) 退出"
echo ""

read -p "选择操作 [1-5/q]: " choice

case $choice in
    1)
        echo ""
        read -p "任务描述: " desc
        echo "选择 Agent:"
        echo "  1) codex - 后端/复杂逻辑"
        echo "  2) claude - 前端/快速"
        echo "  3) gemini - 设计/UI"
        read -p "选择 [1-3]: " agent_choice
        case $agent_choice in
            1) agent="codex" ;;
            2) agent="claude" ;;
            3) agent="gemini" ;;
            *) agent="codex" ;;
        esac
        echo "选择优先级:"
        echo "  1) critical - 紧急"
        echo "  2) high - 高"
        echo "  3) normal - 普通"
        echo "  4) low - 低"
        read -p "选择 [1-4]: " prio_choice
        case $prio_choice in
            1) prio="critical" ;;
            2) prio="high" ;;
            3) prio="normal" ;;
            4) prio="low" ;;
            *) prio="normal" ;;
        esac
        echo ""
        ./create-task.sh "$desc" "$agent" "$prio"
        ;;
    2)
        ./status.sh
        ;;
    3)
        ./monitor-agents.sh
        ;;
    4)
        echo ""
        echo "可用日志文件:"
        ls -la logs/ 2>/dev/null || echo "暂无日志"
        echo ""
        read -p "查看哪个日志? (直接回车查看最新): " logfile
        if [ -z "$logfile" ]; then
            tail -50 logs/monitor.log 2>/dev/null || echo "暂无监控日志"
        else
            tail -50 "logs/$logfile" 2>/dev/null || echo "日志不存在"
        fi
        ;;
    5)
        cat README.md
        ;;
    q|Q)
        echo "再见!"
        exit 0
        ;;
    *)
        echo "无效选择"
        ;;
esac
