module.exports = async function handler(req, res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  const { url, headers: reqHeaders, body } = req.body;
  if (!url) return res.status(400).json({ error: "missing url" });

  try {
    const fetchOpts = {
      method: "POST",
      headers: { "Content-Type": "application/json", ...(reqHeaders || {}) }
    };
    if (typeof body === "string") {
      fetchOpts.body = body;
    } else {
      fetchOpts.body = JSON.stringify(body);
    }

    const resp = await fetch(url, fetchOpts);
    const data = await resp.json();
    res.json(data);
  } catch (e) {
    res.status(502).json({ error: "proxy failed: " + e.message });
  }
};