#ifndef __SHADERINPUT_FXH__
#define __SHADERINPUT_FXH__

#include "primitives.fxh"
#include "materials.fxh"
#include "lights.fxh"

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

StructuredBuffer<float> primitiveBuffer;
StructuredBuffer<float> materialBuffer;
StructuredBuffer<float> lightBuffer;
Texture3D sdfTexture;
Texture2DArray textures;
Texture2D envMap;

Primitive fetchPrimitiveData(const uint index)
{
	uint b = index * primitiveBufferStride;
	Primitive p = (Primitive)0;
	p.type = primitiveBuffer[b];
	p.materialIdx = primitiveBuffer[b + 1];
	p.args = float4(primitiveBuffer[b + 2], primitiveBuffer[b + 3],
		primitiveBuffer[b + 4], primitiveBuffer[b + 5]);
	p.inverseTransform = float4x4(
		primitiveBuffer[b + 6], primitiveBuffer[b + 7], primitiveBuffer[b + 8], primitiveBuffer[b + 9],
		primitiveBuffer[b + 10], primitiveBuffer[b + 11], primitiveBuffer[b + 12], primitiveBuffer[b + 13],
	    primitiveBuffer[b + 14], primitiveBuffer[b + 15], primitiveBuffer[b + 16], primitiveBuffer[b + 17],
		primitiveBuffer[b + 18], primitiveBuffer[b + 19], primitiveBuffer[b + 20], primitiveBuffer[b + 21]);
	
	return p;
}

Material fetchMaterialData(const uint index)
{
	uint b = index * materialBufferStride;
	Material mat;
	mat.type = materialBuffer[b];
	
	mat.ior = materialBuffer[b + 1];
	mat.roughness = materialBuffer[b + 2];
	mat.colour = float4(materialBuffer[b + 3], materialBuffer[b + 4],
		materialBuffer[b + 5], materialBuffer[b + 6]);
	mat.intensity = materialBuffer[b + 7];
	mat.texIdx = materialBuffer[b + 8];
	mat.uvScale = float2(materialBuffer[b + 9], materialBuffer[b + 10]);
	
	return mat;
}

Light fetchLightData(const uint index)
{
	uint b = index * lightBufferStride;
	Light l;
	l.type = lightBuffer[b];
	l.colour = float4(lightBuffer[b + 1], lightBuffer[b + 2], lightBuffer[b + 3],
		lightBuffer[b + 4]);
	l.intensity = lightBuffer[b + 5];
	l.transform = float4x4(
		lightBuffer[b + 6], lightBuffer[b + 7], lightBuffer[b + 8], lightBuffer[b + 9],
		lightBuffer[b + 10], lightBuffer[b + 11], lightBuffer[b + 12], lightBuffer[b + 13],
	    lightBuffer[b + 14], lightBuffer[b + 15], lightBuffer[b + 16], lightBuffer[b + 17],
		lightBuffer[b + 18], lightBuffer[b + 19], lightBuffer[b + 20], lightBuffer[b + 21]);
	l.params = float4(lightBuffer[b + 22], lightBuffer[b + 23],
		lightBuffer[b + 24], lightBuffer[b + 25]);
	
	return l;
}

Texture3D fetchSDFTexture(const uint index)
{
	return sdfTexture;
}

#endif