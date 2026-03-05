#!/bin/bash
# A股利好监控脚本 - 交易日9:20执行
# 范围：所有A股上市公司

FEISHU_WEBHOOK="https://open.feishu.cn/open-apis/bot/v2/hook/02fdfc79-889b-497d-894d-ffd8af32da14"
DATA_DIR="$HOME/.a-stock-monitor"
mkdir -p "$DATA_DIR"

# 发送飞书消息
send_feishu() {
    local title=$1
    local content=$2
    local time=$(date '+%Y-%m-%d %H:%M')
    
    curl -s -X POST "$FEISHU_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "{
            \"msg_type\": \"post\",
            \"content\": {
                \"post\": {
                    \"zh_cn\": {
                        \"title\": \"📈 [twitter] $title\",
                        \"content\": [
                            [
                                {
                                    \"tag\": \"text\",
                                    \"text\": \"$content\"
                                }
                            ],
                            [
                                {
                                    \"tag\": \"text\",
                                    \"text\": \"\n⏰ $time | 类型: A股利好信息\"
                                }
                            ]
                        ]
                    }
                }
            }
        }" > /dev/null
}

# 从东方财富获取快讯
fetch_eastmoney_news() {
    local api="https://np-anotice-stock.eastmoney.com/api/security/ann?page_size=50&page_index=1& ann_type=A&client_source=web"
    curl -s "$api" 2>/dev/null | grep -o '"title":"[^"]*"' | head -20
}

# 从新浪财经获取7x24小时
fetch_sina_news() {
    curl -s "https://feed.mix.sina.com.cn/api/roll/get?pageid=153&lid=2515&k=&num=30&page=1&r=$(date +%s)" 2>/dev/null | \
        python3 -c "import sys,json; d=json.load(sys.stdin); [print(x['title']) for x in d.get('result',{}).get('data',[])][:20]" 2>/dev/null
}

# 识别涉及的股票名称（简单匹配常见股票关键词）
filter_stocks() {
    local news=$1
    # 返回股票相关标记，如果新闻包含股票相关词汇
    if echo "$news" | grep -qE "(股|A股|上市公司|证券|板块|行情)"; then
        echo "A股"
    else
        echo ""
    fi
}

# 过滤利好消息
is_positive_news() {
    local news=$1
    echo "$news" | grep -qE "(预增|预盈|增长|签约|中标|回购|增持|利好|突破|获批|合作|订单|销量大增|营收增长|净利润)"
}

# 简单分析
analyze_news() {
    local news=$1
    local analysis=""
    
    if echo "$news" | grep -qE "(预增|预盈|增长|净利润|营收)"; then
        analysis="📊 业绩利好"
    elif echo "$news" | grep -qE "(签约|中标|订单)"; then
        analysis="📋 业务突破"
    elif echo "$news" | grep -qE "(回购|增持)"; then
        analysis="💰 资本动作"
    elif echo "$news" | grep -qE "(合作|战略|协议)"; then
        analysis="🤝 战略合作"
    elif echo "$news" | grep -qE "(获批|通过|许可)"; then
        analysis="✅ 政策/资质"
    else
        analysis="📈 市场利好"
    fi
    
    echo "$analysis"
}

echo "开始获取A股利好消息: $(date)"

# 获取昨日和今日凌晨的新闻
YESTERDAY=$(date -v-1d +%Y-%m-%d)
TODAY=$(date +%Y-%m-%d)

# 收集所有新闻
ALL_NEWS=""

# 新浪
SINA_NEWS=$(fetch_sina_news)
ALL_NEWS="$SINA_NEWS"

# 去重并过滤
UNIQUE_NEWS=$(echo "$ALL_NEWS" | sort | uniq)

# 过滤A股利好消息
count=0
SUMMARY=""

while IFS= read -r news; do
    [ -z "$news" ] && continue
    
    # 检查是否是利好
    if is_positive_news "$news"; then
        count=$((count + 1))
        analysis=$(analyze_news "$news")
        SUMMARY="${SUMMARY}• ${analysis}\n  ${news}\n\n"
    fi
done <<< "$UNIQUE_NEWS"

# 发送汇总
if [ $count -gt 0 ]; then
    SUMMARY="${SUMMARY}共发现 ${count} 条A股利好消息"
    send_feishu "A股早盘利好汇总" "$SUMMARY"
    echo "已发送 $count 条利好到飞书"
else
    echo "未发现A股利好消息"
fi

echo "完成: $(date)"
