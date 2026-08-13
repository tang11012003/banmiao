import os, sys, io, random
import requests

try:
    from PIL import Image, ImageDraw
    HAVE_PIL = True
except Exception:
    HAVE_PIL = False

BASE = "http://localhost:8080"
# 每次运行使用随机手机号 -> 新用户 -> 新配额，避免 free 配额累计耗尽导致重复运行失败
PHONE = "13" + "".join(random.choice("0123456789") for _ in range(9))


def p(name, r):
    try:
        body = r.json()
    except Exception:
        body = r.text
    print(f"[{name}] {r.status_code} {str(body)[:260]}")
    return body


def make_dummy_image(path):
    """生成一张有效的试卷图片（带文字线条与红色批改标记），供 OCR 模拟器识别。

    说明：OCR 服务是模拟器，根据图像特征（红色区域比例、面积）决定题目数量与对错分布。
    画一些红色矩形可推高‘错题比例’，从而验证三档聚合（urgent/attention/keep）。
    """
    if HAVE_PIL:
        W, H = 900, 1200
        img = Image.new("RGB", (W, H), (255, 255, 255))
        d = ImageDraw.Draw(img)
        # 文字线条（黑色）
        random.seed(7)
        for _ in range(120):
            y = random.randint(20, H - 20)
            x0 = random.randint(20, W - 200)
            d.line([(x0, y), (x0 + random.randint(80, 180), y)], fill=(20, 20, 20), width=2)
        # 红色批改标记（叉/圈），推高 red_ratio → 更多错题
        for _ in range(18):
            x = random.randint(60, W - 80)
            y = random.randint(60, H - 60)
            d.rectangle([x, y, x + 26, y + 26], outline=(220, 0, 0), width=4)
        img.save(path, "PNG")
        return
    # 无 PIL 兜底：写一张极简有效 PNG（1x1 白点），OCR 仍会产出 5~10 道模拟题
    png_b64 = ("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")
    with open(path, "wb") as f:
        import base64
        f.write(base64.b64decode(png_b64))


def login(phone):
    """发送验证码 -> 登录，返回 token。"""
    r = p("send-sms", requests.post(f"{BASE}/api/auth/send-sms", json={"phone": phone}))
    dev_code = r.get("data", {}).get("dev_code")
    if not dev_code:
        raise SystemExit("未拿到验证码")
    r = p("login", requests.post(f"{BASE}/api/auth/login", json={"phone": phone, "code": dev_code}))
    token = r.get("data", {}).get("token")
    if not token:
        raise SystemExit("登录失败，未拿到 token")
    return token


print("==== 陪读社区 端到端集成测试 ====")

# 1. 首次登录（此时角色为 unverified）
token = login(PHONE)
H = {"Authorization": f"Bearer {token}"}

# 2. 生成邀请码
r = p("invite_generate", requests.post(f"{BASE}/api/invites/generate", headers=H))
code = r.get("data", {}).get("code")
assert code, "未生成邀请码"

# 3. 使用邀请码 -> 自动完成家长认证（DB role=parent）
p("invite_use", requests.post(f"{BASE}/api/invites/use", headers=H, json={"code": code}))

# 4. 关键：邀请码改写了 DB 中的 role，但旧 token 已固化 role=unverified，
#    需重新登录获取携带 role=parent 的新 token，否则 /papers/upload 会被 VerifiedMiddleware 拦截。
token = login(PHONE)
H = {"Authorization": f"Bearer {token}"}

# 5. 认证状态应为 approved
r = p("verification_status", requests.get(f"{BASE}/api/users/verification/status", headers=H))
status = (r.get("data") or {}).get("status")
print("  认证状态:", status)
role_ok = (status == "approved")

# 6. 上传试卷（触发 OCR + 知识点聚合三档判定）
dummy = "/tmp/dummy_paper.png"
make_dummy_image(dummy)
with open(dummy, "rb") as f:
    r = p("paper_upload", requests.post(
        f"{BASE}/api/papers/upload", headers=H,
        files={"file": ("paper.png", f, "image/png")},
        data={"student_id": "1", "subject": "数学", "exam_name": "一模"}))
paper_id = (r.get("data") or {}).get("id")
if not paper_id:
    raise SystemExit("试卷上传失败，链路中断")

# 7. 获取分析报告
r = p("paper_report", requests.get(f"{BASE}/api/papers/{paper_id}/report", headers=H))
d = r.get("data", {})
items = d.get("items", [])
kp = d.get("kp_results", [])
print(f"  试卷题目数={len(items)} 知识点结果数={len(kp)}")
for x in kp[:8]:
    print(f"    KP {x.get('knowledge_name')}: kp_id={x.get('knowledge_point_id')} 错误率={x.get('error_rate')} 档={x.get('level')}")

# 8. 三档分布
r = p("tier", requests.get(f"{BASE}/api/papers/tier-distribution", headers=H))
print("  三档分布:", r.get("data"))

# 9. 得分率趋势
r = p("trend", requests.get(f"{BASE}/api/papers/trend", headers=H))
print("  趋势记录数:", len(r.get("data", [])))

# 10. 分享报告（应赠送奖励次数）
p("paper_share", requests.post(f"{BASE}/api/papers/{paper_id}/share?channel=wechat", headers=H))
r = p("quota", requests.get(f"{BASE}/api/users/quota", headers=H))
print("  当前配额:", r.get("data"))

# 11. 社区圈子上架后可供前端选择（公开接口）
p("circles", requests.get(f"{BASE}/api/community/circles"))

# 12. 单知识点历次错误率趋势（验证知识点种子灌库后 knowledge_point_id 可关联）
first_kp_id = next((x.get("knowledge_point_id") for x in kp if x.get("knowledge_point_id")), 0)
if first_kp_id:
    r = p("kp_trend", requests.get(f"{BASE}/api/papers/knowledge/{first_kp_id}/trend", headers=H))
    print("  知识点趋势记录数:", len(r.get("data", [])))
    kp_trend_ok = len(r.get("data", [])) >= 1
else:
    print("  [warn] 无 knowledge_point_id>0 的结果，跳过知识点趋势校验")
    kp_trend_ok = False

print("\n=== 集成测试结论 ===")
print("登录链路(含重新登录):", "OK" if token else "FAIL")
print("家长认证(邀请码):", "OK" if role_ok else "FAIL")
print("试卷上传+分析:", "OK" if paper_id else "FAIL")
print("知识点三档聚合:", f"{len(kp)} 条结果" + (" (>=1 视为链路打通)" if kp else " (0 条，需排查匹配)"))
print("知识点种子关联(kp_id>0):", "OK" if first_kp_id else "FAIL")
print("单知识点趋势:", "OK" if kp_trend_ok else "FAIL")
print("报告/趋势/分享/配额/圈子:", "OK" if (paper_id and r.get("data") is not None) else "FAIL")
