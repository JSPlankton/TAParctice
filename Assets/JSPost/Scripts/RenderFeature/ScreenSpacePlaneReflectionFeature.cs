using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

/*
 * 对于高度为RT,宽度为 RT / aspect（屏幕宽纵比）的图，需要使用 RT * RT / aspect 个线程进行处理
 * 因为是对2d图像进行处理，我们希望调度线程id和UV保持对应
 * 组内线程id使用2维 (8, 8, 1) = 一个线程组有64个线程；
 * 线程调度使用2维 (RT / 8 / aspect, RT / 8, 1)
 * 保证 0->1的UV ==对应==> 0->RT-1
 * 确保UV和id的对应关系正确
 */
namespace JSRender
{
    [System.Serializable]
    public class Settings
    {
        public RenderPassEvent eventPlugin = RenderPassEvent.AfterRenderingTransparents;
        public string commandName = "屏幕空间反射SSPR";
    }
    public class ScreenSpacePlaneReflectionFeature : ScriptableRendererFeature
    {
        public struct Thread    //存储线程相关数据
        {
            public int GroupThreadX;    //线程组内id x分量
            public int GroupThreadY;    //线程组内id y分量
            public int GroupX;          //线程组id x分量
            public int GroupY;          //线程组id y分量
        }
        class CustomRenderPass : ScriptableRenderPass
        {
            private ScreenSpacePlaneReflection SSPRVolume;
            private Thread SSPRThread = new Thread();
            private int xSize;
            private int ySize;
            //存储反射图像颜色
            private static readonly int reflectColor = Shader.PropertyToID("_ReflectColor");
            private static readonly int reflectDepth = Shader.PropertyToID("_ReflectDepth");
            private RenderTargetIdentifier reflectColorId = new RenderTargetIdentifier(reflectColor);
            private RenderTargetIdentifier reflectDepthId = new RenderTargetIdentifier(reflectDepth);
            private ComputeShader CShader;
            private Settings _settings;

            public CustomRenderPass(Settings settings)
            {
                _settings = settings;
            }

            public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
            {
                //获取自定义后处理组件来使用参数控制反射效果
                var postStack = VolumeManager.instance.stack;
                SSPRVolume = postStack.GetComponent<ScreenSpacePlaneReflection>();
                
                float aspect = (float) Screen.height / Screen.width;
                SSPRThread.GroupThreadX = 8;
                SSPRThread.GroupThreadY = 8;
                SSPRThread.GroupY = SSPRVolume.rtSize.value / SSPRThread.GroupThreadY;
                SSPRThread.GroupX = Mathf.RoundToInt(SSPRThread.GroupY / aspect);

                xSize = SSPRThread.GroupThreadX * SSPRThread.GroupX;
                ySize = SSPRThread.GroupThreadY * SSPRThread.GroupY;
                //计算需要4张图
                //1.屏幕颜色(URP-_CameraColorTexture) 2.屏幕深度(URP-_CameraDepthTexture)
                //3.反射后的屏幕颜色(自己计算) 4.反射后的屏幕深度(自己计算)
                RenderTextureDescriptor desc = new RenderTextureDescriptor(xSize, ySize, RenderTextureFormat.ARGB32);
                desc.enableRandomWrite = true;  //绑定UAV
                cmd.GetTemporaryRT(reflectColor, desc);
                desc.colorFormat = RenderTextureFormat.R8; //只需要使用R通道,对精度要求不高
                cmd.GetTemporaryRT(reflectDepth, desc);

                CShader = AssetDatabase.LoadAssetAtPath<ComputeShader>("Assets/JSPost/Shader/SSPR.compute");
            }

            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                if (CShader == null)
                {
                    Debug.LogError("SSPR ComputeShader Lost!");
                    return;
                }

                if (SSPRVolume.@on.value)
                {
                    CommandBuffer cmd = CommandBufferPool.Get(_settings.commandName);
                    cmd.SetComputeFloatParam(CShader, Shader.PropertyToID("reflectPlaneH"), SSPRVolume.reflectHeight.value);
                    cmd.SetComputeVectorParam(CShader, Shader.PropertyToID("rtSize"), new Vector2(xSize, ySize));
                    cmd.SetComputeFloatParam(CShader, Shader.PropertyToID("fadeOut2Edge"), SSPRVolume.fadeOutRange.value);
                }
            }

            public override void OnCameraCleanup(CommandBuffer cmd)
            {
            }
        }

        CustomRenderPass m_ScriptablePass;
        private Settings m_Settings;

        /// <inheritdoc/>
        public override void Create()
        {
            m_ScriptablePass = new CustomRenderPass(m_Settings);
            m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            renderer.EnqueuePass(m_ScriptablePass);
        }
    }
}


