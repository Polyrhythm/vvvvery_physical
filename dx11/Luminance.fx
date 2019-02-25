Texture2D<float4> tex <string uiname="Texture";>;
 
cbuffer cbPerDraw : register( b0 )
{
	float4x4 tVP : LAYERVIEWPROJECTION;
	float2 dimensions = 1.0;
	bool toLinear = true;
};

cbuffer cbPerObj : register( b1 )
{
	float4x4 tW : WORLD;
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
    output.PosWVP  = mul(input.PosO,mul(tW,tVP));
    output.TexCd = input.TexCd;
    return output;
}

float getLuminance(const float3 colour)
{
	return 0.299 * colour.r + 0.587 * colour.g + 0.114 * colour.b;
}

float4 PS(vs2ps In): SV_Target
{
    float4 col = tex.Load(uint3(In.TexCd.xy * dimensions, 0));
	
	if (toLinear == true)
	{
		col = pow(col, 1/2.2);
	}
	
	const float lum = getLuminance(col.rgb);
    return float4(lum, lum, lum, 1.0);
	//return float4(col.rgb, 1.0);
}

technique10 Constant
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS() ) );
	}
}




