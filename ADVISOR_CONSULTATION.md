# Advisor Consultation: Maintenance Reminder System

## The Situation
We built a YAML-based reminder system (`115_maintenance`) that:
- ✅ Uses git-backed YAML (human editable, version controlled)
- ✅ Routes to correct Telegram channels (EFS, ARS, etc.)
- ✅ Handles recurring reminders (auto-updates next due date)
- ❌ Can't actually send Telegram messages from cron (no OpenClaw tool access)

## The Options

### Option A: Fix with Apprise (30 min)
- Add Apprise Python library for Telegram notifications
- Keep our YAML + Python approach
- Cron job actually sends messages
- **Trade-off:** Need Telegram bot token, still fairly DIY

### Option B: MIND (1 hour setup)
- Self-hosted web UI with Docker
- Recurring reminders, 80+ notification platforms
- **Trade-off:** SQLite DB (not git-backed), more complex, overkill?

### Option C: cron-telebot
- Telegram-native bot for recurring messages
- **Trade-off:** MongoDB backend, no YAML editing

### Option D: Manual queue (keep current)
- Cron writes pending reminders to queue file
- I check queue during heartbeats and send manually
- **Trade-off:** 15-min delay, requires me to be running

---

## Questions for Advisors

**Maggie:** What's the business risk of a missed SSL cert renewal vs. the operational cost of maintaining this system?

**Rachel:** Is "crawl" the YAML approach with a proper notification library, or should we just use an existing tool? When do we stop building and start using?

**Sandy:** What's the cost comparison? Our time to build/maintain vs. hosted solution? Do we need budget for a proper SaaS?

**Tom:** Who's going to own this long-term? If Mark or I get hit by a bus, can someone else maintain it?

**David:** Does rolling our own fit Creative Intelligence's culture of pragmatic solutions, or are we reinventing wheels we shouldn't?

**Marcus:** What's the operational risk of our current broken implementation vs. the risk of a more complex system we don't fully control?

---

*Waiting for Mark's decision on direction.*
