Shader "JSU/Light/Phong"
/*
    max(N * L, 0.0) + pow(max(R * V, 0.0), smoothness) + ambient = Phong
    漫反射 + 高光 R:反射光 V:视口方向 s:粗糙度 + 环境光 = 冯氏光照模型
*/
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Shininess ("高光范围（粗糙度）", Range(0.01, 100)) = 1.0
        _SpecIntensity ("高光强度", Range(0.01, 100)) = 1.0
        _AmbientColor ("环境光", Color) = (0, 0, 0, 0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags{"LightMode" = "UniversalForward"}
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase

            #include "UnityCG.cginc"
            #include "AutoLight.cginc"

            struct appdata
            {
                half4 vertex : POSITION;
                half2 uv : TEXCOORD0;
                half3 normal : NORMAL;
            };

            struct v2f
            {
                half2 uv : TEXCOORD0;
                half4 vertex : SV_POSITION;
                half3 normal_dir : TEXCOORD1;      //世界空间下的法线数据
                half3 pos_world : TEXCOORD2;       //世界空间下的顶点数据
            };

            sampler2D _MainTex;
            half4 _MainTex_ST;
            half4 _LightColor0;    //光源的颜色值定义就可以拿到
            half _Shininess;
            half _SpecIntensity;
            half4 _AmbientColor;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal_dir = normalize(mul(half4(v.normal, 0.0), unity_WorldToObject).xyz);
                o.pos_world = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                half4 base_color = tex2D(_MainTex, i.uv);

                half3 normal_dir = normalize(i.normal_dir);    //法线的方向(法线数据光栅化后会改变长度,需要normalize)
                half3 view_dir = normalize(_WorldSpaceCameraPos.xyz - i.pos_world);        //视口的方向
                half3 light_dir = normalize(_WorldSpaceLightPos0.xyz);     //光源的方向

                //漫反射
                half NdotL = dot(normal_dir, light_dir);       // -1,1的结果
                half3 diffuse_color = max(0.0, NdotL) * _LightColor0.xyz * base_color.xyz;          //限制在0-1之间 * 光源的颜色

                //高光
                half3 reflect_dir = reflect(-light_dir, normal_dir);   //光的反射方向
                half RdotV = dot(reflect_dir, view_dir);
                half3 spec_color = pow(max(0.0, RdotV), _Shininess)  * _LightColor0.xyz * _SpecIntensity;    //去掉负数,_Shininess次方

                half3 final_color = diffuse_color + spec_color;

                return half4(final_color, 1.0);
            }
            ENDCG
        }
    }
}
