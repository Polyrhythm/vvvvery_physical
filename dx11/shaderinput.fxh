#ifndef __SHADERINPUT_FXH__
#define __SHADERINPUT_FXH__

#include "primitives.fxh"
#include "materials.fxh"
#include "lights.fxh"
#include "BVH.fxh"

cbuffer cbPerDraw : register( b0 )
{
	float4x4 tVP : VIEWPROJECTION;
	float4x4 tVI : VIEWINVERSE;
	float4x4 tPI : PROJECTIONINVERSE;
	uint bounces = 1;
	uint SampleIndex = 0;
	uint renderSky = 0;
	float4 worldColour <bool color=true;String uiname="World Colour";> = { 0.0f, 0.0f, 0.0f, 1.0f };
};

cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
};

StructuredBuffer<Primitive> primitiveBuffer;
StructuredBuffer<Material> materialBuffer;
StructuredBuffer<Light> lightBuffer;
StructuredBuffer<BVHNode> bvhBuffer;
Texture3D sdfTexture;
Texture2DArray textures;
Texture2D envMap;

BVHNode fetchBVHNodeData(const uint index)
{
	BVHNode bvh = bvhBuffer[index];
	return bvh;
}

Primitive fetchPrimitiveData(const uint index)
{
	Primitive p = primitiveBuffer[index];
	
	return p;
}

Material fetchMaterialData(const uint index)
{
	Material mat = materialBuffer[index];

	return mat;
}

Light fetchLightData(const uint index)
{
	Light light = lightBuffer[index];
	
	return light;
}

Texture3D fetchSDFTexture(const uint index)
{
	return sdfTexture;
}

#endif