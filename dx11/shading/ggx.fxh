#ifndef __GGX_FXH__
#define __GGX_FXH__

#include "math.fxh"

// GGX (Trowbridge-Reitz
float getNDF(const float NoH, float a2)
{
	float denom = NoH * NoH * (a2 - 1) + 1;
	
	return a2 / (PI * denom * denom);
}

// GGX as seen in http://graphicrants.blogspot.com/2013/08/specular-brdf-reference.html
float getGDF(const float NoV, const float a2)
{
	float denom = NoV + sqrt(a2 + (1.0 - a2) * NoV * NoV);
	
	return (2 * NoV) / denom;
}

#endif