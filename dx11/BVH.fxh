#ifndef __BVH_FXH__
#define __BVH_FXH__

struct BVHNode
{
	float3 minBounds;
	float3 maxBounds;
	bool isLeaf;
	int leftIndex;
	int rightIndex;
	row_major float4x4 inverseTransform;
};

#endif