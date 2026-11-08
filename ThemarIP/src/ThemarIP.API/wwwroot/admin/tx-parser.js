// ============================================================
// THEMAR IP — BANK TRANSACTION MESSAGE PARSER ADMIN MODULE
// Separate admin module for database-driven SMS & statement parsing,
// structured field extraction, user-friendly descriptions, confidence
// scoring, deduplication, and manual review queue.
// ============================================================

const TxMessageParser = {
  rules: [],
  messages: [],
  overview: null,
  statusFilter: 'ALL',
  bankFilter: 'ALL',

  bankDirectory: {
    'Bank Muscat': { code: 'BANK_MUSCAT', senders: 'BankMuscat, BM, BM-ALERT, Bank Muscat' },
    'National Bank of Oman': { code: 'NBO', senders: 'NBO, NBOMAN, NBO-ALERT' },
    'Bank Dhofar': { code: 'BANK_DHOFAR', senders: 'BankDhofar, BDHOFAR, Bank Dhofar' },
    'Oman Arab Bank': { code: 'OAB', senders: 'OAB, OMANARAB' },
    'Sohar International': { code: 'SOHAR_INTL', senders: 'SoharIntl, SOHAR' },
    'Ahli Bank Oman': { code: 'AHLI_BANK', senders: 'AhliBank, AHLIBANK' },
    'Bank Nizwa': { code: 'BANK_NIZWA', senders: 'BankNizwa, NIZWA' },
    'Alizz Islamic Bank': { code: 'ALIZZ_BANK', senders: 'AlizzBank, ALIZZ' }
  },

  samplePresets: [
    {
      label: 'BM: Mobile Payment Sent (Masked)',
      sender: 'BankMuscat',
      text: 'Dear Customer, You have sent OMR 100.000 to ALI #######################AHRI from your a/c 0468XXXXXXXX0033 on 26/10/2026 18:25:24 using Mobile Payment services. Txn Id BMCT015840785480. Avl Bal OMR 11.711.'
    },
    {
      label: 'BM: Mobile Payment Received',
      sender: 'BankMuscat',
      text: 'Dear Customer, You have received OMR 0.100 from TURKI ALI SULAIMAN AL BAHRI in your a/c 0312XXXXXXXX0014 using Mobile Payment services . Txn Id BMCT015700338903. Avl Bal OMR 2521.281.'
    },
    {
      label: 'BM: Card Payment at Merchant',
      sender: 'BankMuscat',
      text: 'Card 420460******0292 used for OMR 3.160 at COFFEE STORE on 15/10/2026 08:24:35. Available limit OMR 875.250.'
    },
    {
      label: 'BM: Card of A/C Payment',
      sender: 'BankMuscat',
      text: 'Card of a/c 0312XXXXXXXX0014 used for OMR 29.855 at 7202 OMAN OIL MAZOON STRE on 15/10/2026 15:40:28. Avl Bal OMR 2526.641.'
    },
    {
      label: 'BM: ATM Cash Withdrawal',
      sender: 'BankMuscat',
      text: 'OMR 50.000 withdrawn from ATM AL KHUWAIR using card of a/c 0312XXXXXXXX0014 on 18/10/2026 14:20:00. Avl Bal OMR 1200.000.'
    },
    {
      label: 'BM: Internal Account Transfer',
      sender: 'BankMuscat',
      text: 'OMR 1035.680 is debited from your A/C 0312XXXXXXXX0014 and credited to your A/C 0312XXXXXXXX0038 on 16/10/2026 09:53:32.'
    }
  ],

  async apiFetch(path, options = {}) {
    const token = (typeof state !== 'undefined' && state.token)
      ? state.token
      : sessionStorage.getItem('themar_admin_token');
    const headers = Object.assign({ 'Content-Type': 'application/json' }, options.headers || {});
    if (token) headers['Authorization'] = `Bearer ${token}`;

    const cleanSubPath = path.startsWith('/api/') ? path.substring(4) : path;
    const candidates = [];

    if (typeof window !== 'undefined' && (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1' || window.location.protocol === 'file:')) {
      candidates.push(`http://localhost:5267/api${cleanSubPath}`);
    }
    if (typeof THEMAR_API_BASE !== 'undefined') {
      candidates.push(`${THEMAR_API_BASE}${cleanSubPath}`);
    }
    candidates.push(`http://localhost:5267/api${cleanSubPath}`);

    let lastErr = null;
    for (const url of [...new Set(candidates)]) {
      try {
        const res = await fetch(url, Object.assign({}, options, { headers }));
        if (!res.ok) {
          let msg = `HTTP ${res.status}`;
          try {
            const err = await res.json();
            msg = err.message || err.title || msg;
          } catch (_) {}
          throw new Error(msg);
        }
        return await res.json();
      } catch (err) {
        lastErr = err;
      }
    }
    throw lastErr || new Error('Failed to reach Transaction Message Parser API');
  },

  async render() {
    this.bindEventsOnce();
    await this.loadAll();
    if (!this._initialSandboxRun) {
      this._initialSandboxRun = true;
      this.runLiveParseTest();
    }
  },

  async loadAll() {
    try {
      const [overview, rules, messages] = await Promise.all([
        this.apiFetch('/api/message-parser/overview'),
        this.apiFetch('/api/message-parser/rules'),
        this.apiFetch(`/api/message-parser/messages?status=${encodeURIComponent(this.statusFilter)}&bankCode=${encodeURIComponent(this.bankFilter)}&limit=250`)
      ]);
      this.overview = overview;
      this.rules = rules || [];
      this.messages = messages || [];

      this.renderOverviewKpis();
      this.renderRulesTable();
      this.renderMessagesTable();
      this.updateReviewBadge();
      if (typeof refreshIcons === 'function') refreshIcons();
    } catch (e) {
      console.error('TxMessageParser load error:', e);
      if (typeof Toast !== 'undefined') Toast.error('Failed to load Transaction Message Parser: ' + e.message);
    }
  },

  updateReviewBadge() {
    const badge = document.getElementById('nav-tx-parser-review-count');
    if (!badge || !this.overview) return;
    const count = this.overview.needsReviewMessages || 0;
    badge.textContent = count;
    badge.style.display = count > 0 ? 'inline-flex' : 'none';
  },

  renderOverviewKpis() {
    const o = this.overview || {};
    const set = (id, val) => {
      const el = document.getElementById(id);
      if (el) el.textContent = val;
    };
    set('txp-kpi-rules', `${o.activeRules ?? 0} / ${o.totalRules ?? 0}`);
    set('txp-kpi-parsed', o.totalParsedMessages ?? 0);
    set('txp-kpi-approved', o.autoApprovedMessages ?? 0);
    set('txp-kpi-review', o.needsReviewMessages ?? 0);
    set('txp-kpi-confidence', `${o.averageConfidence ?? 0}%`);
  },

  renderRulesTable() {
    const tbody = document.getElementById('tbody-txp-rules');
    if (!tbody) return;

    if (!this.rules.length) {
      tbody.innerHTML = `<tr><td colspan="8" style="text-align:center;color:var(--text-muted);padding:24px;">No extraction rules found. Click "Add Extraction Rule" to create one.</td></tr>`;
      return;
    }

    tbody.innerHTML = this.rules.map(r => {
      const dirBadge = r.direction === 'CREDIT'
        ? `<span class="badge" style="background:rgba(16,185,129,0.15);color:#34d399;border:1px solid rgba(16,185,129,0.3);">INCOMING (CREDIT)</span>`
        : `<span class="badge" style="background:rgba(242,106,27,0.15);color:#fb923c;border:1px solid rgba(242,106,27,0.35);">OUTGOING (DEBIT)</span>`;

      const statusBadge = r.isActive
        ? `<span class="badge badge-success">Active</span>`
        : `<span class="badge badge-neutral">Inactive</span>`;

      return `
        <tr>
          <td>
            <div style="font-weight:600;color:var(--text-primary);">${this.esc(r.bankName)}</div>
            <div style="font-size:11px;color:var(--text-muted);font-family:monospace;">${this.esc(r.bankCode)} · P${r.priority}</div>
          </td>
          <td>
            <div style="font-weight:600;">${this.esc(r.ruleName)}</div>
            <div style="font-size:11px;color:var(--text-muted);">${this.esc(r.senderIds)}</div>
          </td>
          <td><span class="badge badge-info">${this.esc(r.transactionType)}</span></td>
          <td>${dirBadge}</td>
          <td>
            <div style="font-weight:600;color:#c084fc;font-size:12.5px;">${this.esc(r.descriptionTemplate)}</div>
            <div style="font-size:11px;color:var(--text-dim);">Fallback: ${this.esc(r.fallbackDescription)}</div>
          </td>
          <td style="max-width:260px;">
            <code style="display:block;font-size:11px;color:var(--text-muted);background:rgba(255,255,255,0.03);padding:6px 8px;border-radius:6px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;" title="${this.esc(r.regexPattern)}">${this.esc(r.regexPattern)}</code>
          </td>
          <td><span style="font-weight:600;color:#38bdf8;">${r.baseConfidence}%</span></td>
          <td>${statusBadge}</td>
          <td style="text-align:right;white-space:nowrap;">
            <button class="btn btn-secondary btn-sm" onclick="TxMessageParser.openRuleModal('${r.id}')" title="Edit Rule"><i data-lucide="edit-3"></i></button>
            <button class="btn btn-danger btn-sm" onclick="TxMessageParser.deleteRule('${r.id}')" title="Delete Rule"><i data-lucide="trash-2"></i></button>
          </td>
        </tr>
      `;
    }).join('');
  },

  renderMessagesTable() {
    const tbody = document.getElementById('tbody-txp-messages');
    if (!tbody) return;

    if (!this.messages.length) {
      tbody.innerHTML = `<tr><td colspan="8" style="text-align:center;color:var(--text-muted);padding:24px;">No parsed transaction messages match the selected filters.</td></tr>`;
      return;
    }

    tbody.innerHTML = this.messages.map(m => {
      const dirBadge = m.direction === 'CREDIT'
        ? `<span class="badge" style="background:rgba(16,185,129,0.15);color:#34d399;border:1px solid rgba(16,185,129,0.3);">+ CREDIT</span>`
        : `<span class="badge" style="background:rgba(242,106,27,0.15);color:#fb923c;border:1px solid rgba(242,106,27,0.35);">- DEBIT</span>`;

      const confColor = m.confidenceScore >= 85 ? '#34d399' : (m.confidenceScore >= 70 ? '#fbbf24' : '#f87171');
      const statusBadge = m.reviewStatus === 'NEEDS_REVIEW'
        ? `<span class="badge" style="background:rgba(239,68,68,0.18);color:#f87171;border:1px solid rgba(239,68,68,0.35);">NEEDS REVIEW</span>`
        : m.reviewStatus === 'MANUALLY_REVIEWED'
          ? `<span class="badge" style="background:rgba(56,189,248,0.18);color:#38bdf8;border:1px solid rgba(56,189,248,0.35);">REVIEWED</span>`
          : `<span class="badge badge-success">AUTO APPROVED</span>`;

      const dateStr = m.transactionDate ? new Date(m.transactionDate).toLocaleString('en-GB', {
        day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit'
      }) : '—';

      return `
        <tr>
          <td>
            <div style="font-weight:700;color:#f8fafc;font-size:13.5px;">${this.esc(m.generatedDescription)}</div>
            <div style="font-size:11px;color:var(--text-muted);margin-top:2px;">Rule: ${this.esc(m.matchedRuleName || 'Heuristic Fallback')}</div>
          </td>
          <td>
            <div style="font-weight:600;">${this.esc(m.bankName)}</div>
            <div style="font-size:11px;color:var(--text-muted);">${this.esc(m.transactionType)}</div>
          </td>
          <td>
            ${dirBadge}
            <div style="font-weight:700;margin-top:4px;font-family:monospace;">${this.esc(m.currency)} ${Number(m.amount || 0).toFixed(3)}</div>
          </td>
          <td>
            <div style="font-weight:600;color:#e2e8f0;">${this.esc(m.counterpartyName || '—')}</div>
            ${m.rawCounterparty && m.rawCounterparty !== m.counterpartyName ? `<div style="font-size:10.5px;color:var(--text-dim);font-family:monospace;">Raw: ${this.esc(m.rawCounterparty)}</div>` : ''}
          </td>
          <td style="font-size:11.5px;font-family:monospace;color:var(--text-muted);">
            <div>A/C: ${this.esc(m.accountNumberMasked || '—')}</div>
            <div>Ref: ${this.esc(m.transactionReference || '—')}</div>
            <div style="color:var(--text-dim);">${this.esc(dateStr)}</div>
          </td>
          <td style="max-width:290px;">
            <div style="font-size:11px;font-family:monospace;color:var(--text-muted);background:rgba(255,255,255,0.03);padding:6px 8px;border-radius:6px;max-height:54px;overflow-y:auto;line-height:1.35;">${this.esc(m.originalMessage)}</div>
          </td>
          <td>
            <div style="font-weight:700;color:${confColor};font-size:13px;">${m.confidenceScore}%</div>
            <div style="margin-top:4px;">${statusBadge}</div>
          </td>
          <td style="text-align:right;white-space:nowrap;">
            <button class="btn btn-secondary btn-sm" onclick="TxMessageParser.openReviewModal('${m.id}')" title="Inspect & Review">
              <i data-lucide="check-circle-2"></i> Review
            </button>
          </td>
        </tr>
      `;
    }).join('');
  },

  async runLiveParseTest() {
    const sender = document.getElementById('txp-sandbox-sender')?.value || 'BankMuscat';
    const message = document.getElementById('txp-sandbox-message')?.value || '';
    const box = document.getElementById('txp-sandbox-result');
    if (!box) return;

    if (!message.trim()) {
      if (typeof Toast !== 'undefined') Toast.warning('Enter or choose a sample bank SMS message first.');
      return;
    }

    try {
      const r = await this.apiFetch('/api/message-parser/parse-test', {
        method: 'POST',
        body: JSON.stringify({ senderId: sender, rawMessage: message })
      });

      const confColor = r.confidenceScore >= 85 ? '#34d399' : (r.confidenceScore >= 70 ? '#fbbf24' : '#f87171');
      box.style.display = 'block';
      box.innerHTML = `
        <div style="background:rgba(16,185,129,0.06);border:1px solid rgba(16,185,129,0.25);border-radius:10px;padding:16px;margin-top:14px;">
          <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:12px;margin-bottom:12px;padding-bottom:12px;border-bottom:1px solid rgba(255,255,255,0.08);">
            <div>
              <div style="font-size:11px;text-transform:uppercase;letter-spacing:0.8px;color:var(--text-muted);">Generated User-Friendly Description</div>
              <div style="font-size:18px;font-weight:800;color:#f8fafc;margin-top:2px;">${this.esc(r.generatedDescription)}</div>
            </div>
            <div style="display:flex;gap:10px;align-items:center;">
              <span class="badge" style="background:rgba(56,189,248,0.15);color:${confColor};font-weight:700;font-size:12.5px;">Confidence: ${r.confidenceScore}%</span>
              <span class="badge ${r.needsManualReview ? 'badge-danger' : 'badge-success'}">${this.esc(r.reviewStatus)}</span>
            </div>
          </div>
          <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(175px,1fr));gap:10px;font-size:12.5px;">
            <div><span style="color:var(--text-muted);">1. Bank Name:</span> <strong style="color:#fff;">${this.esc(r.bankName)} (${this.esc(r.bankCode)})</strong></div>
            <div><span style="color:var(--text-muted);">2. Transaction Type:</span> <strong style="color:#c084fc;">${this.esc(r.transactionType)}</strong></div>
            <div><span style="color:var(--text-muted);">3. Direction:</span> <strong style="color:${r.direction === 'CREDIT' ? '#34d399' : '#fb923c'};">${this.esc(r.direction)}</strong></div>
            <div><span style="color:var(--text-muted);">4. Amount & Currency:</span> <strong style="font-family:monospace;color:#fff;">${this.esc(r.currency)} ${Number(r.amount || 0).toFixed(3)}</strong></div>
            <div><span style="color:var(--text-muted);">5. Sender/Recipient:</span> <strong style="color:#38bdf8;">${this.esc(r.counterpartyName || '—')}</strong></div>
            <div><span style="color:var(--text-muted);">6. Transaction Date:</span> <strong style="font-family:monospace;">${this.esc(r.transactionDate ? new Date(r.transactionDate).toLocaleString() : '—')}</strong></div>
            <div><span style="color:var(--text-muted);">7. Masked Account:</span> <strong style="font-family:monospace;">${this.esc(r.accountNumberMasked || '—')}</strong></div>
            <div><span style="color:var(--text-muted);">8. Txn Reference:</span> <strong style="font-family:monospace;">${this.esc(r.transactionReference || '—')}</strong></div>
            <div><span style="color:var(--text-muted);">Isolated Balance After:</span> <strong style="font-family:monospace;color:var(--text-dim);">${r.balanceAfter != null ? ('OMR ' + Number(r.balanceAfter).toFixed(3)) : '— (Not confused with amount)'}</strong></div>
            <div><span style="color:var(--text-muted);">Matched Rule:</span> <strong>${this.esc(r.matchedRuleName || 'Fallback')}</strong></div>
          </div>
        </div>
      `;
    } catch (e) {
      if (typeof Toast !== 'undefined') Toast.error('Parse test failed: ' + e.message);
    }
  },

  openRuleModal(ruleId = null) {
    const modal = document.getElementById('txp-rule-modal');
    if (!modal) return;
    const rule = ruleId ? this.rules.find(x => x.id === ruleId) : null;

    document.getElementById('txp-rule-modal-title').textContent = rule ? 'Edit Bank Extraction Rule' : 'Add Bank Extraction Rule';
    document.getElementById('txp-rule-id').value = rule ? rule.id : '';
    const bankName = rule ? rule.bankName : 'Bank Muscat';
    document.getElementById('txp-rule-bank').value = bankName;
    const bankMeta = this.bankDirectory[bankName] || { code: 'BANK_MUSCAT', senders: 'BankMuscat' };
    document.getElementById('txp-rule-bankcode').value = rule ? rule.bankCode : bankMeta.code;
    document.getElementById('txp-rule-senders').value = rule ? rule.senderIds : bankMeta.senders;
    document.getElementById('txp-rule-name').value = rule ? rule.ruleName : '';
    document.getElementById('txp-rule-txtype').value = rule ? rule.transactionType : 'TRANSFER_SENT';
    document.getElementById('txp-rule-direction').value = rule ? rule.direction : 'DEBIT';
    document.getElementById('txp-rule-priority').value = rule ? rule.priority : 10;
    document.getElementById('txp-rule-confidence').value = rule ? rule.baseConfidence : 95;
    document.getElementById('txp-rule-template').value = rule ? rule.descriptionTemplate : 'Money sent to {Counterparty}';
    document.getElementById('txp-rule-fallback').value = rule ? rule.fallbackDescription : 'Outgoing bank transfer';
    document.getElementById('txp-rule-pattern').value = rule ? rule.regexPattern : '';
    document.getElementById('txp-rule-sample').value = rule ? (rule.sampleMessage || '') : '';
    document.getElementById('txp-rule-active').value = rule ? String(rule.isActive) : 'true';

    modal.classList.remove('hidden');
  },

  async saveRule() {
    const id = document.getElementById('txp-rule-id').value;
    const payload = {
      bankCode: document.getElementById('txp-rule-bankcode').value.trim(),
      bankName: document.getElementById('txp-rule-bank').value.trim(),
      senderIds: document.getElementById('txp-rule-senders').value.trim(),
      ruleName: document.getElementById('txp-rule-name').value.trim(),
      transactionType: document.getElementById('txp-rule-txtype').value,
      direction: document.getElementById('txp-rule-direction').value,
      priority: parseInt(document.getElementById('txp-rule-priority').value, 10) || 10,
      baseConfidence: parseInt(document.getElementById('txp-rule-confidence').value, 10) || 95,
      descriptionTemplate: document.getElementById('txp-rule-template').value.trim(),
      fallbackDescription: document.getElementById('txp-rule-fallback').value.trim(),
      regexPattern: document.getElementById('txp-rule-pattern').value.trim(),
      sampleMessage: document.getElementById('txp-rule-sample').value.trim(),
      defaultCurrency: 'OMR',
      dateFormats: 'dd/MM/yyyy HH:mm:ss|dd/MM/yyyy HH:mm|dd/MM/yyyy|dd-MM-yyyy HH:mm:ss|dd-MMM-yyyy',
      cleanCounterparty: true,
      isActive: document.getElementById('txp-rule-active').value === 'true'
    };

    if (!payload.ruleName || !payload.regexPattern || !payload.descriptionTemplate) {
      if (typeof Toast !== 'undefined') Toast.warning('Rule Name, Regex Pattern, and Description Template are required.');
      return;
    }

    try {
      if (id) {
        await this.apiFetch(`/api/message-parser/rules/${id}`, {
          method: 'PUT',
          body: JSON.stringify(payload)
        });
        if (typeof Toast !== 'undefined') Toast.success('Extraction rule updated.');
      } else {
        await this.apiFetch('/api/message-parser/rules', {
          method: 'POST',
          body: JSON.stringify(payload)
        });
        if (typeof Toast !== 'undefined') Toast.success('New bank extraction rule created.');
      }
      document.getElementById('txp-rule-modal').classList.add('hidden');
      await this.loadAll();
    } catch (e) {
      if (typeof Toast !== 'undefined') Toast.error('Failed to save rule: ' + e.message);
    }
  },

  async deleteRule(id) {
    if (!confirm('Delete this bank message extraction rule?')) return;
    try {
      await this.apiFetch(`/api/message-parser/rules/${id}`, { method: 'DELETE' });
      if (typeof Toast !== 'undefined') Toast.success('Rule deleted.');
      await this.loadAll();
    } catch (e) {
      if (typeof Toast !== 'undefined') Toast.error('Delete failed: ' + e.message);
    }
  },

  openReviewModal(id) {
    const m = this.messages.find(x => x.id === id);
    if (!m) return;
    const modal = document.getElementById('txp-review-modal');
    if (!modal) return;

    document.getElementById('txp-review-id').value = m.id;
    document.getElementById('txp-review-original').textContent = m.originalMessage || '';
    document.getElementById('txp-review-description').value = m.generatedDescription || '';
    document.getElementById('txp-review-counterparty').value = m.counterpartyName || '';
    document.getElementById('txp-review-txtype').value = m.transactionType || 'CARD_PAYMENT';
    document.getElementById('txp-review-direction').value = m.direction || 'DEBIT';
    document.getElementById('txp-review-notes').value = m.reviewNotes || '';

    modal.classList.remove('hidden');
  },

  async saveManualReview() {
    const id = document.getElementById('txp-review-id').value;
    const payload = {
      generatedDescription: document.getElementById('txp-review-description').value.trim(),
      counterpartyName: document.getElementById('txp-review-counterparty').value.trim(),
      transactionType: document.getElementById('txp-review-txtype').value,
      direction: document.getElementById('txp-review-direction').value,
      reviewNotes: document.getElementById('txp-review-notes').value.trim()
    };

    try {
      await this.apiFetch(`/api/message-parser/messages/${id}/review`, {
        method: 'PUT',
        body: JSON.stringify(payload)
      });
      if (typeof Toast !== 'undefined') Toast.success('Transaction description reviewed and approved (100% confidence).');
      document.getElementById('txp-review-modal').classList.add('hidden');
      await this.loadAll();
    } catch (e) {
      if (typeof Toast !== 'undefined') Toast.error('Review save failed: ' + e.message);
    }
  },

  async triggerBackfill() {
    try {
      if (typeof Toast !== 'undefined') Toast.info('Re-evaluating all transactions against database extraction rules...');
      const res = await this.apiFetch('/api/message-parser/backfill', { method: 'POST' });
      if (typeof Toast !== 'undefined') Toast.success(`Parsed & verified ${res.processedCount || 0} transaction messages.`);
      await this.loadAll();
    } catch (e) {
      if (typeof Toast !== 'undefined') Toast.error('Backfill failed: ' + e.message);
    }
  },

  bindEventsOnce() {
    if (this._bound) return;
    this._bound = true;

    // Populate preset buttons
    const presetContainer = document.getElementById('txp-preset-buttons');
    if (presetContainer) {
      presetContainer.innerHTML = this.samplePresets.map((p, idx) =>
        `<button type="button" class="btn btn-secondary btn-sm" data-preset-idx="${idx}" style="font-size:11.5px;">${this.esc(p.label)}</button>`
      ).join('');
      presetContainer.addEventListener('click', (e) => {
        const btn = e.target.closest('[data-preset-idx]');
        if (!btn) return;
        const preset = this.samplePresets[Number(btn.dataset.presetIdx)];
        if (!preset) return;
        document.getElementById('txp-sandbox-sender').value = preset.sender;
        document.getElementById('txp-sandbox-message').value = preset.text;
        this.runLiveParseTest();
      });
    }

    document.getElementById('btn-txp-run-sandbox')?.addEventListener('click', () => this.runLiveParseTest());
    document.getElementById('btn-txp-add-rule')?.addEventListener('click', () => this.openRuleModal(null));
    document.getElementById('btn-txp-backfill')?.addEventListener('click', () => this.triggerBackfill());

    document.getElementById('txp-rule-bank')?.addEventListener('change', (e) => {
      const meta = this.bankDirectory[e.target.value];
      if (meta) {
        document.getElementById('txp-rule-bankcode').value = meta.code;
        document.getElementById('txp-rule-senders').value = meta.senders;
      }
    });

    document.getElementById('txp-rule-modal-close')?.addEventListener('click', () => {
      document.getElementById('txp-rule-modal').classList.add('hidden');
    });
    document.getElementById('txp-rule-modal-cancel')?.addEventListener('click', () => {
      document.getElementById('txp-rule-modal').classList.add('hidden');
    });
    document.getElementById('txp-rule-modal-save')?.addEventListener('click', () => this.saveRule());

    document.getElementById('txp-review-modal-close')?.addEventListener('click', () => {
      document.getElementById('txp-review-modal').classList.add('hidden');
    });
    document.getElementById('txp-review-modal-cancel')?.addEventListener('click', () => {
      document.getElementById('txp-review-modal').classList.add('hidden');
    });
    document.getElementById('txp-review-modal-save')?.addEventListener('click', () => this.saveManualReview());

    document.getElementById('txp-filter-status')?.addEventListener('change', (e) => {
      this.statusFilter = e.target.value;
      this.loadAll();
    });
    document.getElementById('txp-filter-bank')?.addEventListener('change', (e) => {
      this.bankFilter = e.target.value;
      this.loadAll();
    });
  },

  esc(str) {
    if (str === null || str === undefined) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }
};
