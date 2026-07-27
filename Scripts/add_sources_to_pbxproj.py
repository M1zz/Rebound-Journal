#!/usr/bin/env python3
"""Register Swift sources in the (non-synchronized) Xcode project.

This project uses objectVersion 56 groups, so new files are invisible to the
build until they appear in PBXFileReference / PBXBuildFile / PBXGroup /
PBXSourcesBuildPhase. Running this again with the same paths is a no-op.

    python3 Scripts/add_sources_to_pbxproj.py "Rebound Journal/Redesign/Foo.swift" ...

Paths are relative to the repository root and must live under the
"Rebound Journal" group.
"""

import hashlib
import re
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent / "Rebound Journal.xcodeproj" / "project.pbxproj"
ROOT_GROUP = "586F228A2A33861C004C7410"   # "Rebound Journal"
SOURCES_PHASE = "586F22842A33861C004C7410"
ROOT_DIR = "Rebound Journal"


def uid(seed):
    """Stable 24-hex-char object id, so reruns reuse the same identifiers."""
    return hashlib.sha1(seed.encode()).hexdigest()[:24].upper()


def definition_start(src, gid):
    """Index of `<gid> ... = {`, the object's definition.

    A bare `src.index(gid)` is wrong: an id appears in its parent's children
    list before it is defined, so searching from there lands on the *next*
    object's body.
    """
    match = re.search(r"^\t\t%s\b[^\n]*= \{" % gid, src, re.MULTILINE)
    if not match:
        raise KeyError("no definition for %s" % gid)
    return match.start()


def group_children(src, gid):
    """Return (children_body, span) for the group's `children = ( ... );`."""
    start = definition_start(src, gid)
    body = src.index("children = (", start) + len("children = (")
    end = src.index(");", body)
    return src[body:end], (body, end)


def find_child_group(src, parent_gid, name):
    children, _ = group_children(src, parent_gid)
    for cid, cname in re.findall(r"(\w{24}) /\* (.*?) \*/", children):
        if cname == name and re.search(
            r"%s /\* %s \*/ = \{\s*isa = PBXGroup;" % (cid, re.escape(name)), src
        ):
            return cid
    return None


def insert_into_group(src, gid, entry):
    children, (body, end) = group_children(src, gid)
    if entry.split(" ")[0] in children:
        return src
    indent = "\n\t\t\t\t"
    return src[:end] + indent + entry + src[end:]


def ensure_group(src, parent_gid, name, path_seed):
    existing = find_child_group(src, parent_gid, name)
    if existing:
        return src, existing
    gid = uid("group:" + path_seed)
    block = (
        "\t\t%s /* %s */ = {\n"
        "\t\t\tisa = PBXGroup;\n"
        "\t\t\tchildren = (\n"
        "\t\t\t);\n"
        "\t\t\tpath = %s;\n"
        '\t\t\tsourceTree = "<group>";\n'
        "\t\t};\n" % (gid, name, name)
    )
    marker = "/* Begin PBXGroup section */\n"
    src = src.replace(marker, marker + block, 1)
    src = insert_into_group(src, parent_gid, "%s /* %s */," % (gid, name))
    return src, gid


def add_file(src, rel_path):
    parts = Path(rel_path).parts
    assert parts[0] == ROOT_DIR, "expected a path under %r, got %r" % (ROOT_DIR, rel_path)
    name = parts[-1]

    gid = ROOT_GROUP
    for depth, folder in enumerate(parts[1:-1], start=1):
        src, gid = ensure_group(src, gid, folder, "/".join(parts[: depth + 1]))

    file_ref = uid("fileref:" + rel_path)
    build_id = uid("buildfile:" + rel_path)

    if file_ref not in src:
        ref = (
            "\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = "
            'sourcecode.swift; path = %s; sourceTree = "<group>"; };\n' % (file_ref, name, name)
        )
        marker = "/* Begin PBXFileReference section */\n"
        src = src.replace(marker, marker + ref, 1)

    if build_id not in src:
        bf = "\t\t%s /* %s in Sources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };\n" % (
            build_id,
            name,
            file_ref,
            name,
        )
        marker = "/* Begin PBXBuildFile section */\n"
        src = src.replace(marker, marker + bf, 1)

    src = insert_into_group(src, gid, "%s /* %s */," % (file_ref, name))

    # A build phase lists `files = (...)`, not `children = (...)`.
    start = definition_start(src, SOURCES_PHASE)
    body = src.index("files = (", start) + len("files = (")
    end = src.index(");", body)
    if build_id not in src[body:end]:
        entry = "%s /* %s in Sources */," % (build_id, name)
        src = src[:end] + "\n\t\t\t\t" + entry + src[end:]
    return src


def main(paths):
    src = PROJECT.read_text()
    for p in paths:
        src = add_file(src, p)
        print("registered", p)
    PROJECT.write_text(src)


if __name__ == "__main__":
    main(sys.argv[1:])
