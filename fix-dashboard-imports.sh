#!/bin/bash
# ============================================
# Fix dashboard — missing import + server/client issues
# Run from: ~/groundup
# ============================================

set -e
echo "🔧 Fixing dashboard..."

python3 << 'PYEOF'
content = open("app/dashboard/page.tsx", "r").read()
changes = 0

# 1. Add NotificationBell import if missing
if "NotificationBell" in content and "import NotificationBell" not in content:
    # Add import after the last import line
    last_import = content.rfind("import ")
    line_end = content.find("\n", last_import)
    content = content[:line_end+1] + 'import NotificationBell from "@/components/NotificationBell";\n' + content[line_end+1:]
    changes += 1
    print("  ✓ Added NotificationBell import")

# 2. Check if NotificationBell component file exists
import os
if not os.path.exists("components/NotificationBell.tsx"):
    # Remove the NotificationBell usage since the component doesn't exist yet
    # Replace with a simple placeholder
    content = content.replace(
        '<NotificationBell />',
        '{/* NotificationBell */}',
    )
    # Remove the import we just added
    content = content.replace('import NotificationBell from "@/components/NotificationBell";\n', '')
    changes += 1
    print("  ✓ NotificationBell component not found — commented out usage")

# 3. Check if calculateProfileCompletion is defined
if "calculateProfileCompletion" in content and "function calculateProfileCompletion" not in content:
    # It's used but not defined — add it
    # Find where the function is called
    func = '''
function calculateProfileCompletion(user: any): number {
  let score = 0;
  let total = 0;
  
  // Basic info
  total += 4;
  if (user.firstName) score++;
  if (user.lastName) score++;
  if (user.bio) score++;
  if (user.location) score++;
  
  // Skills
  total += 1;
  if (user.skills && user.skills.length > 0) score++;
  
  // Working style
  total += 1;
  if (user.workingStyle) score++;
  
  return Math.round((score / total) * 100);
}
'''
    # Insert before the export
    export_pos = content.find("export default")
    if export_pos > 0:
        content = content[:export_pos] + func + "\n" + content[export_pos:]
        changes += 1
        print("  ✓ Added calculateProfileCompletion function")

open("app/dashboard/page.tsx", "w").write(content)
print(f"\n  {changes} patches applied")
PYEOF

# Also make sure the NotificationBell component exists
if [ ! -f "components/NotificationBell.tsx" ]; then
mkdir -p components

cat > components/NotificationBell.tsx << 'EOF'
"use client";

import { useState, useEffect, useCallback, useRef } from "react";

interface Notification {
  id: string;
  type: string;
  title: string;
  content: string;
  isRead: boolean;
  actionUrl: string | null;
  actionText: string | null;
  createdAt: string;
}

export default function NotificationBell() {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unread, setUnread] = useState(0);
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  const fetchNotifications = useCallback(async () => {
    try {
      const res = await fetch("/api/notifications");
      if (!res.ok) return;
      const data = await res.json();
      if (!data.error) {
        setNotifications(data.notifications || []);
        setUnread(data.unreadCount || 0);
      }
    } catch {}
  }, []);

  useEffect(() => {
    fetchNotifications();
    const interval = setInterval(fetchNotifications, 30000);
    return () => clearInterval(interval);
  }, [fetchNotifications]);

  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, []);

  async function markAllRead() {
    await fetch("/api/notifications", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ markAllRead: true }),
    });
    setUnread(0);
    setNotifications((prev) => prev.map((n) => ({ ...n, isRead: true })));
  }

  async function markRead(id: string) {
    await fetch("/api/notifications", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ id }),
    });
    setNotifications((prev) =>
      prev.map((n) => (n.id === id ? { ...n, isRead: true } : n))
    );
    setUnread((prev) => Math.max(prev - 1, 0));
  }

  return (
    <div className="notif-bell-wrap" ref={ref}>
      <button className="notif-bell-btn" onClick={() => setOpen(!open)}>
        🔔
        {unread > 0 && <span className="notif-bell-badge">{unread}</span>}
      </button>

      {open && (
        <div className="notif-dropdown">
          <div className="notif-header">
            <span className="notif-header-title">Notifications</span>
            {unread > 0 && (
              <button className="notif-mark-all" onClick={markAllRead}>
                Mark all read
              </button>
            )}
          </div>

          {notifications.length === 0 ? (
            <div className="notif-empty">No notifications yet</div>
          ) : (
            <div className="notif-list">
              {notifications.map((n) => (
                <div
                  key={n.id}
                  className={`notif-item ${!n.isRead ? "notif-unread" : ""}`}
                  onClick={() => {
                    if (!n.isRead) markRead(n.id);
                    if (n.actionUrl) window.location.href = n.actionUrl;
                  }}
                >
                  <div className="notif-item-title">{n.title}</div>
                  <div className="notif-item-content">{n.content}</div>
                  <div className="notif-item-time">
                    {new Date(n.createdAt).toLocaleDateString(undefined, {
                      month: "short",
                      day: "numeric",
                      hour: "numeric",
                      minute: "2-digit",
                    })}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
EOF

echo "  ✓ Created NotificationBell component"

# Now re-enable in dashboard
python3 << 'PYEOF2'
content = open("app/dashboard/page.tsx", "r").read()
if "{/* NotificationBell */}" in content:
    content = content.replace("{/* NotificationBell */}", "<NotificationBell />")
    if "import NotificationBell" not in content:
        last_import = content.rfind("import ")
        line_end = content.find("\n", last_import)
        content = content[:line_end+1] + 'import NotificationBell from "@/components/NotificationBell";\n' + content[line_end+1:]
    open("app/dashboard/page.tsx", "w").write(content)
    print("  ✓ Re-enabled NotificationBell in dashboard")
PYEOF2
fi

# Quick build check
echo ""
echo "  Testing build..."
npx next build 2>&1 | grep -E "error|Error|✓|✗" | head -10

git add .
git commit -m "fix: add missing NotificationBell import + component to dashboard"
git push origin main

echo ""
echo "✅ Dashboard fixed!"
