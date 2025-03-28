// Copyright (c) 2024 JohnTonarino
// Released under the MIT license
// FuchidoriPopToon v 1.0.5
Shader "FuchidoriPopToon/Transparent"
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
        _SpecularBias("SpecularBias",Range(0., 1.)) = 0.5
        _Smoothness("Smoothness", Range(0.,1.)) = 0.5

        [Header(Shadow)]
        [Space(10)]
        _ShadowTex("ShadowTex", 2D) = "white" {}
        _ShadowOverlayColor1st("ShadowOverlayColor1st", Color) = (0., 0., 0., 1.)
        _ShadowOverlayColor2nd("ShadowOverlayColor2nd", Color) = (0., 0., 0., 1.)
        _ShadowWidth("ShadowWidth",Range(0., 1.)) = 0.5
        _ShadowEdgeSmoothness("ShadowEdgeSmoothness",Range(0., 1.)) = 0.05
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

        [Header(ExperimentalFeature)]
        [Space(10)]
        [Toggle(_)] _SDFOn("SDF(Experimental)", Int) = 0
        _SDFMaskTex ("SDFMaskTex", 2D) = "white" {}

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
        Tags { "RenderType"="Transparent" "Queue"="Transparent"}
        LOD 100

        CGINCLUDE
        #include "../Includes/FPT_Core.cginc"
        #include "../Includes/FPT_Outline.cginc"
        #include "../Includes/FPT_Lighting.cginc"

        #pragma skip_variants LIGHTMAP_ON DYNAMICLIGHTMAP_ON LIGHTMAP_SHADOW_MIXING SHADOWS_SHADOWMASK DIRLIGHTMAP_COMBINED

        fixed drawRimLighting(float2 INuv, float4 INscreenPos, float3 viewDir, float3 INnormal) {
            float2 viewportPos = INscreenPos.xy / INscreenPos.w;
            float2 screenPos = viewportPos * _ScreenParams.xy;
            fixed4 rimLightMask = tex2D(_RimLightMask, INuv);
            return lerp(0., pow(1. - saturate(dot(viewDir, INnormal)), 2.), _RimLightStrength) * rimLightMask.x;
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
            #pragma vertex vert_main_pass
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

                fixed3 factor = CaluculateShadow(i, N, L, NdotL);
                if (_ReceiveShadow) factor *= attenuation;

                fixed4 col = tex2D(_MainTex, i.uv) * _MainTexOverlayColor;
                CalculateMaterialEffects(col, i, N, L, viewDir);

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
            #pragma vertex vert_main_pass
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

                fixed3 factor = CaluculateShadow(i, N, L, NdotL);

                fixed4 col = tex2D(_MainTex, i.uv) * _MainTexOverlayColor;
                CalculateMaterialEffects(col, i, N, L, viewDir);

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
            #pragma geometry geom_outline
            #pragma fragment frag_outline

            appdata vert(appdata v)
            {
                return v;
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
        // For ShadowRendering (not for outline)
        Pass
        {
            Tags {"LightMode" = "ShadowCaster"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"

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
        // For ShadowRendering (for outline)
        Pass
        {
            Tags {"LightMode" = "ShadowCaster"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"

            v2f_shadow vert(appdata_base v)
            {
                v2f_shadow o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                o.pos = CalculateOutlineVertex(v.normal, v.texcoord.xy, v.vertex, _OuterOutlineWidth);
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
