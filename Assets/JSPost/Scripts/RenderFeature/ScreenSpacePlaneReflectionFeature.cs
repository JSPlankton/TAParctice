using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace JSRender
{
    public class ScreenSpacePlaneReflectionFeature : ScriptableRendererFeature
    {
        class CustomRenderPass : ScriptableRenderPass
        {

            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
            }

            public override void OnCameraCleanup(CommandBuffer cmd)
            {
            }
        }

        CustomRenderPass m_ScriptablePass;

        /// <inheritdoc/>
        public override void Create()
        {
            m_ScriptablePass = new CustomRenderPass();
            m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            renderer.EnqueuePass(m_ScriptablePass);
        }
    }
}


