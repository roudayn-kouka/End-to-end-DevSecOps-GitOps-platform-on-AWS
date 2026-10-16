"""Renders docs/images/skyforge-architecture.gif (animated architecture diagram).

    pip install pillow
    python docs/images/make_architecture_gif.py

Animation: the 10 Jenkins stages light up one after another while packets flow along
every connection and the Grafana panel streams metrics.
"""

import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).with_name("skyforge-architecture.gif")

S = 2  # supersampling factor (drawn at 2x, downscaled for anti-aliasing)
W, H = 900, 1210
FRAMES = 40
STEP_FRAMES = 4  # frames per pipeline stage highlight
FRAME_MS = 140

BG_TOP = (14, 20, 44)
BG_BOTTOM = (46, 18, 30)
CARD = (43, 50, 71)
CARD_BORDER = (78, 88, 116)
ICON_BG = (30, 35, 52)
TEXT = (240, 242, 248)
MUTED = (150, 158, 180)
ORANGE = (245, 135, 58)
BLUE = (88, 140, 255)
GREEN = (46, 139, 87)
LINE = (190, 196, 214)
CLUSTER = (26, 34, 64)
CLUSTER_BORDER = (98, 118, 190)


# ------------------------------------------------------------------ fonts
def _font(candidates, size):
    for path in candidates:
        try:
            return ImageFont.truetype(path, size * S)
        except OSError:
            continue
    sys.exit(f"None of these fonts were found: {candidates}")


REGULAR = ["C:/Windows/Fonts/segoeui.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]
BOLD = ["C:/Windows/Fonts/segoeuib.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]
EMOJI = ["C:/Windows/Fonts/seguiemj.ttf", "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"]

F_TITLE = _font(BOLD, 26)
F_SUB = _font(REGULAR, 12)
F_CARD = _font(BOLD, 13)
F_SMALL = _font(REGULAR, 10)
F_NUM = _font(BOLD, 10)
F_LABEL = _font(BOLD, 12)
F_STAT = _font(BOLD, 15)
F_ICON = _font(EMOJI, 22)
F_ICON_SMALL = _font(EMOJI, 16)


def s(*values):
    return [v * S for v in values]


# ------------------------------------------------------------------ primitives
def card(d, x, y, w, h, title, sub, icon, num=None, active=False, done=False):
    border = ORANGE if active else CARD_BORDER
    d.rounded_rectangle(s(x, y, x + w, y + h), radius=12 * S, fill=CARD, outline=border,
                        width=(3 if active else 1) * S)
    # icon tile
    ix, iy, isz = x + w / 2 - 22, y + 10, 44
    d.rounded_rectangle(s(ix, iy, ix + isz, iy + isz), radius=9 * S, fill=ICON_BG)
    d.text(s(ix + isz / 2, iy + isz / 2 + 1), icon, font=F_ICON, anchor="mm", embedded_color=True)
    d.text(s(x + w / 2, y + h - 30), title, font=F_CARD, fill=TEXT, anchor="mm")
    d.text(s(x + w / 2, y + h - 13), sub, font=F_SMALL, fill=MUTED, anchor="mm")
    if num is not None:
        d.text(s(x + 9, y + 8), str(num), font=F_NUM, fill=ORANGE if active else MUTED)
    if done:  # small green check badge
        cx, cy = x + w - 14, y + 14
        d.ellipse(s(cx - 7, cy - 7, cx + 7, cy + 7), fill=GREEN)
        d.line(s(cx - 3.5, cy, cx - 1, cy + 3, cx + 4, cy - 3), fill=TEXT, width=2 * S)


def glow_dot(d, x, y, r=4, color=ORANGE):
    for k, alpha in ((2.4, 45), (1.7, 90)):
        rr = r * k
        d.ellipse(s(x - rr, y - rr, x + rr, y + rr), fill=color + (alpha,))
    d.ellipse(s(x - r, y - r, x + r, y + r), fill=(255, 214, 170))


def arrow(d, points, dashed=False, head=True, color=LINE):
    pts = [tuple(v * S for v in p) for p in points]
    for (x1, y1), (x2, y2) in zip(pts, pts[1:], strict=False):
        if dashed:
            length = math.dist((x1, y1), (x2, y2))
            n = max(int(length / (8 * S)), 1)
            for i in range(0, n, 2):
                a, b = i / n, min((i + 1) / n, 1)
                d.line([(x1 + (x2 - x1) * a, y1 + (y2 - y1) * a), (x1 + (x2 - x1) * b, y1 + (y2 - y1) * b)],
                       fill=color, width=2 * S)
        else:
            d.line([(x1, y1), (x2, y2)], fill=color, width=2 * S)
    if head:
        (x1, y1), (x2, y2) = pts[-2], pts[-1]
        ang = math.atan2(y2 - y1, x2 - x1)
        size = 8 * S
        left = (x2 - size * math.cos(ang - 0.45), y2 - size * math.sin(ang - 0.45))
        right = (x2 - size * math.cos(ang + 0.45), y2 - size * math.sin(ang + 0.45))
        d.polygon([(x2, y2), left, right], fill=color)


def point_on(points, t):
    """Point at fraction t (0..1) of a polyline's length."""
    segments = list(zip(points, points[1:], strict=False))
    lengths = [math.dist(a, b) for a, b in segments]
    target = t * sum(lengths)
    for (a, b), length in zip(segments, lengths, strict=False):
        if target <= length and length:
            r = target / length
            return a[0] + (b[0] - a[0]) * r, a[1] + (b[1] - a[1]) * r
        target -= length
    return points[-1]


# ------------------------------------------------------------------ layout
TOP = [  # x, y, w, h, title, sub, icon
    (40, 100, 160, 84, "Developer", "git push", "💻"),
    (250, 100, 170, 84, "GitHub", "app · IaC · GitOps", "🐙"),
    (470, 100, 180, 84, "Jenkins", "JCasC · private subnet", "🤵"),
    (700, 100, 165, 84, "Terraform + Ansible", "VPC · ALB · EC2 · SSM", "🏗"),
]

CW, CH = 146, 100
COLS = [45, 212, 379, 546, 713]
ROW1, ROW2 = 248, 378
STAGES = [  # (x, y, title, sub, icon) in execution order
    (COLS[0], ROW1, "Checkout", "git · [skip ci] guard", "📥"),
    (COLS[1], ROW1, "Secrets scan", "gitleaks", "🔑"),
    (COLS[2], ROW1, "Dockerfile lint", "hadolint", "📄"),
    (COLS[3], ROW1, "Unit tests", "ruff · pytest 100%", "🧪"),
    (COLS[4], ROW1, "SonarQube", "quality gate", "📈"),
    (COLS[4], ROW2, "Build image", "multi-stage · non-root", "🐳"),
    (COLS[3], ROW2, "Trivy gate", "block CRITICAL", "🛡"),
    (COLS[2], ROW2, "Push image", "sha-build tag", "📤"),
    (COLS[1], ROW2, "Cosign sign", "image digest", "🔏"),
    (COLS[0], ROW2, "GitOps bump", "values-dev.yaml", "🔀"),
]

MID = [
    (40, 528, 210, 84, "Helm values in Git", "dev auto · prod on approval", "📝"),
    (270, 528, 210, 84, "ArgoCD", "app of apps · self-heal", "🔄"),
    (520, 528, 180, 84, "Docker Hub", "skyforge-tasks:<sha>", "🐳"),
    (722, 528, 143, 84, "Slack", "Alertmanager", "💬"),
]
USERS = (40, 652, 150, 84, "End users", "HTTPS", "🌍")
ALB = (215, 652, 150, 84, "AWS ALB", "ACM TLS · :443", "⚖")
GRAFANA = (540, 645, 325, 150)

CLUSTER_BOX = (30, 830, 870, 1180)


def edges():
    """Every connection: (points, dashed)."""
    c = lambda i: (STAGES[i][0] + CW / 2, STAGES[i][1] + CH / 2)  # noqa: E731
    e = [
        ([(200, 142), (250, 142)], False),
        ([(420, 142), (470, 142)], False),
        ([(700, 142), (650, 142)], False),
        ([(630, 184), (630, 214), (118, 214), (118, ROW1)], False),
    ]
    for i in range(4):  # row 1 left -> right
        e.append(([(STAGES[i][0] + CW, c(i)[1]), (STAGES[i + 1][0], c(i)[1])], False))
    e.append(([(c(4)[0] + 45, ROW1 + CH), (c(4)[0] + 45, ROW2)], False))
    for i in range(5, 9):  # row 2 right -> left
        e.append(([(STAGES[i][0], c(i)[1]), (STAGES[i + 1][0] + CW, c(i)[1])], False))
    e += [
        ([(c(7)[0] + 48, ROW2 + CH), (c(7)[0] + 48, 505), (610, 505), (610, 528)], False),   # push -> Docker Hub
        ([(c(9)[0] + 52, ROW2 + CH), (c(9)[0] + 52, 528)], False),                           # GitOps -> values
        ([(250, 570), (270, 570)], False),                                         # values -> ArgoCD
        ([(460, 612), (460, 830)], False),                                         # ArgoCD sync
        ([(540, 612), (540, 630), (500, 630), (500, 900)], True),                  # pull image
        ([(190, 694), (215, 694)], False),                                         # users -> ALB
        ([(345, 736), (345, 892), (120, 892), (120, 905)], False),                 # ALB -> Traefik
        ([(702, 830), (702, 795)], True),                                          # scrape metrics
        ([(793, 645), (793, 612)], True),                                          # alerts -> Slack
    ]
    return e


EDGES = edges()


# ------------------------------------------------------------------ static layer
def background():
    img = Image.new("RGBA", (W * S, H * S))
    d = ImageDraw.Draw(img)
    bands = 24  # few flat bands: keeps the GIF palette clean (no banding/dither noise)
    for i in range(bands):
        r = i / (bands - 1)
        col = tuple(int(BG_TOP[k] + (BG_BOTTOM[k] - BG_TOP[k]) * r) for k in range(3))
        y0, y1 = H * S * i / bands, H * S * (i + 1) / bands
        d.rectangle([0, y0, W * S, y1], fill=col)
    return img


def draw_static(d):
    d.text(s(36, 26), "SkyForge · DevSecOps & GitOps on AWS", font=F_TITLE, fill=TEXT)
    d.text(s(38, 66), "Terraform · Ansible · Jenkins · Docker · Trivy · Cosign · Kubernetes · Helm · "
                      "ArgoCD · Prometheus/Grafana", font=F_SUB, fill=MUTED)
    # author badge
    d.rounded_rectangle(s(690, 22, 866, 58), radius=18 * S, fill=(250, 250, 252),
                        outline=ORANGE, width=2 * S)
    d.ellipse(s(698, 27, 724, 53), fill=ORANGE)
    d.text(s(711, 40), "RK", font=F_NUM, fill=(255, 255, 255), anchor="mm")
    d.text(s(795, 40), "Roudayna Kouka", font=F_LABEL, fill=(25, 30, 50), anchor="mm")

    # CI frame
    d.rounded_rectangle(s(30, 228, 870, 492), radius=6 * S, outline=(120, 128, 150), width=S)
    label = "Continuous Integration · Jenkins shared library · pinned tool containers"
    lw = d.textlength(label, font=F_LABEL) / S
    d.rectangle(s(450 - lw / 2 - 8, 220, 450 + lw / 2 + 8, 236), fill=(20, 24, 48))
    d.text(s(450, 228), label, font=F_LABEL, fill=ORANGE, anchor="mm")

    # Kubernetes cluster
    x0, y0, x1, y1 = CLUSTER_BOX
    d.rounded_rectangle(s(x0, y0, x1, y1), radius=16 * S, fill=CLUSTER, outline=CLUSTER_BORDER, width=2 * S)
    d.ellipse(s(48, 846, 84, 882), fill=(50, 108, 229))
    d.text(s(66, 864), "☸", font=F_ICON_SMALL, anchor="mm", embedded_color=True, fill=TEXT)
    d.text(s(92, 849), "Kubernetes 1.31", font=F_CARD, fill=TEXT)
    d.text(s(92, 868), "kubeadm · Calico", font=F_SMALL, fill=MUTED)

    # Traefik
    card(d, 50, 905, 140, 92, "Traefik", "ingress · :30080", "🚦")
    d.text(s(120, 1020), "HPA · PDB · probes", font=F_SMALL, fill=MUTED, anchor="mm")
    d.text(s(120, 1036), "read-only FS · non-root", font=F_SMALL, fill=MUTED, anchor="mm")

    for nx, name, pods in ((275, "skyforge-dev", 1), (470, "skyforge-prod", 2)):
        d.rounded_rectangle(s(nx, 900, nx + 180, 1160), radius=12 * S, outline=CARD_BORDER, width=S,
                            fill=(34, 42, 74))
        d.text(s(nx + 90, 918), name, font=F_CARD, fill=TEXT, anchor="mm")
        d.text(s(nx + 90, 936), "namespace · default-deny", font=F_SMALL, fill=MUTED, anchor="mm")
        xs = [nx + 90] if pods == 1 else [nx + 55, nx + 125]
        for px in xs:
            hexagon(d, px, 985, 24, BLUE)
            d.text(s(px, 985), "📦", font=F_ICON_SMALL, anchor="mm", embedded_color=True)
        d.text(s(nx + 90, 1022), "api pods (gunicorn)", font=F_SMALL, fill=MUTED, anchor="mm")
        hexagon(d, nx + 90, 1075, 24, (60, 90, 140))
        d.text(s(nx + 90, 1075), "🐘", font=F_ICON_SMALL, anchor="mm", embedded_color=True)
        d.text(s(nx + 90, 1112), "PostgreSQL StatefulSet", font=F_SMALL, fill=MUTED, anchor="mm")
        d.text(s(nx + 90, 1128), "SealedSecret credentials", font=F_SMALL, fill=MUTED, anchor="mm")

    d.rounded_rectangle(s(670, 900, 852, 1160), radius=12 * S, outline=CARD_BORDER, width=S, fill=(34, 42, 74))
    d.text(s(761, 918), "Platform add-ons", font=F_CARD, fill=TEXT, anchor="mm")
    for i, (icon, name) in enumerate((("🔒", "Sealed Secrets"), ("📊", "metrics-server"),
                                      ("💾", "local-path storage"), ("🔥", "kube-prometheus"),
                                      ("🚦", "Traefik"))):
        y = 950 + i * 41
        d.text(s(690, y), icon, font=F_ICON_SMALL, anchor="lm", embedded_color=True)
        d.text(s(718, y), name, font=F_SMALL, fill=TEXT, anchor="lm")

    for x, y, w, h, title, sub, icon in TOP + MID + [USERS, ALB]:
        card(d, x, y, w, h, title, sub, icon)

    for pts, dashed in EDGES:
        arrow(d, pts, dashed=dashed)
    d.text(s(466, 812), "sync", font=F_SMALL, fill=ORANGE, anchor="lm")
    d.text(s(506, 812), "pull signed image", font=F_SMALL, fill=MUTED, anchor="lm")
    d.text(s(708, 812), "scrape /metrics", font=F_SMALL, fill=ORANGE, anchor="lm")


def hexagon(d, cx, cy, r, color):
    pts = [(cx + r * math.cos(math.radians(60 * k - 30)), cy + r * math.sin(math.radians(60 * k - 30)))
           for k in range(6)]
    d.polygon([(px * S, py * S) for px, py in pts], fill=color)


# ------------------------------------------------------------------ dynamic layer
def draw_grafana(d, frame):
    x, y, w, h = GRAFANA
    d.rounded_rectangle(s(x, y, x + w, y + h), radius=10 * S, fill=(18, 20, 32), outline=CARD_BORDER, width=S)
    d.text(s(x + 14, y + 16), "🔥", font=F_ICON_SMALL, anchor="lm", embedded_color=True)
    d.text(s(x + 40, y + 12), "Prometheus + Grafana", font=F_LABEL, fill=TEXT, anchor="lm")
    d.text(s(x + 40, y + 27), "SkyForge dashboard · alerts → Slack", font=F_SMALL, fill=MUTED, anchor="lm")
    phase = 2 * math.pi * frame / FRAMES
    stats = (("RPS", f"{42 + 6 * math.sin(phase):.1f}", GREEN),
             ("p95", f"{118 + 14 * math.sin(phase * 2):.0f}ms", GREEN),
             ("5xx", f"{0.2 + 0.1 * abs(math.sin(phase)):.2f}%", (40, 46, 66)))
    for i, (name, value, col) in enumerate(stats):
        bx = x + 14 + i * 102
        d.rounded_rectangle(s(bx, y + 42, bx + 94, y + 78), radius=5 * S, fill=col)
        d.text(s(bx + 47, y + 53), name, font=F_SMALL, fill=(210, 230, 220), anchor="mm")
        d.text(s(bx + 47, y + 68), value, font=F_STAT, fill=TEXT, anchor="mm")
    for color, amp, freq, off in ((ORANGE, 14, 2.0, 0.0), (BLUE, 9, 3.0, 1.3)):
        pts = []
        for i in range(60):
            px = x + 14 + i * (w - 28) / 59
            py = y + 118 + amp * math.sin(freq * i / 59 * 2 * math.pi + phase * 2 + off) \
                + 4 * math.sin(i * 0.9 + phase * 3)
            pts.append((px * S, py * S))
        d.line(pts, fill=color, width=2 * S, joint="curve")


def render_frame(static, frame):
    img = static.copy()
    d = ImageDraw.Draw(img, "RGBA")
    active = (frame // STEP_FRAMES) % len(STAGES)
    for i, (x, y, title, sub, icon) in enumerate(STAGES):
        card(d, x, y, CW, CH, title, sub, icon, num=i + 1, active=i == active, done=i < active)
    # connection endpoints
    for pts, _ in EDGES:
        glow_dot(d, *pts[0], r=2.5)
    # packets travelling along every connection
    t = (frame % 10) / 10
    for pts, _ in EDGES:
        glow_dot(d, *point_on(pts, t + 0.05), r=3.5)
    draw_grafana(d, frame)
    return img.resize((W, H), Image.LANCZOS).convert("RGB")


def main():
    static = background()
    draw_static(ImageDraw.Draw(static, "RGBA"))
    frames = [render_frame(static, f) for f in range(FRAMES)]
    palette = frames[0].quantize(colors=255, method=Image.Quantize.MEDIANCUT)
    gif = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
    gif[0].save(OUT, save_all=True, append_images=gif[1:], duration=FRAME_MS, loop=0, optimize=True)
    frames[FRAMES // 2].save(OUT.with_suffix(".png"))
    print(f"wrote {OUT} ({OUT.stat().st_size / 1024:.0f} KB, {FRAMES} frames)")


if __name__ == "__main__":
    main()
