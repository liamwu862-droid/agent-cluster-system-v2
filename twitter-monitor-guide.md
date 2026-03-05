# 硅谷大佬推特监控配置指南

## 方案 1: RSSHub 自建 (推荐)

```bash
# 1. 部署 RSSHub
docker run -d --name rsshub -p 1200:1200 diygod/rsshub

# 2. 配置 Twitter Cookie (关键!)
# 登录 Twitter → F12 → Application → Cookies → 复制 auth_token
# 设置环境变量:
export TWITTER_AUTH_TOKEN=你的_token
export TWITTER_COOKIE=你的_cookie

# 3. 使用
http://localhost:1200/twitter/user/elonmusk
```

## 方案 2: IFTTT (最简单,免费)
1. 注册 ifttt.com
2. 创建 Applet:
   - Trigger: New tweet by specific user
   - Action: Webhook → Telegram/飞书/钉钉
3. 每个大佬创建一个 Applet

## 方案 3: Twitter API (付费但稳定)
- Basic: $100/月, 5000 条/月
- Pro: $5000/月
- https://developer.twitter.com

## 监控列表建议
- @elonmusk - Tesla/SpaceX/X
- @sama - OpenAI CEO
- @satyanadella - Microsoft CEO
- @sundarpichai - Google CEO
- @tim_cook - Apple CEO
- @finkd - Meta CEO
- @pmarca - a16z 创始人
- @paulg - YC 创始人
- @balajis - 天使投资人
- @naval - 投资人/思想家

## 自动化脚本 (配合 blogwatcher)
一旦 RSS 源配置好，使用:
```bash
blogwatcher add "Elon Musk" "http://你的rsshub/twitter/user/elonmusk"
blogwatcher scan  # 检查更新
```
