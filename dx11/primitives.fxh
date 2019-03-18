#ifndef __PRIMITIVES_FXH__
#define __PRIMITIVES_FXH__

#define VolumeSize 512

#include "math.fxh"
#include "common.fxh"

static const int SPHERE = 0;
static const int BOX = 1;
static const int SDF = 2;

SamplerState linearSampler : IMMUTABLE
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
	AddressW = Clamp;
};

struct Primitive
{
	int type;
	int materialIdx;
	float4 args;
	row_major float4x4 inverseTransform;
	float3 minBounds;
	float3 maxBounds;
};

float2 intersectSDF(const Ray ray, Texture3D sdfVolume, out float t,
	out float3 pos)
{
	t = 0.1;
	const float MAX_DIST = 100.0;
	const int MAX_STEPS = 128;
	const float EPSILON = 0.002;
	
	for (int i = 0; i < MAX_STEPS; i++) {
		if (t > VolumeSize)
		{
			return -1.0;
		}
		
		pos = ray.origin + ray.dir * t;
		float h = sdfVolume.SampleLevel(linearSampler, pos, 0).r;
		
		if (h < EPSILON)
		{
			return 1.0;
		}
		
		t += h;
	}
	
	return -1.0;
}

void getSDFNormal(Texture3D sdfVolume, const float3 pos, out float3 n)
{
	float2 eps = float2(0.0, 0.002);
	n.x = sdfVolume.SampleLevel(linearSampler, pos + eps.yxx, 0).r
		- sdfVolume.SampleLevel(linearSampler, pos - eps.yxx, 0).r;
	n.y = sdfVolume.SampleLevel(linearSampler, pos + eps.xyx, 0).r
		- sdfVolume.SampleLevel(linearSampler, pos - eps.xyx, 0).r;
	n.z = sdfVolume.SampleLevel(linearSampler, pos + eps.xxy, 0).r
		- sdfVolume.SampleLevel(linearSampler, pos - eps.xxy, 0).r;
	
	n = normalize(n);
}

float2 intersectSphere(const float3 center, const float radius, const Ray ray,
	out float t)
{
	float t0, t1;
	float3 L = ray.origin - center;
	float a = dot(ray.dir, ray.dir);
	float b = 2 * dot(ray.dir, L);
	float c = dot(L, L) - radius * radius;
	
	float2 res = (float2)-1;
	
	float discriminant = b * b - 4.0 * a * c;
	if (discriminant > 0.0) {
		t = (-b - sqrt(discriminant)) / (2.0 * a);
		if (t > 0.0) {
			res = (float2)t;
		}
	}
		
	return res;
}

void getSphereNormal(const float3 center, const float3 pHit, out float3 nHit)
{
	nHit = pHit - center;
	nHit = normalize(nHit);
}

void getSphereUV(const float3 nHit, out float2 uv)
{
	uv.x = (1 + atan2(nHit.x, nHit.z) / PI) * 0.5;
	uv.y = acos(nHit.y) / PI;
}

void getBoxBounds(const float3 size, const float4x4 transform,
	out float3 bounds[2])
{
	float3 pos = float3(transform[3].x,
						transform[3].y,
						transform[3].z);
	
	bounds[0] = float3(pos - size / 2);
	bounds[1] = float3(pos + size / 2);
}

float2 intersectBVH(const Ray ray, const float3 minBounds, const float3 maxBounds,
	out float t)
{
	float3 tMin = (minBounds - ray.origin) / ray.dir;
	float3 tMax = (maxBounds - ray.origin) / ray.dir;
	float3 t1 = min(tMin, tMax);
	float3 t2 = max(tMin, tMax);
	float tNear = max(max(t1.x, t1.y), t1.z);
	float tFar = min(min(t2.x, t2.y), t2.z);
	
	float2 res = (float2)-1;
	
	if (max(tNear,0) <= tFar) {
		t = tNear;
		res = float2(tNear, tFar);
	}
		
	return res;
}

float2 intersectBox(const Ray ray, const float3 size, const float4x4 transform,
	out float t)
{	
	float3 bounds[2];
	getBoxBounds(size, transform, bounds);
	
	float3 tMin = (bounds[0] - ray.origin) / ray.dir;
	float3 tMax = (bounds[1] - ray.origin) / ray.dir;
	float3 t1 = min(tMin, tMax);
	float3 t2 = max(tMin, tMax);
	float tNear = max(max(t1.x, t1.y), t1.z);
	float tFar = min(min(t2.x, t2.y), t2.z);
	
	float2 res = (float2)-1;
	
	if (max(tNear,0) <= tFar) {
		t = tNear;
		res = float2(tNear, tFar);
	}
		
	return res;
}

void getBoxNormal(const float3 size, const float4x4 transform,
	const float3 pHit, out float3 nHit)
{
	float3 bounds[2];
	getBoxBounds(size, transform, bounds);
	
	static const float epsilon = 0.0001;
	if (pHit.x < bounds[0].x + epsilon) nHit = float3(-1, 0, 0);
	else if (pHit.x > bounds[1].x - epsilon) nHit = float3(1, 0, 0);
	else if (pHit.y < bounds[0].y + epsilon) nHit = float3(0, -1, 0);
	else if (pHit.y > bounds[1].y - epsilon) nHit = float3(0, 1, 0);
	else if (pHit.z < bounds[0].z + epsilon) nHit = float3(0, 0, -1);
	else nHit = float3(0, 0, 1);
}

void getBoxUV(const float3 size, const float4x4 transform, const float3 nor,
	const float3 pHit, out float2 uvHit)
{
	float3 bounds[2];
	getBoxBounds(size, transform, bounds);
	
	uvHit = float2(0, 0);
	
	if (nor.y == 1) {
		uvHit.x = -pHit.x / bounds[0].x * 0.5 + 0.5;
		uvHit.y = pHit.z / bounds[0].z * 0.5 + 0.5;
	}
	
	else if (nor.y == -1) {
		uvHit.x = -pHit.x / bounds[0].x * 0.5 + 0.5;
		uvHit.y = -pHit.z / bounds[0].z * 0.5 + 0.5;
	}
	
	else if (nor.x == 1) {
		uvHit.x = -pHit.z / bounds[0].z * 0.5 + 0.5;
		uvHit.y = pHit.y / bounds[0].y * 0.5 + 0.5;
	}
	
	else if (nor.x == -1) {
		uvHit.x = pHit.z / bounds[0].z * 0.5 + 0.5;
		uvHit.y = pHit.y / bounds[0].y * 0.5 + 0.5;
	}
	
	else if (nor.z == 1) {
		uvHit.x = pHit.x / bounds[0].x * 0.5 + 0.5;
		uvHit.y = pHit.y / bounds[0].y * 0.5 + 0.5;
	}
	
	else if (nor.z == -1) {
		uvHit.x = -pHit.x / bounds[0].x * 0.5 + 0.5;
		uvHit.y = pHit.y / bounds[0].y * 0.5 + 0.5;
	}
}

#endif