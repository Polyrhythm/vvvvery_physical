#ifndef __TRACER_FXH__
#define __TRACER_FXH__

#include "common.fxh"
#include "shaderinput.fxh"
#include "sampling.fxh"

float2 intersect(const Primitive hit, const Ray ray, out float t)
{
	float2 tIntersect = float2(-1,-1);
	switch (hit.type) {
		// sphere
		case 0:
			float3 center;
			center.x = hit.transform[3][0];
			center.y = hit.transform[3][1];
			center.z = hit.transform[3][2];
			
			tIntersect = intersectSphere(center, hit.args[0], ray, t);
			break;
		
		// box
		case 1:
			float3 size = hit.args.xyz;
			
			tIntersect = intersectBox(ray, size, hit.transform, t);
			break;
	}
	
	return tIntersect;
}

Surface trace(const Ray ray)
{
	Surface surf = (Surface)0;
	float2 result = -1;
	float tNear = INFINITY;
	uint count, stride;
	primitiveBuffer.GetDimensions(count, stride);
	count /= primitiveBufferStride;
	surf.matIdx = -1;
	int hitId = -1;
	Primitive hit;

	[fastopt]
	for (uint i = 0; i < count; i++) {
		float t = INFINITY;
		hit = fetchPrimitiveData(i);
		float2 tIntersect = intersect(hit, ray, t);
		
		if (tIntersect.x != -1 && t < tNear) {			
			hitId = i;
			tNear = t;
		}
	}
	
	if( hitId != -1 )
	{
		hit = fetchPrimitiveData(hitId);
		surf.matIdx = hit.materialIdx;
		surf.pos = ray.origin + ray.dir * tNear;
		switch(hit.type) {
			// sphere
			case 0:
				float3 center;
				center.x = hit.transform[3][0];
				center.y = hit.transform[3][1];
				center.z = hit.transform[3][2];
				
				getSphereNormal(center, surf.pos, surf.nor, surf.tex);
				break;
			
			// box
			case 1:
				float3 size = hit.args.xyz;
			
				getBoxNormal(size, hit.transform, surf.pos, surf.nor, surf.tex);
				break;
		}
	}
	return surf;
}

float shadow(const float3 origin, const Light light, out float3 lightDir,
	out float3 lightPos)
{
	lightPos.x = light.transform[3][0];
	lightPos.y = light.transform[3][1];
	lightPos.z = light.transform[3][2];
	lightDir = normalize(lightPos - origin);
	
	Ray shadowRay;
	shadowRay.origin = origin;
	shadowRay.dir = lightDir;
	
	float shad = 0.0;
	
	Surface surf = trace(shadowRay);
	if (surf.matIdx != -1) {
		shad = 1.0;
	}
	
	return shad;
}

float3 castRay(Ray ray, float4 pos)
{
	uint seed = jenkins_hash(uint3(pos.xy,SampleIndex));
	LCG rng = LCG::New(seed);

	float3 accumColour = 0.0;
	float3 colourMask = 1.0;
	
	float3 origin = ray.origin;
	float3 dir = ray.dir;
	
	int hitObjIdx;
	
	[fastopt] for (uint i = 0; i < bounces; i++) {
		Ray newRay;
		newRay.origin = origin;
		newRay.dir = dir;
		
		float t;
		//hitObjIdx = -1;
		Surface surf = trace(newRay);
		if (surf.matIdx == -1) {
			break;
		}

		Material mat = fetchMaterialData(surf.matIdx);
		float3 Fd = mat.colour.xyz;

		origin = surf.pos;
		dir = cosineWeightedDirection(surf.nor, rng.GetFloat2());
		
		colourMask *= Fd;
		
		uint count, stride;
		lightBuffer.GetDimensions(count, stride);
		count /= lightBufferStride;
		
		float r = rng.GetFloat();
		int j = floor(r*count);
		float3 lightDir, lightPos;
		Light light = fetchLightData(j);
		float shadowIntensity = shadow(surf.pos, light, lightDir, lightPos);
		float diffuse = getLambertianDiffuse(lightDir, surf.nor);
		float attenuation = getAttenuation(surf.pos, lightPos); 
		
		accumColour += colourMask * diffuse
			* (light.colour.xyz * light.intensity * (1.0 - shadowIntensity)
		                        * lightAttenuation);
	}
	
	return accumColour;
}

#endif