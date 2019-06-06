#include "math.fxh"

RWTexture2D<float3> OutputBuffer : BACKBUFFER;

Texture2D envMap;

#define ThreadsX 32
#define ThreadsY 32

#define SIZE 256

[numthreads(ThreadsX, ThreadsY, 1)]
void CS_Diffuse(uint3 tid : SV_DispatchThreadID)
{
	const float xInterval = float(PI2) / float(SIZE);
	const float yInterval = float(PI) / float(SIZE);
	
	const float phi = xInterval * tid.x;
	const float theta = yInterval * tid.y;
	
	float3 Wo = float3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi));
	float3 colour = envMap.Load(int3(tid.xy, 0)).rgb;
	
	float3 sum = 0.0;
	for (int y = 0; y < SIZE; y++)
	{
		for (int x = 0; x < SIZE; x++)
		{
			float3 incident = envMap.Load(int3(x, y, 0)).rgb + 0.01;
			
			const float Wi_phi = xInterval * (float)x;
			const float Wi_theta = yInterval * (float)y;
			
			float3 Wi = float3(
				sin(Wi_theta) * cos(Wi_phi),
				cos(Wi_theta),
				sin(Wi_theta) * sin(Wi_phi)
			);
			
			sum += incident * saturate(dot(Wi, Wo));
		}
	}
	
	OutputBuffer[tid.xy] = sum * 0.0001;// / ((float)SIZE * (float)SIZE);
}

technique11 Diffuse
{
	pass P0
	{
		SetComputeShader( CompileShader( cs_5_0, CS_Diffuse() ) );
	}
}




