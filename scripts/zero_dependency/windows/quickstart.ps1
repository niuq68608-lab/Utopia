﻿# 方舟平台 (Ark) 快速入门脚本 (PowerShell 版)
# 
# 这是一个零依赖的 API 调用脚本，无需安装 Python。
# 仅适用于 Windows 7 及以上系统。

$ErrorActionPreference = "Stop"
$InteractiveMode = -not [Console]::IsInputRedirected
$VideoPollMaxAttempts = if ($env:ARK_VIDEO_POLL_MAX_ATTEMPTS) { [int]$env:ARK_VIDEO_POLL_MAX_ATTEMPTS } else { 40 }
$VideoPollIntervalSeconds = if ($env:ARK_VIDEO_POLL_INTERVAL_SECONDS) { [int]$env:ARK_VIDEO_POLL_INTERVAL_SECONDS } else { 30 }
$MultimodalEmbeddingModel = if ($env:ARK_MULTIMODAL_EMBEDDING_MODEL) { $env:ARK_MULTIMODAL_EMBEDDING_MODEL } else { "doubao-embedding-vision-251215" }

# API Key 弱格式校验函数：
# - 接受历史 UUID 格式
# - 接受新格式 ark-<uuid>-<suffix>
# - 其他非空格式不阻断，只给出提示
function Test-ApiKeyFormat {
    param([string]$ApiKey)
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        return $false
    }

    if ($ApiKey -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
        return $true
    }

    return $ApiKey -match '^ark-[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}-[A-Za-z0-9._-]+$'
}

function Get-CapabilityLabel {
    param([string]$Choice)

    switch ($Choice) {
        "1" { return "文本生成" }
        "2" { return "图片生成" }
        "3" { return "视频生成" }
        "4" { return "多模态向量化" }
        "5" { return "工具调用（联网工具）" }
        default { return "文本生成" }
    }
}

function Get-DefaultPrompt {
    param([string]$Choice)

    switch ($Choice) {
        "1" { return "请用简洁的语言解释什么是人工智能。" }
        "2" { return "生成一张未来城市夜景海报，霓虹灯光，电影感构图。" }
        "3" { return "一只橘猫坐在窗边，看着城市夜景，镜头缓慢推进。 --dur 5" }
        "4" { return "请总结这段文本和图片的共同主题。" }
        "5" { return "今天北京天气怎么样？" }
        default { return "请用简洁的语言解释什么是人工智能。" }
    }
}

function Get-DefaultImageUrl {
    return "https://ark-project.tos-cn-beijing.volces.com/doc_image/ark_demo_img_1.png"
}

function Select-Capability {
    Write-Host "请选择要体验的能力："
    Write-Host "1. 文本生成"
    Write-Host "2. 图片生成"
    Write-Host "3. 视频生成"
    Write-Host "4. 多模态向量化"
    Write-Host "5. 工具调用（联网工具）"

    if ($InteractiveMode) {
        $choice = Read-Host "请输入能力编号（直接回车默认 1）"
    } else {
        $choice = ""
    }

    switch ($choice) {
        "1" { return "1" }
        "2" { return "2" }
        "3" { return "3" }
        "4" { return "4" }
        "5" { return "5" }
        default { return "1" }
    }
}

function Read-Prompt {
    param([string]$Choice)

    $defaultPrompt = Get-DefaultPrompt $Choice
    Write-Host "默认 Prompt: $defaultPrompt"

    if ($InteractiveMode) {
        $customPrompt = Read-Host "请输入自定义 Prompt（直接回车使用默认 Prompt）"
    } else {
        $customPrompt = ""
    }

    if ([string]::IsNullOrWhiteSpace($customPrompt)) {
        return $defaultPrompt
    }

    return $customPrompt
}

function Read-ImageUrl {
    param([string]$Choice)

    if ($Choice -ne "4") {
        return $null
    }

    $defaultImageUrl = Get-DefaultImageUrl
    Write-Host "默认图片 URL: $defaultImageUrl"

    if ($InteractiveMode) {
        $customImageUrl = Read-Host "请输入图片 URL（直接回车使用默认图片 URL）"
    } else {
        $customImageUrl = ""
    }

    if ([string]::IsNullOrWhiteSpace($customImageUrl)) {
        return $defaultImageUrl
    }

    return $customImageUrl
}

function Get-ResponseText {
    param($Response)

    if ($null -ne $Response.choices -and $Response.choices.Count -gt 0) {
        return $Response.choices[0].message.content
    }

    if ($null -ne $Response.output_text -and $Response.output_text -ne "") {
        return $Response.output_text
    }

    if ($null -ne $Response.output -and $Response.output.Count -gt 0) {
        foreach ($item in $Response.output) {
            if ($item.type -eq "message" -and $null -ne $item.content -and $item.content.Count -gt 0) {
                foreach ($contentItem in $item.content) {
                    if ($contentItem.type -eq "output_text" -and -not [string]::IsNullOrWhiteSpace($contentItem.text)) {
                        return $contentItem.text
                    }
                }
            }
        }
    }

    return "调用成功，但未解析到文本结果。"
}

function Write-EmbeddingSummary {
    param($Response)

    if ($Response.data -is [System.Array]) {
        $embedding = $Response.data[0].embedding
    } else {
        $embedding = $Response.data.embedding
    }
    $dimension = 0
    $preview = @()
    if ($null -ne $embedding) {
        $dimension = $embedding.Count
        $preview = $embedding | Select-Object -First 5
    }

    Write-Host "向量生成成功"
    Write-Host "向量维度: $dimension"
    Write-Host ("向量摘要: [{0}]" -f (($preview | ForEach-Object { $_.ToString() }) -join ", "))
}

function Get-VideoUrlFromTaskResponse {
    param($TaskResponse)

    $candidates = @(
        $TaskResponse.content.video_url,
        $TaskResponse.content.url,
        $TaskResponse.content.video.url,
        $TaskResponse.data.video_url
    )

    if ($null -ne $TaskResponse.data -and $TaskResponse.data.Count -gt 0) {
        $firstData = $TaskResponse.data[0]
        $candidates += @(
            $firstData.video_url,
            $firstData.url,
            $firstData.video.url
        )
    }

    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            return $candidate
        }
    }

    return $null
}

function Write-ManualVideoQueryCommand {
    param([string]$TaskId)

    $statusUrl = "https://ark.cn-beijing.volces.com/api/v3/contents/generations/tasks/$TaskId"
    Write-Host "手动查询命令："
    Write-Host "Invoke-RestMethod -Uri `"$statusUrl`" -Method Get -Headers @{"
    Write-Host '  Authorization = "Bearer $env:ARK_API_KEY"'
    Write-Host '  "Content-Type" = "application/json"'
    Write-Host "}"
}

function Show-DevEnvSummary {
    Write-Host ""
    Write-Host "开发者环境会执行以下步骤："
    Write-Host "1. 下载或复用 uv 工具"
    Write-Host "2. 创建项目级 Python 3.12 虚拟环境 (.venv)"
    Write-Host "3. 安装方舟 SDK"
    Write-Host "4. 生成项目根目录下的 run_demo.bat"
    Write-Host "5. 后续可在 IDE 中选择 .venv 继续开发"
    Write-Host ""
}

function Start-DevEnvSetup {
    $setupScript = Join-Path $PSScriptRoot "..\..\init_dev_env\setup_windows.bat"
    $setupScript = [System.IO.Path]::GetFullPath($setupScript)
    Write-Host ""
    Write-Host "正在启动开发者环境构建脚本：$setupScript"
    cmd /c "`"$setupScript`""
}

function Get-PostSuccessAction {
    if (-not $InteractiveMode) {
        return "exit"
    }

    while ($true) {
        Write-Host ""
        Write-Host "接下来你想做什么？"
        Write-Host "1. 体验其他能力"
        Write-Host "2. 创建开发者环境"
        Write-Host "3. 查看开发者环境会做什么"
        Write-Host "4. 结束"
        $choice = Read-Host "请输入选项编号（默认 4）"

        switch ($choice) {
            "1" { return "retry_capability" }
            "2" { return "create_dev_env" }
            "3" { Show-DevEnvSummary }
            "4" { return "exit" }
            "" { return "exit" }
            default { Write-Host "无效选项，请重新输入。" -ForegroundColor Yellow }
        }
    }
}

function Main {
    Write-Host "--------------------------------------------------" -ForegroundColor Cyan
    Write-Host "   方舟平台 (Ark) 快速入门自动化脚本 (Windows)   " -ForegroundColor Cyan
    Write-Host "--------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""

    # 最大重试次数
    $maxRetries = 3
    $retryCount = 0

    # 重试循环
    while ($retryCount -lt $maxRetries) {
        # 1. 获取 API Key
        $apiKey = $env:ARK_API_KEY
        $useEnvKey = $false

        if (-not [string]::IsNullOrWhiteSpace($apiKey)) {
            # 脱敏展示
            $maskedKey = $apiKey.Substring(0, 4) + "****" + $apiKey.Substring($apiKey.Length - 4)
            Write-Host "检测到环境变量中的 API Key: $maskedKey"
            if ($InteractiveMode) {
                $confirm = Read-Host "是否使用该 API Key？[Y/n]，直接回车默认使用"
            } else {
                $confirm = ""
            }
            if ($confirm -eq "" -or $confirm.ToLower() -eq "y") {
                $useEnvKey = $true
            } else {
                $apiKey = $null
            }
        }

        if (-not $useEnvKey -or [string]::IsNullOrWhiteSpace($apiKey)) {
            Write-Host "欢迎使用！我们需要您的 API Key 来调用模型服务。"
            Write-Host "如果您还没有 API Key，请访问控制台获取：https://console.volcengine.com/ark/region:ark+cn-beijing/apikey"
            Write-Host ""
            if ($InteractiveMode) {
                $apiKey = Read-Host "请输入您的 API Key (回车确认)"
            } else {
                Write-Host "非交互模式下未检测到可用的 ARK_API_KEY，脚本即将退出。" -ForegroundColor Red
                return
            }
            
            if ([string]::IsNullOrWhiteSpace($apiKey)) {
                Write-Host "API Key 不能为空！" -ForegroundColor Red
                continue
            }
        }

        # 2. 本地弱校验（不阻断）
        if (-not (Test-ApiKeyFormat $apiKey)) {
            Write-Host "提示：当前 API Key 未匹配到已知本地格式（兼容 UUID 与 ark-<uuid>-<suffix>）。" -ForegroundColor Yellow
            Write-Host "脚本将继续尝试调用；如果后续鉴权失败，请检查 Key 是否正确。" -ForegroundColor Yellow
        }

        while ($true) {
            # 3. 能力选择与 prompt 输入
            $capabilityChoice = Select-Capability
            $capabilityLabel = Get-CapabilityLabel $capabilityChoice
            $userQuestion = Read-Prompt $capabilityChoice
            $imageUrl = Read-ImageUrl $capabilityChoice

            Write-Host ""
            Write-Host "已选择能力：$capabilityLabel" -ForegroundColor Cyan
            if (-not [string]::IsNullOrWhiteSpace($imageUrl)) {
                Write-Host "图片 URL: $imageUrl" -ForegroundColor Cyan
            }

            # 4. 构造请求
            $url = "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
            $modelId = "doubao-seed-2-0-lite-260215"
            $resultTitle = "调用成功！模型回复："
            $responseKind = "text"
            $headers = @{
                "Authorization" = "Bearer $apiKey"
                "Content-Type" = "application/json; charset=utf-8"
            }

            switch ($capabilityChoice) {
            "2" {
                $url = "https://ark.cn-beijing.volces.com/api/v3/images/generations"
                $modelId = "doubao-seedream-5-0-260128"
                $resultTitle = "调用成功！图片结果 URL："
                $responseKind = "image"
                $bodyPayload = @{
                    model = $modelId
                    prompt = $userQuestion
                    size = "2K"
                    response_format = "url"
                    watermark = $false
                } | ConvertTo-Json -Depth 10
            }
            "3" {
                $url = "https://ark.cn-beijing.volces.com/api/v3/contents/generations/tasks"
                $modelId = "doubao-seedance-2-0-260128"
                $resultTitle = "视频生成任务已创建："
                $responseKind = "video_task"
                $bodyPayload = @{
                    model = $modelId
                    content = @(
                        @{
                            type = "text"
                            text = $userQuestion
                        }
                    )
                } | ConvertTo-Json -Depth 10
            }
            "4" {
                $url = "https://ark.cn-beijing.volces.com/api/v3/embeddings/multimodal"
                $modelId = $MultimodalEmbeddingModel
                $resultTitle = "调用成功！图文向量化摘要："
                $responseKind = "embedding"
                $bodyPayload = @{
                    model = $modelId
                    input = @(
                        @{
                            type = "text"
                            text = $userQuestion
                        },
                        @{
                            type = "image_url"
                            image_url = @{
                                url = $imageUrl
                            }
                        }
                    )
                    dimensions = 1024
                } | ConvertTo-Json -Depth 10
            }
            "5" {
                $url = "https://ark.cn-beijing.volces.com/api/v3/responses"
                $modelId = "doubao-seed-2-0-lite-260215"
                $resultTitle = "调用成功！联网工具结果："
                $responseKind = "text"
                $bodyPayload = @{
                    model = $modelId
                    tools = @(
                        @{
                            "type" = "web_search"
                            max_keyword = 2
                        }
                    )
                    input = @(
                        @{
                            role = "user"
                            content = $userQuestion
                        }
                    )
                } | ConvertTo-Json -Depth 10
            }
            default {
                $bodyPayload = @{
                    model = $modelId
                    messages = @(
                        @{
                            role = "system"
                            content = "你是一个乐于助人的 AI 助手。"
                        },
                        @{
                            role = "user"
                            content = $userQuestion
                        }
                    )
                } | ConvertTo-Json -Depth 10
            }
            }

            # 强制使用 UTF-8 编码转换 Body，防止 Windows 默认编码 (GBK) 导致乱码
            $utf8Body = [System.Text.Encoding]::UTF8.GetBytes($bodyPayload)

            Write-Host ""
            Write-Host "问题：$userQuestion" -ForegroundColor Cyan
            Write-Host "正在调用豆包模型 ($modelId)..." -ForegroundColor Yellow

            if ($capabilityChoice -eq "5") {
                Write-Host "已启用联网工具。" -ForegroundColor DarkYellow
            }

            # 5. 发送请求
            try {
            # Invoke-RestMethod 会自动解析 JSON 响应
            $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $utf8Body -ErrorAction Stop
            
            # 6. 展示结果
            if ($responseKind -eq "video_task") {
                Write-Host ""
                Write-Host $resultTitle -ForegroundColor Green
                Write-Host "--------------------------------------------------"
                Write-Host $response.id
                $taskId = $response.id
                $videoStatusUrl = "https://ark.cn-beijing.volces.com/api/v3/contents/generations/tasks/$taskId"
                Write-Host "状态查询地址: $videoStatusUrl"
                Write-Host "轮询配置: 最多 $VideoPollMaxAttempts 次，每次间隔 $VideoPollIntervalSeconds 秒"
                $videoCompleted = $false
                $lastVideoStatus = "queued"
                for ($i = 0; $i -lt $VideoPollMaxAttempts; $i++) {
                    if ($i -gt 0) {
                        Start-Sleep -Seconds $VideoPollIntervalSeconds
                    }
                    $taskResponse = Invoke-RestMethod -Uri $videoStatusUrl -Method Get -Headers $headers -ErrorAction Stop
                    $lastVideoStatus = $taskResponse.status
                    Write-Host "轮询状态: $($taskResponse.status)"
                    if ($taskResponse.status -eq "succeeded") {
                        $videoCompleted = $true
                        $videoUrl = Get-VideoUrlFromTaskResponse $taskResponse
                        if (-not [string]::IsNullOrWhiteSpace($videoUrl)) {
                            Write-Host "视频结果 URL: $videoUrl"
                        } else {
                            Write-Host "视频任务已成功，但暂未从响应中解析到视频链接。"
                            Write-Host "请稍后使用任务 ID 再次查询：$taskId"
                            Write-ManualVideoQueryCommand $taskId
                            Write-Host ($taskResponse | ConvertTo-Json -Depth 20)
                        }
                        break
                    }
                    if ($taskResponse.status -in @("failed", "expired", "cancelled")) {
                        $videoCompleted = $true
                        Write-Host "视频生成任务未成功完成。"
                        if ($taskResponse.error) {
                            Write-Host "详细错误: $($taskResponse.error.message)" -ForegroundColor Red
                        }
                        break
                    }
                }
                if (-not $videoCompleted) {
                    Write-Host "视频任务仍在处理中，当前最后状态：$lastVideoStatus" -ForegroundColor Yellow
                    Write-Host "请稍后使用任务 ID 再次查询：$taskId" -ForegroundColor Yellow
                    Write-ManualVideoQueryCommand $taskId
                    Write-Host "你也可以调大轮询配置后重试：" -ForegroundColor Yellow
                    Write-Host '  $env:ARK_VIDEO_POLL_MAX_ATTEMPTS = "40"' -ForegroundColor DarkYellow
                    Write-Host '  $env:ARK_VIDEO_POLL_INTERVAL_SECONDS = "30"' -ForegroundColor DarkYellow
                }
                Write-Host "--------------------------------------------------"
                Write-Host ""
                $nextAction = Get-PostSuccessAction
                switch ($nextAction) {
                    "retry_capability" { continue }
                    "create_dev_env" { Start-DevEnvSetup; return }
                    default { return }
                }
            }

            if ($responseKind -eq "image") {
                $content = $response.data[0].url
            } elseif ($responseKind -eq "embedding") {
                $content = $null
            } else {
                $content = Get-ResponseText $response
            }
            
            Write-Host ""
            Write-Host $resultTitle -ForegroundColor Green
            Write-Host "--------------------------------------------------"
            if ($responseKind -eq "embedding") {
                Write-EmbeddingSummary $response
            } else {
                Write-Host $content
            }
            Write-Host "--------------------------------------------------"
            Write-Host ""
            $nextAction = Get-PostSuccessAction
            switch ($nextAction) {
                "retry_capability" { continue }
                "create_dev_env" { Start-DevEnvSetup; return }
                default { return }
            }

            } catch {
                $statusCode = [int]$_.Exception.Response.StatusCode
                if ($statusCode -eq 401 -or $statusCode -eq 403) {
                    $retryCount++
                    $remaining = $maxRetries - $retryCount
                    Write-Host ""
                    Write-Host "API Key 无效或权限不足！剩余重试次数：$remaining" -ForegroundColor Red
                    Write-Host "请检查您的 API Key 是否正确，或者重新输入。" -ForegroundColor Yellow
                    Remove-Item Env:ARK_API_KEY -ErrorAction SilentlyContinue
                    break
                } else {
                    Write-Host ""
                    Write-Host "调用失败: $($_.Exception.Message)" -ForegroundColor Red
                    
                    if ($_.Exception.Response) {
                        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                        $errBody = $reader.ReadToEnd()
                        Write-Host "详细错误: $errBody" -ForegroundColor Red
                        if ($errBody -match 'InvalidParameter' -and $errBody -match 'image size must be at least') {
                            Write-Host "图片生成参数提示：当前模型 $modelId 不接受 1024x1024 这类较小尺寸，建议使用 2K 或更高分辨率。" -ForegroundColor Yellow
                        } elseif ($capabilityChoice -eq "4" -and $errBody -match 'InvalidEndpointOrModel.NotFound') {
                            Write-Host "多模态向量化提示：当前模型 $modelId 不存在或当前账号暂无权限。" -ForegroundColor Yellow
                            Write-Host "你可以先在控制台开通图文向量化模型，或使用环境变量覆盖为已开通的 Model ID / Endpoint ID：" -ForegroundColor Yellow
                            Write-Host '  $env:ARK_MULTIMODAL_EMBEDDING_MODEL = "<your-model-or-endpoint-id>"' -ForegroundColor DarkYellow
                        }
                    }

                    Write-Host "可能的原因："
                    Write-Host "1. API Key 无效或过期"
                    Write-Host "2. 模型 ID 不存在或无权限调用"
                    Write-Host "3. 网络连接问题"
                    return
                }
            }
        }
    }

    # 重试次数耗尽
    Write-Host ""
    Write-Host "重试次数已达上限！请确认您的 API Key 正确无误后重新运行脚本。" -ForegroundColor Red
}

Main
