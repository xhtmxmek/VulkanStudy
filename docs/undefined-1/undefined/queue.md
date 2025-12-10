# 논리적 장치와 queue

물리적 디바이스를 찾은 뒤에는 해당 디바이스와 연동할 논리 장치를 세팅해야한다.  동일한 물리적 장치에 대해 요구사항에따라여러 논리적 장치를 생성 할 수도 있다.(그래픽전용, 컴퓨팅 전용 등 여러 큐패밀리와매칭되는 논리적디바이스들을  하나의 물리적 장치에 연동 할수 있다는 뜻인것 같다). 몇가지 기억할만한 특징들이있다.

* queueCount는 실제로 두개이상 필요하지 않기 때문에 하나만 지정
* 대기열 우선순위를 지정할 수 있다.  0.0\~1.0 사이로. 대기열이 하나여도 필수로 지정해야함
* vkInstanceCreateInfo처럼 확장자와 검증 계층을 지정해야 한다. 최신 vulkan에서는 enableLayerCount와 ppEnabledLayerNames가 무시되지만, 이전 버전과 호환되도록 설정해 놓는 것이 좋다.
* 논리 디바이스와 queue는 같이 생성되지만, queue에 대한 핸들은 vkGetDeviceQueue로 얻어와야함

```cpp
void CreateLogicalDevice()
{
	QueueFamilyIndices indices = findQueueFamilies(physicalDevice);

	VkDeviceQueueCreateInfo queueCreateInfo{};
	queueCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
	queueCreateInfo.queueFamilyIndex = indices.graphicsFamily.value();
	queueCreateInfo.queueCount = 1;
	float queuePriority = 1.0f;
	queueCreateInfo.pQueuePriorities = &queuePriority;

	VkPhysicalDeviceFeatures deviceFeatures{};

	VkDeviceCreateInfo createInfo{};
	createInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
	createInfo.pQueueCreateInfos = &queueCreateInfo;
	createInfo.queueCreateInfoCount = 1;
	createInfo.pEnabledFeatures = &deviceFeatures;

	createInfo.enabledExtensionCount = 0;
	if (enableValidationLayers)
	{
		createInfo.enabledLayerCount = static_cast<uint32_t>(validationLayers.size());
		createInfo.ppEnabledLayerNames = validationLayers.data();
	}
	else
	{
		createInfo.enabledLayerCount = 0;
	}

	if (vkCreateDevice(physicalDevice, &createInfo, nullptr, &device) != VK_SUCCESS)
	{
		throw std::runtime_error("failed to create logical device!");
	}

	vkGetDeviceQueue(device, indices.graphicsFamily.value(), 0, &graphicsQueue);
}
```
