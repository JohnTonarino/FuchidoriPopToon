// Copyright (c) 2024 JohnTonarino
// Released under the MIT license
// FuchidoriPopToon v 1.0.10
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
        [Enum(Lerp,0,Mul,1)]_MatCapType ("MatCapCalcType", int) = 0
        _MatCapStrength("MatCapStrength", Range(0., 1.)) = 0.
        _MatCapMask("MatCapMask", 2D) = "white" {}

        [Header(Specular)]
        [Space(10)]
        _SpecularColor ("Specular Color", Color) = (1, 1, 1, 1)
        _SpecularStrength("SpecularStrength",Range(0., 1.)) = 0.
        _SpecularSize ("Specular Size", Range(0, 1)) = 0.8
        _SpecularSmoothness ("Specular Smoothness", Range(0.001, 0.25)) = 0.02
        _SpecPatternTex   ("Spec Pattern Tex", 2D) = "white" {}
        _SpecPatternScale ("Spec Pattern Scale", Float) = 1.0

        [Header(Shadow)]
        [Space(10)]
        _ShadowTex("ShadowTex", 2D) = "white" {}
        _ShadowOverlayColor1st("ShadowOverlayColor1st", Color) = (0., 0., 0., 1.)
        _ShadowOverlayColor2nd("ShadowOverlayColor2nd", Color) = (0., 0., 0., 1.)
        _ShadowStep1("Second Shadow Border", Range(0.0, 1.0)) = 0.3
        _ShadowStep2("Lit Border",Range(0.0, 1.0)) = 0.5
        _ShadowEdgeSmoothness("ShadowEdgeSmoothness",Range(0., 1.)) = 0.05
        _ShadowStrength("ShadowStrength",Range(0., 1.)) = 0.5
        [Toggle(_)] _SDFOn("SDF", Int) = 0
        _SDFMaskTex ("SDFMaskTex", 2D) = "white" {}
        _ShadowPatternTex      ("Shadow Pattern Tex", 2D) = "white" {}
        _ShadowPatternScale    ("Shadow Pattern Scale", Float) = 1.0

        [Header(RimColor)]
        [Space(10)]
        _RimColor("RimLightColor", Color) = (1., 1., 1., 1.)
        _RimLightStrength("RimLightStrength", Range(0., 1.)) = .5
        _RimPower("RimLightPower", Range(0.25, 8.0)) = 2.0
        _RimSmoothness("RimSmoothness", Range(0.001, 0.49)) = 0.08
        _RimLightMask("RimLightMask", 2D) = "white" {}
        _RimPatternTex      ("Rim Pattern Tex", 2D) = "white" {}
        _RimPatternScale    ("Rim Pattern Scale", Float) = 1.0

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
        [Toggle(_)] _VertexColorNormal("VertexColorNormal", Int) = 0
        _AsOutlineUnlit("As OutlineUnlit", Range(0,1)) = 0.5

        [Header(Transparent)]
        [Space(10)]
        _TransparentMask("TransparentMask", 2D) = "white" {}
        _TransparentLevel("TransparentLevel", Range(0., 1.)) = 0.

        [Header(Emission)]
        [Space(10)]
        _EmissiveTex("EmissiveTex", 2D) = "black" {}
        [HDR] _EmissiveColor("EmissiveColor", Color) = (1., 1., 1., 1.)

        [Header(VRCLightVolumes)]
        [Space(10)]
        [Toggle(_)] _VRCLightVolumesOn("VRCLightVolumes", Int) = 0
        _VRCLightVolumesStrength("VRCLightVolumesStrength", Range(0., 1.)) = 1.

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
        [Toggle(_)] _ReceiveShadow("Receive Shadow", Int) = 0

        //------------------------------------------------------------------------------------------------------------------------------
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry"}
        LOD 100

        CGINCLUDE
        #include "../Includes/FPT_Core.cginc"
        #include "../Includes/FPT_Outline.cginc"
        #include "../Includes/FPT_Lighting.cginc"

        #pragma skip_variants LIGHTMAP_ON DYNAMICLIGHTMAP_ON LIGHTMAP_SHADOW_MIXING SHADOWS_SHADOWMASK DIRLIGHTMAP_COMBINED
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

                float3 viewDir = normalize(UnityWorldSpaceViewDir(i.positionWS));

                // Lighting
                // [OpenLit] Copy light datas from the input
                OpenLitLightDatas lightDatas;
                FPT_UnpackOpenLitData(i, lightDatas);

                half3 normalmap = UnpackScaleNormal(tex2D(_BumpMap, i.uv), _BumpScale);
                float3 N = normalize(i.tangent * normalmap.x + i.binormal * normalmap.y + i.normalWS * normalmap.z);
                float3 L = lightDatas.lightDirection;

                half3 albedo = tex2D(_MainTex, i.uv).rgb * _MainTexOverlayColor.rgb;

                albedo = FPT_MatCap(albedo, i.uv, N);
                albedo = FPT_Rim(i.positionWS, albedo, i.uv, i.normalWS, viewDir);

                half3 color = FPT_BaseLighting(i, albedo, N, L, attenuation);

                color += FPT_Specular(i.positionWS, N, L, viewDir)*lightDatas.directLight*attenuation;

#if !defined(LIGHTMAP_ON) && UNITY_SHOULD_SAMPLE_SH
                color += albedo * i.vertexLight;
                color = min(color, albedo* _LightMaxLimit);
#endif

                color += tex2D(_EmissiveTex, i.uv).rgb * _EmissiveColor.rgb;
                fixed4 result = fixed4(color, 1.0);
                UNITY_APPLY_FOG(i.fogCoord, result);

                return result;
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

                float3 viewDir = normalize(UnityWorldSpaceViewDir(i.positionWS));

                // Lighting
                // [OpenLit] Copy light datas from the input
                OpenLitLightDatas lightDatas;
                FPT_UnpackOpenLitData(i, lightDatas);

                half3 normalmap = UnpackScaleNormal(tex2D(_BumpMap, i.uv), _BumpScale);
                float3 N = normalize(i.tangent * normalmap.x + i.binormal * normalmap.y + i.normalWS * normalmap.z);
                float3 L = normalize(UnityWorldSpaceLightDir(i.positionWS));

                fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _MainTexOverlayColor.rgb;

                fixed lightLevel = FPT_LitFactor(i, N, L);
                fixed toonLight = _SDFOn > 0.5h?
                    lightLevel:
                    smoothstep(
                        _ShadowStep2-_ShadowEdgeSmoothness,
                        _ShadowStep2+_ShadowEdgeSmoothness,
                        lightLevel
                    );
                toonLight = lerp(1.0, toonLight, _ShadowStrength);

                fixed3 addLight = OPENLIT_LIGHT_COLOR*attenuation;
                fixed3 contribution = albedo*addLight*toonLight;

                fixed4 result = fixed4(contribution, 0.0);
                UNITY_APPLY_FOG(i.fogCoord, result);

                return result;
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
                o = vert_outlinebase(v);
                o.pos.xy += (_VertexColorNormal == 1) ?
                    CalculateOffsetVectorVertex(v.color, v.normalOS, v.tangent, v.uv, v.vertex)*_InnerOutlineWidth:
                    CalculateOffsetVectorNormal(v.normalOS, v.uv)*_InnerOutlineWidth;
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
                o.pos = UnityObjectToClipPos(v.vertex);
                o.pos.xy += CalculateOffsetVectorNormal(v.normal, v.texcoord.xy)*_OuterOutlineWidth;
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
