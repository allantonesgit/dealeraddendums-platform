const express = require('express');
const path = require('path');

const app = express();
app.use(express.json());
app.use('/printersupport', express.static(path.join(__dirname, '../public')));

const CHECKER_SYSTEM = "You are a laser printer compatibility expert for DealerAddendums. Determine if a printer can print addendum label stock from a main paper tray (not bypass/manual). Customers load full stacks.\n\nEvaluate BOTH sizes:\n- Standard Addendum: 4.25\" x 11\"\n- Narrow Addendum: 3.125\" x 11\"\n\nRULES:\n0. Inkjets: both incompatible immediately.\n1. Standard: tray must support 4.25\" min width.\n2. Narrow: tray must support 3.125\" min width. Narrow-compatible implies Standard-compatible.\n3. Labels media type must be selectable from main tray.\n4. Do not disqualify on warnings alone.\n5. Canon imageCLASS MF645Cdw: always return both true.\n6. If compatible: provide step-by-step configuration instructions.\n7. If not compatible: explain why. Suggest up to 3 same-brand alternatives. Prioritize color. Alternatives must be priced within $300 of the incompatible printer's approximate retail price.\n\nRespond with valid JSON only:\n{\"standardCompatible\":true,\"narrowCompatible\":true,\"confidence\":\"high\",\"reason\":\"explanation.\",\"steps\":[\"Step 1...\"],\"alternatives\":[{\"model\":\"\",\"approxPrice\":\"\",\"reason\":\"\"}]}";

const TROUBLESHOOT_SYSTEM = "You are an expert IT support technician for DealerAddendums, a dealership addendum label printing SaaS. Customers print Standard Addendum (4.25\" x 11\") or Narrow Addendum (3.125\" x 11\") adhesive labels on laser printers loaded as a stack into a main paper tray with media type set to Labels.\n\nIf a printer model is provided, tailor EVERY step to that model. If OS is provided, tailor to that OS. For iOS: cover AirPrint, same Wi-Fi, manufacturer apps. For Android: cover Mopria and manufacturer apps. Note custom paper sizes may not be available on mobile.\n\nReturn JSON only:\n{\"summary\":\"One sentence.\",\"category\":\"Setup\",\"steps\":[{\"title\":\"Title\",\"detail\":\"Detail.\"}],\"escalate\":\"Note or null\"}\n\nCategory: Setup, Scaling, Print Quality, Paper Feed, Driver/Software, or Unknown. 5-8 steps max.";

async function callAnthropic(system, userMsg, maxTokens, res) {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) return res.status(500).json({ error: 'ANTHROPIC_API_KEY not set on server' });

  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-20250514',
        max_tokens: maxTokens,
        system: system,
        messages: [{ role: 'user', content: userMsg }]
      })
    });

    const data = await response.json();

    if (!response.ok) {
      console.error('Anthropic error:', data);
      return res.status(502).json({ error: data.error?.message || 'API error' });
    }

    const raw = (data.content || []).find(b => b.type === 'text');
    const text = raw ? raw.text : '';
    const match = text.match(/\{[\s\S]*\}/);
    if (!match) return res.status(502).json({ error: 'No JSON in response' });

    res.json(JSON.parse(match[0]));
  } catch (err) {
    console.error('Printer support API error:', err.message);
    res.status(500).json({ error: err.message });
  }
}

// Compatibility checker endpoint
app.post('/printersupport/api/check', async (req, res) => {
  const { model } = req.body;
  if (!model) return res.status(400).json({ error: 'model is required' });
  const userMsg = `Printer model: ${model}\n\nCompatible with Standard Addendum (4.25" x 11") and/or Narrow Addendum (3.125" x 11") from main tray?`;
  await callAnthropic(CHECKER_SYSTEM, userMsg, 1500, res);
});

// Troubleshoot endpoint
app.post('/printersupport/api/troubleshoot', async (req, res) => {
  const { symptoms, printer, os } = req.body;
  if (!symptoms) return res.status(400).json({ error: 'symptoms is required' });
  let userMsg = 'Issue: ' + symptoms;
  if (printer) userMsg += '\nPrinter: ' + printer;
  if (os) userMsg += '\nOS: ' + os;
  await callAnthropic(TROUBLESHOOT_SYSTEM, userMsg, 1200, res);
});

app.get('/printersupport', (req, res) => res.sendFile(path.join(__dirname, '../public/index.html')));

const PORT = process.env.PORT || 3002;
app.listen(PORT, () => console.log(`Printer Support running on port ${PORT}`));
