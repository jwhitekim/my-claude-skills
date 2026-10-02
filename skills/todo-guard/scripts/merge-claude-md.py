# -*- coding: utf-8 -*-
"""프로젝트 CLAUDE.md 에 투두가드 운영 규칙을 넣거나 최신 판으로 바꾼다.

왜 필요한가
  전에는 「todo-guard」 글자가 있으면 「이미 병합됨」으로 보고 손대지 않았다.
  운영 방식이 바뀌어도(모델이 직접 등록 → 훅이 등록) 세팅한 프로젝트에는
  옛 규칙이 그대로 남아, 모델이 옛 방식대로 TODO.md 를 열고 고쳤다.

하는 일
  「# 작업 관리 규칙 (todo-guard)」 대목이 있으면 판 표시를 보고
    - 최신이면 그대로 둔다
    - 옛 판이면 그 대목만 바꾼다 (다음 「# 」 제목 앞까지). 바꾸기 전에 백업한다
  없으면 파일 끝에 덧붙인다.
  사용자가 쓴 나머지는 건드리지 않는다. 줄끝(CRLF · LF)도 원래대로 둔다.

사용: python merge-claude-md.py <CLAUDE.md 경로> <규칙 원본 경로>
"""
import io
import os
import sys
import time

try:
    sys.stdout.reconfigure(encoding="utf-8")
except (AttributeError, ValueError):
    pass

HEAD = "# 작업 관리 규칙 (todo-guard)"
MARK = "todo-guard 운영 규칙 v6"


def main(path, src):
    block = io.open(src, encoding="utf-8").read().replace("\r\n", "\n").rstrip() + "\n"
    raw = b""
    if os.path.exists(path):
        raw = open(path, "rb").read()
    crlf = b"\r\n" in raw
    text = raw.decode("utf-8", errors="replace").replace("\r\n", "\n")

    if HEAD in text:
        if MARK in text:
            print("  CLAUDE.md 운영 규칙 최신 (v6)")
            return 0
        i = text.find(HEAD)
        j = text.find("\n# ", i + len(HEAD))
        tail = text[j + 1:] if j >= 0 else ""
        new = text[:i] + block + ("\n" + tail if tail else "")
        # 백업은 프로젝트 맨 위를 어지르지 않게 .claude/ 안에 둔다
        bdir = os.path.join(os.path.dirname(os.path.abspath(path)), ".claude")
        try:
            os.makedirs(bdir)
        except OSError:
            pass
        backup = os.path.join(bdir, "CLAUDE.md.todo-guard-백업_" + time.strftime("%Y%m%d-%H%M%S"))
        open(backup, "wb").write(raw)
        msg = "  CLAUDE.md 운영 규칙을 v6 로 바꿈 (백업 .claude/%s)" % os.path.basename(backup)
    elif any(line.startswith("# 작업 관리 규칙") for line in text.split("\n")):
        print("  [알림] CLAUDE.md 에 옛 세대의 「작업 관리 규칙」 대목이 있습니다. 덮어쓰지 않았습니다.")
        print("    규칙이 두 벌이 되지 않도록, 옛 대목을 지우고 다시 세팅하십시오.")
        return 0
    else:
        new = (text.rstrip("\n") + "\n\n" if text.strip() else "") + block
        msg = "  CLAUDE.md 에 운영 규칙 병합 (v6)"

    out = new.replace("\n", "\r\n") if crlf else new
    open(path, "wb").write(out.encode("utf-8"))
    print(msg)
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__.strip())
        sys.exit(2)
    sys.exit(main(sys.argv[1], sys.argv[2]))
