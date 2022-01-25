using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace JSRender
{
    public class ColorAdjustComputeFeature : ScriptableRendererFeature
    {
        [System.Serializable]
        public class Settings
        {
            public string RenderPassName = "JSRender Compute ColorAdjust";
            public ComputeShader CShader = null;
            [Range(0, 2), Tooltip("饱和度")]
            public float Satureate = 1;
            [Range(0, 2), Tooltip("明暗度")]
            public float Bright = 1;
            [Range(-2, 3), Tooltip("对比度")]
            public float Constrast = 1;

            public RenderPassEvent RenderPassEvent = RenderPassEvent.AfterRenderingTransparents;
        }
        class CustomRenderPass : ScriptableRenderPass
        {
            private const string PROFILER_TAG = "JSRender Compute ColorAdjust Pass";
            private Settings s_Settings;
            private ComputeShader s_CShader;
            private RenderTargetIdentifier s_Src;
            //private int s_ColorAdjustID = Shader.PropertyToID("ColorAdjustID");

            public CustomRenderPass(ref Settings settings)
            {
                this.s_Settings = settings;
                s_CShader = settings.CShader;
            }

            public void Setup(RenderTargetIdentifier src)
            {
                this.s_Src = src;
            }

            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                if (renderingData.cameraData.isSceneViewCamera) return;
                CommandBuffer cmd = CommandBufferPool.Get(s_Settings.RenderPassName);
                cmd.Clear();

                int s_ColorAdjustID = Shader.PropertyToID("ColorAdjustID");

                RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
                desc.enableRandomWrite = true;

                cmd.GetTemporaryRT(s_ColorAdjustID, desc);
                cmd.SetComputeFloatParam(s_CShader, "_Bright", s_Settings.Bright);
                cmd.SetComputeFloatParam(s_CShader, "_Saturate", s_Settings.Satureate);
                cmd.SetComputeFloatParam(s_CShader, "_Constrast", s_Settings.Constrast);

                cmd.SetComputeTextureParam(s_CShader, 0, "_Ret", s_ColorAdjustID);
                cmd.SetComputeTextureParam(s_CShader, 0, "_Src", s_Src);

                cmd.DispatchCompute(s_CShader, 0, (int)desc.width / 8, (int)desc.height / 8, 1);
                cmd.Blit(s_ColorAdjustID, s_Src);

                context.ExecuteCommandBuffer(cmd);
                CommandBufferPool.Release(cmd);
            }

            // Cleanup any allocated resources that were created during the execution of this render pass.
            public override void OnCameraCleanup(CommandBuffer cmd)
            {
                //cmd.ReleaseTemporaryRT(s_ColorAdjustID);
            }
        }

        CustomRenderPass m_ScriptablePass;
        public Settings m_ScriptableSettings;

        /// <inheritdoc/>
        public override void Create()
        {
            m_ScriptablePass = new CustomRenderPass( ref m_ScriptableSettings );
            m_ScriptablePass.renderPassEvent = m_ScriptableSettings.RenderPassEvent;
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (m_ScriptableSettings.CShader != null)
            {
                m_ScriptablePass?.Setup(renderer.cameraColorTarget);
                renderer.EnqueuePass(m_ScriptablePass);
            }
        }
    }
}
