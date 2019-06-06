
using System.Collections.Generic;
using System.Runtime.InteropServices;
using SharpDX;

namespace physical
{
    public enum PrimitiveType : int
    {
        Sphere = 0,
        Box = 1,
        SDF = 2,
        Triangle = 3
    }

    public enum MaterialType : int
    {
        DiffuseDielectric = 0,
        Metallic = 1,
        Emissive = 2,
        Dielectric = 3,
        ParticipatingMedia = 4
    }

    public enum LightType : int
    {
        Point = 0,
        Spot = 1,
        Area = 2
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct Primitive
    {
        public PrimitiveType PrimitiveType;
        public int MaterialIndex;
        public Vector4 Params;
        public Matrix InverseTransform;
        public Vector3 MinBounds;
        public Vector3 MaxBounds;

        public int Va;
        public int Vb;
        public int Vc;

        public int UVa;
        public int UVb;
        public int UVc;

        public int Na;
        public int Nb;
        public int Nc;

        public Primitive(PrimitiveType primitiveType, int materialIndex, Vector4 primitiveParams,
            Matrix transform)
        {
            PrimitiveType = primitiveType;
            MaterialIndex = materialIndex;
            Params = primitiveParams;
            InverseTransform = transform;

            Va = -1;
            Vb = -1;
            Vc = -1;
            UVa = -1;
            UVb = -1;
            UVc = -1;
            Na = -1;
            Nb = -1;
            Nc = -1;

            // All transforms going into the raytracer need to be inverse for ray calculation
            InverseTransform.Invert();

            Vector3 pos = transform.TranslationVector;

            BoundingBox aabb = new BoundingBox();
            switch (primitiveType)
            {
                case physical.PrimitiveType.Sphere:
                    float radius = primitiveParams.X;
                    BoundingSphere bSphere = new BoundingSphere(pos, radius);
                    aabb = BoundingBox.FromSphere(bSphere);
                    MinBounds = aabb.Minimum;
                    MaxBounds = aabb.Maximum;
                    break;

                case physical.PrimitiveType.Box:
                    MinBounds = aabb.Minimum;
                    MaxBounds = aabb.Maximum;

                    Vector3 size = new Vector3(primitiveParams.X, primitiveParams.Y, primitiveParams.Z);
                    aabb = GetAABBFromPoints(size, transform);
                    MinBounds = aabb.Minimum;
                    MaxBounds = aabb.Maximum;
                    break;

                default:
                    Vector3 defaultSize = new Vector3(2.0f, 2.0f, 2.0f);
                    MinBounds = aabb.Minimum;
                    MaxBounds = aabb.Maximum;
                    aabb = GetAABBFromPoints(defaultSize, transform);

                    MinBounds = aabb.Minimum;
                    MaxBounds = aabb.Maximum;
                    break;
            }
        }

        private BoundingBox GetAABBFromPoints(Vector3 size, Matrix transform)
        {
            List<Vector3> points = new List<Vector3>();
            points.Add(new Vector3(-size.X, -size.Y, -size.Z) * 0.5f);
            points.Add(new Vector3( size.X, -size.Y, -size.Z) * 0.5f);
            points.Add(new Vector3( size.X, -size.Y,  size.Z) * 0.5f);
            points.Add(new Vector3(-size.X, -size.Y,  size.Z) * 0.5f);
            points.Add(new Vector3(-size.X,  size.Y, -size.Z) * 0.5f);
            points.Add(new Vector3( size.X,  size.Y, -size.Z) * 0.5f);
            points.Add(new Vector3( size.X,  size.Y,  size.Z) * 0.5f);
            points.Add(new Vector3(-size.X,  size.Y,  size.Z) * 0.5f);

            for (int i = 0; i < 8; i++)
            {
                points[i] = (Vector3)Vector3.Transform(points[i], transform);
            }

            return BoundingBox.FromPoints(points.ToArray());
        }
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct Material
    {
        public MaterialType MaterialType;
        public float IOR;
        public float Roughness;
        public Color4 Colour;
        public float Intensity;
        public int AlbedoTexIndex;
        public int RoughnessTexIndex;
        public int MetallicTexIndex;
        public int NormalTexIndex;
        public Vector2 UVScale;
        public float Padding;

        public Material(MaterialType materialType, float ior, float roughness, Color4 colour, float intensity, Vector2 uvScale,
            int albedoTexIndex = -1, int roughnessTexIndex = -1, int metallicTexIndex = -1, int normalTexIndex = -1)
        {
            MaterialType = materialType;
            IOR = ior;
            Roughness = roughness;
            Colour = colour;
            Intensity = intensity;
            AlbedoTexIndex = albedoTexIndex;
            RoughnessTexIndex = roughnessTexIndex;
            MetallicTexIndex = metallicTexIndex;
            NormalTexIndex = normalTexIndex;
            UVScale = uvScale;
            Padding = 0;
        }
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct Light
    {
        public LightType LightType;
        public Color4 Colour;
        public float Intensity;
        public Matrix Transform;
        public Matrix InverseTransform;
        public Vector2 Params;

        public Light(LightType lightType, Color4 colour, float intensity, Matrix transform, Vector2 lightParams)
        {
            LightType = lightType;
            Colour = colour;
            Intensity = intensity;
            Transform = transform;
            transform.Invert();
            InverseTransform = transform;
            Params = lightParams;
        }
    }
}
