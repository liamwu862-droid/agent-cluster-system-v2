# Twitter Monitor Skill

监控指定 Twitter/X 用户的最新推文，支持推送到多种渠道。

## 安装

```bash
# 1. 设置 Twitter API Token
export TWITTER_BEARER_TOKEN="你的_bearer_token"

# 2. 添加监控用户
echo "elonmusk" >> users.txt
echo "sama" >> users.txt
```

## 获取 Twitter API Token

1. 访问 https://developer.twitter.com
2. 创建 App → 获取 Bearer Token
3. 免费层级足够监控用

## 使用方法

```bash
# 手动检查一次
./twitter-monitor.sh

# 查看监控列表
cat users.txt

# 添加新用户
echo "username" >> users.txt
```

## 配置定时任务 (cron)

```bash
# 每 5 分钟检查一次
*/5 * * * * cd /Users/clawd/.openclaw/workspace/skills/twitter-monitor && ./twitter-monitor.sh >> monitor.log 2>&1
```

## 配置推送通知

编辑 `twitter-monitor.sh`，找到 `# 这里可以添加推送到 Telegram/飞书的逻辑`，添加：

### Telegram 推送
```bash
curl -s -X POST "https://api.telegram.org/bot<token>/sendMessage" \
  -d "chat_id=<chat_id>" \
  -d "text=🐦 @$user: $new_tweets"
```

### 飞书推送
```bash
curl -s -X POST "https://open.feishu.cn/open-apis/bot/v2/hook/<token>" \
  -H "Content-Type: application/json" \
  -d "{\"msg_type\":\"text\",\"content\":{\"text\":\"🐦 @$user: $new_tweets\"}}"
```

## 监控列表建议

- elonmusk - Tesla/SpaceX/X
- sama - OpenAI CEO
- satyanadella - Microsoft CEO
- sundarpichai - Google CEO
- tim_cook - Apple CEO
- pmarca - a16z
- paulg - YC
- balajis - 投资人
