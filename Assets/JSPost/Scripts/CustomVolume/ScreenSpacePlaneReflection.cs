using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace JSRender
{
    [SerializeField, VolumeComponentMenu("JSRender/PostProcessing/ScreenSpacePlaneReflection)")]
    public class ScreenSpacePlaneReflection : VolumeComponent
    {
        public BoolParameter on = new BoolParameter(false);
        public ClampedIntParameter rtSize = new ClampedIntParameter(512, 128, 720, false);
        public FloatParameter reflectHeight = new FloatParameter(0.2f, false);
        public ClampedFloatParameter fadeOutRange = new ClampedFloatParameter(0.3f, 0.0f, 1.0f, false);
        public bool IsActive() => on.value;
        public bool IsTileCompatible() => false;
    }

}
