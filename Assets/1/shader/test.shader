Shader "test"
{
    Properties
    {
        [Header(BaseInfo)]
        _BaseMap("BaseMap", 2D) = "white" {}
        _CompMask("CompMask(RM)", 2D) = "white" {}
        [Normal] _NormalMap("NormalMap", 2D) = "bump" {}
        _RoughnessAdjust("Roughness Adjust", Range(-1, 1)) = 0.0
        _MetalAdjust("Metal Adjust", Range(-1, 1)) = 0.0
        _SpecShininess("Spec Shininess", Float) = 10

        [Header(SSS)]
        _SkinLUT("Skin LUT", 2D) = "white" {}
        _SSSOffset("SSS Offset", Range(-1, 1)) = 0

        [Header(IBL)]
        _EnvMap("Env Map", Cube) = "white" {}
        _Expose("Expose", Float) = 1.0

        [Toggle(_DIFFUSECHECK_ON)] _DiffuseCheck("Diffuse Check", Float) = 1.0
        [Toggle(_SPECCHECK_ON)] _SpecCheck("Spec Check", Float) = 1.0
        [Toggle(_SHCHECK_ON)] _SHCheck("SH Check", Float) = 1.0
        [Toggle(_IBLCHECK_ON)] _IBLCheck("IBL Check", Float) = 1.0

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
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }
        LOD 100

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        TEXTURE2D(_BaseMap);        SAMPLER(sampler_BaseMap);
        TEXTURE2D(_CompMask);       SAMPLER(sampler_CompMask);
        TEXTURE2D(_NormalMap);      SAMPLER(sampler_NormalMap);
        TEXTURE2D(_SkinLUT);        SAMPLER(sampler_SkinLUT);
        TEXTURECUBE(_EnvMap);       SAMPLER(sampler_EnvMap);

        CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            float4 _EnvMap_HDR;
            half _RoughnessAdjust;
            half _MetalAdjust;
            half _SpecShininess;
            half _SSSOffset;
            half _Expose;
            half4 custom_SHAr;
            half4 custom_SHAg;
            half4 custom_SHAb;
            half4 custom_SHBr;
            half4 custom_SHBg;
            half4 custom_SHBb;
            half4 custom_SHC;
        CBUFFER_END
        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForwardOnly" }

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex CharacterBodyVertex
            #pragma fragment CharacterBodyFragment

            #pragma shader_feature_local_fragment _DIFFUSECHECK_ON
            #pragma shader_feature_local_fragment _SPECCHECK_ON
            #pragma shader_feature_local_fragment _SHCHECK_ON
            #pragma shader_feature_local_fragment _IBLCHECK_ON

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile_instancing

            #define CHARACTER_SKIN_SPECULAR_F0 0.05h
            #include "CharacterBodyForwardPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex CharacterShadowVertex
            #pragma fragment CharacterShadowFragment
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #pragma multi_compile_instancing
            #include "CharacterShadowCasterPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            ZWrite On
            ColorMask R

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex CharacterDepthVertex
            #pragma fragment CharacterDepthFragment
            #pragma multi_compile_instancing
            #include "CharacterDepthOnlyPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode" = "DepthNormalsOnly" }
            ZWrite On

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex CharacterDepthNormalsVertex
            #pragma fragment CharacterDepthNormalsFragment
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #pragma multi_compile_instancing
            #include "CharacterDepthNormalsPass.hlsl"
            ENDHLSL
        }
    }

    FallBack Off
}
