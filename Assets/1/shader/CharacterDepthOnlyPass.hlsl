#ifndef CHARACTER_DEPTH_ONLY_PASS_INCLUDED
#define CHARACTER_DEPTH_ONLY_PASS_INCLUDED

struct CharacterDepthAttributes
{
    float4 positionOS : POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct CharacterDepthVaryings
{
    float4 positionCS : SV_POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

CharacterDepthVaryings CharacterDepthVertex(CharacterDepthAttributes input)
{
    CharacterDepthVaryings output = (CharacterDepthVaryings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
    return output;
}

half4 CharacterDepthFragment(CharacterDepthVaryings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
    return 0.0h;
}

#endif
