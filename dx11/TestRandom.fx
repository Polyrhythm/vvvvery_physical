
#include "random.fxh"

float4 TextureSize : TARGETSIZE;

#define materialBufferStride 7
StructuredBuffer<float> materialBuffer;
struct Material
{
	uint type;
	float ior;
	float roughness;
	float4 colour;
};

#define primitiveBufferStride 22
StructuredBuffer<float> primitiveBuffer;
struct Primitive
{
	uint type;
	uint materialIdx;
	float4 args;
	float4x4 transform;
};

#define lightBufferStride 22
StructuredBuffer<float> lightBuffer;
struct Light
{
	uint type;
	float4 colour;
	float intensity;
	float4x4 transform;
};
 
cbuffer cbPerDraw : register( b0 )
{
	float4x4 tVP : VIEWPROJECTION;
	float4x4 tVI : VIEWINVERSE;
	float4x4 tPI : PROJECTIONINVERSE;
};

cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
};

#define INFINITY 9999
static const float PI = 3.14159265359;

struct VS_IN
{
	float4 PosO : POSITION;
	float4 TexCd : TEXCOORD0;

};

struct vs2ps
{
    float4 PosWVP: SV_POSITION;
    float4 TexCd: TEXCOORD0;
};

struct Ray
{	
	float3 dir;
	float3 origin;
};

struct Options
{
	float fov;
};

uint bounces = 1;
uint SampleIndex = 0;
static const float epsilon = 0.0001;

// *******
// Primitive functions
// *******

float2 intersectSphere(const float3 center, const float radius, const Ray ray,
	out float t)
{
	float t0, t1;
	float3 L = ray.origin - center;
	float a = dot(ray.dir, ray.dir);
	float b = 2 * dot(ray.dir, L);
	float c = dot(L, L) - radius * radius;
	
	float discriminant = b * b - 4.0 * a * c;
	if (discriminant > 0.0) {
		t = (-b - sqrt(discriminant)) / (2.0 * a);
		if (t > 0.0) {
			return t;
		}
	}
		
	return -1;
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
		
	if (tNear <= tFar) {
		t = tNear;
		
		return float2(tNear, tFar);
	}
		
	return -1;
}

void getBoxNormal(const float3 bounds[2], const float3 pHit, out float3 nHit,
	out float2 tex)
{
	if (pHit.x < bounds[0].x + epsilon) nHit = float3(-1, 0, 0);
	else if (pHit.x > bounds[1].x - epsilon) nHit = float3(1, 0, 0);
	else if (pHit.y < bounds[0].y + epsilon) nHit = float3(0, -1, 0);
	else if (pHit.y > bounds[1].y - epsilon) nHit = float3(0, 1, 0);
	else if (pHit.z < bounds[0].z + epsilon) nHit = float3(0, 0, -1);
	else nHit = float3(0, 0, 1);

	tex = 0.0;
}

// *******
// Buffer data fetch
// *******
Material fetchMaterialData(const uint index)
{
	uint b = index * materialBufferStride;
	Material mat;
	mat.type = materialBuffer[b];
	mat.ior = materialBuffer[b + 1];
	mat.roughness = materialBuffer[b + 2];
	mat.colour = float4(materialBuffer[b + 3], materialBuffer[b + 4],
		materialBuffer[b + 5], materialBuffer[b + 6]);
	
	return mat;
}

Primitive fetchPrimitiveData(const uint index)
{
	uint b = index * primitiveBufferStride;
	Primitive p;
	p.type = primitiveBuffer[b];
	p.materialIdx = primitiveBuffer[b + 1];
	p.args = float4(primitiveBuffer[b + 2], primitiveBuffer[b + 3],
		primitiveBuffer[b + 4], primitiveBuffer[b + 5]);
	p.transform = float4x4(
		primitiveBuffer[b + 6], primitiveBuffer[b + 7], primitiveBuffer[b + 8], primitiveBuffer[b + 9],
		primitiveBuffer[b + 10], primitiveBuffer[b + 11], primitiveBuffer[b + 12], primitiveBuffer[b + 13],
	    primitiveBuffer[b + 14], primitiveBuffer[b + 15], primitiveBuffer[b + 16], primitiveBuffer[b + 17],
		primitiveBuffer[b + 18], primitiveBuffer[b + 19], primitiveBuffer[b + 20], primitiveBuffer[b + 21]);
	
	return p;
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
	
	return l;
}

// *******
// Math utils
// *******
float random(float3 scale, float seed, float4 pos)
{
	return frac(sin(dot(pos.xyz + seed, scale)) * 43758.5453 + seed);
}

// http://www.rorydriscoll.com/2009/01/07/better-sampling/
float3 cosineWeightedDirection(float3 normal, float seed, float4 pos)
{
	float u = random(float3(12.9898, 78.233, 151.7182), seed, pos);
	float v = random(float3(63.7264, 10.873, 623.6736), seed, pos);
	float r = sqrt(u);
	float angle = 6.283185307179586 * v;
	
	float3 sdir, tdir;
	if (abs(normal.x) < 0.5) {
		sdir = cross(normal, float3(1,0,0));
	} else {
		sdir = cross(normal, float3(0,1,0));
	}
	
	tdir = cross(normal, sdir);
	
	return r * cos(angle) * sdir + r * sin(angle) * tdir + sqrt(1.0 - u) * normal;
}

float3 uniformlyRandomDirection(float seed, float4 pos)
{
	float u = random(float3(12.9898, 78.233, 151.7182), seed, pos);
	float v = random(float3(63.7264, 10.873, 623.6736), seed, pos);
	float z = 1.0 - 2.0 * u;
	float r = sqrt(1.0 - z * z);
	float angle = 6.283185307179586 * v;
	
	return float3(r * cos(angle), r* sin(angle), z);
}

float3 uniformlyRandomVector(float seed, float4 pos)
{
	return uniformlyRandomDirection(seed, pos) * sqrt(random(
		float3(36.7539, 50.3658, 306.2759), seed, pos));
}

// *********
// Rays
// *********
float2 intersect(const Primitive hit, const Ray ray, out float t)
{
	float2 tIntersect;
	switch (hit.type) {
		case 0:
			float3 center;
			center.x = hit.transform[3][0];
			center.y = hit.transform[3][1];
			center.z = hit.transform[3][2];
			
			tIntersect = intersectSphere(center, hit.args[0], ray, t);
			break;
	}
	
	return tIntersect;
}

float shadow(const float3 origin, const Light light, out float3 lightDir)
{
	float3 lightPos;
	lightPos.x = light.transform[3][0];
	lightPos.y = light.transform[3][1];
	lightPos.z = light.transform[3][2];
	lightDir = normalize(lightPos - origin);
	
	Ray shadowRay;
	shadowRay.origin = origin;
	shadowRay.dir = lightDir;
	float t;
	
	uint count, stride;
	primitiveBuffer.GetDimensions(count, stride);
	count /= primitiveBufferStride;
	
	for (uint i = 0; i < 10; i++) {
		Primitive hit = fetchPrimitiveData(i);
		if( i >= count ) break;
		if (intersect(hit, shadowRay, t).x != -1) {
			if (t <= length(lightPos - origin)) {
				return 1.0;
			}
		}
	}
	
	return 0.0;
}

float2 trace(const Ray ray, out float tNear, out int hitObjIdx)
{
	float2 result = -1;
	tNear = INFINITY;
	uint count, stride;
	primitiveBuffer.GetDimensions(count, stride);
	count /= primitiveBufferStride;
	
	[loop]
	for (uint i = 0; i < count; i++) {
		float t = INFINITY;
		Primitive hit = fetchPrimitiveData(i);
		float2 tIntersect = intersect(hit, ray, t);
		
		if (tIntersect.x != -1 && t < tNear) {			
			result = tIntersect;
			hitObjIdx = i;
			tNear = t;
		}
	}
	
	return result;
}

float3 castRay(Ray ray, float4 pos)
{
	float3 accumColour = 0.0;
	float3 colourMask = 1.0;
	
	float3 origin = ray.origin;
	float3 dir = ray.dir;
	
	[fastopt]
	for (uint i = 0; i < bounces; i++) {
		Ray newRay;
		newRay.origin = origin;
		newRay.dir = dir;
		
		float t;
		int hitObjIdx = -1;
		if (trace(ray, t, hitObjIdx).x == -1) {
			//return accumColour;
			break;
		}
		
		float3 pHit = origin + dir * t;
		float3 nHit;
		float2 tex;
		float3 Fd;
		
		Primitive hit = fetchPrimitiveData(hitObjIdx);
		switch(hit.type) {
			case 0:
				float3 center;
				center.x = hit.transform[3][0];
				center.y = hit.transform[3][1];
				center.z = hit.transform[3][2];
				
				getSphereNormal(center, pHit, nHit, tex);
				break;
		}
		
		Material mat = fetchMaterialData(hit.materialIdx);
		Fd = mat.colour.xyz;

		origin = pHit;
		//dir = cosineWeightedDirection(nHit, SampleIndex + i, pos);
		dir = uniformlyRandomDirection(SampleIndex + i, pos);
		float dn = dot(dir,nHit);
		if( dn < 0 ){
			dir = -dir;
			dn = -dn;
		}
		
		colourMask *= Fd * dn;
		
		uint count, stride;
		lightBuffer.GetDimensions(count, stride);
		count /= lightBufferStride;
		
		float r = random(float3(12.9898, 78.233, 151.7182),(SampleIndex + i),pos);
		int j = floor(r*count);
		float3 lightDir;
		Light light = fetchLightData(j);
		float shadowIntensity = shadow(pHit, light, lightDir);
		float diffuse = saturate(dot(lightDir, nHit));
			
		accumColour += colourMask * (0.5 * diffuse * (1.0 - shadowIntensity))
					 * light.colour.xyz * light.intensity;
	}
	
	return accumColour;
}

// **********
// Camera
// **********
float3 UVtoEYE(float2 UV)
{
    return normalize(
        mul(
            float4(
                mul(float4((UV.xy * 2 - 1) * float2(1, -1), 0, 1), tPI).xy,
                1,
                0
            ),
            tVI
        ).xyz
    );
}

float3 render(const float2 uv, const Options options, float4 pos)
{
	float scale = tan(radians(options.fov * 0.5));
	float imageAspectRatio = TextureSize.x / TextureSize.y;
	Ray ray;
	ray.origin = tVI[3].xyz;
	ray.dir = UVtoEYE(uv.xy);
	
	return castRay(ray, pos);
}

// ********
// Shaders
// ********
vs2ps VS(VS_IN input)
{
    vs2ps output;
    output.PosWVP  = input.PosO;
    output.TexCd = input.TexCd;
    return output;
}

float4 PS(vs2ps In): SV_Target
{
	Options opts;
	opts.fov = 51.52;
	float3 colour = render(In.TexCd.xy, opts, In.PosWVP);
	
    return float4(colour, 1);
}

technique10 Render
{
	pass P0
	{
		SetVertexShader(CompileShader(vs_4_0, VS()));
		SetPixelShader(CompileShader(ps_5_0, PS()));
	}
}
