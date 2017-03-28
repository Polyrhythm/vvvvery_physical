#ifndef __PRIMITIVES_FXH__
#define __PRIMITIVES_FXH__

#include "math.fxh"
#include "common.fxh"

struct Primitive
{
	uint type;
	uint materialIdx;
	float4 args;
	float4x4 transform;
};

#define primitiveBufferStride 22


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

void getSphereNormal(const float3 center, const float3 pHit, out float3 nHit,
	out float2 tex)
{
	nHit = pHit - center;
	nHit = normalize(nHit);
		
	tex.x = (1 + atan2(nHit.x, nHit.z) / PI) * 0.5;
	tex.y = acos(nHit.y) / PI;
}

float2 intersectBox(const Ray ray, float3 bounds[2], out float t)
{
	float3 tMin = (bounds[0] - ray.origin) / ray.dir;
	float3 tMax = (bounds[1] - ray.origin) / ray.dir;
	float3 t1 = min(tMin, tMax);
	float3 t2 = max(tMin, tMax);
	float tNear = max(max(t1.x, t1.y), t1.z);
	float tFar = min(min(t2.x, t2.y), t2.z);
	
	float2 res = (float2)-1;
	
	if (tNear <= tFar) {
		t = tNear;
		res = float2(tNear, tFar);
	}
		
	return res;
}

void getBoxNormal(const float3 bounds[2], const float3 pHit, out float3 nHit,
	out float2 tex)
{
	static const float epsilon = 0.0001;
	if (pHit.x < bounds[0].x + epsilon) nHit = float3(-1, 0, 0);
	else if (pHit.x > bounds[1].x - epsilon) nHit = float3(1, 0, 0);
	else if (pHit.y < bounds[0].y + epsilon) nHit = float3(0, -1, 0);
	else if (pHit.y > bounds[1].y - epsilon) nHit = float3(0, 1, 0);
	else if (pHit.z < bounds[0].z + epsilon) nHit = float3(0, 0, -1);
	else nHit = float3(0, 0, 1);

	tex = 0.0;
}

#endif