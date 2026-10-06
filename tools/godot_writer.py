"""Minimal writer for Godot 4 text scenes (.tscn) and resources (.tres)."""
import json, math, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class Raw:
    def __init__(self, v): self.v = v
    def __repr__(self): return self.v


class NodeRef:
    """An exported Node property: written as NodePath and listed in node_paths."""
    def __init__(self, path): self.path = path


def V2(x, y): return Raw("Vector2(%s, %s)" % (num(x), num(y)))
def V3(x, y, z): return Raw("Vector3(%s, %s, %s)" % (num(x), num(y), num(z)))
def SN(s): return Raw('&"%s"' % s)
def NP(s): return Raw('NodePath("%s")' % s)


def num(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if abs(v) < 1e-9:
        return "0"
    s = ("%.6f" % v).rstrip("0").rstrip(".")
    return s if s not in ("-0", "") else "0"


def hexcol(h, a=1.0, k=1.0):
    if isinstance(h, int):
        h = "%06x" % h
    h = h.lstrip("#")
    r, g, b = int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255
    if len(h) == 8:
        a = int(h[6:8], 16) / 255
    return Raw("Color(%s, %s, %s, %s)" % (num(r * k), num(g * k), num(b * k), num(a)))


def col(r, g, b, a=1.0):
    return Raw("Color(%s, %s, %s, %s)" % (num(r), num(g), num(b), num(a)))


def fmt(v):
    if isinstance(v, Raw):
        return v.v
    if isinstance(v, NodeRef):
        return 'NodePath("%s")' % v.path
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return num(v)
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, (list, tuple)):
        return "[" + ", ".join(fmt(x) for x in v) + "]"
    if isinstance(v, dict):
        return "{\n" + ",\n".join("%s: %s" % (fmt(k), fmt(x)) for k, x in v.items()) + "\n}"
    raise TypeError(type(v))


# ---------------------------------------------------------------- transforms
def _rx(a): c, s = math.cos(a), math.sin(a); return [[1, 0, 0], [0, c, -s], [0, s, c]]
def _ry(a): c, s = math.cos(a), math.sin(a); return [[c, 0, s], [0, 1, 0], [-s, 0, c]]
def _rz(a): c, s = math.cos(a), math.sin(a); return [[c, -s, 0], [s, c, 0], [0, 0, 1]]
def mm(a, b): return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def basis(rx=0.0, ry=0.0, rz=0.0, order="XYZ", sx=1.0, sy=1.0, sz=1.0, pre=None):
    """Rotation matrix using three.js Euler conventions (order 'XYZ' = Rx*Ry*Rz), then scale.
    `pre` is an extra local rotation applied first (e.g. to lay a torus into the XY plane)."""
    R = {"X": _rx(rx), "Y": _ry(ry), "Z": _rz(rz)}
    m = mm(mm(R[order[0]], R[order[1]]), R[order[2]])
    if pre is not None:
        m = mm(m, pre)
    return [[m[i][0] * sx, m[i][1] * sy, m[i][2] * sz] for i in range(3)]


def T3(x=0.0, y=0.0, z=0.0, rx=0.0, ry=0.0, rz=0.0, order="XYZ", s=None, pre=None):
    sx, sy, sz = (s, s, s) if isinstance(s, (int, float)) else (s or (1, 1, 1))
    b = basis(rx, ry, rz, order, sx, sy, sz, pre)
    vals = [b[0][0], b[0][1], b[0][2], b[1][0], b[1][1], b[1][2], b[2][0], b[2][1], b[2][2], x, y, z]
    return Raw("Transform3D(" + ", ".join(num(v) for v in vals) + ")")


TORUS_TO_XY = _rx(math.pi / 2)   # three.js tori/circles lie in XY; Godot's in XZ


# ---------------------------------------------------------------- documents
class _Doc:
    def __init__(self):
        self.ext = []        # (type, path, id)
        self.sub = []        # (type, id, props)
        self._ext_ids = {}
        self._n = 0

    def ext_res(self, path, type=None):
        if not path.startswith("res://"):
            path = "res://" + path
        if path in self._ext_ids:
            return Raw('ExtResource("%s")' % self._ext_ids[path])
        if type is None:
            type = {".gd": "Script", ".tscn": "PackedScene", ".tres": "Resource", ".gdshader": "Shader", ".glb": "PackedScene",
                    ".png": "Texture2D", ".jpg": "Texture2D", ".svg": "Texture2D", ".mp3": "AudioStream"}[os.path.splitext(path)[1]]
            if path.endswith(".tres") and "/materials/" in path:
                type = "Material"
        self._n += 1
        i = "%d_%s" % (self._n, os.path.splitext(os.path.basename(path))[0][:12].replace(" ", "_"))
        self._ext_ids[path] = i
        self.ext.append((type, path, i))
        return Raw('ExtResource("%s")' % i)

    def sub_res(self, type, **props):
        self._n += 1
        i = "%s_%d" % (type, self._n)
        self.sub.append((type, i, props))
        return Raw('SubResource("%s")' % i)

    def _head(self):
        out = []
        for t, p, i in self.ext:
            out.append('[ext_resource type="%s" path="%s" id="%s"]\n' % (t, p, i))
        for t, i, props in self.sub:
            out.append('\n[sub_resource type="%s" id="%s"]\n' % (t, i))
            for k, v in props.items():
                out.append("%s = %s\n" % (k, fmt(v)))
        return out


class Resource(_Doc):
    def __init__(self, type, script=None, script_class=None):
        super().__init__()
        self.type = type
        self.props = {}
        self.script_class = script_class
        if script:
            self.props["script"] = self.ext_res(script)

    def save(self, rel):
        path = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        sc = ' script_class="%s"' % self.script_class if self.script_class else ""
        out = ['[gd_resource type="%s"%s load_steps=%d format=3]\n\n' % (self.type, sc, len(self.ext) + len(self.sub) + 1)]
        out += self._head()
        out.append("\n[resource]\n")
        for k, v in self.props.items():
            out.append("%s = %s\n" % (k, fmt(v)))
        open(path, "w").write("".join(out))
        return "res://" + rel


class Scene(_Doc):
    def __init__(self, root_name, root_type=None, props=None, instance=None, groups=None):
        super().__init__()
        self.nodes = []
        self._children = {}
        self.node(root_name, root_type, None, props, instance=instance, groups=groups)

    def node(self, name, type=None, parent=".", props=None, instance=None, groups=None, unique=False):
        props = dict(props or {})
        key = parent if parent is not None else "#root"
        used = self._children.setdefault(key, set())
        base, n = name, 2
        while name in used:
            name = "%s%d" % (base, n)
            n += 1
        used.add(name)
        if isinstance(instance, str):
            instance = self.ext_res(instance)
        self.nodes.append((name, type, parent, props, instance, groups, unique))
        if parent is None:
            return "."
        return name if parent == "." else parent + "/" + name

    def save(self, rel):
        path = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        out = ["[gd_scene load_steps=%d format=3]\n\n" % (len(self.ext) + len(self.sub) + 1)]
        out += self._head()
        for name, type, parent, props, instance, groups, unique in self.nodes:
            h = '\n[node name="%s"' % name
            if type and not instance:
                h += ' type="%s"' % type
            if parent is not None:
                h += ' parent="%s"' % parent
            refs = [k for k, v in props.items() if isinstance(v, NodeRef) or (isinstance(v, list) and v and all(isinstance(x, NodeRef) for x in v))]
            if refs:
                h += " node_paths=PackedStringArray(%s)" % ", ".join('"%s"' % r for r in refs)
            if instance:
                h += " instance=%s" % instance.v
            if groups:
                h += " groups=[%s]" % ", ".join('"%s"' % g for g in groups)
            out.append(h + "]\n")
            if unique:
                out.append("unique_name_in_owner = true\n")
            for k, v in props.items():
                out.append("%s = %s\n" % (k, fmt(v)))
        open(path, "w").write("".join(out))
        return "res://" + rel
