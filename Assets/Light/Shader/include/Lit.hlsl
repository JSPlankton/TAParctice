#ifndef CUSTOM_URP_PHONG_INCLUDE
#define CUSTOM_URP_PHONG_INCLUDE

struct Attributes
{
    float4 pos_OS : POSITION;
    float3 normal_OS : NORMAL;
    float2 texcoord : TEXCOORD0;
    float4 tangent : TANGENT;
};

struct Varyings
{
    float4 pos_CS : SV_POSITION;        //裁剪空间下的顶点数据
    float2 texcoord : TEXCOORD0;
    float3 normal_WS : TEXCOORD1;       //世界空间下的法线数据
    float3 pos_WS : TEXCOORD2;          //世界空间下的顶点数据
    float3 tangent_WS : TEXCOORD3;
    float3 binnormal_WS : TEXCOORD4;
};

CBUFFER_START(UnityPerMaterial)
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

TEXTURE2D(_AOMap);
SAMPLER(sampler_AOMap);

TEXTURE2D(_NormalMap);
SAMPLER(sampler_NormalMap);

TEXTURE2D(_SpecMaskMap);
SAMPLER(sampler_SpecMaskMap);


half4 _BaseMap_ST;

half4 _AmbientColor;
half _Shininess;
half _SpecIntensity;
half _NormalIntensity;
CBUFFER_END

/// lightColor：光源颜色
/// lightDirectionWS：世界空间下光线方向
/// lightAttenuation：光照衰减
/// normalWS：世界空间下法线
/// viewDirectionWS：世界空间下视角方向
half3 LightingBased(half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 normalWS, half3 viewDirectionWS)
{
    // 兰伯特漫反射计算
    half NdotL = saturate(dot(normalWS, lightDirectionWS));
    half3 radiance = lightColor * (lightAttenuation * NdotL);
    // BlinnPhong高光反射
    half3 halfDir = normalize(lightDirectionWS + viewDirectionWS);
    half3 specColor = lightColor * pow(saturate(dot(normalWS, halfDir)), _Shininess);
                
    return radiance + specColor;
}

half3 LightingBased(Light light, half3 normalWS, half3 viewDirectionWS)
{
    // 注意light.distanceAttenuation * light.shadowAttenuation，这里已经将距离衰减与阴影衰减进行了计算
    return LightingBased(light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation, normalWS, viewDirectionWS);
}

Varyings LitPassVert(Attributes input)
{
	Varyings output;

    output.pos_CS = TransformObjectToHClip(input.pos_OS);
    output.texcoord = TRANSFORM_TEX(input.texcoord, _BaseMap);
    output.normal_WS = normalize( mul(half4(input.normal_OS, 0.0), UNITY_MATRIX_I_M).xyz );
    output.tangent_WS = normalize( mul(UNITY_MATRIX_M, float4(input.tangent.xyz, 0.0)));
    output.binnormal_WS = cross( output.normal_WS, output.tangent_WS ) * input.tangent.w;
    output.pos_WS = mul(UNITY_MATRIX_M, input.pos_OS).xyz;

	return output;
}

real4 LitPassFragment(Varyings input) : SV_TARGET
{

    half4 base_color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.texcoord);
    half4 ao_color = SAMPLE_TEXTURE2D(_AOMap, sampler_AOMap, input.texcoord);
    half4 spec_mask = SAMPLE_TEXTURE2D(_SpecMaskMap, sampler_SpecMaskMap, input.texcoord);
    half4 normal_map = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.texcoord);
    half3 normal_data = UnpackNormal(normal_map);
    normal_data.xy = normal_data.xy * _NormalIntensity;
    //NORMAL
    half3 normal_dir = normalize(input.normal_WS);
    half3 tangent_dir = normalize(input.tangent_WS);
    half3 binnormal_dir = normalize(input.binnormal_WS);

    float3x3 TBN = float3x3(tangent_dir, binnormal_dir, normal_dir);
    normal_dir = normalize( mul( normal_data.xyz, TBN ) );
    //normal_dir = normalize( tangent_dir * normal_data.x * _NormalIntensity + binnormal_dir * normal_data.y * _NormalIntensity + normal_dir * normal_data.z );

    //OTHER DIR
    half3 view_dir = normalize(_WorldSpaceCameraPos.xyz - input.pos_WS);
    Light mainLight = GetMainLight();
    half3 light_dir = normalize(mainLight.direction);    

    //DIFFUSE
    half NdotL = dot(normal_dir, light_dir);
    half3 diffuse_color = max(0.0, NdotL) * mainLight.color * base_color.xyz;

    //SPECULAR
    half3 reflect_dir = reflect(-light_dir, normal_dir);   //光的反射方向
    half RdotV = dot(reflect_dir, view_dir);
    half3 spec_color = pow(max(0.0, RdotV), _Shininess)  * mainLight.color * _SpecIntensity * spec_mask;    //去掉负数,_Shininess次方

    //MULTI LIGHT
    #ifdef _AdditionalLights
        uint pixelLightCount = GetAdditionalLightsCount();
        for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
        {
            // 获取其他光源
            Light light = GetAdditionalLight(lightIndex, input.pos_WS);
            diffuse_color += LightingBased(light, normal_dir, view_dir);
        }
    #endif

    half3 final_color = (diffuse_color + spec_color + _AmbientColor.xyz) * ao_color;

	return half4(final_color, 1);
}


#endif