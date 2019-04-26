#ifndef __MATH_FXH__
#define __MATH_FXH__

#define PI (3.1415926535897932384626433832795)
#define PI2 (6.283185307179586476925286766559)
#define PI4 (12.566370614359172953850573533118)
#define INV_PI (0.31830988618379067153776752674503)
#define PIOVER2 (1.57079632679)
#define PIOVER180 (0.01745329251)

#define COS45 (0.70710678118654752440084436210485)

#define SQRT2 (1.4142135623730950488016887242097)

#define INFINITY (1.#INF)

void makeOrthonormalBasis( float3 N, out float3 T, out float3 B ){
	float3 h = N;
	if( abs(N.x) <= abs(h.y) && abs(h.x) <= abs(h.z) ){
		h.x = 1.0;
	} else if( abs(h.y) <= abs(h.x) && abs(h.y) <= abs(h.z) ){
		h.y = 1.0;
	} else {
		h.z = 1.0;
	}

	T = normalize(cross(h,N));
	B = normalize(cross(T,N));
}

float signum(float a)
{
	return a < 0.0 ? -1.0 : 1.0;
}

#endif