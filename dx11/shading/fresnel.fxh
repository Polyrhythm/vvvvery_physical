#ifndef __FRESNEL_FXH__
#define __FRESNEL_FXH__

// schlick
float3 getFresnel(const float LoH, const float3 f0)
{
	return f0 + (1.0 - f0) * pow(1.0 - LoH, 5.0);
}

#endif