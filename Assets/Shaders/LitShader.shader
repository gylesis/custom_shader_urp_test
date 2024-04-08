Shader "Custom/MyLitShader"
{
    Properties
    {
        _BaseMap ("Example Texture", 2D) = "white" {}
        _BaseColor ("Example Colour", Color) = (0, 0.66, 0.73, 1)
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
            UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor);
            float4 _BaseMap_ST;
        CBUFFER_END
        
        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags
            {
                "LightMode"="UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING 
            #pragma multi_compile _ SHADOWS_SHADOWMASK 

            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float4 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                float2 lightmapUV : TEXCOORD1;
                float4 color : COLOR;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
                float3 normalWS : TEXCOORD2;
                float3 positionWS : TEXCOORD3;
                float4 color : COLOR;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            Varyings LitPassVertex(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionCS = positionInputs.positionCS;
                OUT.positionWS = positionInputs.positionWS;

                VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS.xyz);
                OUT.normalWS = normalInputs.normalWS;

                OUTPUT_LIGHTMAP_UV(IN.lightmapUV, unity_LightmapST, OUT.lightmapUV);
                OUTPUT_SH(OUT.normalWS.xyz, OUT.vertexSH);

                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                OUT.color = IN.color;
                return OUT;
            }

            half4 LitPassFragment(Varyings IN) : SV_Target
            {
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);

                half3 bakedGI = SAMPLE_GI(IN.lightmapUV, IN.vertexSH, IN.normalWS);

                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS.xyz);
                Light mainLight = GetMainLight(shadowCoord);
                half3 attenuatedLightColor = mainLight.color * (mainLight.distanceAttenuation * mainLight.
                    shadowAttenuation);

                MixRealtimeAndBakedGI(mainLight, IN.normalWS, bakedGI);

                half3 shading = bakedGI + LightingLambert(attenuatedLightColor, mainLight.direction, IN.normalWS);
                half4 color = baseMap * UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor) * IN.color;
               // half4 color = baseMap * _BaseColor * IN.color;

                LIGHT_LOOP_BEGIN(GetAdditionalLightsCount())
                    Light light = GetAdditionalLight(lightIndex, IN.positionWS);

                    float3 lightColor = light.color * (light.distanceAttenuation * light.shadowAttenuation);

                    color += float4(lightColor, 1);
                LIGHT_LOOP_END

                return half4(color.rgb * shading, color.a);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Fragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes {
            	float3 positionOS : POSITION;
            	float3 normalOS : NORMAL;
            };
            
            struct Interpolators {
            	float4 positionCS : SV_POSITION;
            };
            
            float3 _LightDirection;
            
            float4 GetShadowCasterPositionCS(float3 positionWS, float3 normalWS) {
            	float3 lightDirectionWS = _LightDirection;
            	float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
            	positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
           
            	return positionCS;
            }
            
            Interpolators Vertex(Attributes input) {
            	Interpolators output;
            
            	VertexPositionInputs posnInputs = GetVertexPositionInputs(input.positionOS); 
            	VertexNormalInputs normInputs = GetVertexNormalInputs(input.normalOS); 
            
            	output.positionCS = GetShadowCasterPositionCS(posnInputs.positionWS, normInputs.normalWS);
            	return output;
            }
            
            float4 Fragment(Interpolators input) : SV_TARGET {
            	return 0;
            }
            ENDHLSL
        }

    }
}