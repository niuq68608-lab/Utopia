const DEFAULT_API_KEY = "VxCgNvLTE.ChB6aU1DUTVKVTU4cEZ4ek5TEO3V4PcHGAEqEAl43vyg8U8trBxpP_KAd0M.os3Vjw-sptwj4XDu6aUirbdjrCwBIJTI4IUgdTdL_9DzYObTYWTF8Kv7-nyP0cLoRUW47Cjdr2lhab7WonofLgeZ";
const DEFAULT_MODEL = "doubao-lite-32k";
const DEFAULT_URL = "https://ark.cn-beijing.volces.com/api/v3/chat/completions";

module.exports = async function handler(req, res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

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
};