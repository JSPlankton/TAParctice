Shader "JSU URP/PBR/PBR_Test"
{
    Properties
    {
        [MainColor] _BaseColor("Color", Color) = (1,1,1,1)
        [Header(Sampling Map)]
        [Space]
        [MainTexture]_BaseMap ("Albedo(RGB)", 2D) = "white" {}
        _MaskMap ("Metallic(R), AO(G) Smoothness(A)", 2D ) = "white" {}
        [Normal]_Normal ("Normal", 2D) = "bump" {}
        [Space(20)]
        [Header(Material Paramters)]
        [Space]
        _Metallic ("Metallic", Range(0, 1)) = 1.0
        _RoughnessAdjust("Roughness Adjust", Range(-1,1)) = 0.0
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl"
            #pragma vertex Vertex
            #pragma fragment Fragment

            struct Attributes
            {
                float4 pos_OS : POSITION;       //物体空间下的顶点坐标
                float4 tangent_OS : TANGENT;    //切线坐标
                float3 normal_OS : NORMAL;      //法线坐标
                float2 texcoord : TEXCOORD0;
                float2 texcoord1 : TEXCOORD1;
                float2 texcoord2 : TEXCOORD2;
                float2 texcoord3 : TEXCOORD3;
                float2 texcoord4 : TEXCOORD4;
                float4 color : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 pos_CS : SV_POSITION;        //裁剪空间位置
                float2 uv : TEXCOORD0;              //贴图UV
                half3 pos_WS : TEXCOORD1;           //世界坐标
                half3 normal_WS : TEXCOORD2;        //世界空间法线坐标(TBN矩阵)
                half3 tangent_WS : TEXCOORD3;       //世界空间切线坐标(TBN矩阵)
                half3 binormal_WS : TEXCOORD4;      //世界空间副切线坐标(TBN矩阵)
                half  fogFactor : TEXCOORD5;        //雾效坐标
                float4 shadowCoord : TEXCOORD6;     //阴影ShadowMap采样坐标
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
            TEXTURE2D(_MaskMap);
            SAMPLER(sampler_MaskMap);

            CBUFFER_START(UnityPerMaterial)
            half4 _BaseMap_ST;

            half _RoughnessAdjust;
            CBUFFER_END

            //----核心方程D项 法线微表面分布函数 = 直接光的高光计算----
            float D_Function(float NdotH, float roughness)
            {
                float a2 = roughness * roughness;
                float NdotH2 = NdotH * NdotH;

                //公式代入
                float nom = a2;
                float denom = NdotH2 * (a2 - 1) + 1;
                denom = denom * denom * PI;

                return nom / denom;
            }

            //----核心方程G项 几何函数 计算光线方向与视角方向被物体本身微观几何遮挡的比重----
            //----Begin----
            float G_Section(float dot, float k)
            {
                float nom = dot;
                float denom = lerp(dot, 1, k);
                return nom / denom;
            }
            
            float G_Function(float NdotL, float NdotV, float roughness)
            {
                //k系数：直接光与间接光计算不同
                //       直接光：float k = pow(1 + roughness, 2) / 8;
                //       间接光：float k = pow(roughness, 2) / 2;
                float k = pow(1 + roughness, 2) / 8;
                float Gnl = G_Section(NdotL, k);
                float Gnv = G_Section(NdotV, k);

                return Gnl * Gnv;
            }
            float EnvG_Function(float NdotL, float NdotV, float roughness)
            {
                //k系数：直接光与间接光计算不同
                //       直接光：float k = pow(1 + roughness, 2) / 8;
                //       间接光：float k = pow(roughness, 2) / 2;
                float k = pow(roughness, 2) / 2;
                float Gnl = G_Section(NdotL, k);
                float Gnv = G_Section(NdotV, k);

                return Gnl * Gnv;
            }
            //----End----

            //----核心方程F项 菲涅尔函数
            real3 F_Function(float HdotL, float3 F0)
            {
                float fresnel = exp2( (-5.55473 * HdotL - 6.98316) * HdotL );
                return lerp(fresnel, 1, F0);
            }
            //间接光的菲尼尔计算
            real3 EnvF_Function(float NdotV, float3 F0, float roughness)
            {
                float fresnel = exp2( (-5.55473 * NdotV - 6.98316) * NdotV );
                return F0 + fresnel * saturate(1 - roughness - F0);
            }

            //间接光漫反射 球谐函数 光照探针
            real3 SH_IndirectionDiff(float3 normalWS)
            {
                real4 SHCoefficients[7];
                SHCoefficients[0] = unity_SHAr;
                SHCoefficients[1] = unity_SHAg;
                SHCoefficients[2] = unity_SHAb;
                SHCoefficients[3] = unity_SHBr;
                SHCoefficients[4] = unity_SHBg;
                SHCoefficients[5] = unity_SHBb;
                SHCoefficients[6] = unity_SHC;

                float3 color = SampleSH9(SHCoefficients, normalWS);
                return max(0, color);
            }

            Varyings Vertex(Attributes input)
            {
                Varyings output;
                output.pos_CS = TransformObjectToHClip(input.pos_OS);
                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.pos_WS = mul(UNITY_MATRIX_M, input.pos_OS).xyz;
                //TBN矩阵世界坐标
                output.normal_WS = normalize( mul(half4(input.normal_OS, 0.0), UNITY_MATRIX_I_M).xyz );
                output.tangent_WS = normalize(mul(UNITY_MATRIX_M, half4(input.tangent_OS.xyz, 0.0)));
                output.binormal_WS = cross(output.normal_WS, output.tangent_WS) * input.tangent_OS.w;

                output.fogFactor = ComputeFogFactor(output.pos_CS.z);

                return output;
            }

            half4 Fragment(Varyings input) : SV_TARGET
            {
                half4 albedo_color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half4 comp_mask = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, input.uv);

                float metal = comp_mask.r;
                float ao = comp_mask.g;
                float smoothness = comp_mask.a;
                float roughness = 1 - smoothness + _RoughnessAdjust;
                roughness = saturate(pow(roughness, 2));

                //主光源的阴影衰减
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(input.pos_WS));
                half3 light_dir = SafeNormalize(mainLight.direction);

                //法线-NormalMap
                half4 normal_map = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv);
                half3 normalData = UnpackNormal(normal_map);
                half3 normal_dir = SafeNormalize(input.normal_WS);
                half3 tangent_dir = SafeNormalize(input.tangent_WS);
                half3 binormal_dir = SafeNormalize(input.binormal_WS);

                float3x3 TBN = float3x3(tangent_dir, binormal_dir, normal_dir);
                normal_dir = SafeNormalize(mul(normalData.xyz, TBN));

                //视线观察方向
                half3 view_dir = SafeNormalize(_WorldSpaceCameraPos.xyz - input.pos_WS);
                //光的反射方向
                half3 reflect_dir = reflect(-view_dir, normal_dir);
                //半角向量
                half3 half_dir = SafeNormalize(light_dir + view_dir);
                //避免结果为0除以0计算错误
                half NdotH = max(saturate(dot(normal_dir, half_dir)), 0.000001);
                half NdotL = max(saturate(dot(normal_dir, light_dir)), 0.000001);
                half NdotV = max(saturate(dot(normal_dir, view_dir)), 0.000001);
                half HdotV = max(saturate(dot(half_dir, view_dir)), 0.000001);
                half LdotH = max(saturate(dot(light_dir, half_dir)), 0.000001);

                float3 F0 = lerp(0.04, albedo_color, metal);

                //直接光的高光计算
                float D = D_Function(NdotH, roughness);
                float G = G_Function(NdotL, NdotV, roughness);
                float3 F = F_Function(LdotH, F0);
                float3 BRDFSpecSection = D*G*F / (4*NdotL*NdotV);
                float3 DirectSpecColor = BRDFSpecSection * mainLight.color * NdotL * PI;

                //直接光漫反射
                float3 KS = F;
                float3 KD = (1 - KS) * (1 - metal);
                float3 DirectDiffColor = KD * albedo_color * mainLight.color * NdotL;

                //间接光，光照探针采样
                //float3 sh_Color = SH_IndirectionDiff(input.normal_WS);
                float4 sh_Color;
                OUTPUT_SH(input.normal_WS, sh_Color);
                float3 env_diffuseKS = EnvF_Function(NdotV, F0, roughness);
                float3 env_diffuseKD = (1 - env_diffuseKS) * (1 - metal);
                float3 env_diffuse_color = sh_Color * env_diffuseKD * albedo_color;

                float3 final_color = DirectSpecColor + DirectDiffColor;

                return float4(env_diffuse_color, 1);
            }
            ENDHLSL
        }
    }
}
