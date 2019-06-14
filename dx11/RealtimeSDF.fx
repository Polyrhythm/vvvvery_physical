/**
 * Testbed for raymarching shenanigans.
 */

#include "textures.fxh"

Texture3D sdfVolume <string uiname="SDF Volume";>;
Texture2D skyTexture <string uiname="Sky Texture";>;
Texture2D skyConvolution <string uiname="Sky Diffuse Convolution";>;
Texture3D densityNoise <string uiname="Density noise texture";>;

#define EPS 0.002

SamplerState volumeSampler : IMMUTABLE
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
	AddressW = Clamp;
};
 
cbuffer cbPerDraw : register( b0 )
{
	float4x4 tVP : LAYERVIEWPROJECTION;
	float4x4 tVI : VIEWINVERSE;
	float4x4 tPI : PROJECTIONINVERSE;
	float3 lightDir = float3(0.0, 1.0, 0.0);
};

cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
	float4x4 sdfTransform <string uiname="SDF Transform";>;
};

struct VS_IN
{
	float4 PosO : POSITION;
	float4 TexCd : TEXCOORD0;

};

struct vs2ps
{
    float4 PosWVP: SV_Position;
    float4 TexCd: TEXCOORD0;
};

vs2ps VS(VS_IN input)
{
    vs2ps output;
    output.PosWVP  = mul(input.PosO, tW);
    output.TexCd = input.TexCd;
    return output;
}

float trace(float3 ro, float3 rd, out float3 pos, out int steps)
{
	float t = 0.1;
	const float MAX_DIST = 100.0;
	const int MAX_STEPS = 256;
	
	for (steps = 0; steps < MAX_STEPS; steps++) {
		if (t > MAX_DIST) {
			return -1.0;
		}
		
		pos = ro + rd * t;
		pos = mul(float4(pos, 1), sdfTransform).xyz;
		float h = sdfVolume.SampleLevel(volumeSampler, pos, 0).r;
		
		if (h < EPS) {
			return 1.0;
		}
		
		t += h;
	}
	
	return -1.0;
}

float traceWithDist(float3 ro, float3 rd, out float3 startPos, out float3 endPos, out float dist)
{
	float t = 0.1;
	const float MAX_DIST = 100.0;
	const int MAX_STEPS = 256;
	
	for (int steps = 0; steps < MAX_STEPS; steps++) {
		if (t > MAX_DIST) {
			return -1.0;
		}
		
		startPos = ro + rd * t;
		startPos = mul(float4(startPos, 1), sdfTransform).xyz;
		float h = sdfVolume.SampleLevel(volumeSampler, startPos, 0).r;
		
		if (h < EPS) {
			t += 0.1;
			for (int isteps = 0; isteps < MAX_STEPS; isteps++)
			{
				endPos = ro + rd * t;
				endPos = mul(float4(endPos, 1), sdfTransform).xyz;
				
				if (t > MAX_DIST) return -1.0;
				
				float hi = sdfVolume.SampleLevel(volumeSampler, endPos, 0).r;
				
				if (hi >= EPS)
				{
					dist = length(startPos - endPos);
					return t;
				}
				
				t += abs(hi);
			}
		}
		
		t += h;
	}
	
	dist = -1.0;
	return -1.0;
}

float3 getNormal(float3 pos)
{
	float2 eps = float2(0.0, 0.02);
	float3 n;
	n.x = sdfVolume.SampleLevel(volumeSampler, pos + eps.yxx, 0).r
		- sdfVolume.SampleLevel(volumeSampler, pos - eps.yxx, 0).r;
	n.y = sdfVolume.SampleLevel(volumeSampler, pos + eps.xyx, 0).r
		- sdfVolume.SampleLevel(volumeSampler, pos - eps.xyx, 0).r;
	n.z = sdfVolume.SampleLevel(volumeSampler, pos + eps.xxy, 0).r
		- sdfVolume.SampleLevel(volumeSampler, pos - eps.xxy, 0).r;
	
	return normalize(n);
}

float3 render(float3 ro, float3 rd) {
	float3 pos;
	int steps;
	float t = trace(ro, rd, pos, steps);
	
	if (t == -1.0) {
		return 0.0;
	}
	
	float3 colour = 0.0;
	float3 n = getNormal(pos);
	
	const int NUM_LIGHTS = 3;
	const float4 lights[NUM_LIGHTS] = {
		float4(1.0, 1.0, 0.0, 1.0),
		float4(-0.5, 0.5, 3.0, 0.5),
		float4(-1.0, 0.5, 3.0, 0.25)
	};
	
	float amb = saturate(0.5 + 0.5 * n.y);
	
	float3 diffuseColour = float3(0.1, 0.2, 0.3);
	
	for (int i = 0 ; i < NUM_LIGHTS; i++) {
		float3 lightDir = normalize(lights[i].xyz - pos);
		float diffuse = saturate(dot(n, lightDir));
		float3 Fd = diffuse * diffuseColour;
		
		float3 h = normalize(-rd + lightDir);
		float3 spec = pow(saturate(dot(n, h)), 64.0);
		float3 specColour = 1.0;
		float3 Fs = spec * specColour;
		
		float fre = (1.0 - diffuse) * 1.5;
		
		colour += Fd + Fs * fre * lights[i].w;
	}
	
	return colour + amb * 0.01;
}

float phaseFunction()
{
	return 1.0 / (4.0 * PI);
}

float4 renderVolume(float3 ro, float3 rd, out float3 normal)
{
	float3 pos = 0.0;
	float3 endPos = 0.0;
	float dist = 0.0;
	float t = traceWithDist(ro, rd, pos, endPos, dist);
	
	if (t == -1.0)
	{
		return float4(0.0, 0.0, 0.0, 0.0);
	}
	
	normal = getNormal(pos);
	
	float2 indirectUVDown = getEquirectUV(float3(0.001,-1.,0.001));
	float3 indirectDown = skyConvolution.Sample(volumeSampler, indirectUVDown).rgb;
	
	float2 indirectUVUp = getEquirectUV(float3(0.001,1.,0.001));
	float3 indirectUp = skyConvolution.Sample(volumeSampler, indirectUVUp).rgb;
	
	float vT = 0.01;
	float transmittance = 1.0;
	float3 scatteredLight = 0.0;
	const int MAX_STEPS = 100;
	const float dd = dist / (float)MAX_STEPS;

	float material = 0.0;
	
	float3 volumePos = pos + rd * vT;
	for (int volumeSteps = 0; volumeSteps < MAX_STEPS; volumeSteps++)
	{		
		float density = 0.5;//0.5 + 0.5 * densityNoise.SampleLevel(volumeSampler, volumePos * 0.001, 0).r;
		float norY = saturate((volumePos.y - pos.y) * (1.0 / dist));
		float3 ambient = lerp(indirectDown, indirectUp, norY);
		
		float3 S = ambient;
		
		float dTrans = exp(-density * dd);
		
		scatteredLight += density * S * phaseFunction() * transmittance * dd;
		scatteredLight += 0.1;
		transmittance *= dTrans;
		
		vT += dd;
		volumePos += rd * vT;
	}
	
	return float4(scatteredLight, 1.0 - transmittance);
}

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

float4 PS(vs2ps In): SV_Target
{
	float3 ro = tVI[3].xyz;
	float3 rd = UVtoEYE(In.TexCd.xy);
	
	float3 colour = render(ro, rd);
	
	const float3 GAMMA = 1.0 / 2.2;
	colour = pow(colour, GAMMA);
	
    return float4(colour, 1.0);
}

float4 PS_Volume(vs2ps In): SV_Target
{
	float3 ro = tVI[3].xyz;
	float3 rd = UVtoEYE(In.TexCd.xy);
	
	float2 eyeUV = getEquirectUV(rd);
	float3 sky = skyTexture.Sample(volumeSampler, eyeUV).rgb;
	
	float3 normal = 0.0;
	float4 transmittance = renderVolume(ro, rd, normal);
	
	float2 indirectUV = getEquirectUV(normal);
	float3 indirectDiffuse = skyConvolution.Sample(volumeSampler, indirectUV).rgb;
	
	float3 colour = sky + transmittance.a;
	
    return float4(colour, 1.0);
}

technique10 Render
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS() ) );
	}
}

technique10 RenderVolume
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS_Volume() ) );
	}
}




