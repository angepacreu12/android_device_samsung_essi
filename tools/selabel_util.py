# SPDX-FileCopyrightText: 2026 dxjsk
# SPDX-License-Identifier: Apache-2.0

"""Shared helpers: file_contexts lookups through libselinux, and `ls -laRZ` parsing."""
import ctypes
import os
import re
import stat
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

SELABEL_CTX_FILE = 0
SELABEL_OPT_PATH = 3

MODE = {"-": stat.S_IFREG, "d": stat.S_IFDIR, "l": stat.S_IFLNK, "c": stat.S_IFCHR,
        "b": stat.S_IFBLK, "s": stat.S_IFSOCK, "p": stat.S_IFIFO}


class _Opt(ctypes.Structure):
    _fields_ = [("type", ctypes.c_int), ("value", ctypes.c_char_p)]


class FileContexts:
    """matchpathcon-style lookups using the real libselinux (selabel_open/selabel_lookup), so precedence
    between overlapping regexes is the library's, not ours."""

    def __init__(self, sources, fc_sort=None):
        """sources: list of file_contexts paths, in the order the platform concatenates them
        (plat, system_ext, product, vendor, odm).  Comments are stripped.  If fc_sort (path to
        system/sepolicy/tests/fc_sort.py) is given, the vendor part is sorted like the build does."""
        lines = []
        for s in sources:
            if not os.path.exists(s):
                continue
            for l in open(s, errors="replace"):
                l = l.split("#")[0].rstrip()
                if l.strip():
                    lines.append(l)
        self.path = tempfile.mktemp(prefix="file_contexts.")
        with open(self.path, "w") as f:
            f.write("\n".join(lines) + "\n")
        if fc_sort and os.path.exists(fc_sort):
            sorted_path = self.path + ".sorted"
            subprocess.run([sys.executable, fc_sort, "-i", self.path, "-o", sorted_path], check=True)
            self.path = sorted_path
        self.lib = ctypes.CDLL("libselinux.so.1", use_errno=True)
        self.lib.selabel_open.restype = ctypes.c_void_p
        self.lib.selabel_lookup.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_char_p), ctypes.c_char_p, ctypes.c_int]
        opt = _Opt(SELABEL_OPT_PATH, self.path.encode())
        self.h = self.lib.selabel_open(SELABEL_CTX_FILE, ctypes.byref(opt), 1)
        if not self.h:
            raise RuntimeError("selabel_open failed (errno %d) on %s" % (ctypes.get_errno(), self.path))
        self.n = len(lines)

    def lookup(self, path, mode_char="-"):
        con = ctypes.c_char_p()
        rc = self.lib.selabel_lookup(self.h, ctypes.byref(con), path.encode(), MODE.get(mode_char, 0))
        if rc != 0:
            return None
        return con.value.decode()

    def type_of(self, path, mode_char="-"):
        c = self.lookup(path, mode_char)
        return c.split(":")[2] if c else None


def parse_ls_z(path):
    """Yield (fullpath, mode_char, type, name) for every entry of an `ls -laRZ` dump."""
    cur = None
    for line in open(path, errors="replace"):
        line = line.rstrip("\n")
        if line.endswith(":") and line.startswith("/"):
            cur = line[:-1]
            continue
        if not line or line.startswith("total ") or cur is None:
            continue
        parts = line.split()
        if len(parts) < 7:
            continue
        mode = parts[0][0]
        label = parts[4]
        if not label.startswith("u:"):
            continue
        # perms links user group label size day month year|time name...  (name may contain spaces)
        m = re.match(r"^(?:\S+\s+){9}(.*)$", line)
        name = m.group(1) if m else parts[-1]
        if mode == "l" and " -> " in name:
            name = name.split(" -> ")[0]
        if name in (".", ".."):
            if name == ".":
                yield cur, mode, label.split(":")[2], "."
            continue
        yield os.path.join(cur, name), mode, label.split(":")[2], name
