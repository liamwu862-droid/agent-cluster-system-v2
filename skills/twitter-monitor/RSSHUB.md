# Twitter 监控 - RSSHub 方案

## 1. 部署 RSSHub

```bash
# 使用 Docker
docker run -d --name rsshub \
  -p 1200:1200 \
  -e CACHE_TYPE=memory \
  diygod/rsshub
```

## 2. 获取 Twitter Cookie

1. 浏览器登录 Twitter
2. F12 → Application → Cookies
3. 复制 `auth_token` 的值

## 3. 配置 RSSHub 使用 Cookie

```bash
docker stop rsshub
docker rm rsshub

docker run -d --name rsshub \
  -p 1200:1200 \
  -e CACHE_TYPE=memory \
  -e TWITTER_AUTH_TOKEN="你的_auth_token" \
  diygod/rsshub
```

## 4. 使用 RSS 源

```
http://localhost:1200/twitter/user/elonmusk
http://localhost:1200/twitter/user/sama
```

## 5. 配合 blogwatcher 监控

```bash
blogwatcher add "Elon Musk" "http://localhost:1200/twitter/user/elonmusk"
blogwatcher scan
```

## 6. 推送飞书

修改脚本解析 RSS 并推送
