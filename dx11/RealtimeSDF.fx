Texture3D sdfVolume <string uiname="SDF Volume";>;

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
	const float EPS = 0.002;
	const int MAX_STEPS = 128;
	
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

technique10 Render
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS() ) );
	}
}




