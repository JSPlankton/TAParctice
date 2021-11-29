Shader "JSU URP/Light/Lit"
/*
    max(N * L, 0.0) + pow(max(R * V, 0.0), smoothness) + ambient = Phong
    漫反射 + 高光 R:反射光 V:视口方向 s:粗糙度 + 环境光 = 冯氏光照模型
*/
{
    Properties
    {
        _BaseMap ("Base Map", 2D) = "white" {}
        _NormalMap ("Normal Map", 2D) = "white" {}
        _AOMap ("Ambient Occlusiont Map", 2D) = "white" {}
        _SpecMaskMap ("Specular Mask Map", 2D) = "white" {}
        _Shininess ("Roughness", Range(0.01, 100)) = 1.0
        _SpecIntensity ("Specular Intensity", Range(0.01, 100)) = 1.0
        _NormalIntensity ("Normal Intensity", Range(0.0, 5.0)) = 1.0
        _AmbientColor ("Ambient Color", Color) = (0, 0, 0, 0)

        [Toggle(_AdditionalLights)] _AddLights ("AddLights", Float) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags{"LightMode" = "UniversalForward"}
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "include/Lit.hlsl"

            // -------------------------------------
            // keywords
            #pragma shader_feature _AdditionalLights

            #pragma vertex LitPassVert
            #pragma fragment LitPassFragment
            ENDHLSL
        }
    }
}
