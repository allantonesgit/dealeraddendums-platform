const express = require('express');
const path = require('path');

const app = express();
app.use(express.json());

// Serve static files under /staterules
app.use('/staterules', express.static(path.join(__dirname, '../public')));

// API endpoint — proxies to Anthropic server-side so API key stays secret
app.post('/staterules/api/lookup', async (req, res) => {
  const { state } = req.body;
  if (!state) return res.status(400).json({ error: 'State is required' });

  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) return res.status(500).json({ error: 'ANTHROPIC_API_KEY not set on server' });

  const isFederal = state === 'Federal Requirements';

  const prompt = isFederal
    ? `You are a legal research assistant specializing in U.S. automotive dealer regulations.

Research and summarize the current FEDERAL laws and regulations that apply nationwide to new vehicle pricing addendums at car dealerships.

Cover these federal topics:
1. The Monroney Act — federal window sticker (MSRP) requirements for new vehicles
2. FTC rules — unfair or deceptive acts and practices (UDAP) as applied to dealer pricing and addendums
3. FTC Vehicle Shopping Rule — what dealers must disclose in advertising and at point of sale
4. Truth in Lending Act (TILA) / Regulation Z — financing disclosure requirements on vehicle sales contracts
5. Consumer Financial Protection Bureau (CFPB) — guidance and oversight for auto dealers
6. Federal advertising rules — what must be included when a price is advertised
7. Penalties for non-compliance with federal rules
8. Key federal statutes and regulatory citations

Format your response as HTML using only these tags: <h3>, <p>, <ul>, <li>, <div class="callout">, <div class="warning-callout">
Use <h3> for each numbered section title. Do NOT use markdown, bold, italic, or a top-level heading.
End with a <div class="warning-callout"> reminding readers this is a summary and they should verify with official sources.`

    : `You are a legal research assistant specializing in U.S. automotive dealer regulations.

Research and summarize the CURRENT rules and regulations in ${state} regarding new vehicle pricing addendums at car dealerships.

Cover these topics if applicable to ${state}:
1. Window sticker / addendum disclosure requirements (what must be shown, font size, placement)
2. Dealer processing / documentation fee rules (caps, required disclosure language)
3. Market adjustment / above-MSRP markup rules (legality, any restrictions)
4. Dealer-installed accessories on addendums (disclosure requirements, negotiability)
5. Advertising rules (must addendum charges be included in advertised price?)
6. Penalties or enforcement for non-compliance
7. Key statutes, codes, or regulatory citations

Format your response as HTML using only these tags: <h3>, <p>, <ul>, <li>, <div class="callout">, <div class="warning-callout">
Use <h3> for each numbered section title. Do NOT use markdown, bold, italic, or a top-level state name heading.
If ${state} has no specific rules beyond federal law, explain that clearly.
End with a <div class="warning-callout"> reminding readers this is a summary and they should verify with official sources.`;

  try {
    const anthropicRes = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 2000,
        stream: true,
        tools: [{ type: 'web_search_20250305', name: 'web_search' }],
        messages: [{ role: 'user', content: prompt }]
      })
    });

    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    const reader = anthropicRes.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop();
      for (const line of lines) {
        if (!line.startsWith('data: ')) continue;
        const data = line.slice(6).trim();
        if (data === '[DONE]') continue;
        try {
          const evt = JSON.parse(data);
          if (evt.type === 'content_block_delta' && evt.delta?.type === 'text_delta') {
            res.write(`data: ${JSON.stringify({ text: evt.delta.text })}\n\n`);
          }
        } catch {}
      }
    }
    res.write('data: [DONE]\n\n');
    res.end();
  } catch (err) {
    console.error('Anthropic error:', err.message);
    if (!res.headersSent) res.status(500).json({ error: 'Upstream API error' });
  }
});

// Root redirect
app.get('/staterules', (req, res) => res.sendFile(path.join(__dirname, '../public/index.html')));

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`State Rules running on port ${PORT}`));
