"""构建仓 Git 传输失败时，以 GitHub Git Data API 推送已提交的差异。

只允许 Aegink/leaflow-build；要求远端分支与本地父提交一致，不强推、不改变可见性。
运行前需用户授权构建窗口；主还原仓禁止调用此工具推送。
"""
import base64
import json
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "github-build"
REPO = "Aegink/leaflow-build"


def git(*args) -> str:
    return subprocess.check_output(["git", "-C", str(BUILD), *args]).decode("utf-8").strip()


def api(endpoint, payload=None):
    command = ["gh", "api", f"repos/{REPO}/{endpoint}"]
    if payload is not None:
        command += ["--method", "POST", "--input", "-"]
    for attempt in range(3):
        result = subprocess.run(command, input=json.dumps(payload).encode() if payload else None,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode == 0:
            return json.loads(result.stdout)
        error = result.stderr.decode("utf-8", errors="replace")
        transient = any(fragment in error.lower() for fragment in (
            "eof", "timeout", "connection reset", "goaway", "502", "503", "504"))
        if not transient or attempt == 2:
            raise RuntimeError(f"构建API调用失败：{endpoint}；{error.strip()}")
        print(f"构建API暂时中断，重试 {attempt + 1}/2：{endpoint}", flush=True)
        time.sleep(attempt + 1)


def main():
    if git("remote", "get-url", "origin") != f"https://github.com/{REPO}.git":
        raise RuntimeError("构建仓远端不匹配，拒绝推送")
    parent = git("rev-parse", "HEAD^")
    remote = api("git/ref/heads/main")["object"]["sha"]
    if parent != remote:
        raise RuntimeError("远端已变化或本地有多笔未推提交，需先核对差异")
    tree = []
    for line in git("diff", "--name-status", "HEAD^", "HEAD").splitlines():
        status, path = line.split("\t", 1)
        if not path.startswith(("src/", "tools/", ".github/")) and path not in ("project.yml", "README.md"):
            raise RuntimeError(f"不允许上传该路径：{path}")
        if status == "D":
            tree.append(dict(path=path, mode="100644", type="blob", sha=None))
            continue
        if status not in ("A", "M"):
            raise RuntimeError(f"暂不处理此变更类型：{status}")
        content = subprocess.check_output(["git", "-C", str(BUILD), "show", f"HEAD:{path}"])
        blob = api("git/blobs", dict(content=base64.b64encode(content).decode(), encoding="base64"))
        tree.append(dict(path=path, mode="100644", type="blob", sha=blob["sha"]))
        print(f"已上传构建源码：{path}", flush=True)
    base = api(f"git/commits/{remote}")["tree"]["sha"]
    new_tree = api("git/trees", dict(base_tree=base, tree=tree))["sha"]
    commit = api("git/commits", dict(message=git("log", "-1", "--format=%B"),
                 tree=new_tree, parents=[remote]))["sha"]
    if api("git/ref/heads/main")["object"]["sha"] != remote:
        raise RuntimeError("上传期间远端变化，拒绝更新分支")
    print(f"API_COMMIT={commit}")
    print("快照准备完成；请在授权公开窗口更新 refs/heads/main 后等待构建。")


if __name__ == "__main__":
    main()
