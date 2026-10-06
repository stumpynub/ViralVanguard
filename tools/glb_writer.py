"""Tiny glTF 2.0 (.glb) writer shared by the asset extractors."""
import json, struct


class GLB:
    def __init__(self):
        self.bin = bytearray()
        self.j = {"asset": {"version": "2.0", "generator": "viral-vanguard extract"},
                  "scene": 0, "scenes": [{"nodes": []}], "nodes": [], "meshes": [],
                  "accessors": [], "bufferViews": [], "buffers": [], "materials": []}

    def _view(self, data, target):
        while len(self.bin) % 4:
            self.bin.append(0)
        off = len(self.bin)
        self.bin += data
        self.j["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": len(data), "target": target})
        return len(self.j["bufferViews"]) - 1

    def _acc(self, flat, comps, ctype=5126, target=34962, minmax=False):
        typ = {1: "SCALAR", 2: "VEC2", 3: "VEC3", 4: "VEC4"}[comps]
        fmt = {5126: "f", 5125: "I"}[ctype]
        v = self._view(struct.pack("<%d%s" % (len(flat), fmt), *flat), target)
        a = {"bufferView": v, "componentType": ctype, "count": len(flat) // comps, "type": typ}
        if minmax:
            a["min"] = [min(flat[i::comps]) for i in range(comps)]
            a["max"] = [max(flat[i::comps]) for i in range(comps)]
        self.j["accessors"].append(a)
        return len(self.j["accessors"]) - 1

    def material(self, name, color, metal=0.0, rough=0.5, emissive=None):
        m = {"name": name, "pbrMetallicRoughness": {"baseColorFactor": list(color) + [1.0],
             "metallicFactor": metal, "roughnessFactor": rough}}
        if emissive:
            k = max(emissive)
            if k > 1.0:
                m["extensions"] = {"KHR_materials_emissive_strength": {"emissiveStrength": k}}
                self.j.setdefault("extensionsUsed", []).append("KHR_materials_emissive_strength")
                emissive = [c / k for c in emissive]
            m["emissiveFactor"] = list(emissive)
        self.j["materials"].append(m)
        return len(self.j["materials"]) - 1

    def mesh(self, name, prims):
        """prims: list of dict(pos, nrm, col(optional vec3), idx(optional), mat)"""
        out_p = []
        for p in prims:
            attrs = {"POSITION": self._acc(p["pos"], 3, minmax=True), "NORMAL": self._acc(p["nrm"], 3)}
            if p.get("col"):
                attrs["COLOR_0"] = self._acc(p["col"], 3)
            pr = {"attributes": attrs, "material": p["mat"]}
            if p.get("idx"):
                pr["indices"] = self._acc(p["idx"], 1, 5125, 34963)
            out_p.append(pr)
        self.j["meshes"].append({"name": name, "primitives": out_p})
        return len(self.j["meshes"]) - 1

    def node(self, name, mesh=None, t=None, s=None, children=None, root=False):
        n = {"name": name}
        if mesh is not None: n["mesh"] = mesh
        if t: n["translation"] = list(t)
        if s: n["scale"] = list(s)
        if children: n["children"] = children
        self.j["nodes"].append(n)
        i = len(self.j["nodes"]) - 1
        if root:
            self.j["scenes"][0]["nodes"].append(i)
        return i

    def save(self, path):
        while len(self.bin) % 4:
            self.bin.append(0)
        self.j["buffers"] = [{"byteLength": len(self.bin)}]
        js = json.dumps(self.j, separators=(",", ":")).encode()
        while len(js) % 4:
            js += b" "
        with open(path, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(self.bin)))
            f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
            f.write(struct.pack("<II", len(self.bin), 0x004E4942) + self.bin)


