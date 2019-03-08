
using System.Runtime.InteropServices;
using SharpDX;

namespace physical
{
    public enum PrimitiveType : int
    {
        Sphere = 0,
        Box = 1,
        SDF = 2
    }

    public enum MaterialType : int
    {
        Dielectric = 0,
        Metallic = 1,
        Emissive = 2
    }

    public enum LightType : int
    {
        Point = 0,
        Spot = 1
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct Primitive
    {
        public float PrimitiveType;
        public float MaterialIndex;
        public Vector4 Params;
        public Matrix InverseTransform;
        public Vector3 MinBounds;
        public Vector3 MaxBounds;

        public Primitive(PrimitiveType primitiveType, float materialIndex, Vector4 primitiveParams,
            Matrix transform)
        {
            PrimitiveType = (float)primitiveType;
            MaterialIndex = materialIndex;
            Params = primitiveParams;
            InverseTransform = transform;

            // All transforms going into the raytracer need to be inverse for ray calculation
            InverseTransform.Invert();

            Vector3 pos = transform.TranslationVector;

            BoundingBox aabb;
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
                    Vector3 size = new Vector3(primitiveParams.X, primitiveParams.Y, primitiveParams.Z);
                    aabb = new BoundingBox(pos - size / 2.0f, pos + size / 2.0f);
                    MinBounds = aabb.Minimum;
                    MaxBounds = aabb.Maximum;
                    break;

                default:
                    Vector3 defaultSize = new Vector3(1.0f, 1.0f, 1.0f);
                    aabb = new BoundingBox(pos - defaultSize / 2.0f, pos + defaultSize / 2.0f);
                    MinBounds = aabb.Minimum;
                    MaxBounds = aabb.Maximum;
                    break;
            }
        }
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct Material
    {
        public float MaterialType;
        public float IOR;
        public float Roughness;
        public Color4 Colour;
        public float Intensity;
        public float TextureIndex;
        public Vector2 UVScale;

        public Material(MaterialType materialType, float ior, float roughness, Color4 colour, float intensity,
            int textureIndex, Vector2 uvScale)
        {
            MaterialType = (float)materialType;
            IOR = ior;
            Roughness = roughness;
            Colour = colour;
            Intensity = intensity;
            TextureIndex = textureIndex;
            UVScale = uvScale;
        }
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct Light
    {
        public float LightType;
        public Color4 Colour;
        public float Intensity;
        public Matrix Transform;
        public Vector2 Params;

        public Light(LightType lightType, Color4 colour, float intensity, Matrix transform, float penumbra, float umbra)
        {
            LightType = (float)lightType;
            Colour = colour;
            Intensity = intensity;
            Transform = transform;
            Params.X = penumbra;
            Params.Y = umbra;
        }
    }
}
