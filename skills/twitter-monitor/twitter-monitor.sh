#!/bin/bash
# twitter-monitor.sh - 监控硅谷大佬推特，推送到飞书

TWITTER_BEARER_TOKEN="${TWITTER_BEARER_TOKEN:-}"
FEISHU_WEBHOOK="${FEISHU_WEBHOOK:-https://open.feishu.cn/open-apis/bot/v2/hook/02fdfc79-889b-497d-894d-ffd8af32da14}"
USERS=("elonmusk" "sama" "satyanadella" "sundarpichai" "tim_cook" "pmarca" "paulg" "balajis")
DATA_DIR="$HOME/.twitter-monitor"

if [ -z "$TWITTER_BEARER_TOKEN" ]; then
    echo "错误：请设置 TWITTER_BEARER_TOKEN"
    exit 1
fi

mkdir -p "$DATA_DIR"

# 发送飞书消息
send_feishu() {
    local user=$1
    local tweet=$2
    local time=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 关键词验证: 必须包含 "twitter"
    curl -s -X POST "$FEISHU_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "{
            \"msg_type\": \"post\",
            \"content\": {
                \"post\": {
                    \"zh_cn\": {
                        \"title\": \"🐦 [twitter] @$user 有新推文\",
                        \"content\": [
                            [
                                {
                                    \"tag\": \"text\",
                                    \"text\": \"$tweet\"
                                }
                            ],
                            [
                                {
                                    \"tag\": \"text\",
                                    \"text\": \"\n⏰ $time\"
                                }
                            ]
                        ]
                    }
                }
            }
        }" > /dev/null
}

check_user() {
    local user=$1
    local api_url="https://api.twitter.com/2/users/by/username/${user}"
    local user_id=$(curl -s -H "Authorization: Bearer $TWITTER_BEARER_TOKEN" "$api_url" 2>/dev/null | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ -z "$user_id" ]; then
        echo "[$user] 无法获取用户ID"
        return
    fi
    
    # 获取最近推文
    local tweets_url="https://api.twitter.com/2/users/${user_id}/tweets?max_results=5&tweet.fields=created_at,text,author_id"
    local response=$(curl -s -H "Authorization: Bearer $TWITTER_BEARER_TOKEN" "$tweets_url" 2>/dev/null)
    
    # 提取推文文本
    echo "$response" | grep -o '"text":"[^"]*"' | sed 's/"text":"//g; s/"$//g' > "$DATA_DIR/${user}_new.txt" 2>/dev/null
    
    if [ -f "$DATA_DIR/${user}_last.txt" ]; then
        # 对比新旧推文
        while IFS= read -r tweet; do
            if ! grep -qF "$tweet" "$DATA_DIR/${user}_last.txt" 2>/dev/null; then
                # 新推文
                send_feishu "$user" "$tweet"
                echo "[$user] 已发送新推文到飞书"
            fi
        done < "$DATA_DIR/${user}_new.txt"
    fi
    
    mv "$DATA_DIR/${user}_new.txt" "$DATA_DIR/${user}_last.txt"
}

echo "开始检查: $(date)"
for user in "${USERS[@]}"; do
    check_user "$user"
    sleep 1
done
echo "检查完成: $(date)"
