#ifndef CHARACTER_DEPTH_NORMALS_PASS_INCLUDED
#define CHARACTER_DEPTH_NORMALS_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"

struct CharacterDepthNormalsAttributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct CharacterDepthNormalsVaryings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    half3 normalWS : TEXCOORD1;
    half4 tangentWS : TEXCOORD2;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

CharacterDepthNormalsVaryings CharacterDepthNormalsVertex(
    CharacterDepthNormalsAttributes input)
{
    CharacterDepthNormalsVaryings output = (CharacterDepthNormalsVaryings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
    output.normalWS = normalInputs.normalWS;
    output.tangentWS = half4(normalInputs.tangentWS, input.tangentOS.w * GetOddNegativeScale());
    return output;
}

half4 CharacterDepthNormalsFragment(CharacterDepthNormalsVaryings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv));
    half3 normalWS = NormalizeNormalPerPixel(input.normalWS);
    half3 tangentWS = normalize(input.tangentWS.xyz);
    half3 bitangentWS = input.tangentWS.w * cross(normalWS, tangentWS);
    normalWS = NormalizeNormalPerPixel(TransformTangentToWorld(
        normalTS, half3x3(tangentWS, bitangentWS, normalWS)));

    #if defined(_GBUFFER_NORMALS_OCT)
        float2 octNormalWS = PackNormalOctQuadEncode(normalWS);
        float2 remappedOctNormalWS = saturate(octNormalWS * 0.5 + 0.5);
        return half4(PackFloat2To888(remappedOctNormalWS), 0.0h);
    #else
        return half4(normalWS, 0.0h);
    #endif
}

#endif
