# 커맨드 버퍼

## DX11 vs Vulkan Command Model 정리 요약

### 1. DX11의 Command 실행 방식

#### ✔ Immediate Context
- API 호출 시 **즉시 드라이버로 전달**
- 드라이버가 상태 변경, validation, hazard 추론을 **즉시 수행**
- 멀티스레드 접근 시 내부적으로 **락(lock) 발생**

#### ✔ Deferred Context
- 여러 스레드에서 Command List를 생성 가능
- 하지만:
  - Command 기록 중에도 **드라이버에 접근**
  - 상태 추론 / validation / 리소스 추적 수행
  - 결국 **락 + 드라이버 오버헤드 발생**
- Command List는 마지막에 Immediate Context로 제출

➡ **“모든 명령을 한 번에 제출”해도  
명령 생성 단계부터 이미 드라이버 병목이 존재**

---

### 2. Vulkan의 Command Buffer 모델

#### ✔ 명령 기록과 실행의 완전한 분리
- Command Buffer 기록 시:
  - **드라이버 로직 거의 없음**
  - validation, 상태 추론 없음
  - 단순한 명령 스트림 생성
- 여러 스레드에서 **락 없이 병렬 기록 가능**

#### ✔ 제출 시점에만 드라이버 개입
- `vkQueueSubmit()` 시:
  - 전체 명령을 한 번에 전달
  - 드라이버가 명령을 **일괄 분석 & 최적화**
- GPU가 명령을 효율적으로 스케줄링 가능

➡ Vulkan의 핵심 장점:
> **“Command 생성 비용이 매우 싸고, 병렬화가 진짜로 가능하다”**

---

### 3. DX11 Deferred Context vs Vulkan Command Buffer 차이

| 항목 | DX11 Deferred Context | Vulkan Command Buffer |
|----|----------------------|----------------------|
| 명령 기록 중 드라이버 접근 | 있음 | 거의 없음 |
| 내부 락 | 있음 | 없음 |
| 상태 추론 | 드라이버 암시적 처리 | 애플리케이션이 명시 |
| 멀티스레드 효율 | 제한적 | 매우 높음 |
| 명령 기록 비용 | 높음 | 매우 낮음 |

---

### 4. Vulkan Command Pool 플래그 의미

#### ✔ `VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT`
- 개별 Command Buffer를 reset 가능
- 변화가 있는 Command Buffer만 선택적으로 재녹화 가능
- **실제 렌더링에서 필수**

#### ✔ `VK_COMMAND_POOL_CREATE_TRANSIENT_BIT`
- Command Buffer가 짧게 사용됨을 알리는 **힌트**
- 있어도 되고 없어도 됨
- 성능 차이는 드라이버 의존

---

### 5. Command Buffer 재사용 전략 (엔진 관점)

#### ❌ 오브젝트 1개 = Command Buffer 1개
- 비효율적
- submit / 관리 / sync 비용 폭증

#### ✅ Pass / 그룹 단위 Command Buffer
예:
- StaticGeometryCB (거의 재녹화 없음)
- DynamicGeometryCB (매 프레임 재녹화)
- ClothCB (변화 있을 때만 재녹화)

각 CB 안에 **여러 오브젝트의 DrawCall 포함**

---

### 6. Dynamic / Cloth 처리 방식

- 변환 행렬만 바뀌는 경우:
  - Push Constant / UBO 업데이트
  - **Command Buffer 재녹화 불필요**
- Vertex Buffer 자체가 바뀌는 경우:
  - Compute / CPU 시뮬레이션 결과 반영
  - **관련 CB만 reset 후 재녹화**

---

### 7. Cloth는 왜 자주 재녹화하는가

- Cloth는:
  - Vertex Position / Normal이 매 프레임 변경
  - 단순 Transform Matrix로 표현 불가
- 결과:
  - Vertex Buffer 업데이트
  - 종종 DrawCall 순서 / 리소스 바인딩 변화
  - **해당 CB 재녹화 필요**

---

### 8. CPU Cloth vs GPU Cloth

#### GPU Cloth
- 대규모 Cloth에 매우 효율적
- 병렬성 극대화
- 하지만:
  - 디버깅 어려움
  - 작은 개수에서는 오버헤드가 더 클 수 있음

#### CPU Cloth
- 소규모 / 단순 Cloth에 적합
- 구현·디버깅 용이
- GPU 동기화 비용 감소

➡ **GPU Cloth가 항상 더 빠른 것은 아님**

---

### 🎯 최종 핵심 요약

- DX11 병목의 핵심은 **명령 생성 단계의 드라이버 개입**
- Vulkan은 **명령 생성과 실행을 완전히 분리**
- Command Buffer는 오브젝트 단위가 아니라 **Pass/그룹 단위**
- 변경된 부분만 선택적으로 재녹화하는 구조가 핵심
- `RESET_COMMAND_BUFFER_BIT`은 이를 가능하게 하는 필수 옵션

## Command Buffer 레벨

### Primary Command Buffer (`VK_COMMAND_BUFFER_LEVEL_PRIMARY`)

- Queue에 직접 제출 가능
- 독립적으로 실행 가능
- Secondary Command Buffer를 호출할 수 있음 (`vkCmdExecuteCommands`)

### Secondary Command Buffer (`VK_COMMAND_BUFFER_LEVEL_SECONDARY`)

- Queue에 직접 제출 불가능
- Primary Command Buffer 내에서만 호출 가능 (`vkCmdExecuteCommands`)
- RenderPass가 시작된 상태에서만 사용 가능 (조건부)

## Primary vs Secondary

### Primary만으로도 충분한 경우

여러 오브젝트를 렌더링할 때 Primary만으로도 충분:

```cpp
// Primary Command Buffer만으로 여러 오브젝트 렌더링
vkBeginCommandBuffer(commandBuffer, &beginInfo);
vkCmdBeginRenderPass(commandBuffer, &renderPassBeginInfo, VK_SUBPASS_CONTENTS_INLINE);

// 오브젝트 1
vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline1);
vkCmdBindVertexBuffers(commandBuffer, 0, 1, &vertexBuffer1, offsets);
vkCmdDraw(commandBuffer, vertexCount1, 1, 0, 0);

// 오브젝트 2
vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline2);
vkCmdBindVertexBuffers(commandBuffer, 0, 1, &vertexBuffer2, offsets);
vkCmdDraw(commandBuffer, vertexCount2, 1, 0, 0);

vkCmdEndRenderPass(commandBuffer);
vkEndCommandBuffer(commandBuffer);
```

### Secondary를 사용하는 이유

#### 1. 멀티스레드 병렬 기록

```cpp
// 스레드 1: 오브젝트 1-100 기록
// 스레드 2: 오브젝트 101-200 기록
// 스레드 3: 오브젝트 201-300 기록

// 각 스레드가 독립적으로 Secondary Command Buffer 기록
// Primary는 단순히 모든 Secondary를 호출만 함
vkCmdExecuteCommands(primaryBuffer, secondaryBuffers.size(), secondaryBuffers.data());
```

**중요**: Primary는 단일 스레드에서만 기록할 수 있지만, Secondary는 여러 스레드에서 동시에 기록 가능

#### 2. 여러 Primary에서 재사용

**핵심 차이**: Primary는 다른 Primary에서 호출할 수 없지만, Secondary는 여러 Primary에서 호출 가능

```cpp
// UI를 Secondary로 기록
VkCommandBuffer uiSecondary;
// ... UI 렌더링 명령 기록 ...

// Primary 1의 RenderPass 내에서 호출
VkCommandBuffer primary1;
vkBeginCommandBuffer(primary1, &beginInfo);
vkCmdBeginRenderPass(primary1, &mainRenderPassBeginInfo, VK_SUBPASS_CONTENTS_SECONDARY_COMMAND_BUFFERS);
vkCmdExecuteCommands(primary1, 1, &uiSecondary);  // ✅ 가능! RenderPass 내에서 호출
vkCmdEndRenderPass(primary1);
vkEndCommandBuffer(primary1);

// Primary 2의 RenderPass 내에서도 호출
VkCommandBuffer primary2;
vkBeginCommandBuffer(primary2, &beginInfo);
vkCmdBeginRenderPass(primary2, &overlayRenderPassBeginInfo, VK_SUBPASS_CONTENTS_SECONDARY_COMMAND_BUFFERS);
vkCmdExecuteCommands(primary2, 1, &uiSecondary);  // ✅ 같은 Secondary를 다른 Primary에서 호출!
vkCmdEndRenderPass(primary2);
vkEndCommandBuffer(primary2);
```

#### 3. RenderPass 전환 오버헤드 제거

**Primary로 UI를 기록할 때의 문제**:
- 별도 RenderPass 필요 → 전환 오버헤드
- 메인 씬과 분리 → 동기화 복잡
- 오버레이를 위해 추가 설정 필요

**Secondary로 UI를 기록할 때의 장점**:
- 메인 씬의 RenderPass 내에서 실행 → 전환 없음
- 자연스러운 오버레이
- 여러 Primary에서 재사용 가능

**비용 비교**:
- Primary 방식: RenderPass 전환 비용 + 자연스러운 오버레이를 위한 추가 설정 비용
- Secondary 방식: RenderPass 전환 없음 + 추가 설정 불필요

따라서 UI를 Secondary로 두는 것이 더 효율적

## 재사용성

### Primary도 재사용 가능

```cpp
// Primary Command Buffer 생성
VkCommandBuffer primaryBuffer;
vkAllocateCommandBuffers(device, &allocInfo, &primaryBuffer);

// 한 번만 기록
vkBeginCommandBuffer(primaryBuffer, &beginInfo);
// ... 렌더링 명령 ...
vkEndCommandBuffer(primaryBuffer);

// 여러 프레임에서 재사용 가능!
for (int frame = 0; frame < 1000; frame++) {
    vkQueueSubmit(graphicsQueue, 1, &submitInfo, fence);
    vkWaitForFences(device, 1, &fence, VK_TRUE, UINT64_MAX);
    vkResetFences(device, 1, &fence);
}
```

### Secondary의 재사용성 장점

Secondary는 여러 Primary에서 같은 Secondary를 호출 가능:

```cpp
// UI Secondary (한 번만 기록)
VkCommandBuffer uiSecondary;
vkBeginCommandBuffer(uiSecondary, &beginInfo);
// ... UI 렌더링 명령 기록 ...
vkEndCommandBuffer(uiSecondary);

// 프레임마다
for (int frame = 0; frame < 1000; frame++) {
    // UI만 변경되었을 때만 UI Secondary 다시 기록
    if (uiChanged) {
        vkResetCommandBuffer(uiSecondary, 0);
        vkBeginCommandBuffer(uiSecondary, &beginInfo);
        // ... 새로운 UI 렌더링 명령 기록 ...
        vkEndCommandBuffer(uiSecondary);
    }
    
    // 메인 씬 Primary는 다시 기록할 필요 없음! (이미 기록되어 있음)
    // 단지 UI Secondary가 업데이트되었을 뿐
    vkQueueSubmit(graphicsQueue, 1, &submitInfo, fence);
}
```

**차이점**:
- Primary: 여러 프레임에서 재사용 가능
- Secondary: 여러 Primary에서 호출 가능 (더 유연한 재사용)

## 게임 씬에서의 구분

### Primary Command Buffer (독립적인 RenderPass)

1. **G-Buffer 생성** (Deferred Rendering)
   - Primary: G-Buffer RenderPass
   - 여러 오브젝트를 Secondary로 기록 가능

2. **Shadow Map 생성**
   - Primary: Shadow Map RenderPass
   - 각 라이트마다 Secondary로 기록 가능

3. **포스트 프로세싱**
   - Primary: Post-Process RenderPass
   - 각 PP 단계를 Secondary로 기록 가능

4. **스카이박스/환경 렌더링**
   - Primary: 별도 RenderPass
   - Secondary로 기록 가능

### Secondary Command Buffer (다른 Primary의 RenderPass 내에서 호출)

1. **씬 오브젝트 렌더링**
   - G-Buffer Primary의 RenderPass 내에서 호출
   - 각 오브젝트/배치를 Secondary로 기록

2. **UI 렌더링**
   - 메인 씬 Primary의 RenderPass 내에서 호출
   - UI 요소들을 Secondary로 기록

3. **디버그 렌더링**
   - 메인 씬 Primary의 RenderPass 내에서 호출
   - 라인, 텍스트 등을 Secondary로 기록

## VkCommandBufferBeginInfo 플래그

### 1. `VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT`

**의미**: Command Buffer가 한 번만 제출되고 재사용 안됨

**사용 시나리오**:
- Command Buffer를 한 번만 사용하고 버릴 때
- 매 프레임마다 새로 기록하는 경우

**예시**:
```cpp
VkCommandBufferBeginInfo beginInfo{};
beginInfo.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
vkBeginCommandBuffer(commandBuffer, &beginInfo);
// ... 명령 기록 ...
vkEndCommandBuffer(commandBuffer);

vkQueueSubmit(queue, 1, &submitInfo, fence);
// 이후 이 Command Buffer는 재사용하지 않음
```

**장점**: 드라이버가 최적화 가능 (재사용 고려 불필요)

### 2. `VK_COMMAND_BUFFER_USAGE_RENDER_PASS_CONTINUE_BIT`

**의미**: Secondary Command Buffer가 이미 시작된 RenderPass 내에서 실행됨

**사용 시나리오**:
- Secondary Command Buffer를 기록할 때
- Primary의 RenderPass 내에서 호출될 때

**예시**:
```cpp
// Secondary Command Buffer
VkCommandBufferInheritanceInfo inheritanceInfo{};
inheritanceInfo.renderPass = renderPass;
inheritanceInfo.framebuffer = framebuffer;

VkCommandBufferBeginInfo beginInfo{};
beginInfo.flags = VK_COMMAND_BUFFER_USAGE_RENDER_PASS_CONTINUE_BIT;
beginInfo.pInheritanceInfo = &inheritanceInfo;  // RenderPass 정보 상속

vkBeginCommandBuffer(secondaryBuffer, &beginInfo);
// ... RenderPass 내에서 실행될 명령 기록 ...
vkEndCommandBuffer(secondaryBuffer);
```

**중요**: 이 플래그는 Secondary Command Buffer에만 사용

### 3. `VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT`

**의미**: Command Buffer가 여러 Queue에 동시에 제출될 수 있음을 나타냄

**사용 시나리오**:
- 같은 Command Buffer를 여러 Queue에 동시에 제출할 때
- 여러 프레임에서 동시에 사용할 때

**예시**:
```cpp
VkCommandBufferBeginInfo beginInfo{};
beginInfo.flags = VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT;
vkBeginCommandBuffer(commandBuffer, &beginInfo);
// ... 명령 기록 ...
vkEndCommandBuffer(commandBuffer);

// 여러 Queue에 동시에 제출 가능
vkQueueSubmit(queue1, 1, &submitInfo1, fence1);
vkQueueSubmit(queue2, 1, &submitInfo2, fence2);  // 같은 Command Buffer 재사용
```

**주의**: 이 플래그가 없으면 Command Buffer가 실행 중일 때 다시 제출 불가능

**실제로는**: 대부분의 경우 이 플래그를 사용하지 않습니다. Command Buffer를 재기록하거나 여러 Command Buffer를 사용하는 것이 더 효율적입니다.

## Command Buffer의 재기록

### 암묵적 리셋

**중요**: Command Buffer는 "추가(append)" 모드를 지원하지 안함

```cpp
// 첫 번째 기록
vkBeginCommandBuffer(commandBuffer, &beginInfo);
vkCmdDraw(commandBuffer, 3, 1, 0, 0);  // 명령 1
vkEndCommandBuffer(commandBuffer);

// 나중에 추가 명령을 덧붙이려고 시도
vkBeginCommandBuffer(commandBuffer, &beginInfo);  // ❌ 이전 내용이 모두 지워짐!
vkCmdDraw(commandBuffer, 3, 1, 0, 0);  // 명령 2 (명령 1은 사라짐)
vkEndCommandBuffer(commandBuffer);

// 결과: 명령 1은 없고 명령 2만 있음
```

**`vkBeginCommandBuffer`는 항상 리셋합니다**:
- 이미 기록된 Command Buffer에 `vkBeginCommandBuffer`를 호출하면 암묵적으로 리셋
- 나중에 명령을 추가하려면 전체를 다시 기록해야 함

**명시적 리셋 vs 암묵적 리셋**:
```cpp
// 명시적 리셋 (선택사항)
vkResetCommandBuffer(commandBuffer, 0);  // 명시적으로 리셋
vkBeginCommandBuffer(commandBuffer, &beginInfo);

// 암묵적 리셋 (자동)
vkBeginCommandBuffer(commandBuffer, &beginInfo);  // 자동으로 리셋됨
```

두 방식 모두 동일하게 동작합니다. `vkBeginCommandBuffer`가 자동으로 리셋하므로 명시적 리셋은 선택사항

## Queue 제출의 비동기 특성

### Queue 제출은 비동기적

```cpp
// 순차적으로 제출
vkQueueSubmit(graphicsQueue, 1, &submitInfo1, fence1);
vkQueueSubmit(graphicsQueue, 1, &submitInfo2, fence2);
vkQueueSubmit(graphicsQueue, 1, &submitInfo3, fence3);

// 하지만 실행은 비동기적으로!
// - submitInfo1, submitInfo2, submitInfo3가 동시에 실행될 수 있음
// - 순서가 보장되지 않을 수 있음
```

**중요**: `vkQueueSubmit`은 즉시 반환되며, 실제 실행은 GPU에서 비동기로 진행

### 동기화 필요성

**문제 상황**:
```cpp
// 문제 상황
vkQueueSubmit(graphicsQueue, 1, &submitInfo1, nullptr);  // 이미지 복사
vkQueueSubmit(graphicsQueue, 1, &submitInfo2, nullptr);  // 이미지 사용

// submitInfo2가 submitInfo1보다 먼저 실행될 수 있음!
// → 이미지가 아직 복사되지 않았는데 사용하려고 함
```

**해결 방법**: Semaphore, Fence, 또는 Pipeline Barrier를 사용하여 동기화해야 함

## RenderPass 간 동기화

### 불투명 오브젝트와 반투명 오브젝트

불투명 오브젝트와 반투명 오브젝트가 다른 RenderPass일 때, 동기화가 필요함

**Semaphore 사용 (권장)**:
```cpp
VkSemaphore opaqueFinishedSemaphore;
vkCreateSemaphore(device, &semaphoreInfo, nullptr, &opaqueFinishedSemaphore);

// 불투명 오브젝트 제출 (완료 시 Semaphore 신호)
VkSubmitInfo opaqueSubmitInfo{};
opaqueSubmitInfo.pCommandBuffers = &opaqueCommandBuffer;
opaqueSubmitInfo.signalSemaphoreCount = 1;
opaqueSubmitInfo.pSignalSemaphores = &opaqueFinishedSemaphore;  // 완료 시 신호
vkQueueSubmit(graphicsQueue, 1, &opaqueSubmitInfo, nullptr);

// 반투명 오브젝트 제출 (불투명 완료 대기)
VkSubmitInfo transparentSubmitInfo{};
transparentSubmitInfo.waitSemaphoreCount = 1;
transparentSubmitInfo.pWaitSemaphores = &opaqueFinishedSemaphore;  // 불투명 완료 대기
transparentSubmitInfo.pCommandBuffers = &transparentCommandBuffer;
vkQueueSubmit(graphicsQueue, 1, &transparentSubmitInfo, nullptr);
```

**Fence vs Semaphore**:
- **Semaphore**: GPU-GPU 동기화 (RenderPass 간 순서 보장)
- **Fence**: CPU-GPU 동기화 (CPU가 GPU 완료를 기다려야 할 때)

**결론**: 같은 Queue에서 순차 제출해도 실행 순서가 보장되지 않을 수 있으므로, 명시적 동기화가 필요

## 요약

### Command Buffer 레벨
- **Primary**: Queue에 직접 제출, 독립 실행 가능
- **Secondary**: Primary 내에서만 호출, RenderPass 내에서만 사용 가능

### 재사용성
- **Primary**: 여러 프레임에서 재사용 가능
- **Secondary**: 여러 Primary에서 호출 가능 (더 유연한 재사용)

### 사용 시나리오
- **Primary**: 독립적인 RenderPass가 필요한 단계 (G-Buffer, Shadow Map, Post-Process 등)
- **Secondary**: 다른 Primary의 RenderPass 내에서 실행되는 단계 (씬 오브젝트, UI, 디버그 등)

### 플래그
- **ONE_TIME_SUBMIT_BIT**: 한 번만 제출
- **RENDER_PASS_CONTINUE_BIT**: Secondary용, RenderPass 내에서 실행
- **SIMULTANEOUS_USE_BIT**: 여러 Queue에 동시 제출 (거의 사용 안 함)

### 동기화
- Queue 제출은 비동기적
- RenderPass 간 순서 보장을 위해 Semaphore 사용
- CPU가 기다려야 할 때는 Fence 사용


## 튜토리얼 예제
위까지는 command buffer에 대한 개요이다. 결국 vulkan에서는 렌더링을 위해서 commandBuffer에 렌더링 명령이 기록되어야 한다.

### 커맨드 풀
커맨드 버퍼는 커맨드 풀로부터 할당된다.

```c++
VkCommandPool commandPool;\
void initVulkan() {
    //...
    createCommandPool();
}

void createCommandPool()
{
    QueueFamilyIndices queueFamilyIndices = findQueueFamilies(physicalDevice);
    VkCommandPoolCreateInfo poolInfo{};
    poolInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    poolInfo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    poolInfo.queueFamilyIndex = queueFamilyIndices.graphicsFamily.value();
    if (vkCreateCommandPool(device, &poolInfo, nullptr, &commandPool) != VK_SUCCESS) 
    {
        throw std::runtime_error("failed to create command pool!");
    }
}

void cleanUp()
{
    vkDestroyCommandPool(device, commandPool, nullptr);
}
```

### 커맨드 버퍼 할당
```c++
VkCommandBuffer commandBuffer;

void initVulkan()
{
    createCommandBuffer();
}

void createCommandBuffer()
{
    VkCommandbufferAllocateInfo allocInfo{};
    allocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    allocInfo.commandPool = commandPool;
    allocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    allocInfo.commandBufferCount = 1;

    if (vkAllocateCommandBuffers(device, &allocInfo, &commandBuffer) != VK_SUCCESS) {
        throw std::runtime_error("failed to allocate command buffers!");
    }
}
```

### 커맨드 버퍼 기록

커맨드 버퍼를 기록할때 지금은 primary로 충분하기떄문에 primary로 기록한다. renderpass를 시작하고,
고정 함수기능들(그래픽스 파이프라인, 동적 파이프라인 객체)들을 세팅한다. 마지막으로 그리기 명령을 내리고 렌더패스와 커맨드 버퍼 기록을 종료한다.

```c++
void recordCommandBuffer(VkCommandBuffer commandBuffer, uint32_t imageIndex) 
{
    VkCommandBufferBeginInfo beginInfo{};
    beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    beginInfo.flags = 0; // Optional
    beginInfo.pInheritanceInfo = nullptr; // Optional

    if (vkBeginCommandBuffer(commandBuffer, &beginInfo) != VK_SUCCESS) 
    {
        throw std::runtime_error("failed to begin recording command buffer!");
    }

    VkRenderPassBeginInfo renderPassInfo{};
	renderPassInfo.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
	renderPassInfo.renderPass = renderPass;
	renderPassInfo.framebuffer = swapChainFramebuffers[imageIndex];
	renderPassInfo.renderArea.offset = { 0, 0 };
	renderPassInfo.renderArea.extent = swapChainExtent;
	VkClearValue clearColor = { 0.f ,0.f, 0.f, 1.f };
	renderPassInfo.clearValueCount = 1;
	renderPassInfo.pClearValues = &clearColor;
	vkCmdBeginRenderPass(commandBuffer, &renderPassInfo, VK_SUBPASS_CONTENTS_INLINE);

	vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_GRAPHICS, graphicsPipeline);
	VkViewport viewport{};
	viewport.x = 0.f;
	viewport.y = 0.f;
	viewport.width = swapChainExtent.width;
	viewport.height = swapChainExtent.height;
	viewport.minDepth = 0.f;
	viewport.maxDepth = 1.f;
	vkCmdSetViewport(commandBuffer, 0, 1, &viewport);
	VkRect2D scissor{};
	scissor.offset = {0, 0};
	scissor.extent = swapChainExtent;
	vkCmdSetScissor(commandBuffer, 0, 1, &scissor);

	vkCmdDraw(commandBuffer, 3, 1, 0, 0);

	vkCmdEndRenderPass(commandBuffer);
	if (vkEndCommandBuffer(commandBuffer) != VK_SUCCESS)
	{
		throw std::runtime_error("failed to record command buffer!");
	}
}
```