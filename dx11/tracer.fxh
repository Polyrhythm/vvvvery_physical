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
//#define USE_BVH // use bvh nodes for scene traversal

Surface lightIntersect(const Light hit, const uint lightIdx, const Ray ray)
{
	float t = INFINITY;
	Surface surf = (Surface)0;
	surf.matIdx = -1;
	surf.lightIdx = -1;
	float tIntersect = -1.0;
	
	switch (hit.type)
	{
		case AREA:
			float2 size = hit.params.xy;
			float unused = 0.0;
			tIntersect = intersectBox(ray, float3(size.xy, 0.01), 0, unused).x;
			break;
		
		case POINT:
			float3 pos = hit.transform[2].xyz;
			float t0, t1;
			bool sphereHit = intersectSphere(pos, 0.1, ray, t0, t1);
		
			if (false) // figure out why point light intersects don't work??
			{
				tIntersect = t0;
			}
			break;
		
		default:
			break;
	}
	
	if (tIntersect != -1.0)
	{
		surf.lightIdx = lightIdx;
	}
	
	return surf;
}

Surface intersectShadow(const Primitive hit, const Ray ray)
{
	float t = INFINITY;
	Surface surf = (Surface)0;
	surf.matIdx = -1;
	surf.lightIdx = -1;
	float2 tIntersect = float2(-1,-1);
	switch (hit.type) {
		case SPHERE:
			float t0, t1;
			bool sphereHit = intersectSphere(0, hit.args[0], ray, t0, t1);
			if (sphereHit)
			{
				tIntersect = float2(t0, t1);
			}
			break;
		
		case BOX:
			float3 size = hit.args.xyz;
			tIntersect = intersectBox(ray, size, 0, t);
			break;

		case SDF:
			Texture3D sdfVolume = fetchSDFTexture(0);
			float3 pos;
			tIntersect = intersectSDF(ray, sdfVolume, t, pos);
			break;
		
		case TRIANGLE:
			float3 a = vertexBuffer[hit.Va];
			float3 b = vertexBuffer[hit.Vb];
			float3 c = vertexBuffer[hit.Vc];
			Intersection intersect = intersectTriangle(a, b, c, ray);
			
			if (testTriangleIntersect(intersect) == false) break;
		
			tIntersect.x = 0; // successful intersection
			break;
	}
	
	if( tIntersect.x != -1 ){
		surf.matIdx = hit.materialIdx;
	}

	return surf;
}

Surface intersect(const Primitive hit, const Ray ray, out float t)
{
	t = INFINITY;
	Surface surf = (Surface)0;
	surf.matIdx = -1;
	surf.lightIdx = -1;
	float2 tIntersect = float2(-1,-1);
	switch (hit.type) {
		case SPHERE:
			float t0, t1;
			bool sphereHit = intersectSphere(0, hit.args[0], ray, t0, t1);
			t = t0;
			surf.pos = ray.origin + ray.dir * t0;
			if (sphereHit) {
				tIntersect = float2(t0, t1);
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
		
		case TRIANGLE:
			float3 a = vertexBuffer[hit.Va];
			float3 b = vertexBuffer[hit.Vb];
			float3 c = vertexBuffer[hit.Vc];
			Intersection intersect = intersectTriangle(a, b, c, ray);
			
			if (testTriangleIntersect(intersect) == false) break;
		
			float2 UVa = uvBuffer[hit.UVa];
			float2 UVb = uvBuffer[hit.UVb];
			float2 UVc = uvBuffer[hit.UVc];
		
			float3 Na = normalBuffer[hit.Na];
			float3 Nb = normalBuffer[hit.Nb];
			float3 Nc = normalBuffer[hit.Nc];
		
			t = intersect.T;
			tIntersect.x = 0; // successful intersection
			surf.pos = ray.origin + ray.dir * t;
			surf.uv = getTriangleUV(UVa, UVb, UVc, intersect);
			surf.nor = normalize(getBarycentric(Na, Nb, Nc, float2(intersect.U, intersect.V)));
			
			break;
	}
	
	if( tIntersect.x != -1 ){
		surf.matIdx = hit.materialIdx;
	}

	return surf;
}

Surface traceShadow(const Ray ray, float tMax)
{
	Surface surf = (Surface)0;
	surf.matIdx = -1;
	surf.lightIdx = -1;
	float tNear = INFINITY;
	int hitId = -1;
	Primitive hit;
	
	#ifdef USE_BVH
	uint count, stride;
	bvhBuffer.GetDimensions(count, stride);
	
	// Create a stack for keeping track of what nodes to test against
	int nodeStack[35];
	// Initial node is root
	nodeStack[0] = 0;
	// Start the offset at one since we have a root node
	int nodeStackOffset = 1;
	int escape = 0;
	
	[fastopt]
	while (nodeStackOffset > 0 && count > 0 && escape == 0)
	{
		BVHNode node = fetchBVHNodeData(nodeStack[--nodeStackOffset]);
		
		if (node.isLeaf == 1)
		{
			for (int i = 0; i < LEAF_SIZE; i++)
			{
				int leaf = node.leaves[i];
				if (leaf == -1)
				{
					break;
				}
				
				//checkIntersection(ray, tMax, i, hitId, tNear, surf, hit);
				Ray nray = (Ray)0;
				float t = INFINITY;
				hit = fetchPrimitiveData(leaf);

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
					escape = 1;
					break;
				}
			}

			continue;
		}
		
		// Check both child nodes for a hit
		float2 leftHit = -1;
		float2 rightHit = -1;
		
		BVHNode leftNode = fetchBVHNodeData(node.leftIndex);
		BVHNode rightNode = fetchBVHNodeData(node.rightIndex);
		
		leftHit = intersectBVH(ray, leftNode.minBounds, leftNode.maxBounds);
		rightHit = intersectBVH(ray, rightNode.minBounds, rightNode.maxBounds);
		
		if (leftHit.x != -1.0) nodeStack[nodeStackOffset++] = node.leftIndex;
		if (rightHit.x != -1.0) nodeStack[nodeStackOffset++] = node.rightIndex;
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

		if (nsurf.matIdx != -1 && t < tMax) {			
			hitId = i;
			surf = nsurf;
			// Object space normals into world space using transpose inverse transform.
			surf.nor = normalize(mul(float4(surf.nor,0),transpose(hit.inverseTransform)).xyz);
			break;
		}
	}
#endif

	return surf;
}

Surface trace(const Ray ray, float tMax )
{
	Surface surf = (Surface)0;
	surf.matIdx = -1;
	surf.lightIdx = -1;
	float tNear = INFINITY;
	int hitId = -1;
	Primitive hit;

#ifdef USE_BVH
	uint count, stride;
	bvhBuffer.GetDimensions(count, stride);
	
	float3 invDir = float3(1.0 / ray.dir.x, 1.0 / ray.dir.y, 1.0 / ray.dir.z);
	int dirIsNeg[3] = {
		invDir.x < 0,
		invDir.y < 0,
		invDir.z < 0
	};
	
	// Create a stack for keeping track of what nodes to test against
	int nodeStack[35];
	// Initial node is root
	nodeStack[0] = 0;
	// Start the offset at one since we have a root node
	int nodeStackOffset = 1;
	
	[fastopt]
	while (nodeStackOffset > 0 && count > 0)
	{
		BVHNode node = fetchBVHNodeData(nodeStack[--nodeStackOffset]);
		
		if (node.isLeaf == 1)
		{
			for (int i = 0; i < LEAF_SIZE; i++)
			{
				int leaf = node.leaves[i];
				if (leaf == -1)
				{
					break;
				}
				
				//checkIntersection(ray, tMax, i, hitId, tNear, surf, hit);
				Ray nray = (Ray)0;
				float t = INFINITY;
				hit = fetchPrimitiveData(leaf);

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
					surf.primIdx = leaf;
				}
			}

			continue;
		}
		
		// Check both child nodes for a hit
		float2 leftHit = -1;
		float2 rightHit = -1;
		
		BVHNode leftNode = fetchBVHNodeData(node.leftIndex);
		BVHNode rightNode = fetchBVHNodeData(node.rightIndex);
		
		leftHit = intersectBVH(ray, leftNode.minBounds, leftNode.maxBounds);
		rightHit = intersectBVH(ray, rightNode.minBounds, rightNode.maxBounds);
		
		// Decide which order to traverse children - we want to do front to back.
		int traverseForward = dirIsNeg[node.splitAxis - 1];
		if (traverseForward == 1)
		{
			if (leftHit.x != -1.0 && leftHit.x < tNear)
				nodeStack[nodeStackOffset++] = node.leftIndex;
			if (rightHit.x != -1.0 && rightHit.x < tNear)
				nodeStack[nodeStackOffset++] = node.rightIndex;
		}
		else
		{
			if (rightHit.x != -1.0 && rightHit.x < tNear)
				nodeStack[nodeStackOffset++] = node.rightIndex;
			if (leftHit.x != -1.0 && leftHit.x < tNear)
				nodeStack[nodeStackOffset++] = node.leftIndex;
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
			surf.primIdx = (int)i;
		}
	}
#endif
	
	if( hitId != -1 )
	{
		surf.pos = ray.origin + ray.dir * tNear;
		return surf;
	}
	
	// Check for hits on lights
	uint lightCount, lightStride;
	lightBuffer.GetDimensions(lightCount, lightStride);
	Light lightHit;
	
	[fastopt]
	for (uint il = 0; il < lightCount; il++) {
		Ray nray = (Ray)0;
		lightHit = fetchLightData(il);
		
		nray.origin = mul(float4(ray.origin,1), lightHit.inverseTransform).xyz;
		nray.dir = mul(float4(ray.dir,0), lightHit.inverseTransform).xyz;
		float rscale = 1.0/length(nray.dir);
		nray.dir *= rscale;
		
		Surface nsurf = lightIntersect(lightHit, il, nray);
		
		if (nsurf.lightIdx != -1)
		{
			surf = nsurf;
			break;
		}
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
		Surface surf = traceShadow(shadowRay, ldist);
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

float3 castRay(Ray ray, float4 pos, RandomSampler rSampler)
{
	
	// I'm leaving this option here to test stratified sampling performance.
	// Supposedly this can increase cache coherency.
#ifdef STRATIFIED
	RandomSampler randSampler = rSampler;
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
		
		Surface surf = trace(newRay, INFINITY);
		
		// Check to see if we hit a light
		if (surf.lightIdx != -1 && i > 0)
		{
			Light light = fetchLightData(surf.lightIdx);
			PrimitiveLightModel lm;
			
			float power = lm.getPower(light);
			float2 st = rSampler.SampleFloat2();
			float attenuation = lm.getAtten(light, surf.pos, st);
			accumColour += colourMask * light.colour.xyz * power * attenuation;
			break;
		}
		
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

		Material mat = fetchMaterialData(surf.matIdx);
		
		// Checks for textures to set the material parameters
		if (mat.albedoTexIdx != -1) {
			mat.colour = textures.SampleLevel(linearSampler,
				float3(surf.uv * mat.uvScale, mat.albedoTexIdx), 0);
		}
		if (mat.roughnessTexIdx != -1) {
			mat.roughness = textures.SampleLevel(linearSampler,
				float3(surf.uv * mat.uvScale, mat.roughnessTexIdx), 0).r;
		}
		if (mat.normalTexIdx != -1) {
			Primitive prim = fetchPrimitiveData(surf.primIdx);
			float2 uv1 = uvBuffer[prim.UVa];
			float2 uv2 = uvBuffer[prim.UVb];
			float2 uv3 = uvBuffer[prim.UVc];
			float3 v1 = vertexBuffer[prim.Va];
			float3 v2 = vertexBuffer[prim.Vb];
			float3 v3 = vertexBuffer[prim.Vc];
			
			float2 edge1UV = uv2 - uv1;
			float2 edge2UV = uv3 - uv1;
			
			float3 edge1 = v2 - v1;
			float3 edge2 = v3 - v1;
			
			float cp = edge1UV.y * edge2UV.x - edge1UV.x * edge2UV.y;
			float mult = 1.f/cp;
			float3 tangent, bitangent;
			tangent = (edge2 * edge1UV.y - edge1 * edge2UV.y) * mult;
			bitangent = (edge2 * edge1UV.x - edge1 * edge2UV.x) * mult;
			tangent -= surf.nor * dot(tangent, surf.nor);
			tangent = normalize(tangent);
			bitangent -= surf.nor * dot(bitangent, surf.nor);
			bitangent -= tangent*dot(bitangent, tangent);
			bitangent = normalize(bitangent);
			
			float3 normal = textures.SampleLevel(linearSampler,
				float3(surf.uv * mat.uvScale, mat.normalTexIdx), 0).xyz;
			normal = normalize(normal * 2.0 - 1.0);

			surf.nor = normal.z * surf.nor +
						normal.x * tangent -
						normal.y * bitangent; 
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

		if(count > 0 ){
			// Randomly pick one of our lights
			float r = randSampler.SampleFloat();
			int j = floor(r*count);
			Light light = fetchLightData(j);
			
			// Roughly approximate total light intensity
			PrimitiveLightModel lm;
			float power = lm.getPower(light);
			power *= count;
			
			float2 st = rSampler.SampleFloat2();
			float attenuation = lm.getAtten(light, surf.pos, st);
			float3 lightDir = lm.getLightDir(light, surf.pos, st);
			
			float shadowIntensity = shadow(surf, lightDir);
			float diffuse = max(0,dot(lightDir,surf.nor));

			BSDFSample lsamp = matModel.Evaluate(mat, surf, randSampler, -dir, lightDir);
			if( lsamp.type != NULL_BSDF_TYPE ){
				accumColour += colourMask * clamp(lsamp.value, 0, 4)
							* (light.colour.xyz * power * (1.0 - shadowIntensity)
			                        * attenuation);
			}
		}

		float3 nDir = 0;
		BSDFSample bsamp = matModel.Sample(mat, surf, randSampler, -dir, nDir);
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