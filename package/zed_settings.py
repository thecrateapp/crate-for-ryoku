#!/usr/bin/env python3
"""Select a Zed theme in settings.json and put the old one back.

    zed_settings.py select  PATH THEME                 -> prints "mode<TAB>previous"
    zed_settings.py restore PATH THEME MODE PREVIOUS   -> prints "restored" or "kept"
    zed_settings.py current PATH                       -> prints the dark theme in effect

Zed's settings.json is JSONC: comments and trailing commas are allowed, and the
file is the user's. Every edit is a slice of the original text, so whatever is
not the theme value stays byte for byte. Modes:

    dark        theme was an object: its "dark" value was replaced
    added-dark  theme was an object without "dark": one was inserted
    string      theme was a single name (or another value): it was replaced
    added       there was no theme key: one was inserted at the top
    created     there was no settings.json: one was written

A file that does not parse is never written (exit 3 from the command line).
"""
import json
import os
import re
import sys

LITERAL = re.compile(r"[^\s,\]}/]+")


def _created(theme):
    return '{"theme": {"mode": "system", "light": "One Light", "dark": %s}}\n' % json.dumps(theme)


def _top_insert(theme):
    # a bare name: Zed's object form needs both "light" and "dark"
    return '"theme": %s' % json.dumps(theme)


def _dark_insert(theme):
    return '"dark": %s' % json.dumps(theme)


def _skip(text, i):
    """Index of the next character that is not whitespace or a comment."""
    n = len(text)
    while i < n:
        c = text[i]
        if c.isspace():
            i += 1
        elif text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j + 1
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            if j < 0:
                raise ValueError("unterminated comment")
            i = j + 2
        else:
            break
    return i


def _string_end(text, i):
    """End (exclusive) of the string literal that starts at text[i] == '"'."""
    i += 1
    n = len(text)
    while i < n:
        c = text[i]
        if c == "\\":
            i += 2
        elif c == '"':
            return i + 1
        else:
            i += 1
    raise ValueError("unterminated string")


def _value_end(text, i):
    if i >= len(text):
        raise ValueError("missing value")
    c = text[i]
    if c == '"':
        return _string_end(text, i)
    if c == "{":
        return _object(text, i)[1]
    if c == "[":
        i = _skip(text, i + 1)
        while True:
            if i >= len(text):
                raise ValueError("unterminated array")
            if text[i] == "]":
                return i + 1
            i = _skip(text, _value_end(text, i))
            if i < len(text) and text[i] == ",":
                i = _skip(text, i + 1)
            elif i >= len(text) or text[i] != "]":
                raise ValueError("expected , or ]")
    m = LITERAL.match(text, i)
    if not m:
        raise ValueError("unexpected %r" % c)
    return m.end()


def _object(text, i):
    """Members [(key, key_start, value_start, value_end)] of the object at text[i] == '{', and its end."""
    if i >= len(text) or text[i] != "{":
        raise ValueError("expected {")
    members = []
    i = _skip(text, i + 1)
    while True:
        if i >= len(text):
            raise ValueError("unterminated object")
        if text[i] == "}":
            return members, i + 1
        if text[i] != '"':
            raise ValueError("expected a key")
        kstart = i
        kend = _string_end(text, i)
        key = json.loads(text[i:kend])
        i = _skip(text, kend)
        if i >= len(text) or text[i] != ":":
            raise ValueError("expected :")
        vstart = _skip(text, i + 1)
        vend = _value_end(text, vstart)
        members.append((key, kstart, vstart, vend))
        i = _skip(text, vend)
        if i < len(text) and text[i] == ",":
            i = _skip(text, i + 1)
        elif i >= len(text) or text[i] != "}":
            raise ValueError("expected , or }")


def _root(text):
    start = _skip(text, 0)
    members, end = _object(text, start)
    if _skip(text, end) != len(text):
        raise ValueError("text after the settings object")
    return start, members


def _member(members, key):
    for m in members:
        if m[0] == key:
            return m
    return None


def _write(path, text):
    # through a symlink (a dotfiles repo, say) to the real file, keeping its mode
    path = os.path.realpath(path)
    tmp = path + ".crate-tmp"
    with open(tmp, "w") as f:
        f.write(text)
    if os.path.exists(path):
        os.chmod(tmp, os.stat(path).st_mode & 0o7777)
    os.replace(tmp, path)


def _without(text, members, index):
    """text with members[index] removed, with its comma, so the object stays valid."""
    _, ks, _, ve = members[index]
    if index + 1 < len(members):
        # the member, its comma and the one space an insertion puts after it;
        # a line left blank goes with its indentation and newline
        b = _skip(text, ve) + 1  # past the comma (comments between are skipped)
        if text[b:b + 1] == " ":
            b += 1
        line = text.rfind("\n", 0, ks) + 1
        nl = text.find("\n", b)
        if not text[line:ks].strip() and nl >= 0 and not text[b:nl].strip():
            ks, b = line, nl + 1
        return text[:ks] + text[b:]
    if index > 0:
        return text[:members[index - 1][3]] + text[ve:]
    end = _skip(text, ve)
    if end < len(text) and text[end] == ",":
        ve = end + 1
    return text[:ks] + text[ve:]


def _read(path):
    with open(path) as f:
        return f.read()


def select(path, theme):
    """Make `theme` the dark theme in effect; return (mode, previous)."""
    if not os.path.exists(path):
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        _write(path, _created(theme))
        return "created", "-"
    text = _read(path)
    start, members = _root(text)
    new = json.dumps(theme)
    m = _member(members, "theme")
    if m is None:
        ins = _top_insert(theme) + (", " if members else "")
        _write(path, text[:start + 1] + ins + text[start + 1:])
        return "added", "-"
    _, _, vs, ve = m
    if text[vs] == "{":
        sub, _ = _object(text, vs)
        d = _member(sub, "dark")
        if d is None:
            ins = _dark_insert(theme) + (", " if sub else "")
            _write(path, text[:vs + 1] + ins + text[vs + 1:])
            return "added-dark", "-"
        _, _, ds, de = d
        prev = json.dumps(json.loads(text[ds:de]))
        _write(path, text[:ds] + new + text[de:])
        return "dark", prev
    prev = json.dumps(json.loads(text[vs:ve]))
    _write(path, text[:vs] + new + text[ve:])
    return "string", prev


def current(path):
    """The dark theme in effect, or "" when unset or unreadable."""
    try:
        text = _read(path)
        _, members = _root(text)
    except (OSError, ValueError):
        return ""
    m = _member(members, "theme")
    if m is None:
        return ""
    _, _, vs, ve = m
    if text[vs] == "{":
        sub, _ = _object(text, vs)
        d = _member(sub, "dark")
        if d is None:
            return ""
        value = json.loads(text[d[2]:d[3]])
    else:
        value = json.loads(text[vs:ve])
    return value if isinstance(value, str) else ""


def _index(members, key):
    for i, m in enumerate(members):
        if m[0] == key:
            return i
    return -1


def restore(path, theme, mode, previous):
    """Undo select() while `theme` is still the one in effect."""
    if mode == "created":
        try:
            if _read(path) == _created(theme):
                os.remove(path)
                return True
        except OSError:
            return False
        # edited since: keep the file, drop only the theme it was created for
        mode = "added"
    if current(path) != theme:
        return False
    text = _read(path)
    _, members = _root(text)
    i = _index(members, "theme")
    _, _, vs, ve = members[i]
    if mode == "added":
        _write(path, _without(text, members, i))
        return True
    if text[vs] == "{":
        sub, _ = _object(text, vs)
        j = _index(sub, "dark")
        if mode == "added-dark":
            _write(path, _without(text, sub, j))
            return True
        if mode == "dark":
            _, _, ds, de = sub[j]
            _write(path, text[:ds] + previous + text[de:])
            return True
        return False
    if mode == "string":
        _write(path, text[:vs] + previous + text[ve:])
        return True
    return False


def main(argv):
    try:
        if len(argv) == 4 and argv[1] == "select":
            print("%s\t%s" % select(argv[2], argv[3]))
        elif len(argv) == 6 and argv[1] == "restore":
            print("restored" if restore(*argv[2:6]) else "kept")
        elif len(argv) == 3 and argv[1] == "current":
            print(current(argv[2]))
        else:
            print(__doc__.strip(), file=sys.stderr)
            return 2
    except ValueError as e:
        print("zed_settings.py: %s: %s" % (argv[2], e), file=sys.stderr)
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
