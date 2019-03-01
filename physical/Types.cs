
using System.Runtime.InteropServices;
using SharpDX;

namespace physical
{
    public enum PrimitiveType
    {
        Sphere = 0,
        Box = 1,
        SDF = 2
    }

    public enum MaterialType
    {
        Dielectric = 0,
        Metallic = 1,
        Emissive = 2
    }

    public enum LightType
    {
        Point = 0,
        Spot = 1
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct Primitive
    {
        public PrimitiveType PrimitiveType;
        public uint MaterialIndex;
        public Vector4 Params;
        public Matrix InverseTransform;
        public BoundingBox AABB;

        public Primitive(PrimitiveType primitiveType, uint materialIndex, Vector4 primitiveParams,
            Matrix transform)
        {
            PrimitiveType = primitiveType;
            MaterialIndex = materialIndex;
            Params = primitiveParams;
            InverseTransform = transform;

            // All transforms going into the raytracer need to be inverse for ray calculation
            InverseTransform.Invert();

            Vector3 pos = transform.TranslationVector;

            switch (primitiveType)
            {
                case PrimitiveType.Sphere:
                    float radius = primitiveParams.X;
                    BoundingSphere bSphere = new BoundingSphere(pos, radius);
                    AABB = BoundingBox.FromSphere(bSphere);
                    break;

                case PrimitiveType.Box:
                    Vector3 size = new Vector3(primitiveParams.X, primitiveParams.Y, primitiveParams.Z);
                    AABB = new BoundingBox(pos - size / 2.0f, pos + size / 2.0f);
                    break;

                default:
                    Vector3 defaultSize = new Vector3(1.0f, 1.0f, 1.0f);
                    AABB = new BoundingBox(pos - defaultSize / 2.0f, pos + defaultSize / 2.0f);
                    break;
            }
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
        public int TextureIndex;
        public Vector2 UVScale;

        public Material(MaterialType materialType, float ior, float roughness, Color4 colour, float intensity,
            int textureIndex, Vector2 uvScale)
        {
            MaterialType = materialType;
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
        public LightType LightType;
        public Color4 Colour;
        public float Intensity;
        public Matrix Transform;
        public Vector4 Params;

        public Light(LightType lightType, Color4 colour, float intensity, Matrix transform, Vector4 lightParams)
        {
            LightType = lightType;
            Colour = colour;
            Intensity = intensity;
            Transform = transform;
            Params = lightParams;
        }
    }
}
