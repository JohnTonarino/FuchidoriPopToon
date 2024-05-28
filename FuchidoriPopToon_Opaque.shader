// Copyright (c) 2024 JohnTonarino
// Released under the MIT license
// FuchidoriPopToon v 1.0.2
Shader "FuchidoriPopToon/Opaque"
{
    Properties
    {
        [Header(MainColor)]
        [Space(10)]
        _MainTex ("Texture", 2D) = "white" {}
        _MainTexOverlayColor("MainTexOverlayColor", Color) = (1., 1., 1., 1.)

        [Header(NormalMap)]
        [Space(10)]
        [Normal]_BumpMap("NormalMap", 2D) = "bump" {}
        _BumpScale("NormalScale", Range(.01, 1.)) = 1.

        [Header(MatCap)]
        [Space(10)]
        _MatCap("MatCap", 2D) = "white" {}
        _MatCapStrength("MatCapStrength", Range(0., 1.)) = 0.
        _MatCapMask("MatCapMask", 2D) = "white" {}

        [Header(Specular)]
        [Space(10)]
        _SpecularStrength("SpecularStrength",Range(0., 1.)) = 0.0
        _SpecularPower("SpecularPower",Range(0.01, 10.)) = 0.01
        _SpecularBias("SpecularBias",Range(0., 1.)) = 0.5

        [Header(Shadow)]
        [Space(10)]
        _ShadowTex("ShadowTex", 2D) = "white" {}
        _ShadowOverlayColor("ShadowOverlayColor", Color) = (0., 0., 0., 1.)
        _ShadowStrength("ShadowStrength",Range(0., 1.)) = 0.5

        [Header(RimColor)]
        [Space(10)]
        _RimColor("RimLightColor", Color) = (1., 1., 1., 1.)
        _RimLightStrength("RimLightStrength", Range(0., 1.)) = .5
        _RimLightMask("RimLightMask", 2D) = "white" {}

        [Header(Outline)]
        [Space(10)]
        _StencilRef("SencilRef", Int) = 2
        _OuterOutlineColor1st("OuterOutlineColor1st", Color) = (0.,0.,0.,1.)
        _OuterOutlineColor2nd("OuterOutlineColor2nd", Color) = (1.,1.,1.,1.)
        _InnerOutlineColor("InnerOutlineColor", Color) = (0.,0.,0.,1.)
        _OuterOutlineWidth("OuterOutlineWidth", Float) = .01
        _OuterOutlineRatio("OuterOutlineRatio", Range(.01, 1.)) = .3
        _InnerOutlineWidth("InnerOutlineWidth", Float) = .0015
        _OutlineMask("OutlineMask", 2D) = "white" {}
        _AsOutlineUnlit("As OutlineUnlit", Range(0,1)) = 0.5

        [Header(Transparent)]
        [Space(10)]
        _TransparentMask("TransparentMask", 2D) = "white" {}
        _TransparentLevel("TransparentLevel", Range(0., 1.)) = 0.

        [Header(Emission)]
        [Space(10)]
        _EmissiveTex("EmissiveTex", 2D) = "black" {}
        [HDR] _EmissiveColor("EmissiveColor", Color) = (1., 1., 1., 1.)

        //------------------------------------------------------------------------------------------------------------------------------
        // [OpenLit] Properties for lighting

        // It is more accurate to set _LightMinLimit to 0, but the avatar will be black.
        // In many cases, setting a small value will give better results.

        [Header(OpenLit)]
        [Space(10)]
        _AsUnlit("As Unlit", Range(0,1)) = 0
        _LightMinLimit("Light Min Limit", Range(0,1)) = 0.05
        _LightMaxLimit("Light Max Limit", Range(0,10)) = 1
        _BeforeExposureLimit("Before Exposure Limit", Float) = 10000
        _MonochromeLighting("Monochrome lighting", Range(0,1)) = 0
        _AlphaBoostFA("Boost Transparency in ForwardAdd", Range(1,100)) = 10
        _LightDirectionOverride("Light Direction Override", Vector) = (0.001,0.002,0.001,0)

        _ShadowThreshold("Shadow Threshold", Range(-1,1)) = 0
        [Toggle(_)] _ReceiveShadow("Receive Shadow", Int) = 0

        //------------------------------------------------------------------------------------------------------------------------------
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry"}
        LOD 100

        CGINCLUDE
        #include "UnityCG.cginc"
        #include "Lighting.cginc"
        #include "AutoLight.cginc"

        //------------------------------------------------------------------------------------------------------------------------------
        // OpenLit Library 1.0.2
        // This code is licensed under CC0 1.0 Universal.
        // https://creativecommons.org/publicdomain/zero/1.0/

        #if !defined(OPENLIT_CORE_INCLUDED)
        #define OPENLIT_CORE_INCLUDED

        //------------------------------------------------------------------------------------------------------------------------------
        // Macro
        #define OPENLIT_LIGHT_COLOR     _LightColor0.rgb
        #define OPENLIT_LIGHT_DIRECTION _WorldSpaceLightPos0.xyz
        #define OPENLIT_MATRIX_M        unity_ObjectToWorld
        #define OPENLIT_FALLBACK_DIRECTION  float4(0.001,0.002,0.001,0)

        //------------------------------------------------------------------------------------------------------------------------------
        // SRGB <-> Linear
        float3 OpenLitLinearToSRGB(float3 col)
        {
            return LinearToGammaSpace(col);
        }

        float3 OpenLitSRGBToLinear(float3 col)
        {
            return GammaToLinearSpace(col);
        }

        //------------------------------------------------------------------------------------------------------------------------------
        // Color
        float OpenLitLuminance(float3 rgb)
        {
            #if defined(UNITY_COLORSPACE_GAMMA)
                return dot(rgb, float3(0.22, 0.707, 0.071));
            #else
                return dot(rgb, float3(0.0396819152, 0.458021790, 0.00609653955));
            #endif
        }

        float OpenLitGray(float3 rgb)
        {
            return dot(rgb, float3(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0));
        }

        //------------------------------------------------------------------------------------------------------------------------------
        // Structure
        struct OpenLitLightDatas
        {
            float3 lightDirection;
            float3 directLight;
            float3 indirectLight;
        };

        //------------------------------------------------------------------------------------------------------------------------------
        // Light Direction
        // Use `UnityWorldSpaceLightDir(float3 positionWS)` for ForwardAdd passes
        float3 ComputeCustomLightDirection(float4 lightDirectionOverride)
        {
            float3 customDir = length(lightDirectionOverride.xyz) * normalize(mul((float3x3)OPENLIT_MATRIX_M, lightDirectionOverride.xyz));
            return lightDirectionOverride.w ? customDir : lightDirectionOverride.xyz;
        }

        void ComputeLightDirection(out float3 lightDirection, out float3 lightDirectionForSH9, float4 lightDirectionOverride)
        {
            float3 mainDir = OPENLIT_LIGHT_DIRECTION * OpenLitLuminance(OPENLIT_LIGHT_COLOR);
            #if !defined(LIGHTMAP_ON) && UNITY_SHOULD_SAMPLE_SH
                float3 sh9Dir = unity_SHAr.xyz * 0.333333 + unity_SHAg.xyz * 0.333333 + unity_SHAb.xyz * 0.333333;
                float3 sh9DirAbs = float3(sh9Dir.x, abs(sh9Dir.y), sh9Dir.z);
            #else
                float3 sh9Dir = 0;
                float3 sh9DirAbs = 0;
            #endif
            float3 customDir = ComputeCustomLightDirection(lightDirectionOverride);

            lightDirection = normalize(sh9DirAbs + mainDir + customDir);
            lightDirectionForSH9 = sh9Dir + mainDir;
            lightDirectionForSH9 = dot(lightDirectionForSH9,lightDirectionForSH9) < 0.000001 ? 0 : normalize(lightDirectionForSH9);
        }

        void ComputeLightDirection(out float3 lightDirection, out float3 lightDirectionForSH9)
        {
            ComputeLightDirection(lightDirection, lightDirectionForSH9, OPENLIT_FALLBACK_DIRECTION);
        }

        //------------------------------------------------------------------------------------------------------------------------------
        // ShadeSH9
        void ShadeSH9ToonDouble(float3 lightDirection, out float3 shMax, out float3 shMin)
        {
            #if !defined(LIGHTMAP_ON) && UNITY_SHOULD_SAMPLE_SH
                float3 N = lightDirection * 0.666666;
                float4 vB = N.xyzz * N.yzzx;
                // L0 L2
                float3 res = float3(unity_SHAr.w,unity_SHAg.w,unity_SHAb.w);
                res.r += dot(unity_SHBr, vB);
                res.g += dot(unity_SHBg, vB);
                res.b += dot(unity_SHBb, vB);
                res += unity_SHC.rgb * (N.x * N.x - N.y * N.y);
                // L1
                float3 l1;
                l1.r = dot(unity_SHAr.rgb, N);
                l1.g = dot(unity_SHAg.rgb, N);
                l1.b = dot(unity_SHAb.rgb, N);
                shMax = res + l1;
                shMin = res - l1;
                #if defined(UNITY_COLORSPACE_GAMMA)
                    shMax = OpenLitLinearToSRGB(shMax);
                    shMin = OpenLitLinearToSRGB(shMin);
                #endif
            #else
                shMax = 0.0;
                shMin = 0.0;
            #endif
        }

        void ShadeSH9ToonDouble(out float3 shMax, out float3 shMin)
        {
            float3 lightDirection, lightDirectionForSH9;
            ComputeLightDirection(lightDirection, lightDirectionForSH9, OPENLIT_FALLBACK_DIRECTION);
            ShadeSH9ToonDouble(lightDirectionForSH9, shMax, shMin);
        }

        float3 ShadeSH9Toon()
        {
            float3 shMax, shMin;
            ShadeSH9ToonDouble(shMax, shMin);
            return shMax;
        }

        float3 ShadeSH9ToonIndirect()
        {
            float3 shMax, shMin;
            ShadeSH9ToonDouble(shMax, shMin);
            return shMin;
        }

        //------------------------------------------------------------------------------------------------------------------------------
        // Lighting
        void ComputeSHLightsAndDirection(out float3 lightDirection, out float3 directLight, out float3 indirectLight, float4 lightDirectionOverride)
        {
            float3 lightDirectionForSH9;
            ComputeLightDirection(lightDirection, lightDirectionForSH9, lightDirectionOverride);
            ShadeSH9ToonDouble(lightDirectionForSH9, directLight, indirectLight);
        }

        void ComputeSHLightsAndDirection(out float3 lightDirection, out float3 directLight, out float3 indirectLight)
        {
            ComputeSHLightsAndDirection(lightDirection, directLight, indirectLight, OPENLIT_FALLBACK_DIRECTION);
        }

        void ComputeLights(out float3 lightDirection, out float3 directLight, out float3 indirectLight, float4 lightDirectionOverride)
        {
            ComputeSHLightsAndDirection(lightDirection, directLight, indirectLight, lightDirectionOverride);
            directLight += OPENLIT_LIGHT_COLOR;
        }

        void ComputeLights(out float3 lightDirection, out float3 directLight, out float3 indirectLight)
        {
            ComputeSHLightsAndDirection(lightDirection, directLight, indirectLight);
            directLight += OPENLIT_LIGHT_COLOR;
        }

        void ComputeLights(out OpenLitLightDatas lightDatas, float4 lightDirectionOverride)
        {
            ComputeLights(lightDatas.lightDirection, lightDatas.directLight, lightDatas.indirectLight, lightDirectionOverride);
        }

        void ComputeLights(out OpenLitLightDatas lightDatas)
        {
            ComputeLights(lightDatas.lightDirection, lightDatas.directLight, lightDatas.indirectLight);
        }

        //------------------------------------------------------------------------------------------------------------------------------
        // Correct
        void CorrectLights(inout OpenLitLightDatas lightDatas, float lightMinLimit, float lightMaxLimit, float monochromeLighting, float asUnlit)
        {
            lightDatas.directLight = clamp(lightDatas.directLight, lightMinLimit, lightMaxLimit);
            lightDatas.directLight = lerp(lightDatas.directLight, OpenLitGray(lightDatas.directLight), monochromeLighting);
            lightDatas.directLight = lerp(lightDatas.directLight, 1.0, asUnlit);
            lightDatas.indirectLight = clamp(lightDatas.indirectLight, 0.0, lightMaxLimit);
        }

        //------------------------------------------------------------------------------------------------------------------------------
        // Vertex Lighting
        float3 ComputeAdditionalLights(float3 positionWS, float3 positionCS)
        {
            float4 toLightX = unity_4LightPosX0 - positionWS.x;
            float4 toLightY = unity_4LightPosY0 - positionWS.y;
            float4 toLightZ = unity_4LightPosZ0 - positionWS.z;

            float4 lengthSq = toLightX * toLightX + 0.000001;
            lengthSq += toLightY * toLightY;
            lengthSq += toLightZ * toLightZ;

            //float4 atten = 1.0 / (1.0 + lengthSq * unity_4LightAtten0);
            float4 atten = saturate(saturate((25.0 - lengthSq * unity_4LightAtten0) * 0.111375) / (0.987725 + lengthSq * unity_4LightAtten0));

            float3 additionalLightColor;
            additionalLightColor = unity_LightColor[0].rgb * atten.x;
            additionalLightColor = additionalLightColor + unity_LightColor[1].rgb * atten.y;
            additionalLightColor = additionalLightColor + unity_LightColor[2].rgb * atten.z;
            additionalLightColor = additionalLightColor + unity_LightColor[3].rgb * atten.w;

            return additionalLightColor;
        }

        //------------------------------------------------------------------------------------------------------------------------------
        // Encode and decode
        #if !defined(SHADER_API_GLES)
        // -1 - 1
        uint EncodeNormalizedFloat3ToUint(float3 vec)
        {
            uint valx = abs(vec.x) >= 1 ? 511 : abs(vec.x) * 511;
            uint valy = abs(vec.y) >= 1 ? 511 : abs(vec.y) * 511;
            uint valz = abs(vec.z) >= 1 ? 511 : abs(vec.z) * 511;
            valx = valx & 0x000001ffu;
            valy = valy & 0x000001ffu;
            valz = valz & 0x000001ffu;
            valx += vec.x > 0 ? 0 : 512;
            valy += vec.y > 0 ? 0 : 512;
            valz += vec.z > 0 ? 0 : 512;

            valy = valy << 10;
            valz = valz << 20;
            return valx | valy | valz;
        }

        float3 DecodeNormalizedFloat3FromUint(uint val)
        {
            // 5 math in target 5.0
            uint3 val3 = val >> uint3(0,10,20);
            float3 vec = val3 & 0x000001ffu;
            vec /= (val3 & 0x00000200u) == 0x00000200u ? -511.0 : 511.0;
            return vec;
        }

        // 0 - 999
        uint EncodeHDRColorToUint(float3 col)
        {
            col = clamp(col, 0, 999);
            float maxcol = max(col.r,max(col.g,col.b));

            float floatDigit = maxcol == 0 ? 0 : log10(maxcol);
            uint digit = floatDigit >= 0 ? floatDigit + 1 : 0;
            if (digit > 3) digit = 3;
            float scale = pow(10,digit);
            col /= scale;

            uint R = col.r * 1023;
            uint G = col.g * 1023;
            uint B = col.b * 1023;
            uint M = digit;
            R = R & 0x000003ffu;
            G = G & 0x000003ffu;
            B = B & 0x000003ffu;

            G = G << 10;
            B = B << 20;
            M = M << 30;
            return R | G | B | M;
        }

        float3 DecodeHDRColorFromUint(uint val)
        {
            // 5 math in target 5.0
            uint4 RGBM = val >> uint4(0,10,20,30);
            return float3(RGBM.rgb & 0x000003ffu) / 1023.0 * pow(10,RGBM.a);
        }

        void PackLightDatas(out uint3 pack, OpenLitLightDatas lightDatas)
        {
            pack = uint3(
                EncodeNormalizedFloat3ToUint(lightDatas.lightDirection),
                EncodeHDRColorToUint(lightDatas.directLight),
                EncodeHDRColorToUint(lightDatas.indirectLight)
            );
        }

        void UnpackLightDatas(out OpenLitLightDatas lightDatas, uint3 pack)
        {
            lightDatas.lightDirection = DecodeNormalizedFloat3FromUint(pack.x);
            lightDatas.directLight = DecodeHDRColorFromUint(pack.y);
            lightDatas.indirectLight = DecodeHDRColorFromUint(pack.z);
        }
        #endif // #if !defined(SHADER_API_GLES)
        #endif // #if !defined(OPENLIT_CORE_INCLUDED)
        // OpenLit
        //------------------------------------------------------------------------------------------------------------------------------

        #pragma skip_variants LIGHTMAP_ON DYNAMICLIGHTMAP_ON LIGHTMAP_SHADOW_MIXING SHADOWS_SHADOWMASK DIRLIGHTMAP_COMBINED
        #define PI 3.141592

        sampler2D _MainTex;
        float4 _MainTex_ST;
        int _StencilRef;
        fixed4 _MainTexOverlayColor;

        half _BumpScale;
        sampler2D _BumpMap;
        float4 _BumpMap_ST;

        sampler2D _MatCap;
        half _MatCapStrength;
        sampler2D _MatCapMask;

        half _SpecularStrength;
        half _SpecularPower;
        half _SpecularBias;

        sampler2D _ShadowTex;
        fixed4 _ShadowOverlayColor;
        half _ShadowStrength;

        fixed4 _RimColor;
        half _RimLightStrength;
        sampler2D _RimLightMask;

        fixed4 _OuterOutlineColor1st;
        fixed4 _OuterOutlineColor2nd;
        fixed4 _InnerOutlineColor;
        fixed _OuterOutlineRatio;
        fixed _OuterOutlineWidth;
        fixed _InnerOutlineWidth;
        half   _OutlineWidth;
        sampler2D _OutlineMask;
        half   _AsOutlineUnlit;

        sampler2D _TransparentMask;
        half _TransparentLevel;

        sampler2D _EmissiveTex;
        float4 _EmissiveColor;

        // [OpenLit] Properties for lighting
        float _LightIntensity;
        uint _ReceiveShadow;

        float   _AsUnlit;
        float   _LightMinLimit;
        float   _LightMaxLimit;
        float   _BeforeExposureLimit;
        float   _MonochromeLighting;
        float   _AlphaBoostFA;
        float4  _LightDirectionOverride;

        float _ShadowThreshold;
        //---

        struct appdata
        {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
            float2 uv1 : TEXCOORD1;
            half3 normalOS : NORMAL;
            half4 tangent : TANGENT;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct g2f
        {
            float4 pos : SV_POSITION;
            float3 positionWS : TEXCOORD0;
            float2 uv : TEXCOORD1;
            float3 normalWS : TEXCOORD2;

            fixed4 color : COLOR;

            // [OpenLit] Add light datas
            nointerpolation uint3 lightDatas : TEXCOORD3;
            UNITY_FOG_COORDS(4)
                UNITY_LIGHTING_COORDS(5, 6)
#if !defined(LIGHTMAP_ON) && UNITY_SHOULD_SAMPLE_SH
                float3 vertexLight  : TEXCOORD7;
#endif
            UNITY_VERTEX_OUTPUT_STEREO
            float4 screenPos : TEXCOORD8;
            half3 tangent : TEXCOORD9;
            half3 binormal : TEXCOORD10;
            half2 viewUV : TEXCOORD11;
        };

        float4 calcOutlineVertex(appdata v, fixed width){
            float3 norm = normalize(mul((float3x3)UNITY_MATRIX_IT_MV, v.normalOS));
            fixed4 outlineMask = tex2Dlod(_OutlineMask, float4(v.uv.xy, 0., 0.));
            float2 offset = TransformViewToProjection(norm.xy)*outlineMask.r;

            float4 outline_vertex = UnityObjectToClipPos(v.vertex);
            outline_vertex.xy += (offset * width);

            return outline_vertex;
        }
        fixed drawRimLighting(float2 INuv, float4 INscreenPos, float3 viewDir, float3 INnormal) {
            float2 viewportPos = INscreenPos.xy / INscreenPos.w;
            float2 screenPos = viewportPos * _ScreenParams.xy;
            fixed4 rimLightMask = tex2D(_RimLightMask, INuv);
            return lerp(0., pow(1. - saturate(dot(viewDir, INnormal)), 2.), _RimLightStrength) * rimLightMask.x;
        }
        g2f vert_base (appdata v)
        {
            g2f o;
            UNITY_SETUP_INSTANCE_ID(v);
            UNITY_INITIALIZE_OUTPUT(g2f, o);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

            o.pos = UnityObjectToClipPos(v.vertex);
            o.positionWS = mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1.));
            o.uv = v.uv;
            o.normalWS = UnityObjectToWorldNormal(v.normalOS);

            o.screenPos = ComputeScreenPos(o.pos);
            o.tangent = normalize(mul(unity_ObjectToWorld, v.tangent)).xyz;
            o.binormal = normalize(mul(unity_ObjectToWorld, cross(v.normalOS, v.tangent) * v.tangent.w));

            float3 viewNormal = mul((float3x3)UNITY_MATRIX_V, UnityObjectToWorldNormal(v.normalOS));
            o.viewUV = viewNormal.xy * .5 + .5;

            UNITY_TRANSFER_FOG(o, o.pos);
            UNITY_TRANSFER_LIGHTING(o, v.uv);

            // [OpenLit] Calculate and copy vertex lighting
#if !defined(LIGHTMAP_ON) && UNITY_SHOULD_SAMPLE_SH && defined(VERTEXLIGHT_ON)
            o.vertexLight = 0.;
            o.vertexLight = min(o.vertexLight, _LightMaxLimit);
#endif

            return o;
        }
        g2f vert_normalbase(appdata v)
        {
            g2f o;
            o = vert_base(v);

            // [OpenLit] Calculate and copy light datas
            OpenLitLightDatas lightDatas;
            ComputeLights(lightDatas, _LightDirectionOverride);
            CorrectLights(lightDatas, _LightMinLimit, _LightMaxLimit, _MonochromeLighting, _AsUnlit);
            PackLightDatas(o.lightDatas, lightDatas);

            return o;
        }
        g2f vert_outlinebase(appdata v, fixed width)
        {
            g2f o;
            o = vert_base(v);
            o.pos = calcOutlineVertex(v, width);

            // [OpenLit] Calculate and copy light datas
            OpenLitLightDatas lightDatas;
            ComputeLights(lightDatas, _LightDirectionOverride);
            CorrectLights(lightDatas, _LightMinLimit, _LightMaxLimit, _MonochromeLighting, _AsOutlineUnlit);
            PackLightDatas(o.lightDatas, lightDatas);

            return o;
        }
        
        fixed4 frag_outline(g2f i) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
            UNITY_LIGHT_ATTENUATION(attenuation, i, i.positionWS);

            // Lighting
            // [OpenLit] Copy light datas from the input
            OpenLitLightDatas lightDatas;
            UnpackLightDatas(lightDatas, i.lightDatas);

            float factor = 1.;
            if (_ReceiveShadow) factor *= attenuation;

            fixed4 col = i.color;
            col.rgb *= lerp(lightDatas.indirectLight, lightDatas.directLight, factor);
            fixed3 albedo = col.rgb;
#if !defined(LIGHTMAP_ON) && UNITY_SHOULD_SAMPLE_SH
            col.rgb += albedo * i.vertexLight;
            col.rgb = min(col.rgb, albedo.rgb * _LightMaxLimit);
#endif
            UNITY_APPLY_FOG(i.fogCoord, col);

            return col;
        }
        ENDCG

        // For ForwardBase Light
        Pass
        {
            Tags {"LightMode" = "ForwardBase"}
            Stencil{
                Ref [_StencilRef]
                Comp always
                Pass replace
            }
            Cull back

            BlendOp Add, Add
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert_normalbase
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog

            fixed4 frag(g2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                UNITY_LIGHT_ATTENUATION(attenuation, i, i.positionWS);

                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz-i.positionWS);

                // Lighting
                // [OpenLit] Copy light datas from the input
                OpenLitLightDatas lightDatas;
                UnpackLightDatas(lightDatas, i.lightDatas);

                half3 normalmap = UnpackScaleNormal(tex2D(_BumpMap, i.uv), _BumpScale);
                float3 N = (i.tangent * normalmap.x) + (i.binormal * normalmap.y) + (i.normalWS * normalmap.z);
                float3 L = lightDatas.lightDirection;
                float NdotL = dot(N, L);

                float3 H = normalize(L + viewDir);
                half phoneSpec = pow(smoothstep(_SpecularBias-.02,_SpecularBias+.02,max(0., dot(N,H))), _SpecularPower);

                fixed4 shadowTexColor = tex2D(_ShadowTex, i.uv);
                fixed4 shadowColor = shadowTexColor * _ShadowOverlayColor;
                fixed3 factor = NdotL > _ShadowThreshold ? 1 : shadowColor.rgb;
                factor = lerp(1., factor, _ShadowStrength);
                if (_ReceiveShadow) factor *= attenuation;

                fixed4 col = tex2D(_MainTex, i.uv) * _MainTexOverlayColor;
                fixed4 matcap = tex2D(_MatCap, i.viewUV) * tex2D(_MatCapMask, i.uv);
                col.rgb = lerp(col.rgb, matcap.rgb, _MatCapStrength);

                fixed rim = drawRimLighting(i.uv, i.screenPos, viewDir, i.normalWS);
                col.rgb = lerp(col.rgb, _RimColor.rgb, rim);

                fixed4 alphaMask = tex2D(_TransparentMask, i.uv);
                col.a = col.a * OpenLitGray(alphaMask.rgb);
                if (col.a < _TransparentLevel) discard;

                fixed4 emissiveTex = tex2D(_EmissiveTex, i.uv);
                col.rgb += emissiveTex.rgb * _EmissiveColor;

                col.rgb *= lerp(1., 1.+phoneSpec, _SpecularStrength);
                col.rgb *= lerp(lightDatas.indirectLight, lightDatas.directLight, factor);

                fixed3 albedo = col.rgb;
#if !defined(LIGHTMAP_ON) && UNITY_SHOULD_SAMPLE_SH
                col.rgb += albedo * i.vertexLight;
                col.rgb = min(col.rgb, albedo.rgb * _LightMaxLimit);
#endif
                UNITY_APPLY_FOG(i.fogCoord, col);

                return col;
            }
            ENDCG
        }
        // For ForwardAdd Light
        Pass
        {
            Tags { "LightMode" = "ForwardAdd"}

            // [OpenLit] ForwardAdd uses "BlendOp Max" to avoid overexposure
            BlendOp Max, Add
            Blend One One, Zero One

            CGPROGRAM
            #pragma vertex vert_normalbase
            #pragma fragment frag
            #pragma multi_compile_fwdadd
            #pragma multi_compile_fog

            fixed4 frag(g2f i) :SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                UNITY_LIGHT_ATTENUATION(attenuation, i, i.positionWS);

                float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.positionWS);

                // Lighting
                // [OpenLit] Copy light datas from the input
                OpenLitLightDatas lightDatas;
                UnpackLightDatas(lightDatas, i.lightDatas);

                half3 normalmap = UnpackScaleNormal(tex2D(_BumpMap, i.uv), _BumpScale);
                float3 N = (i.tangent * normalmap.x) + (i.binormal * normalmap.y) + (i.normalWS * normalmap.z);
                float3 L = lightDatas.lightDirection;
                float NdotL = dot(N, L);

                half3 H = normalize(L + viewDir);
                half phoneSpec = pow(smoothstep(_SpecularBias-.02,_SpecularBias+.02,max(0., (dot(N, H)))), _SpecularPower);

                fixed4 shadowTexColor = tex2D(_ShadowTex, i.uv);
                fixed4 shadowColor = shadowTexColor * _ShadowOverlayColor;
                float3 factor = NdotL > _ShadowThreshold ? 1 : shadowColor.rgb;
                factor = lerp(1., factor, _ShadowStrength);

                fixed4 col = tex2D(_MainTex, i.uv) * _MainTexOverlayColor;
                fixed4 matcap = tex2D(_MatCap, i.viewUV) * tex2D(_MatCapMask, i.uv);
                col.rgb = lerp(col.rgb, matcap.rgb, _MatCapStrength);

                fixed rim = drawRimLighting(i.uv, i.screenPos, viewDir, i.normalWS);
                col.rgb = lerp(col.rgb, _RimColor.rgb, rim);

                fixed4 alphaMask = tex2D(_TransparentMask, i.uv);
                col.a = col.a * OpenLitGray(alphaMask.rgb);
                if (col.a < _TransparentLevel) discard;

                fixed4 emissiveTex = tex2D(_EmissiveTex, i.uv);
                col.rgb += emissiveTex.rgb * _EmissiveColor;

                col.rgb *= lerp(1., 1.+phoneSpec, _SpecularStrength);
                col.rgb *= lerp(0., OPENLIT_LIGHT_COLOR, factor*attenuation);

                UNITY_APPLY_FOG(i.fogCoord, col);

                // [OpenLit] Premultiply (only for transparent materials)
                col.rgb *= saturate(col.a * _AlphaBoostFA);

                return col;
            }
            ENDCG
        }
        // for stencil outer outline
        Pass{
            Tags {"LightMode" = "ForwardBase"}
            Stencil{
                Ref [_StencilRef]
                Comp NotEqual
                Pass IncrSat
            }
            Cull front
            Offset 1,-1

            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag_outline

            appdata vert(appdata v)
            {
                return v;
            }

            [maxvertexcount(6)]
            void geom(triangle appdata IN[3], inout TriangleStream<g2f> stream) {
                g2f o;
                UNITY_INITIALIZE_OUTPUT(g2f, o);
                UNITY_SETUP_INSTANCE_ID(IN[0]);
                UNITY_SETUP_INSTANCE_ID(IN[1]);
                UNITY_SETUP_INSTANCE_ID(IN[2]);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                // 1st Outline
                for (int i = 0; i < 3; ++i) {
                    appdata v = IN[i];
                    o = vert_outlinebase(v, _OuterOutlineRatio * _OuterOutlineWidth);
                    o.color = _OuterOutlineColor1st;
                    UNITY_TRANSFER_FOG(o, o.vertex);

                    stream.Append(o);
                }
                stream.RestartStrip();

                // 2nd Outline
                for (int j = 0; j < 3; ++j) {
                    appdata v = IN[j];
                    o = vert_outlinebase(v, _OuterOutlineWidth);
                    o.color = _OuterOutlineColor2nd;
                    UNITY_TRANSFER_FOG(o, o.pos);

                    stream.Append(o);
                }
                stream.RestartStrip();
            }
            ENDCG
        }
        // for normal outline
        Pass{
            Tags {"LightMode" = "ForwardBase"}
            Stencil{
                Ref [_StencilRef]
                Comp Equal
            }
            Cull front

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag_outline

            g2f vert(appdata v)
            {
                g2f o;
                UNITY_INITIALIZE_OUTPUT(g2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o = vert_outlinebase(v, _InnerOutlineWidth);
                o.color = _InnerOutlineColor;
                return o;
            }
            ENDCG
        }
        // For ShadowRendering
        Pass
        {
            Tags {"LightMode" = "ShadowCaster"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"

            struct v2f_shadow {
                V2F_SHADOW_CASTER;
                float2 uv : TEXCOORD1;
                float4 screenPos : TEXCOORD2;
            };

            v2f_shadow vert(appdata_base v)
            {
                v2f_shadow o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord.xy;
                o.screenPos = ComputeScreenPos(o.pos);
                return o;
            }
            float4 frag(v2f_shadow i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
    }
}
