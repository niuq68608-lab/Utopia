const express = require("express");
const cors = require("cors");
const multer = require("multer");
const fs = require("fs")
const path = require("path");

const app = express();
app.use(cors());
app.use(express.json());

// ---- 默认 API 配置（用户可在聊天页面自行覆盖）----
const DEFAULT_API_KEY = "VxCgNvLTE.ChB6aU1DUTVKVTU4cEZ4ek5TEO3V4PcHGAEqEAl43vyg8U8trBxpP_KAd0M.os3Vjw-sptwj4XDu6aUirbdjrCwBIJTI4IUgdTdL_9DzYObTYWTF8Kv7-nyP0cLoRUW47Cjdr2lhab7WonofLgeZ";
const DEFAULT_MODEL = "doubao-lite-32k";
const DEFAULT_URL = "https://ark.cn-beijing.volces.com/api/v3/chat/completions";

// ---- 静态文件服务（整个 UTOPIA 网站）----
app.use(express.static(__dirname));

// ---- 新增平行世界留言&拥抱公共接口 ----
// 创建图片上传文件夹
const uploadDir = path.join(__dirname, "upload");
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir);
// 上传配置
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const name = Date.now() + Math.random().toString(36).slice(2) + ext;
    cb(null, name);
  }
});
const upload = multer({ storage, limits: { fileSize: 2 * 1024 * 1024 } });

// 头像上传接口
app.post("/api/upload", upload.single("avatar"), (req, res) => {
  if (!req.file) return res.status(400).json({ err: "请上传图片" });
  const imgUrl = `${req.protocol}://${req.headers.host}/upload/${req.file.filename}`;
  res.json({ url: imgUrl });
});

// 留言、拥抱内存存储（重启丢失，长期使用需数据库）
let msgList = [];
const MAX_MSG_NUM = 30;
let hugRecords = [];

// 获取全部公共留言
app.get("/api/messages", (req, res) => {
  res.json(msgList);
});

// 发布新留言
app.post("/api/messages", (req, res) => {
  const item = req.body;
  msgList.unshift(item);
  if (msgList.length > MAX_MSG_NUM) msgList = msgList.slice(0, MAX_MSG_NUM);
  res.json({ success: true });
});

// 获取指定用户的拥抱信箱
app.get("/api/hug/:nick", (req, res) => {
  const target = req.params.nick;
  const myHugs = hugRecords.filter(v => v.targetNick === target);
  res.json(myHugs);
});

// 发送拥抱记录
app.post("/api/hug", (req, res) => {
  hugRecords.unshift(req.body);
  res.json({ success: true });
});

// ---- API 代理 ----
app.post("/api/chat", async (req, res) => {
  const { role, history, msg, apiKey, model, apiUrl } = req.body;
  const key = apiKey || DEFAULT_API_KEY;
  const mod = model || DEFAULT_MODEL;
  const url = apiUrl || DEFAULT_URL;

  let systemPrompt = "";
  if (role === "qinche") {
    systemPrompt = "你是秦彻，性格清冷内敛，内心温柔，话不多，会安抚对方情绪，说话简短克制，不要过度热情。用户有情绪时优先包容，再解决问题。";
  }
  if (role === "taotao") {
    systemPrompt = "你是陶桃，活泼甜妹，喜欢逛街玩耍，语气轻快可爱，多用轻松口语，爱邀约对方出门。";
  }

  const messages = [
    { role: "system", content: systemPrompt },
    ...(history || []),
    { role: "user", content: msg }
  ];

  try {
    const resp = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer " + key
      },
      body: JSON.stringify({ model: mod, messages, max_tokens: 120 })
    });
    const json = await resp.json();
    res.json(json);
  } catch (e) {
    console.error("API proxy error:", e.message);
    res.json({ choices: [{ message: { content: "AI 暂时连接不上，请稍后再试。" } }] });
  }
});

// ---- 通用代理（客户端指定 API 地址和密钥）----
app.post("/api/proxy", async (req, res) => {
  const { url, headers: reqHeaders, body } = req.body;
  if (!url) return res.status(400).json({ error: "missing url" });
  try {
    const fetchOpts = { method: "POST", headers: { "Content-Type": "application/json", ...(reqHeaders || {}) } };
    fetchOpts.body = typeof body === "string" ? body : JSON.stringify(body);
    const resp = await fetch(url, fetchOpts);
    const data = await resp.json();
    res.json(data);
  } catch (e) {
    res.status(502).json({ error: "proxy failed: " + e.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, "0.0.0.0", () => {
  console.log("UTOPIA running at http://localhost:" + PORT);
  console.log("API proxy: http://localhost:" + PORT + "/api/chat");
});
