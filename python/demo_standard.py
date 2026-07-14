# 标准版方舟 SDK 使用示例 (Python)
# 
# 这是一个标准的 Python 开发示例，展示了如何使用 volcenginesdkarkruntime 库。
# 相比于之前的脚本，这个文件更接近真实的开发代码。

import os
from volcenginesdkarkruntime import Ark

def main():
    print("--------------------------------------------------")
    print("   方舟平台 (Ark) Python SDK 标准示例   ")
    print("--------------------------------------------------")

    # 1. 获取 API Key
    # 在正式开发中，推荐使用环境变量管理 API Key，避免硬编码在代码中。
    api_key = os.environ.get("ARK_API_KEY")
    if not api_key:
        print("欢迎使用！我们需要您的 API Key 来调用模型服务。")
        api_key = input("请输入您的 API Key (回车确认): ").strip()
        if not api_key:
            print("API Key 不能为空！")
            return
        # 设置到环境变量中 (仅当前进程有效)
        os.environ["ARK_API_KEY"] = api_key

    # 2. 初始化客户端
    # 这一步会创建一个 Ark 客户端实例，用于后续的所有 API 调用。
    client = Ark(api_key=api_key)

    # 3. 构造对话请求
    # model: 模型 ID，请确保您已在控制台开通该模型
    # 注意：请使用具体的 Model ID（例如 doubao-seed-2-0-lite-260215），不要使用 Endpoint ID (ep-xxxx)
    model_id = "doubao-seed-2-0-lite-260215" 
    user_content = "请用 Python 写一个 Hello World 程序，并解释代码含义。"
    
    print(f"\n问题：{user_content}")
    print(f"正在调用豆包模型 ({model_id})...")
    try:
        completion = client.chat.completions.create(
            model=model_id,
            messages=[
                {"role": "system", "content": "你是一个专业的 Python 开发助手。"},
                {"role": "user", "content": user_content},
            ],
        )

        # 4. 处理并打印结果
        # SDK 返回的是一个对象，我们需要从中提取 content 字段
        content = completion.choices[0].message.content
        
        print("\n调用成功！模型回复：")
        print("--------------------------------------------------")
        print(content)
        print("--------------------------------------------------")

    except Exception as e:
        print(f"\n调用失败: {e}")
        print("可能的原因：")
        print("1. API Key 无效")
        print("2. 模型 ID 错误")
        print("3. 网络连接问题")

if __name__ == "__main__":
    main()
