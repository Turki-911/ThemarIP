import re

with open('/Users/turki/Desktop/NBO Sandbox/Themar Card Managment/ThemarIP.Admin/style.css', 'r') as f:
    css = f.read()

# Replace root variables
new_root = """:root {
  --bg-main: #0B0E14;
  --bg-sidebar: rgba(15, 23, 42, 0.4);
  --bg-card: rgba(30, 41, 59, 0.5);
  --bg-card-hover: rgba(39, 53, 73, 0.7);
  --bg-input: rgba(15, 23, 42, 0.6);
  
  --border-color: rgba(255, 255, 255, 0.08);
  --border-active: #3B82F6;

  --text-main: #F8FAFC;
  --text-muted: #94A3B8;
  --text-dim: #64748B;

  --accent-blue: #3B82F6;
  --accent-emerald: #10B981;
  --accent-purple: #8B5CF6;
  --accent-indigo: #6366F1;
  --accent-amber: #F59E0B;
  --accent-rose: #F43F5E;

  --radius-sm: 8px;
  --radius-md: 16px;
  --radius-lg: 24px;
  
  --shadow-card: 0 8px 32px 0 rgba(0, 0, 0, 0.37);
  --shadow-glow: 0 0 25px rgba(59, 130, 246, 0.15);
  
  --glass-blur: blur(16px);
}"""

css = re.sub(r':root\s*\{[^}]*\}', new_root, css)

# Update typography
css = css.replace("font-family: 'Inter', -apple-system", "font-family: 'Outfit', 'Inter', -apple-system")

# Add glassmorphism to specific classes
css = css.replace(".sidebar {\n  width: 260px;\n  background-color: var(--bg-sidebar);", 
                  ".sidebar {\n  width: 260px;\n  background-color: var(--bg-sidebar);\n  backdrop-filter: var(--glass-blur);\n  -webkit-backdrop-filter: var(--glass-blur);")

css = css.replace(".kpi-card {\n  background-color: var(--bg-card);",
                  ".kpi-card {\n  background-color: var(--bg-card);\n  backdrop-filter: var(--glass-blur);\n  -webkit-backdrop-filter: var(--glass-blur);")

css = css.replace(".table-container-card {\n  background-color: var(--bg-card);",
                  ".table-container-card {\n  background-color: var(--bg-card);\n  backdrop-filter: var(--glass-blur);\n  -webkit-backdrop-filter: var(--glass-blur);")

css = css.replace(".modal-content {\n  background-color: var(--bg-card);",
                  ".modal-content {\n  background-color: var(--bg-card);\n  backdrop-filter: var(--glass-blur);\n  -webkit-backdrop-filter: var(--glass-blur);")

# Background gradient
css = css.replace("background-color: var(--bg-main);", 
                  "background: radial-gradient(circle at top left, #1a2333 0%, var(--bg-main) 40%, #06080a 100%);\n  background-attachment: fixed;")

with open('/Users/turki/Desktop/NBO Sandbox/Themar Card Managment/ThemarIP.Admin/style.css', 'w') as f:
    f.write(css)
