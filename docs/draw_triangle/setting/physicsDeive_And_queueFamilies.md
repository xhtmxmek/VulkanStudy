# 물리적 장치 및 대기열 패밀리

vulkan 인스턴스 초기화 후에는 물리적 그래픽 카드를 선택해야한다.&#x20;

```cpp
    //...
    VkPhysicalDevice physicalDevice = VK_NULL_HANDLE;
    
    void pickPhysicalDevice() 
    {
        uint32_t deviceCount = 0;
        vkEnumeratePhysicalDevices(instance, &deviceCount, nullptr);
        if (deviceCount == 0)
            throw std::runtime_error("failed to find GPUs with Vulkan support!");

        std::vector<VkPhysicalDevice> devices(deviceCount);
        vkEnumeratePhysicalDevices(instance, &deviceCount, devices.data());
        for (const auto& device : devices)
        {
            if (isDeviceSuitable(device))
            {
                physicalDevice = device;
                break;
            }
        }

        if (physicalDevice == VK_NULL_HANDLE)
            throw std::runtime_error("failed to find a suitable GPU!");
    }
```

디바이스가 적합한 기능들을 지원하는지 검사하고 사용여부를 결정할 수 있다. 예를 들어 외장 GPU를 원한다면 VK\_PHYSICAL\_DEVICE\_TYPE\_DISCRETE\_GPU, 내장 GPU를 검색한다면 VK\_PHYSICAL\_DEVICE\_TYPE\_INTEGRATED\_GPU, 기하 셰이더를 원한다면 deviceFeatures.geometryShader. 이외에도 기능에 따라 가중치를 주는 방법도 있다.

```cpp
bool isDeviceSuitable(VkPhysicalDevice device)
{
    VkPhysicalDeviceProperties deviceProperties;
    vkGetPhysicalDeviceProperties(device, &deviceProperties);

    VkPhysicalDeviceFeatures deviceFeatures;
    vkGetPhysicalDeviceFeatures(device, &deviceFeatures);

    //deviceProperties.deviceType == VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU && deviceFeatures.geometryShader;
    // 
    QueueFamilyIndices indices = findQueueFamilies(device);

    return indices.isComplete();
    //return true;
}
```

#### queue family

그리기, 텍스처 업로드등 모든 작업 명령은 queue에 제출해야 한다. 여러 유형의 queue family가 있으며 각 queue family는 일부 명령만 허용. 컴퓨팅 명령만 처리한다거나, 파일 메모리 전송 명령만 허용한다던가.

렌더링을 위해서 그래픽 명령만 처리하는 queue family를 찾는다. optional을 활용하여 값이 존재하는지 확인

```cpp
struct QueueFamilyIndices
{
    std::optional<uint32_t> graphicsFamily;
    bool isComplete()
    {
        return graphicsFamily.has_value();
    }
};


QueueFamilyIndices findQueueFamilies(VkPhysicalDevice device)
{
    QueueFamilyIndices indices;

    uint32_t queueFamilyCount = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, nullptr);

    std::vector<VkQueueFamilyProperties> queueFamilies(queueFamilyCount);
    vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, queueFamilies.data());

    int i = 0;
    for (const auto& queueFamily : queueFamilies)
    {
        if (queueFamily.queueFlags & VK_QUEUE_GRAPHICS_BIT)
        {
            indices.graphicsFamily = i;
        }

        if (indices.isComplete())
            break;

        i++;
    }

    return indices;
}
```

