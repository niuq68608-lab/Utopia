#!/bin/bash

# 方舟平台 (Ark) 快速入门脚本 (Bash + Curl 版)
# 
# 这是一个零依赖的 API 调用脚本，无需安装 Python。
# 适用于 macOS 和 Linux。

set -e

INTERACTIVE_MODE=false
if [ -t 0 ]; then
    INTERACTIVE_MODE=true
fi

VIDEO_POLL_MAX_ATTEMPTS="${ARK_VIDEO_POLL_MAX_ATTEMPTS:-40}"
VIDEO_POLL_INTERVAL_SECONDS="${ARK_VIDEO_POLL_INTERVAL_SECONDS:-30}"
MULTIMODAL_EMBEDDING_MODEL="${ARK_MULTIMODAL_EMBEDDING_MODEL:-doubao-embedding-vision-251215}"

# API Key 弱格式校验函数：
# - 接受历史 UUID 格式
# - 接受新格式 ark-<uuid>-<suffix>
# - 其他非空格式不阻断，只给出提示
validate_api_key() {
    local api_key=$1
    if [ -z "$api_key" ]; then
        return 1
    fi

    # 兼容旧格式：UUID
    if echo "$api_key" | grep -E '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' > /dev/null; then
        return 0
    fi

    # 兼容新格式：ark-<uuid>-<suffix>
    if echo "$api_key" | grep -E '^ark-[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}-[A-Za-z0-9._-]+$' > /dev/null; then
        return 0
    else
        return 1
    fi
}

get_capability_label() {
    case "$1" in
        1) echo "文本生成" ;;
        2) echo "图片生成" ;;
        3) echo "视频生成" ;;
        4) echo "多模态向量化" ;;
        5) echo "工具调用（联网工具）" ;;
        *) echo "文本生成" ;;
    esac
}

get_default_prompt() {
    case "$1" in
        1) echo "请用简洁的语言解释什么是人工智能。" ;;
        2) echo "生成一张未来城市夜景海报，霓虹灯光，电影感构图。" ;;
        3) echo "一只橘猫坐在窗边，看着城市夜景，镜头缓慢推进。 --dur 5" ;;
        4) echo "请总结这段文本和图片的共同主题。" ;;
        5) echo "今天北京天气怎么样？" ;;
        *) echo "请用简洁的语言解释什么是人工智能。" ;;
    esac
}

get_default_image_url() {
    echo "https://ark-project.tos-cn-beijing.volces.com/doc_image/ark_demo_img_1.png"
}

select_capability() {
    echo "请选择要体验的能力："
    echo "1. 文本生成"
    echo "2. 图片生成"
    echo "3. 视频生成"
    echo "4. 多模态向量化"
    echo "5. 工具调用（联网工具）"

    if [ "$INTERACTIVE_MODE" = true ]; then
        read -r -p "请输入能力编号（直接回车默认 1）: " CAPABILITY_CHOICE
    else
        CAPABILITY_CHOICE=""
    fi

    case "$CAPABILITY_CHOICE" in
        1|2|3|4|5) ;;
        *) CAPABILITY_CHOICE="1" ;;
    esac
}

read_prompt_with_default() {
    local capability_choice=$1
    local default_prompt
    default_prompt=$(get_default_prompt "$capability_choice")

    echo "默认 Prompt: $default_prompt"
    if [ "$INTERACTIVE_MODE" = true ]; then
        read -r -p "请输入自定义 Prompt（直接回车使用默认 Prompt）: " CUSTOM_PROMPT
    else
        CUSTOM_PROMPT=""
    fi

    if [ -n "$CUSTOM_PROMPT" ]; then
        CONTENT="$CUSTOM_PROMPT"
    else
        CONTENT="$default_prompt"
    fi
}

read_image_url_if_needed() {
    if [ "$CAPABILITY_CHOICE" != "4" ]; then
        IMAGE_URL=""
        return
    fi

    local default_image_url
    default_image_url=$(get_default_image_url)

    echo "默认图片 URL: $default_image_url"
    if [ "$INTERACTIVE_MODE" = true ]; then
        read -r -p "请输入图片 URL（直接回车使用默认图片 URL）: " CUSTOM_IMAGE_URL
    else
        CUSTOM_IMAGE_URL=""
    fi

    if [ -n "$CUSTOM_IMAGE_URL" ]; then
        IMAGE_URL="$CUSTOM_IMAGE_URL"
    else
        IMAGE_URL="$default_image_url"
    fi
}

print_response_field() {
    local response_selector=$1
    local jq_expression=""

    case "$response_selector" in
        text)
            jq_expression='first(.output[]? | select(.type == "message") | .content[]? | select(.type == "output_text") | .text) // .choices[0].message.content // .output_text // "调用成功，但未解析到文本结果。"'
            ;;
        image_url)
            jq_expression='.data[0].url // "图片生成成功，但未解析到图片 URL。"'
            ;;
        *)
            jq_expression="$response_selector"
            ;;
    esac

    if command -v jq &> /dev/null; then
        jq -r "$jq_expression" response.json
    elif command -v python3 &> /dev/null; then
        python3 - "$response_selector" <<'PY'
import json
import sys

expr = sys.argv[1]
with open("response.json", "r", encoding="utf-8") as f:
    data = json.load(f)

if expr == "text":
    text = data.get("choices", [{}])[0].get("message", {}).get("content") or data.get("output_text")
    if not text:
        for item in data.get("output") or []:
            if item.get("type") == "message":
                for content_item in item.get("content") or []:
                    if content_item.get("type") == "output_text" and content_item.get("text"):
                        text = content_item["text"]
                        break
            if text:
                break
    print(text or "调用成功，但未解析到文本结果。")
elif expr == "image_url":
    print((((data.get("data") or [{}])[0]).get("url")) or "图片生成成功，但未解析到图片 URL。")
PY
    else
        cat response.json
    fi
}

print_embedding_summary() {
    if command -v jq &> /dev/null; then
        local dimension
        local preview
        dimension=$(jq '.data | (if type == "array" then .[0].embedding else .embedding end) | length' response.json)
        preview=$(jq -c '.data | (if type == "array" then .[0].embedding else .embedding end)[:5]' response.json)
        echo "向量生成成功"
        echo "向量维度: $dimension"
        echo "向量摘要: $preview"
    elif command -v python3 &> /dev/null; then
        python3 <<'PY'
import json

with open("response.json", "r", encoding="utf-8") as f:
    data = json.load(f)

data_field = data.get("data") or {}
if isinstance(data_field, list):
    embedding = (data_field[0] if data_field else {}).get("embedding") or []
else:
    embedding = data_field.get("embedding") or []
print("向量生成成功")
print(f"向量维度: {len(embedding)}")
print(f"向量摘要: {embedding[:5]}")
PY
    else
        echo "向量生成成功，但未检测到可用的摘要解析工具。"
        cat response.json
    fi
}

extract_video_task_status() {
    python3 - <<'PY'
import json
with open("response_status.json", "r", encoding="utf-8") as f:
    data = json.load(f)
print(data.get("status", "unknown"))
PY
}

extract_video_task_url() {
    python3 - <<'PY'
import json

with open("response_status.json", "r", encoding="utf-8") as f:
    data = json.load(f)

candidates = [
    ((data.get("content") or {}).get("video_url")),
    ((data.get("content") or {}).get("url")),
    (((data.get("content") or {}).get("video") or {}).get("url")),
    (((data.get("data") or {}).get("video_url")) if isinstance(data.get("data"), dict) else None),
]

if isinstance(data.get("data"), list) and data["data"]:
    first = data["data"][0]
    if isinstance(first, dict):
        candidates.extend([
            first.get("video_url"),
            first.get("url"),
            ((first.get("video") or {}).get("url")),
        ])

for item in candidates:
    if item:
        print(item)
        break
else:
    print("")
PY
}

print_manual_video_query_command() {
    local task_id=$1
    local status_url="https://ark.cn-beijing.volces.com/api/v3/contents/generations/tasks/$task_id"

    echo "手动查询命令："
    echo "curl -s -X GET \"$status_url\" \\"
    echo "  -H \"Authorization: Bearer \$ARK_API_KEY\" \\"
    echo "  -H \"Content-Type: application/json\""
}

show_dev_env_summary() {
    echo ""
    echo "开发者环境会执行以下步骤："
    echo "1. 下载或复用 uv 工具"
    echo "2. 创建项目级 Python 3.12 虚拟环境 (.venv)"
    echo "3. 安装方舟 SDK"
    echo "4. 生成项目根目录下的 run_demo.sh"
    echo "5. 后续可在 IDE 中选择 .venv 继续开发"
    echo ""
}

run_dev_env_setup() {
    local setup_script="../../init_dev_env/setup_mac.sh"
    echo ""
    echo "正在启动开发者环境构建脚本：$setup_script"
    chmod +x "$setup_script"
    bash "$setup_script"
}

prompt_post_success_action() {
    if [ "$INTERACTIVE_MODE" != true ]; then
        NEXT_ACTION="exit"
        return
    fi

    while true; do
        echo ""
        echo "接下来你想做什么？"
        echo "1. 体验其他能力"
        echo "2. 创建开发者环境"
        echo "3. 查看开发者环境会做什么"
        echo "4. 结束"
        read -r -p "请输入选项编号（默认 4）: " NEXT_ACTION_INPUT

        case "$NEXT_ACTION_INPUT" in
            1)
                NEXT_ACTION="retry_capability"
                return
                ;;
            2)
                NEXT_ACTION="create_dev_env"
                return
                ;;
            3)
                show_dev_env_summary
                ;;
            4|"")
                NEXT_ACTION="exit"
                return
                ;;
            *)
                echo "无效选项，请重新输入。"
                ;;
        esac
    done
}

echo "--------------------------------------------------"
echo "   方舟平台 (Ark) 快速入门自动化脚本 (macOS/Linux)   "
echo "--------------------------------------------------"
echo ""

# 最大重试次数
MAX_RETRIES=3
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    # 1. 获取 API Key
    API_KEY=$ARK_API_KEY
    USE_ENV_KEY=false

    if [ -n "$API_KEY" ]; then
        # 脱敏展示：前4位 + **** + 后4位
        MASKED_KEY="${API_KEY:0:4}****${API_KEY: -4}"
        echo "检测到环境变量中的 API Key: $MASKED_KEY"
        if [ "$INTERACTIVE_MODE" = true ]; then
            read -r -p "是否使用该 API Key？[Y/n]，直接回车默认使用: " CONFIRM
        else
            CONFIRM=""
        fi
        # 兼容 Bash 3.2（macOS 默认版本）的小写转换
        CONFIRM_LOWER=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
        if [ -z "$CONFIRM" ] || [ "$CONFIRM_LOWER" = "y" ]; then
            USE_ENV_KEY=true
        else
            API_KEY=""
        fi
    fi

    if [ "$USE_ENV_KEY" = false ] || [ -z "$API_KEY" ]; then
        echo "欢迎使用！我们需要您的 API Key 来调用模型服务。"
        echo "如果您还没有 API Key，请访问控制台获取：https://console.volcengine.com/ark/region:ark+cn-beijing/apikey"
        echo ""
        if [ "$INTERACTIVE_MODE" = true ]; then
            read -r -p "请输入您的 API Key (回车确认): " API_KEY
        else
            echo "非交互模式下未检测到可用的 ARK_API_KEY，脚本即将退出。"
            exit 1
        fi
        if [ -z "$API_KEY" ]; then
            echo "API Key 不能为空！"
            continue
        fi
    fi

    # 2. 本地弱校验（不阻断）
    if ! validate_api_key "$API_KEY"; then
        echo "提示：当前 API Key 未匹配到已知本地格式（兼容 UUID 与 ark-<uuid>-<suffix>）。"
        echo "脚本将继续尝试调用；如果后续鉴权失败，请检查 Key 是否正确。"
    fi

    while true; do
        # 3. 能力选择与 prompt 输入
        select_capability
        CAPABILITY_LABEL=$(get_capability_label "$CAPABILITY_CHOICE")
        read_prompt_with_default "$CAPABILITY_CHOICE"
        read_image_url_if_needed

        echo ""
        echo "已选择能力：$CAPABILITY_LABEL"
        if [ -n "$IMAGE_URL" ]; then
            echo "图片 URL: $IMAGE_URL"
        fi

        # 4. 构造请求
        RESPONSE_KIND="text"
        URL="https://ark.cn-beijing.volces.com/api/v3/chat/completions"
        MODEL="doubao-seed-2-0-lite-260215"
        RESULT_TITLE="调用成功！模型回复："

        case "$CAPABILITY_CHOICE" in
        2)
            URL="https://ark.cn-beijing.volces.com/api/v3/images/generations"
            MODEL="doubao-seedream-5-0-260128"
            RESPONSE_KIND="image_url"
            RESULT_TITLE="调用成功！图片结果 URL："
            BODY=$(cat <<EOF
{
    "model": "$MODEL",
    "prompt": "$CONTENT",
    "size": "2K",
    "response_format": "url",
    "watermark": false
}
EOF
)
            ;;
        5)
            URL="https://ark.cn-beijing.volces.com/api/v3/responses"
            MODEL="doubao-seed-2-0-lite-260215"
            RESPONSE_KIND="text"
            RESULT_TITLE="调用成功！联网工具结果："
            BODY=$(cat <<EOF
{
    "model": "$MODEL",
    "tools": [
        {
            "type": "web_search",
            "max_keyword": 2
        }
    ],
    "input": [
        {
            "role": "user",
            "content": "$CONTENT"
        }
    ]
}
EOF
)
            ;;
        4)
            URL="https://ark.cn-beijing.volces.com/api/v3/embeddings/multimodal"
            MODEL="$MULTIMODAL_EMBEDDING_MODEL"
            RESPONSE_KIND="embedding"
            RESULT_TITLE="调用成功！图文向量化摘要："
            BODY=$(cat <<EOF
{
    "model": "$MODEL",
    "input": [
        {
            "type": "text",
            "text": "$CONTENT"
        },
        {
            "type": "image_url",
            "image_url": {
                "url": "$IMAGE_URL"
            }
        }
    ],
    "dimensions": 1024
}
EOF
)
            ;;
        3)
            URL="https://ark.cn-beijing.volces.com/api/v3/contents/generations/tasks"
            MODEL="doubao-seedance-2-0-260128"
            RESPONSE_KIND="video_task"
            RESULT_TITLE="视频生成任务已创建："
            BODY=$(cat <<EOF
{
    "model": "$MODEL",
    "content": [
        {
            "type": "text",
            "text": "$CONTENT"
        }
    ]
}
EOF
)
            ;;
        *)
            BODY=$(cat <<EOF
{
    "model": "$MODEL",
    "messages": [
        {"role": "system", "content": "你是一个乐于助人的 AI 助手。"},
        {"role": "user", "content": "$CONTENT"}
    ]
}
EOF
)
            ;;
        esac

        echo ""
        echo "问题：$CONTENT"
        echo "正在调用豆包模型 ($MODEL)..."

        if [ "$CAPABILITY_CHOICE" = "5" ]; then
            echo "已启用联网工具。"
        fi

        # 5. 发送请求
        HTTP_CODE=$(curl -s -w "%{http_code}" -o response.json \
            -X POST "$URL" \
            -H "Authorization: Bearer $API_KEY" \
            -H "Content-Type: application/json" \
            -d "$BODY")

        # 6. 处理结果
        if [ "$HTTP_CODE" -eq 200 ]; then
            echo ""
            if [ "$RESPONSE_KIND" = "video_task" ]; then
            TASK_ID=$(python3 - <<'PY'
import json
with open("response.json", "r", encoding="utf-8") as f:
    data = json.load(f)
print(data.get("id", ""))
PY
)
            echo "$RESULT_TITLE"
            echo "$TASK_ID"
            echo "--------------------------------------------------"
            echo "当前状态: queued"
            VIDEO_STATUS_URL="https://ark.cn-beijing.volces.com/api/v3/contents/generations/tasks/$TASK_ID"
            echo "状态查询地址: $VIDEO_STATUS_URL"
            echo "轮询配置: 最多 ${VIDEO_POLL_MAX_ATTEMPTS} 次，每次间隔 ${VIDEO_POLL_INTERVAL_SECONDS} 秒"
            LAST_VIDEO_STATUS="queued"
            VIDEO_COMPLETED=false
            for ((attempt=1; attempt<=VIDEO_POLL_MAX_ATTEMPTS; attempt++)); do
                HTTP_STATUS_CODE=$(curl -s -w "%{http_code}" -o response_status.json \
                    -X GET "$VIDEO_STATUS_URL" \
                    -H "Authorization: Bearer $API_KEY" \
                    -H "Content-Type: application/json")
                if [ "$HTTP_STATUS_CODE" -ne 200 ]; then
                    echo "查询视频任务状态失败 (HTTP $HTTP_STATUS_CODE)。"
                    cat response_status.json
                    break
                fi
                VIDEO_STATUS=$(extract_video_task_status)
                LAST_VIDEO_STATUS="$VIDEO_STATUS"
                echo "轮询状态: $VIDEO_STATUS"
                if [ "$VIDEO_STATUS" = "succeeded" ]; then
                    VIDEO_COMPLETED=true
                    VIDEO_URL=$(extract_video_task_url)
                    if [ -n "$VIDEO_URL" ]; then
                        echo "视频结果 URL: $VIDEO_URL"
                    else
                        echo "视频任务已成功，但暂未从响应中解析到视频链接。"
                        echo "请稍后使用任务 ID 再次查询：$TASK_ID"
                        print_manual_video_query_command "$TASK_ID"
                        cat response_status.json
                    fi
                    rm -f response_status.json
                    break
                elif [ "$VIDEO_STATUS" = "failed" ] || [ "$VIDEO_STATUS" = "expired" ] || [ "$VIDEO_STATUS" = "cancelled" ]; then
                    echo "视频生成任务未成功完成。"
                    cat response_status.json
                    rm -f response_status.json
                    VIDEO_COMPLETED=true
                    break
                fi
                if [ "$attempt" -lt "$VIDEO_POLL_MAX_ATTEMPTS" ]; then
                    sleep "$VIDEO_POLL_INTERVAL_SECONDS"
                fi
            done
            if [ "$VIDEO_COMPLETED" = false ]; then
                echo "视频任务仍在处理中，当前最后状态：$LAST_VIDEO_STATUS"
                echo "请稍后使用任务 ID 再次查询：$TASK_ID"
                print_manual_video_query_command "$TASK_ID"
                echo "你也可以调大轮询配置后重试："
                echo "  export ARK_VIDEO_POLL_MAX_ATTEMPTS=40"
                echo "  export ARK_VIDEO_POLL_INTERVAL_SECONDS=30"
            fi
            echo "--------------------------------------------------"
            rm -f response.json
            rm -f response_status.json
            prompt_post_success_action
            case "$NEXT_ACTION" in
                retry_capability) continue ;;
                create_dev_env) run_dev_env_setup; exit 0 ;;
                *) exit 0 ;;
            esac
            fi

            echo "$RESULT_TITLE"
            echo "--------------------------------------------------"
            
            if [ "$RESPONSE_KIND" = "image_url" ]; then
                print_response_field "image_url"
            elif [ "$RESPONSE_KIND" = "embedding" ]; then
                print_embedding_summary
            elif command -v jq &> /dev/null; then
                print_response_field "text"
            elif command -v osascript &> /dev/null && [ "$CAPABILITY_CHOICE" = "1" ]; then
            # 如果是 macOS，用 osascript (JavaScript) 解析
            # 读取文件内容并转义单引号，防止 JS 注入
            JSON_CONTENT=$(cat response.json | sed "s/'/\\\\'/g")
            osascript -l JavaScript -e "var json = JSON.parse('$JSON_CONTENT'); console.log(json.choices[0].message.content);"
            else
                print_response_field "text"
            fi
            
            echo "--------------------------------------------------"
            echo ""
            rm -f response.json
            prompt_post_success_action
            case "$NEXT_ACTION" in
                retry_capability) continue ;;
                create_dev_env) run_dev_env_setup; exit 0 ;;
                *) exit 0 ;;
            esac

        elif [ "$HTTP_CODE" -eq 401 ] || [ "$HTTP_CODE" -eq 403 ]; then
            RETRY_COUNT=$((RETRY_COUNT + 1))
            REMAINING=$((MAX_RETRIES - RETRY_COUNT))
            echo ""
            echo "API Key 无效或权限不足！剩余重试次数：$REMAINING"
            echo "请检查您的 API Key 是否正确，或者重新输入。"
            unset ARK_API_KEY
            rm -f response.json
            break

        else
            echo ""
            echo "调用失败 (HTTP $HTTP_CODE):"
            cat response.json
            if grep -q '"code":"InvalidParameter"' response.json && grep -q 'image size must be at least' response.json; then
                echo ""
                echo "图片生成参数提示：当前模型 $MODEL 不接受 1024x1024 这类较小尺寸，建议使用 2K 或更高分辨率。"
            elif [ "$CAPABILITY_CHOICE" = "4" ] && grep -q 'InvalidEndpointOrModel.NotFound' response.json; then
                echo ""
                echo "多模态向量化提示：当前模型 $MODEL 不存在或当前账号暂无权限。"
                echo "你可以先在控制台开通图文向量化模型，或使用环境变量覆盖为已开通的 Model ID / Endpoint ID："
                echo "  export ARK_MULTIMODAL_EMBEDDING_MODEL=<your-model-or-endpoint-id>"
            fi
            rm -f response.json
            echo ""
            echo "可能的原因："
            echo "1. API Key 无效或过期"
            echo "2. 模型 ID 不存在或无权限调用"
            echo "3. 网络连接问题"
            exit 1
        fi
    done
done

# 重试次数耗尽
echo ""
echo "重试次数已达上限！请确认您的 API Key 正确无误后重新运行脚本。"
rm -f response.json
exit 1
