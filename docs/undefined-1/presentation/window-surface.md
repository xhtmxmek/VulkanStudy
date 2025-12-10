# Window Surface

Vulkan은 플랫폼 독립적인 API이므로 각 윈도우  시스템(여기서  말하는 윈도우는 운영체제별로 제공하는 창시스템을의미.  윈도우의  경우엔 win32)과 직접적인 통신 불가능. 결과를 화면에 표시하려면 WSI(window system integration) 확장을 이용해야한다. VK\_KHR\_surface확장은 이미지를 표현할 추상화된 surface를 VkSurfaceKHR로 나타낸다. 프로그램에서 이 표면은 GLFW로 이미 열린 윈도우를 기반으로 한다.

VK\_KHR\_surface는 인스턴스 확장이고, glfwGetRequiredInstanceExtension으로 얻어온다.

window surface는 인스턴스 생성 직후에 생성해야 한다. 물리적 장치 선택에 영향을 미칠수 있다.해당 surface에  물리디바이스가 렌더링  할 수 있는지 검사해야 하기 때문이다.  오프스크린 렌더링을 할 경우 surface는 선택사항이다.

플랫폼별로 추가 기능이 있는데, Windows 같은 경우에는 VK\_KHR\_win32\_surface이다.&#x20;

```cpp
VkWin32SurfaceCreateInfoKHR createInfo{};
createInfo.sType = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR;
createInfo.hwnd = glfwGetWin32Window(window);
createInfo.hinstance = GetModuleHandle(nullptr);

if (vkCreateWin32SurfaceKHR(instance, &createInfo, nullptr, &surface) != VK_SUCCESS) {
    throw std::runtime_error("failed to create window surface!");
}

void createSurface()
{
    if (glfwCreateWindowSurface(instance, window, nullptr, &surface) != VK_SUCCESS)
		    throw std::runtime_error("failed to create window surface!");

}
```

리눅스의 경우에는 vkCreateXcbSurfaceKHR로 xcb 라이브러리와 연결함. 창을 x11의 세부정보로사용.

glfwCreateWindowSurface를 사용하면 플랫폼마다 다른 구현으로 이 작업을 정확하게 수행한다.



#### 프레이젠테이션 지원 쿼리

Vulkan이 WSI를 지원하더라도, 시스템의 모든 장치가 이를 지원하는 것은 아니다. 우리가 만든 surface에 이미지를 표시하는 기능을 지원하는 대기열 패밀리를 찾아야 한다. 즉 그리기 기능이 surface도 지원하는지 확인해야한다.

실제로 렌더링 기능을 지원하는 대기열 패밀리와 프레젠테이션을 위한 대기열 패밀리가 겹치지 않을 수 있다. vkGetPhysicalDeviceSurfaceSupportKHR 함수를 이용해서 surface에 표현 가능한 그리기 큐 패밀리 인덱스를 찾아야 한다.

```cpp
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

		VkBool32 presentSupport = false;
		vkGetPhysicalDeviceSurfaceSupportKHR(device, i, surface, &presentSupport);

		if (presentSupport) {
			indices.presentFamily = i;
		}

		if (indices.isComplete())
			break;

		i++;
	}

	return indices;
}

struct QueueFamilyIndices
{
	std::optional<uint32_t> graphicsFamily;
	std::optional<uint32_t> presentFamily;

	bool isComplete()
	{
		return graphicsFamily.has_value() && presentFamily.has_value();
	}
};
```

#### 프레젠테이션 대기열 만들기

논리디바이스 생성시 presentation queue도 생성하기위해 vkDeviceQueueCreateInfo를 벡터로 넘긴다. presentation queue 핸들을 얻어오기 위한 변수를 새로 설정한다. 그리기 큐와 프레젠테이션 큐가 동일한 경우, 두 핸들이 같은 값을 가질 가능성이 높다.

```cpp
VkQueue presentQueue;

void CreateLogicalDevice()
{
	QueueFamilyIndices indices = findQueueFamilies(physicalDevice);

	std::vector<VkDeviceQueueCreateInfo> queueCreateInfos;
	std::set<uint32_t> uniqueQueueFamilies = { indices.graphicsFamily.value(), indices.presentFamily.value() };

	float queuePriority = 1.0f;
	for (uint32_t queueFamily : uniqueQueueFamilies)
	{
		VkDeviceQueueCreateInfo queueCreateInfo{};
		queueCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
		queueCreateInfo.queueFamilyIndex = queueFamily;
		queueCreateInfo.queueCount = 1;
		queueCreateInfo.pQueuePriorities = &queuePriority;
		queueCreateInfos.push_back(queueCreateInfo);
	}

	VkPhysicalDeviceFeatures deviceFeatures{};

	VkDeviceCreateInfo createInfo{};
	createInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
	createInfo.pQueueCreateInfos = queueCreateInfos.data();
	createInfo.queueCreateInfoCount = static_cast<uint32_t>(queueCreateInfos.size());
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
	vkGetDeviceQueue(device, indices.presentFamily.value(), 0, &presentQueue);
}
```
