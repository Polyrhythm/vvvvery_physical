using System.Collections.Generic;
using System.IO;
using System.Linq;
using ObjParser.Types;
using SharpDX;

namespace physical
{
    public static class Geometry
    {
        public static void LoadObj(bool enable, string filename, Matrix transform, int materialIndex, out IEnumerable<Vector3> vertices,
            out IEnumerable<Vector2> uvs, out IEnumerable<Vector3> normals, out IEnumerable<Primitive> faces)
        {
            vertices = new List<Vector3>();
            faces = new List<Primitive>();
            uvs = new List<Vector2>();
            normals = new List<Vector3>();

            if (!enable)
            {
                return;
            }

            List<Vector3> v = new List<Vector3>();
            List<Vector2> vuv = new List<Vector2>();
            List<Vector3> vn = new List<Vector3>();
            List<Primitive> tris = new List<Primitive>();

            var obj = new ObjParser.Obj();
            var fileStream = new FileStream(filename, FileMode.Open);

            obj.LoadObj(fileStream);

            for (int i = 0; i < obj.VertexList.Count; i++)
            {
                var vt = obj.VertexList[i];
                v.Add(new Vector3((float)vt.X, (float)vt.Y, (float)vt.Z));
            }

            for (int i = 0; i < obj.NormalList.Count; i++)
            {
                var n = obj.NormalList[i];
                vn.Add(new Vector3((float)n.X, (float)n.Y, (float)n.Z));
            }

            for (int i = 0; i < obj.TextureList.Count; i++)
            {
                var uv = obj.TextureList[i];
                vuv.Add(new Vector2((float)uv.X, (float)uv.Y));
            }

            foreach (var f in obj.FaceList)
            {
                Primitive triangle = new Primitive(PrimitiveType.Triangle, materialIndex, Vector4.Zero, transform);
                triangle.Va = f.VertexIndexList[0] - 1;
                triangle.Vb = f.VertexIndexList[1] - 1;
                triangle.Vc = f.VertexIndexList[2] - 1;

                triangle.UVa = f.TextureVertexIndexList[0] - 1;
                triangle.UVb = f.TextureVertexIndexList[1] - 1;
                triangle.UVc = f.TextureVertexIndexList[2] - 1;

                triangle.Na = f.NormalIndexList[0] - 1;
                triangle.Nb = f.NormalIndexList[1] - 1;
                triangle.Nc = f.NormalIndexList[2] - 1;

                Vertex a = obj.VertexList[triangle.Va];
                Vector3 va = new Vector3((float)a.X, (float)a.Y, (float)a.Z);

                Vertex b = obj.VertexList[triangle.Vb];
                Vector3 vb = new Vector3((float)b.X, (float)b.Y, (float)b.Z);

                Vertex c = obj.VertexList[triangle.Vc];
                Vector3 vc = new Vector3((float)c.X, (float)c.Y, (float)c.Z);

                Vector3 ta = (Vector3)Vector3.Transform(va, transform);
                Vector3 tb = (Vector3)Vector3.Transform(vb, transform);
                Vector3 tc = (Vector3)Vector3.Transform(vc, transform);

                BoundingBox aabb = BoundingBox.FromPoints(new Vector3[]{ta, tb, tc});
                triangle.MinBounds = aabb.Minimum;
                triangle.MaxBounds = aabb.Maximum;

                tris.Add(triangle);
            }

            vertices = v;
            uvs = vuv;
            normals = vn;
            faces = tris;
        }
    }
}
