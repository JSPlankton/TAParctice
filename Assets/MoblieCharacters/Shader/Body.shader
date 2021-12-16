Shader "JSU URP/Characters/Body"
{
    Properties
    {
        [Header(Sampling Map)]
        [Space]
        _BaseMap ("Base Map", 2D) = "white" {}
        _NormalMap ("Normal Map", 2D) = "white" {}
        _CompMask("CompMask(RM)", 2D) = "bump" {}
        [Space(20)]
        [Header(Material Paramters)]
        [Space]
        _SpecShininess ("Spec Shininess", Float) = 10
        _RoughnessAdjust("Roughness Adjust", Range(-1,1)) = 0.0
        _MetalAdjust("Metal Adjust", Range(-1,1)) = 0.0
        [Space(20)]
        [Header(IBL)]
        [Space]
        _EnvMap("Env Map",Cube) = "white"{}
		_Tint("Tint",Color) = (1,1,1,1)
		_Expose("Expose",Float) = 1.0
		_Rotate("Rotate",Range(0,360)) = 0
        [Header(SH)]
        [Space]
        [HideInInspector] custom_SHAr("Custom SHAr", Vector) = (0, 0, 0, 0)
        [HideInInspector] custom_SHAg("Custom SHAg", Vector) = (0, 0, 0, 0)
        [HideInInspector] custom_SHAb("Custom SHAb", Vector) = (0, 0, 0, 0)
        [HideInInspector] custom_SHBr("Custom SHBr", Vector) = (0, 0, 0, 0)
        [HideInInspector] custom_SHBg("Custom SHBg", Vector) = (0, 0, 0, 0)
        [HideInInspector] custom_SHBb("Custom SHBb", Vector) = (0, 0, 0, 0)
        [HideInInspector] custom_SHC("Custom SHC", Vector) = (0, 0, 0, 1)
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
            //主光源阴影
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            //主光源联级阴影
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            //柔化阴影，得到软阴影
            #pragma multi_compile _ _SHADOWS_SOFT

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
            TEXTURE2D(_CompMask);
            SAMPLER(sampler_CompMask);
            TEXTURECUBE(_EnvMap);
            SAMPLER(sampler_EnvMap);

            CBUFFER_START(UnityPerMaterial)
            half4 _BaseMap_ST;

            half _SpecShininess;
            half _RoughnessAdjust;
            half _MetalAdjust;

            float4 _EnvMap_HDR;
            float _Expose;

            half4 custom_SHAr;
            half4 custom_SHAg;
            half4 custom_SHAb;
            half4 custom_SHBr;
            half4 custom_SHBg;
            half4 custom_SHBb;
            half4 custom_SHC;
            CBUFFER_END

            //不依赖天空盒的球谐光照计算
            float3 Custom_SH(float3 normal_dir)
            {
                float4 normalForSH = float4(normal_dir, 1.0);
                half3 x;
                x.r = dot(custom_SHAr, normalForSH);
                x.g = dot(custom_SHAg, normalForSH);
                x.b = dot(custom_SHAb, normalForSH);

                half3 x1, x2;
                half4 vB = normalForSH.xyzz * normalForSH.yzzx;
                x1.r = dot(custom_SHBr, vB);
                x1.g = dot(custom_SHBg, vB);
                x1.b = dot(custom_SHBb, vB);

                half vC = normalForSH.x * normalForSH.x - normalForSH.y * normalForSH.y;
                x2 = custom_SHC.rgb * vC;

                float3 sh = max(float3(0.0, 0.0, 0.0), (x + x1 + x2));
                sh = pow(sh, 1.0 / 2.2);

                return sh;
            }

			inline float3 ACES_Tonemapping(float3 x)
			{
				float a = 2.51f;
				float b = 0.03f;
				float c = 2.43f;
				float d = 0.59f;
				float e = 0.14f;
				float3 encode_color = saturate((x*(a*x + b)) / (x*(c*x + d) + e));
				return encode_color;
			};

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
            
            half4 BodyFragment(Varyings input) : SV_TARGET
            {
                //固有色-BaseColor
                half4 base_color_gamma = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.texcoord);
                //half4 albedo_color = Gamma22ToLinear(base_color_gamma);
                half4 albedo_color = base_color_gamma;
                half4 comp_mask = SAMPLE_TEXTURE2D(_CompMask, sampler_CompMask, input.texcoord);

                //粗糙度
                half roughness = saturate( comp_mask.r + _RoughnessAdjust );

                //金属度-区分albedo贴图的金属和非金属颜色
                half metal = saturate( comp_mask.g + _MetalAdjust );
                //非金属的固有色
                half3 base_color = albedo_color.rgb * (1 - metal);
                //金属的高光颜色 : lerp(a,b,w) 根据w返回 a和b的插值
                half3 spec_color = lerp(0.04, albedo_color.rgb, metal);

                //法线-NormalMap
                half4 normal_map = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.texcoord);
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

                //主光源的阴影衰减
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(input.pos_WS));
                half3 light_dir = SafeNormalize(mainLight.direction);
      
                //直接光漫反射 NdotL-Diffuse
                half NdotL = dot(normal_dir, light_dir);
                half diff_term = max(0.0, NdotL);
                half3 direct_diffuse = diff_term * mainLight.color * mainLight.shadowAttenuation * base_color.xyz;
                
                //Bling-Phong直接光的镜面反射 NdotH-Specular
                half3 half_dir = SafeNormalize(light_dir + view_dir);
                half NdotH = dot(normal_dir, half_dir);
                half smoothness = 1.0 - roughness;
                half shniness = lerp(1, _SpecShininess, smoothness);
                half spec_term = pow(max(0.0, NdotH), shniness * smoothness);
                half3 direct_specular = spec_term * spec_color * mainLight.color * mainLight.shadowAttenuation;

                //间接光的漫反射
                half half_lambert = (diff_term + 1.0) * 0.5;
                half3 env_diffuse = Custom_SH(normal_dir) * base_color * half_lambert;

                //间接光的镜面反射
				roughness = roughness * (1.7 - 0.7 * roughness);
				float mip_level = roughness * 6.0;
                half4 color_envmap = SAMPLE_TEXTURECUBE_LOD(_EnvMap, sampler_EnvMap, reflect_dir, mip_level);
                
                #if !defined(UNITY_USE_NATIVE_HDR)
                half3 env_color = DecodeHDREnvironment(color_envmap, _EnvMap_HDR);//确保在移动端能拿到HDR信息
				#else
                half3 env_color = color_envmap.xyz;
                #endif
                half3 env_specular = env_color * _Expose * spec_color;

                half3 final_color = direct_diffuse + direct_specular + env_diffuse * 0.5 + env_specular;

                final_color = ACES_Tonemapping(final_color);

                return half4(final_color, 1.0);
            }

            ENDHLSL
        }

        //阴影投射Pass
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}
