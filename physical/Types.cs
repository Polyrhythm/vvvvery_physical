
using System.Runtime.InteropServices;
using SharpDX;

namespace physical
{
    public enum PrimitiveType
    {
        Sphere,
        Box,
        SDF
    }

    public enum MaterialType
    {
        Dielectric,
        Metallic,
        Emissive
    }

    public enum LightType
    {
        Point,
        Spot,
        Directional
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct Primitive
    {
        public PrimitiveType PrimitiveType;
        public uint MaterialIndex;
        public Vector4 Params;
        public Matrix InverseTransform;

        public Primitive(PrimitiveType primitiveType, uint materialIndex, Vector4 primitiveParams,
            Matrix inverseTransform)
        {
            PrimitiveType = primitiveType;
            MaterialIndex = materialIndex;
            Params = primitiveParams;
            InverseTransform = inverseTransform;
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
