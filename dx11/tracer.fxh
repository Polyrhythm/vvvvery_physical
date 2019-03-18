#ifndef __TRACER_FXH__
#define __TRACER_FXH__

#include "common.fxh"
#include "shaderinput.fxh"
#include "random.fxh"
#include "sampling.fxh"
#include "lights.fxh"
#include "materials.fxh"
#include "sky.fxh"
#include "textures.fxh"

//#define STRATIFIED // use stratified sampling
#define USE_BVH // use bvh nodes for scene traversal

Surface intersect(const Primitive hit, const Ray ray, out float t)
{
	Surface surf = (Surface)0;
	surf.matIdx = -1;
	float2 tIntersect = float2(-1,-1);
	switch (hit.type) {
		case SPHERE:
			tIntersect = intersectSphere(0, hit.args[0], ray, t);
			surf.pos = ray.origin + ray.dir * t;
			if( tIntersect.x != -1 ) {
				getSphereNormal(0, surf.pos, surf.nor);
				getSphereUV(surf.nor, surf.uv);
			}
			break;
		
		case BOX:
			float3 size = hit.args.xyz;
			tIntersect = intersectBox(ray, size, 0, t);
			surf.pos = ray.origin + ray.dir * t;
			if( tIntersect.x != -1 ) {
				getBoxNormal( size, 0, surf.pos, surf.nor);
				getBoxUV(size, 0, surf.nor, surf.pos, surf.uv); 
			}
			break;

		case SDF:
			Texture3D sdfVolume = fetchSDFTexture(0);
			float3 pos;
			tIntersect = intersectSDF(ray, sdfVolume, t, pos);
			surf.pos = pos;
			if (tIntersect.x != -1) getSDFNormal(sdfVolume, surf.pos, surf.nor);
			break;
	}
	
	if( tIntersect.x != -1 ){
		surf.matIdx = hit.materialIdx;
	}

	return surf;
}

void checkIntersection(const Ray ray, const float tMax, const uint idx,
	out uint hitIdx, out float tNear, out Surface surf, out Primitive hit)
{
	Ray nray = (Ray)0;
	float t = INFINITY;
	hit = fetchPrimitiveData(idx);

	// create new ray in object space using inverse transform.
	nray.origin = mul(float4(ray.origin,1),hit.inverseTransform).xyz;
	nray.dir = mul(float4(ray.dir,0),hit.inverseTransform).xyz;
	// rscale tells how distance changes between object and world space in the direction of the ray.
	float rscale = 1.0/length(nray.dir);
	nray.dir *= rscale;

	Surface nsurf = intersect(hit, nray, t);
	// t is currently in object space, so we scale it into world space.
	t *= rscale;

	if (nsurf.matIdx != -1 && t < tMax && t < tNear ) {			
		hitIdx = idx;
		tNear = t;
		surf = nsurf;
		// Object space normals into world space using transpose inverse transform.
		surf.nor = normalize(mul(float4(surf.nor,0),transpose(hit.inverseTransform)).xyz);
	}
}

Surface trace(const Ray ray, float tMax )
{
	Surface surf = (Surface)0;
	surf.matIdx = -1;
	float tNear = INFINITY;
	int hitId = -1;
	Primitive hit;

#ifdef USE_BVH
	int nodeIdx = 0;
	
	// Create a stack for keeping track of what nodes to test against
	int nodeStack[35];
	// Initial node is root
	nodeStack[0] = 0;
	// Start the offset at one since we have a root node
	int nodeStackOffset = 1;
	
	int primStack[35];
	int primStackOffset = 0;
	
	[fastopt]
	while (nodeStackOffset > 0)
	{
		BVHNode node = fetchBVHNodeData(nodeStack[--nodeStackOffset]);
		
		if (node.isLeaf == 1)
		{
			int i = node.leftIndex;
			primStack[primStackOffset++] = i;
			continue;
		}
		
		// Check both child nodes for a hit
		float2 bvHit = float2(-1, -1);
		BVHNode childNode;
		nodeIdx = -1;
		float bvT = INFINITY;
		
		[fastopt]
		for (uint x = 0; x < 2; x++)
		{
			if (x == 0)
			{
				childNode = fetchBVHNodeData(node.leftIndex);
			}
			else
			{
				childNode = fetchBVHNodeData(node.rightIndex);
			}
		
			bvHit = intersectBVH(ray, childNode.minBounds, childNode.maxBounds, bvT);
			
			if (bvHit.x != -1.0)
			{
				if (x == 0) nodeIdx = nodeStack[nodeStackOffset++] = node.leftIndex;
				else nodeIdx = nodeStack[nodeStackOffset++] = node.rightIndex;
			}
		}
	}
	
	[fastopt]
	while (primStackOffset > 0)
	{
		//checkIntersection(ray, tMax, i, hitId, tNear, surf, hit);
		Ray nray = (Ray)0;
		float t = INFINITY;
		int i = primStack[--primStackOffset];
		hit = fetchPrimitiveData(i);

		// create new ray in object space using inverse transform.
		nray.origin = mul(float4(ray.origin,1),hit.inverseTransform).xyz;
		nray.dir = mul(float4(ray.dir,0),hit.inverseTransform).xyz;
		// rscale tells how distance changes between object and world space in the direction of the ray.
		float rscale = 1.0/length(nray.dir);
		nray.dir *= rscale;

		Surface nsurf = intersect(hit, nray, t);
		// t is currently in object space, so we scale it into world space.
		t *= rscale;

		if (nsurf.matIdx != -1 && t < tMax && t < tNear ) {			
			hitId = i;
			tNear = t;
			surf = nsurf;
			// Object space normals into world space using transpose inverse transform.
			surf.nor = normalize(mul(float4(surf.nor,0),transpose(hit.inverseTransform)).xyz);
		}
	}
	
#else
	uint count, stride;
	primitiveBuffer.GetDimensions(count, stride);

	[fastopt]
	for (uint i = 0; i < count; i++) {
		//checkIntersection(ray, tMax, i, hitId, tNear, surf, hit);
		Ray nray = (Ray)0;
		float t = INFINITY;
		hit = fetchPrimitiveData(i);

		// create new ray in object space using inverse transform.
		nray.origin = mul(float4(ray.origin,1),hit.inverseTransform).xyz;
		nray.dir = mul(float4(ray.dir,0),hit.inverseTransform).xyz;
		// rscale tells how distance changes between object and world space in the direction of the ray.
		float rscale = 1.0/length(nray.dir);
		nray.dir *= rscale;

		Surface nsurf = intersect(hit, nray, t);
		// t is currently in object space, so we scale it into world space.
		t *= rscale;

		if (nsurf.matIdx != -1 && t < tMax && t < tNear ) {			
			hitId = i;
			tNear = t;
			surf = nsurf;
			// Object space normals into world space using transpose inverse transform.
			surf.nor = normalize(mul(float4(surf.nor,0),transpose(hit.inverseTransform)).xyz);
		}
	}
#endif
	
	if( hitId != -1 )
	{
		surf.pos = ray.origin + ray.dir * tNear;
	}
	return surf;
}

float shadow(const Surface surf, float3 lightDir)
{
	float ldist = length(lightDir);
	lightDir /= ldist;
	
	Ray shadowRay;
	shadowRay.origin = surf.pos;
	shadowRay.dir = lightDir;
	
	float shad = 0.0;
	if( dot(surf.nor,lightDir) > 0 ){
		float t = INFINITY;
		Surface surf = trace(shadowRay, ldist);
		if (surf.matIdx != -1) {
			shad = 1.0;
		}
	}
	
	return shad;
}

float3 getSkyColour(Ray ray) {
	float3 outColour = 0.0;
	
	switch (renderSky) {
		case 2:
			outColour = worldColour.rgb;
			break;
		
		default:
			break;
	}
	
	return outColour;
}

float3 getEnvMapColour(Ray ray) {
	float2 uv = getEquirectUV(ray.dir);
	return envMap.SampleLevel(linearSampler, uv, 0).rgb;
}

float3 castRay(Ray ray, float4 pos, const RandomSampler vsRandSampler)
{
	
	// I'm leaving this option here to test stratified sampling performance.
	// Supposedly this can increase cache coherency.
#ifdef STRATIFIED
	RandomSampler randSampler = vsRandSampler;
#else
	uint seed = jenkins_hash(uint3(pos.xy,SampleIndex));
	RandomSampler randSampler = RandomSampler::New( seed );
#endif

	float3 accumColour = 0.0;
	float3 colourMask = 1.0;
	
	float3 origin = ray.origin;
	float3 dir = ray.dir;
	
	int hitObjIdx;

	float pdf = 0;
	PrimitiveMaterialModel matModel;

	[fastopt]for (uint i = 0; i < bounces; i++) {
		Ray newRay;
		newRay.origin = origin;
		newRay.dir = dir;
		
		
		float t;
		Surface surf = trace(newRay, INFINITY);
		if (surf.matIdx == -1) {
			// Hit nothing...
			switch (renderSky) {
				case 1:
					accumColour += colourMask * getEnvMapColour(newRay);
					break;
				
				case 2:
					accumColour += colourMask * getSkyColour(newRay);
					break;
				
				default:
					break;
			}
			
			break;
		}

		float3 nDir = (float3)0;
		Material mat = fetchMaterialData(surf.matIdx);
		
		// Check to see if we should use a texture for albedo
		if (mat.texIdx != -1) {
			mat.colour = textures.SampleLevel(linearSampler,
				float3(surf.uv * mat.uvScale, mat.texIdx), 0);
		}
		
		if( mat.type == EMISSIVE ){
			// only use mat.intensity for emissives
			accumColour += colourMask * mat.colour.xyz * mat.intensity;
			break;
		}

		// step back slightly to avoid self intersection.
		surf.pos -= dir * 0.0001;

		uint count, stride;
		lightBuffer.GetDimensions(count, stride);

		if( count > 0 ){
			// Randomly pick one of our lights
			float r = randSampler.SampleFloat();
			int j = floor(r*count);
			Light light = fetchLightData(j);
			
			// Roughly approximate total light intensity
			light.intensity *= count;
			
			PrimitiveLightModel lm;
			float attenuation = lm.getAtten(light, surf.pos);
			float3 lightPos = lm.getPos(light);
			float3 lightDir = normalize(lightPos - surf.pos);
			
			float shadowIntensity = shadow(surf, lightDir);
			float diffuse = max(0,dot(lightDir,surf.nor));

			BSDFSample lsamp = matModel.Evaluate( mat, surf, -dir, lightDir );
			if( lsamp.type != NULL_BSDF_TYPE ){
				accumColour += colourMask * clamp(lsamp.value, 0, 4)
							* (light.colour.xyz * light.intensity * (1.0 - shadowIntensity)
			                        * attenuation);
			}
		}

		BSDFSample bsamp = matModel.Sample( mat, surf, randSampler, -dir, nDir );
		if( bsamp.type == NULL_BSDF_TYPE ) break;
		
		float3 F = bsamp.value;
		if( bsamp.pdf > 0.0 && (F.x + F.y + F.z) > 0.0 ){
			colourMask *= clamp(F / bsamp.pdf,0,4);
		} else {
			break;
		}

		origin = surf.pos;
		dir = nDir;
	}

	return accumColour;
}

#endif