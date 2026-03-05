#!/bin/bash
# 自动化 Code Review 脚本
# 为每个 PR 运行多个 Agent 审查

REPO_ROOT="/Users/clawd/.openclaw/workspace"
PR_NUMBER="$1"

if [ -z "$PR_NUMBER" ]; then
    echo "用法: ./review-pr.sh <pr-number>"
    exit 1
fi

cd "$REPO_ROOT"

# 获取 PR 信息
echo "获取 PR #$PR_NUMBER 信息..."
pr_info=$(gh pr view "$PR_NUMBER" --json number,title,body,headRefName,baseRefName,changedFiles 2>/dev/null)

if [ -z "$pr_info" ]; then
    echo "错误: 无法获取 PR #$PR_NUMBER"
    exit 1
fi

title=$(echo "$pr_info" | jq -r '.title')
body=$(echo "$pr_info" | jq -r '.body')
files=$(echo "$pr_info" | jq -r '.changedFiles')

echo "PR 标题: $title"
echo "改动文件: $files"
echo ""

# 1. Codex Reviewer - 最靠谱的审查者
echo "🤖 启动 Codex Reviewer..."
codex_review=$(cat << EOF
请审查以下 PR，重点关注：
1. 边界情况处理
2. 逻辑错误
3. 缺失的错误处理
4. 竞态条件

PR 标题: $title
PR 描述: $body

请给出具体的代码审查意见。
EOF
)
# 这里可以调用 codex 命令进行审查
# codex --prompt "$codex_review" --files "$files"

# 2. Gemini Reviewer - 安全和扩展性
echo "🤖 启动 Gemini Reviewer..."
gemini_review=$(cat << EOF
请审查以下 PR，重点关注：
1. 安全问题
2. 扩展性问题
3. 代码质量
4. 可维护性

PR 标题: $title
PR 描述: $body
EOF
)
# gemini --prompt "$gemini_review" --files "$files"

# 3. Claude Code Reviewer - 前端和设计
echo "🤖 启动 Claude Code Reviewer..."
claude_review=$(cat << EOF
请审查以下 PR，重点关注：
1. 前端代码质量（如果是前端改动）
2. UI/UX 设计
3. 代码风格

PR 标题: $title
PR 描述: $body
EOF
)
# claude --prompt "$claude_review" --files "$files"

# 提交评论到 PR（简化版）
echo ""
echo "审查完成！"
echo "注意：这是一个简化版，需要接入 Codex/Claude/Gemini API 才能自动提交审查意见。"
