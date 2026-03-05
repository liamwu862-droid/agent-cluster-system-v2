#!/bin/bash
# 增强版 PR 审查系统
# 用法: ./review-pr-v2.sh <pr-number> [--auto-comment]

REPO_ROOT="/Users/clawd/.openclaw/workspace"
AGENT_DIR="$REPO_ROOT/.agent-tasks"
PR_NUMBER="$1"
AUTO_COMMENT=false

if [ "$2" = "--auto-comment" ]; then
    AUTO_COMMENT=true
fi

if [ -z "$PR_NUMBER" ]; then
    echo "用法: ./review-pr-v2.sh <pr-number> [--auto-comment]"
    exit 1
fi

cd "$REPO_ROOT"

# 获取 PR 详细信息
echo "📋 获取 PR #$PR_NUMBER 信息..."
pr_info=$(gh pr view "$PR_NUMBER" --json number,title,body,headRefName,baseRefName,changedFiles,additions,deletions,author 2>/dev/null)

if [ -z "$pr_info" ]; then
    echo "❌ 无法获取 PR #$PR_NUMBER"
    exit 1
fi

title=$(echo "$pr_info" | jq -r '.title')
body=$(echo "$pr_info" | jq -r '.body')
files=$(echo "$pr_info" | jq -r '.changedFiles')
additions=$(echo "$pr_info" | jq -r '.additions')
deletions=$(echo "$pr_info" | jq -r '.deletions')
author=$(echo "$pr_info" | jq -r '.author.login')
head_ref=$(echo "$pr_info" | jq -r '.headRefName')

echo "  标题: $title"
echo "  作者: $author"
echo "  改动: +$additions -$deletions ($files 个文件)"
echo ""

# 获取代码差异
echo "📄 获取代码差异..."
gh pr diff "$PR_NUMBER" > "/tmp/pr-$PR_NUMBER.diff" 2>/dev/null

# 确定审查重点
if echo "$files" | grep -qi "test"; then
    focus="test"
elif echo "$files" | grep -Eqi "\.(css|scss|less|html|vue|jsx|tsx)$"; then
    focus="frontend"
elif echo "$files" | grep -Eqi "\.(sql|prisma|migration)$"; then
    focus="database"
else
    focus="backend"
fi

echo "🔍 审查重点: $focus"
echo ""

# 生成审查提示
generate_review_prompt() {
    local reviewer="$1"
    
    cat << EOF
请审查以下 Pull Request，以 $reviewer 的视角：

PR 信息:
- 标题: $title
- 作者: $author
- 改动: +$additions -$deletions ($files 个文件)
- 审查重点: $focus

审查指南:
EOF

    case "$reviewer" in
        codex)
            echo "- 检查逻辑正确性和边界情况"
            echo "- 评估错误处理是否完善"
            echo "- 分析性能影响"
            echo "- 检查是否有竞态条件"
            echo "- 验证测试覆盖率"
            ;;
        gemini)
            echo "- 评估代码安全性"
            echo "- 检查扩展性和可维护性"
            echo "- 分析架构设计"
            echo "- 建议改进方案"
            ;;
        claude)
            echo "- 检查代码风格和规范"
            echo "- 评估前端/UI 代码质量"
            echo "- 检查可访问性"
            echo "- 建议重构机会"
            ;;
    esac
    
    echo ""
    echo "请提供具体的、可操作的审查意见。格式："
    echo "- 🔴 严重：必须修复的问题"
    echo "- 🟡 建议：可以改进的地方"
    echo "- 🟢 好评：做得好的地方"
    echo ""
    echo "代码差异:"
    cat "/tmp/pr-$PR_NUMBER.diff"
EOF
}

# 执行审查（使用可用的工具）
echo "🤖 开始代码审查..."
echo ""

# Codex 审查（如果可用）
if command -v codex &> /dev/null; then
    echo "Codex Reviewer:"
    generate_review_prompt "codex" | codex --no-interactive 2>/dev/null || echo "  (Codex 未响应)"
    echo ""
fi

# Claude 审查（如果可用）
if command -v claude &> /dev/null; then
    echo "Claude Reviewer:"
    generate_review_prompt "claude" | claude --no-interactive 2>/dev/null || echo "  (Claude 未响应)"
    echo ""
fi

# Gemini 审查（如果可用）
if command -v gemini &> /dev/null; then
    echo "Gemini Reviewer:"
    generate_review_prompt "gemini" | gemini --no-interactive 2>/dev/null || echo "  (Gemini 未响应)"
    echo ""
fi

# 自动生成审查摘要
echo "📝 生成审查摘要..."
cat << SUMMARY

========================================
          PR 审查摘要
========================================
PR: #$PR_NUMBER - $title
作者: $author
改动: +$additions -$deletions
文件: $files
分支: $head_ref

审查重点: $focus

建议:
1. 确保所有 CI 检查通过
2. 检查测试覆盖率
3. 验证功能符合需求
4. 关注安全性问题（如有）

========================================
SUMMARY

# 清理临时文件
rm -f "/tmp/pr-$PR_NUMBER.diff"

echo ""
echo "✅ 审查完成"
echo ""
echo "操作:"
echo "  gh pr view $PR_NUMBER --web    # 在浏览器中查看"
echo "  gh pr checks $PR_NUMBER        # 查看 CI 状态"
echo "  gh pr merge $PR_NUMBER         # 合并 PR"
