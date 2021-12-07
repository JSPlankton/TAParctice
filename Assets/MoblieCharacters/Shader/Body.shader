Shader "JSU URP/Characters/Body"
{
    Properties
    {
        _BaseMap ("Base Map", 2D) = "white" {}
        _NormalMap ("Normal Map", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #pragma vertex BodyVertex
            #pragma fragment BodyFragment

            struct Attributes
            {
                float4 pos_OS : POSITION;
                float3 normal_OS : NORMAL;
                float2 texcoord : TEXCOORD0;
                float4 tangent_OS : TANGENT;
            };

            struct Varyings
            {
                float4 pos_CS : SV_POSITION;
                float2 texcoord : TEXCOORD0;
                float3 normal_WS : TEXCOORD1;
                float3 pos_WS : TEXCOORD2;
                float3 tangent_WS : TEXCOORD3;
                float3 binormal_WS : TEXCOORD4;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            CBUFFER_START(UnityPerMaterial)
            half4 _BaseMap_ST;
            CBUFFER_END



            Varyings BodyVertex(Attributes input)
            {
                Varyings output;
                output.pos_CS = TransformObjectToHClip(input.pos_OS);
                output.texcoord = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.normal_WS = normalize( mul(half4(input.normal_OS, 0.0), UNITY_MATRIX_I_M).xyz );
                output.tangent_WS = normalize(mul(UNITY_MATRIX_M, half4(input.tangent_OS.xyz, 0.0)));
                output.binormal_WS = cross(output.normal_WS, output.tangent_WS) * input.tangent_OS.w;
                output.pos_WS = mul(UNITY_MATRIX_M, input.pos_OS).xyz;

                return output;
            }
            
            real4 BodyFragment(Varyings input) : SV_TARGET
            {
                //固有色-BaseColor
                half4 base_color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.texcoord);

                //法线-NormalMap
                half4 normal_map = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.texcoord);
                half3 normalData = UnpackNormal(normal_map);
                half3 normal_dir = normalize(input.normal_WS);
                half3 tangent_dir = normalize(input.tangent_WS);
                half3 binormal_dir = normalize(input.binormal_WS);

                float3x3 TBN = float3x3(tangent_dir, binormal_dir, normal_dir);
                normal_dir = normalize(mul(normalData.xyz, TBN));

                //光源-Light
                Light mainLight = GetMainLight();
                half3 light_dir = normalize(mainLight.direction);

                //漫反射-Diffuse
                half NdotL = dot(normal_dir, light_dir);
                half3 diffuse_color = max(0.0, NdotL) * mainLight.color * base_color.xyz;
                
                half3 final_color = diffuse_color;

                return half4(final_color, 0.0);
            }

            ENDHLSL
        }
    }
}
