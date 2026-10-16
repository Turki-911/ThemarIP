#!/usr/bin/env python3
"""
Pre-Deploy Backup & Live Railway Sync Script for ThemarIP.
Always run this script BEFORE committing or deploying `themarip.db` to Railway.

Synced Endpoints -> SQLite Tables:
  1. /statements/categories-hierarchy -> PfmCategories (root + subcategories)
  2. /statements/merchants            -> PfmMerchants, PfmMerchantAliases
  3. /statements/category-rules       -> PfmCategorizationRules, PfmRuleConditions
  4. /statements/users                -> Users
  5. /statements/transactions         -> PfmTransactions
  6. /admin/sms-rules                 -> BankSmsRules
  7. /admin/sms-rules/logs?take=200   -> SmsProcessingLogs
"""

import os
import sys
import ssl
import json
import shutil
import sqlite3
import hashlib
import urllib.request
from datetime import datetime, timezone

BASE_URL = "https://themarip.up.railway.app/api"
DB_PATH = "ThemarIP/src/ThemarIP.API/themarip.db"
ADMIN_EMAIL = "admin@themar.ip"
ADMIN_PASSWORD = "AdminPassword123!"

FIELD_MAP = {
    "merchant_name": "MerchantName",
    "merchant_id": "MerchantId",
    "mcc": "MccCode",
    "type": "TransactionType",
    "amount": "Amount",
    "currency": "Currency",
    "narration": "Narration",
}

OP_MAP = {
    "equals": "Equals",
    "equal": "Equals",
    "starts_with": "StartsWith",
    "startswith": "StartsWith",
    "ends_with": "EndsWith",
    "endswith": "EndsWith",
    "greater_than": "GreaterThan",
    "greaterthan": "GreaterThan",
    "less_than": "LessThan",
    "lessthan": "LessThan",
    "between": "Between",
    "contains": "Contains",
}


def fetch_json(endpoint: str, token: str = None):
    ctx = ssl._create_unverified_context()
    headers = {"Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(f"{BASE_URL}/{endpoint}", headers=headers)
    with urllib.request.urlopen(req, context=ctx, timeout=20) as resp:
        return json.loads(resp.read().decode("utf-8"))


def get_admin_token() -> str:
    ctx = ssl._create_unverified_context()
    payload = json.dumps({"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD}).encode("utf-8")
    req = urllib.request.Request(
        f"{BASE_URL}/auth/login",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, context=ctx, timeout=20) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        return data["token"]


def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S.%f+00:00")


def main():
    if not os.path.exists(DB_PATH):
        print(f"[ERROR] Database not found at {DB_PATH}", file=sys.stderr)
        sys.exit(1)

    ts = datetime.now().strftime("%Y_%m_%d_%H%M")
    backup_dir = os.path.join("backups", f"backup_{ts}")
    os.makedirs(backup_dir, exist_ok=True)

    # 1. Backup local SQLite file first
    shutil.copy2(DB_PATH, os.path.join(backup_dir, "themarip.db"))
    print(f"[1/3] Created local DB snapshot in {backup_dir}/themarip.db")

    # 2. Fetch all live endpoints from Railway
    print("[2/3] Fetching live data from Railway...")
    token = get_admin_token()

    endpoints = {
        "categories-hierarchy": ("statements/categories-hierarchy", False),
        "merchants": ("statements/merchants", False),
        "category-rules": ("statements/category-rules", False),
        "users": ("statements/users", False),
        "transactions": ("statements/transactions", False),
        "sms-rules": ("admin/sms-rules", True),
        "sms-logs": ("admin/sms-rules/logs?take=200", True),
    }

    live_data = {}
    for key, (ep, needs_auth) in endpoints.items():
        data = fetch_json(ep, token if needs_auth else None)
        live_data[key] = data
        out_file = os.path.join(backup_dir, f"railway_{key.replace('-', '_')}_{ts}.json")
        with open(out_file, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        print(f"  - Exported /{ep} -> {out_file} ({len(data)} records)")

    # 3. Sync into local SQLite database
    print(f"[3/3] Syncing live Railway data into {DB_PATH}...")
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    ts_now = now_iso()

    # 3a. Sync Categories & Subcategories (PfmCategories)
    cat_count = 0
    sub_count = 0
    for c in live_data["categories-hierarchy"]:
        cid = c.get("id") or c.get("Id")
        cname = c.get("name") or c.get("Name")
        cicon = c.get("icon") or c.get("Icon") or "tag"
        ccolor = c.get("color") or c.get("Color") or "#7C3AED"
        corder = c.get("displayOrder") if c.get("displayOrder") is not None else 0
        cenabled = 1 if c.get("isEnabled", True) else 0

        cur.execute("SELECT Id FROM PfmCategories WHERE lower(Id) = lower(?)", (cid,))
        existing = cur.fetchone()
        if existing:
            cur.execute(
                """UPDATE PfmCategories
                   SET Name = ?, Icon = ?, Color = ?, DisplayOrder = ?, IsEnabled = ?, ParentId = NULL
                   WHERE Id = ?""",
                (cname, cicon, ccolor, corder, cenabled, existing[0]),
            )
            parent_id = existing[0]
        else:
            cur.execute(
                """INSERT INTO PfmCategories (Id, Name, Icon, Color, DisplayOrder, IsEnabled, CreatedAt, UpdatedAt, ParentId)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)""",
                (cid, cname, cicon, ccolor, corder, cenabled, ts_now, ts_now),
            )
            parent_id = cid
        cat_count += 1

        for s in c.get("subcategories") or []:
            sid = s.get("id") or s.get("Id")
            sname = s.get("name") or s.get("Name")
            sicon = s.get("icon") or s.get("Icon") or "tag"
            scolor = s.get("color") or s.get("Color") or ccolor
            sorder = s.get("displayOrder") if s.get("displayOrder") is not None else 0
            senabled = 1 if s.get("isEnabled", True) else 0

            cur.execute("SELECT Id FROM PfmCategories WHERE lower(Id) = lower(?)", (sid,))
            ex_sub = cur.fetchone()
            if ex_sub:
                cur.execute(
                    """UPDATE PfmCategories
                       SET Name = ?, Icon = ?, Color = ?, DisplayOrder = ?, IsEnabled = ?, ParentId = ?
                       WHERE Id = ?""",
                    (sname, sicon, scolor, sorder, senabled, parent_id, ex_sub[0]),
                )
            else:
                cur.execute(
                    """INSERT INTO PfmCategories (Id, Name, Icon, Color, DisplayOrder, IsEnabled, CreatedAt, UpdatedAt, ParentId)
                       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                    (sid, sname, sicon, scolor, sorder, senabled, ts_now, ts_now, parent_id),
                )
            sub_count += 1

    # 3b. Sync Merchants & Aliases (PfmMerchants, PfmMerchantAliases)
    m_count = 0
    alias_count = 0
    for m in live_data["merchants"]:
        mid = m.get("id")
        mname = m.get("name") or ""
        mmcc = m.get("mcc") or None
        mcat = m.get("defaultCategoryId") or None
        msub = m.get("defaultSubcategoryId") or None
        mconf = m.get("defaultConfidence") if m.get("defaultConfidence") is not None else 90
        mactive = 0 if str(m.get("status", "active")).lower() == "inactive" else 1
        mtx = m.get("txCount") or 0
        mrate = str(m.get("correctionRate") or "0.0")

        cur.execute("SELECT Id FROM PfmMerchants WHERE lower(Id) = lower(?)", (mid,))
        ex_m = cur.fetchone()
        if ex_m:
            real_mid = ex_m[0]
            cur.execute(
                """UPDATE PfmMerchants
                   SET Name = ?, MccCode = ?, DefaultCategoryId = ?, DefaultSubcategoryId = ?,
                       DefaultConfidence = ?, IsActive = ?, TransactionCount = ?, CorrectionRate = ?
                   WHERE Id = ?""",
                (mname, mmcc, mcat, msub, mconf, mactive, mtx, mrate, real_mid),
            )
        else:
            real_mid = mid
            cur.execute(
                """INSERT INTO PfmMerchants (
                       Id, Name, MccCode, DefaultCategoryId, DefaultSubcategoryId,
                       DefaultConfidence, IsActive, TransactionCount, CorrectionRate, CreatedAt, UpdatedAt
                   ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (real_mid, mname, mmcc, mcat, msub, mconf, mactive, mtx, mrate, ts_now, ts_now),
            )
        m_count += 1

        # Sync aliases for this merchant
        for alias_text in m.get("aliases") or []:
            if not alias_text or not str(alias_text).strip():
                continue
            clean_alias = str(alias_text).strip()
            cur.execute(
                "SELECT Id FROM PfmMerchantAliases WHERE lower(AliasText) = lower(?)",
                (clean_alias,),
            )
            ex_a = cur.fetchone()
            if not ex_a:
                aid = hashlib.md5(f"{real_mid}:{clean_alias}".encode("utf-8")).hexdigest()
                aid_guid = f"{aid[:8]}-{aid[8:12]}-{aid[12:16]}-{aid[16:20]}-{aid[20:32]}"
                cur.execute(
                    """INSERT OR IGNORE INTO PfmMerchantAliases (Id, MerchantId, AliasText, CreatedAt)
                       VALUES (?, ?, ?, ?)""",
                    (aid_guid, real_mid, clean_alias, ts_now),
                )
            alias_count += 1

    # 3c. Sync Categorization Rules & Conditions (PfmCategorizationRules, PfmRuleConditions)
    rule_count = 0
    cond_count = 0
    for r in live_data["category-rules"]:
        rid = r.get("id")
        rname = r.get("name") or ""
        rcat = r.get("categoryId") or None
        rsub = r.get("subcategoryId") or None
        rconf = r.get("confidence") if r.get("confidence") is not None else 85
        rprio = r.get("priority") if r.get("priority") is not None else 50
        rstat = "Inactive" if str(r.get("status", "active")).lower() == "inactive" else "Active"
        rmatch = r.get("matchCount") or 0
        rlearned = 1 if r.get("isLearnedFromCorrection") else 0

        cur.execute("SELECT Id FROM PfmCategorizationRules WHERE lower(Id) = lower(?)", (rid,))
        ex_r = cur.fetchone()
        if ex_r:
            real_rid = ex_r[0]
            cur.execute(
                """UPDATE PfmCategorizationRules
                   SET Name = ?, CategoryId = ?, SubcategoryId = ?, Confidence = ?,
                       Priority = ?, Status = ?, MatchCount = ?, IsLearnedFromCorrection = ?
                   WHERE Id = ?""",
                (rname, rcat, rsub, rconf, rprio, rstat, rmatch, rlearned, real_rid),
            )
        else:
            real_rid = rid
            cur.execute(
                """INSERT INTO PfmCategorizationRules (
                       Id, Name, CategoryId, SubcategoryId, Confidence, Priority,
                       Status, MatchCount, IsLearnedFromCorrection, CreatedByAdminId, CreatedAt, UpdatedAt
                   ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?)""",
                (real_rid, rname, rcat, rsub, rconf, rprio, rstat, rmatch, rlearned, ts_now, ts_now),
            )
        rule_count += 1

        # Sync conditions for this rule
        cur.execute("DELETE FROM PfmRuleConditions WHERE RuleId = ?", (real_rid,))
        for idx, c in enumerate(r.get("conditions") or []):
            cid = c.get("id") or hashlib.md5(f"{real_rid}:{idx}".encode("utf-8")).hexdigest()
            if len(cid) == 32 and "-" not in cid:
                cid = f"{cid[:8]}-{cid[8:12]}-{cid[12:16]}-{cid[16:20]}-{cid[20:32]}"
            cfield = FIELD_MAP.get(str(c.get("field", "narration")).lower(), "Narration")
            cop = OP_MAP.get(str(c.get("operator", "contains")).lower(), "Contains")
            cval = c.get("value") or ""
            clogic = "Or" if str(c.get("logic", "AND")).upper() == "OR" else "And"
            cur.execute(
                """INSERT OR REPLACE INTO PfmRuleConditions (Id, RuleId, Field, Operator, Value, LogicOperator, OrderIndex)
                   VALUES (?, ?, ?, ?, ?, ?, ?)""",
                (cid, real_rid, cfield, cop, cval, clogic, idx),
            )
            cond_count += 1

    # 3d. Sync Users
    u_count = 0
    for u in live_data["users"]:
        uid = u.get("id")
        cur.execute("SELECT Id FROM Users WHERE lower(Id) = lower(?)", (uid,))
        ex_u = cur.fetchone()
        if ex_u:
            cur.execute(
                """UPDATE Users
                   SET FullName = ?, AccountNumber = ?, AccessStatus = ?, TrustScore = ?
                   WHERE Id = ?""",
                (
                    u.get("fullName") or "",
                    u.get("accountNumber"),
                    u.get("accessStatus") or "Approved",
                    u.get("trustScore") or 0,
                    ex_u[0],
                ),
            )
        else:
            cur.execute(
                """INSERT INTO Users (
                       Id, AccessReasonCode, AccessReasonNote, AccessStatus, AccountNumber,
                       CreatedAt, Email, FullName, PasswordHash, Role, TrustScore
                   ) VALUES (?, NULL, NULL, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    uid,
                    u.get("accessStatus") or "Approved",
                    u.get("accountNumber"),
                    u.get("createdAt") or ts_now,
                    u.get("email") or "",
                    u.get("fullName") or "",
                    "$2a$11$eWkZ.fakehashforlocalparityonly111111111111111111111111",
                    u.get("role") or "User",
                    u.get("trustScore") or 0,
                ),
            )
        u_count += 1

    # 3e. Sync Transactions (PfmTransactions)
    tx_count = 0
    for t in live_data["transactions"]:
        tid = t.get("id")
        cur.execute("SELECT Id FROM PfmTransactions WHERE lower(Id) = lower(?)", (tid,))
        ex_t = cur.fetchone()
        if not ex_t:
            tx_type = "Debit" if t.get("transactionType") == 0 else "Credit"
            tx_stat = "Categorized" if t.get("status") == 0 else "Uncategorized"
            bal = str(t.get("balanceAfter")) if t.get("balanceAfter") is not None else None
            cur.execute(
                """INSERT INTO PfmTransactions (
                       Id, UserId, MerchantId, Narration, Amount, Currency, TransactionType,
                       BalanceAfter, TransactionDate, IsRecurring, IsEssential, Status, MccCode,
                       CreatedAt, UpdatedAt, BankCode, BankName
                   ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    tid,
                    t.get("userId"),
                    t.get("merchantId"),
                    t.get("narration") or "",
                    str(t.get("amount") or 0),
                    t.get("currency") or "OMR",
                    tx_type,
                    bal,
                    t.get("transactionDate") or ts_now,
                    1 if t.get("isRecurring") else 0,
                    1 if t.get("isEssential") else 0,
                    tx_stat,
                    t.get("mccCode"),
                    t.get("createdAt") or ts_now,
                    t.get("updatedAt") or ts_now,
                    t.get("bankCode") or "BANK_MUSCAT",
                    t.get("bankName") or "Bank Muscat",
                ),
            )
        tx_count += 1

    # 3f. Sync Bank SMS Rules (BankSmsRules)
    for sr in live_data["sms-rules"]:
        srid = sr.get("id")
        fm = sr.get("fieldMappings")
        fm_str = json.dumps(fm) if isinstance(fm, (dict, list)) else (fm or "{}")
        cur.execute("SELECT Id FROM BankSmsRules WHERE lower(Id) = lower(?)", (srid,))
        ex_sr = cur.fetchone()
        if ex_sr:
            cur.execute(
                """UPDATE BankSmsRules
                   SET BankName = ?, BankCode = ?, SenderIds = ?, Pattern = ?, FieldMappings = ?,
                       DebitKeywords = ?, CreditKeywords = ?, DefaultType = ?, DefaultCurrency = ?,
                       DateFormats = ?, SampleMessage = ?, IsActive = ?, Version = ?, UpdatedAt = ?, UpdatedBy = ?
                   WHERE Id = ?""",
                (
                    sr.get("bankName") or "",
                    sr.get("bankCode") or "",
                    sr.get("senderIds") or "",
                    sr.get("pattern") or "",
                    fm_str,
                    sr.get("debitKeywords") or "",
                    sr.get("creditKeywords") or "",
                    sr.get("defaultType") or "DEBIT",
                    sr.get("defaultCurrency") or "OMR",
                    sr.get("dateFormats") or "",
                    sr.get("sampleMessage") or "",
                    1 if sr.get("isActive", True) else 0,
                    sr.get("version") or 1,
                    sr.get("updatedAt") or ts_now,
                    sr.get("updatedBy"),
                    ex_sr[0],
                ),
            )
        else:
            cur.execute(
                """INSERT INTO BankSmsRules (
                       Id, BankName, BankCode, SenderIds, Pattern, FieldMappings,
                       DebitKeywords, CreditKeywords, DefaultType, DefaultCurrency,
                       DateFormats, SampleMessage, IsActive, Version, CreatedAt, UpdatedAt, UpdatedBy
                   ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    srid,
                    sr.get("bankName") or "",
                    sr.get("bankCode") or "",
                    sr.get("senderIds") or "",
                    sr.get("pattern") or "",
                    fm_str,
                    sr.get("debitKeywords") or "",
                    sr.get("creditKeywords") or "",
                    sr.get("defaultType") or "DEBIT",
                    sr.get("defaultCurrency") or "OMR",
                    sr.get("dateFormats") or "",
                    sr.get("sampleMessage") or "",
                    1 if sr.get("isActive", True) else 0,
                    sr.get("version") or 1,
                    sr.get("createdAt") or ts_now,
                    sr.get("updatedAt") or ts_now,
                    sr.get("updatedBy"),
                ),
            )

    # 3g. Sync SMS Processing Logs (SmsProcessingLogs)
    for l in live_data["sms-logs"]:
        lid = l.get("id")
        cur.execute("SELECT Id FROM SmsProcessingLogs WHERE lower(Id) = lower(?)", (lid,))
        if not cur.fetchone():
            msg_hash = hashlib.sha256((l.get("rawMessage") or "").encode("utf-8")).hexdigest()[:32]
            cur.execute(
                """INSERT INTO SmsProcessingLogs (
                       Id, UserId, Sender, RawMessage, MessageHash, RuleId, RuleVersion,
                       Status, Details, ExtractedJson, Reference, TransactionId, ReceivedAt, CreatedAt
                   ) VALUES (?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, ?)""",
                (
                    lid,
                    l.get("sender") or "",
                    l.get("rawMessage") or "",
                    msg_hash,
                    l.get("ruleId"),
                    l.get("ruleVersion"),
                    l.get("status") or "",
                    l.get("details") or "",
                    l.get("extractedJson"),
                    l.get("transactionId"),
                    l.get("createdAt") or ts_now,
                    l.get("createdAt") or ts_now,
                ),
            )

    conn.commit()
    conn.close()

    print(
        f"[DONE] Synced {cat_count} root categories, {sub_count} subcategories, "
        f"{m_count} merchants ({alias_count} aliases), {rule_count} rules ({cond_count} conditions), "
        f"{u_count} users, and {tx_count} transactions into {DB_PATH}."
    )


if __name__ == "__main__":
    main()
