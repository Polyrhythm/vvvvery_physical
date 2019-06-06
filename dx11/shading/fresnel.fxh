#ifndef __FRESNEL_FXH__
#define __FRESNEL_FXH__

// schlick
float3 fresnel_schlick(const float VoH, const float3 f0)
{
	// Assuming f90 is 1.0
	float f = pow(1.0 - VoH, 5.0);
	return f + f0 * (1.0 - f);
}

#endif