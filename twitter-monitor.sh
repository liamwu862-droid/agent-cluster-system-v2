#!/bin/bash
# twitter-monitor.sh - 简单的推特监控脚本

USERS=("elonmusk" "sama" "satyanadella" "sundarpichai" "tim_cook")
DATA_DIR="$HOME/.twitter-monitor"
mkdir -p "$DATA_DIR"

for user in "${USERS[@]}"; do
    echo "Checking $user..."
    
    # 使用 nitter 实例获取最新推文
    # 注意：需要找到可用的 nitter 实例
    curl -s "https://nitter.net/$user" -H "User-Agent: Mozilla/5.0" | \
        grep -oP 'tweet-content[^>]*>\K[^<]+' | head -5 > "$DATA_DIR/${user}_new.txt"
    
    # 对比之前的结果
    if [ -f "$DATA_DIR/${user}_last.txt" ]; then
        diff "$DATA_DIR/${user}_last.txt" "$DATA_DIR/${user}_new.txt" | grep "^>" | while read line; do
            echo "[$user] 新推文: $line"
            # 这里可以添加发送到 Telegram/飞书的逻辑
        done
    fi
    
    mv "$DATA_DIR/${user}_new.txt" "$DATA_DIR/${user}_last.txt"
done
