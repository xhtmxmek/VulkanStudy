C:/VulkanSDK/1.4.328.1/Bin/dxc.exe -T vs_6_0 -E main vertex.hlsl -spirv  -fspv-target-env=vulkan1.3 -Fo vertex.spv
C:/VulkanSDK/1.4.328.1/Bin/dxc.exe -T ps_6_0 -E main pixel.hlsl -spirv  -fspv-target-env=vulkan1.3 -Fo pixel.spv
pause