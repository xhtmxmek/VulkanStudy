# 렌더링 및 프레젠테이션

메인 루프에서 호출되어서 렌더링을 수행하고 화면에 표시하는 drawFrame함수를 만든다

```c++
	void mainLoop() {
		while (!glfwWindowShouldClose(window))
		{
			glfwPollEvents();
			drawFrame();
		}
```

한 프레임을 렌더링 하는 과정은 다음과 같다

- 이전 프레임이 끝날 때까지 대기
- 스왑 체인에서 이미지를 가져온다
- 장면을 이미지에 그리는 명령 버퍼를 기록
- 기록된 명령 버퍼를 제출
- 스왑 체인 이미지를 표시

## 1. 동기화
gpu를 제어하는 api 호출은 비동기적으로 이루어진다. 함수는 연산이 완료되기 전에 반환된다. 따라서 원하는 순서로 연산순서를 제어하려면 드라이버에 동기화 객체들을 이용하여 실행 순서를 알려 주어야 한다. 이번 장에서 진행되는 이벤트들의 순서는 다음과 같다.

- 스왑 체인에서 이미지를 획득
- 획득한 이미지 위에 그림을 그리는 명령을 실행
- 해당 이미지를 화면에 표시하여 프레젠테이션을 진행하고, 스왑체인으로 반환

각 이벤트는 비동기 적으로 실행된다. 함수는 실제 실행이 완료되기 전에 반환되며 실행 순서 또한 정의 되지 않는다. 위에 명시한 이벤트들은 이전 단계에 의존적이기 때문에 명시적인 동기화 객체를 이용하여 실행 순서를 보장해 주어야 한다.

### semaphore(GPU↔GPU 동기화)
- 목적: **큐 간/작업 간 순서 보장**
- 종류: 바이너리 세마포어와 타임라인 세마포어 2가지. 튜토리얼에서는 바이너리만 사용
- 동작 방식 : '신호'가 있거나 없는 상태로 시작됨. 하나의 큐에서는 '신호'가 있어서 큐가 동작하고, 하나의 큐에서는 신호가 올떄까지 '대기'하게 만드는 세마포어로 지정시킨다
```c++
VkCommandBuffer A, B = ... // record command buffers
VkSemaphore S = ... // create a semaphore

// enqueue A, signal S when done - starts executing immediately
vkQueueSubmit(work: A, signal: S, wait: None)

// enqueue B, wait on S to start
vkQueueSubmit(work: B, signal: None, wait: S)
```
- 대표 사용:
  - `imageAvailableSemaphore`: Acquire가 준비되었음을 graphics queue가 기다림 (present → render)
  - `renderFinishedSemaphore`: 렌더 완료를 present queue가 기다림 (render → present)
- **중요**: fence처럼 CPU가 “끝났다”를 직접 기다리는 용도가 아님. gpu에서만 대기가 발생하고 cpu는 블록되지 않음

### fence(CPU↔GPU 동기화)
- 목적: CPU가 **GPU가 특정 submit을 끝냈는지** 확인하고, 그 이후에 자원(커맨드 버퍼/UBO 등)을 안전하게 재사용
- 의사 코드
```c++
VkCommandBuffer A = ... // record command buffer with the transfer
VkFence F = ... // create the fence

// enqueue A, start work immediately, signal F when done
vkQueueSubmit(work: A, fence: F)

vkWaitForFence(F) // blocks execution until A has finished executing

save_screenshot_to_disk() // can't run until the transfer has finished
```
- `vkQueueSubmit(..., fence)`에 연결된 fence는 **그 submit이 끝나면 signal** 됨
- 단, **present 완료는 fence와 직접 연결되지 않는다**(기본 swapchain 흐름에서는)

## 2. 동기화 객체 생성
가장 단순한 구조에서는 이미지를 획득할때까지 대기하는 세마포어, 렌더링이 끝났음을 알리는 세마포어, 이전 프레임을 기다리는 fence가 각각 하나씩 필요하다.
그러나 상술했듯이 gpu 명령은 비동기적으로 이루어지기에 이전 프레임의 결과를 cpu에서 펜스로 기다리다보면 불필요한 idle이 발생한다. 따라서 MAX_FRAME_FLIGHT 구조로 여러 프레임에 걸쳐서 동시에 실행시키되 적절한 동기화 객체 사용으로 렌더링 작업을 수행한다.



### 2-1. “왜 semaphore는 이미지 단위가 자연스러운가?”
- present는 **특정 swapchain image**를 대상으로 동작한다.
- 따라서 `renderFinished`를 **프레임 슬롯 기준**으로 재사용하면,
  - 과거 프레임에서 present가 해당 semaphore를 아직 참조 중인데,
  - 다음 프레임의 submit이 같은 semaphore를 다시 signal 하려 할 수 있어 충돌 위험이 생김.
- 반대로 `renderFinished[imageIndex]`처럼 **이미지별로 분리**하면:
  - image 0을 present 중이면 renderFinished[0]이 잡혀 있을 수 있지만,
  - image 1이나 2에 대한 제출은 renderFinished[1]/[2]를 signal 하므로 충돌 구조가 사라진다.
- 충돌 가능 예시:
  - 0번 스왑체인이 renderFinished 세마포어에 묶여있는 채로 wait
  - 1번 스왑체인에대한 최종 present까지 완료
  - 3번쨰 프레임(0프레임)에서 0번 스왑체인은 아직 묶여있지만 다시 접근하는 상황 발생. 따라서 renderFinished는 image단위로 하여 프레젠테이션이 끝난 이미지 인덱스로 접근하면 충돌 가능성 사라짐.

---

## 2-2. “Acquire는 무엇을 보장하나?”
- `vkAcquireNextImageKHR`가 반환하는 것은 “**프레젠테이션 엔진이 더 이상 사용하지 않는 이미지**”이다.
- 토론 중 핵심 정리:
  - **swapchain 이미지 자체**는 acquire로 “다시 렌더타겟으로 써도 됨” 상태가 된다.
  - 하지만 acquire는 **그 이미지와 함께 사용되는 ‘프레임 자원’(UBO/UAV/descriptor/cmd 등)의 안전한 재사용**까지 자동으로 보장해주지 않는다.
- 따라서 이미지 외의 자원 재사용은 별도 구조(프레임 슬롯/펜스)로 관리해야 한다.

---

## 3. MAX_FRAMES_IN_FLIGHT 개념
### 3.1 목적
- CPU가 GPU보다 너무 앞서 달리면서:
  - 자원이 무한히 늘어나거나,
  - 지연(latency)이 예측 불가능해지거나,
  - 메모리 사용량이 폭증하는 것을 막기 위해
- **동시에 굴리는 프레임 수를 제한**해서
  - 자원/메모리/지연을 “통제 가능한 범위”로 묶는다.

### 3.2 프레임 슬롯(frame slot)
- `currentFrame = (currentFrame + 1) % MAX_FRAMES_IN_FLIGHT`
- 프레임 슬롯 단위로 자원을 2세트면 2세트만 돌림:
  - `imageAvailableSemaphores[currentFrame]`
  - `inFlightFences[currentFrame]`
  - `commandBuffers[currentFrame]`
  - (보통) `ubo[currentFrame]`, descriptor set 등도 프레임 슬롯으로 분리

### 3.3 “프레임 슬롯 2개인데 스왑체인 이미지는 3개” 문제
- 프레임 슬롯은 “CPU/GPU 파이프라인 운영 단위”
- 스왑체인 이미지는 “present/render 대상 이미지 풀”
- 개수가 다를 수 있고, **매핑은 매 프레임마다 달라질 수 있음**.
- 그래서 “이미지 인덱스 기반 추적(imagesInFlight)”이 필요해진다.
#### 예시
프레임 슬롯 구조로만 갈 경우에는
1) currentFrame == 0일 때 이미지 0을 받아 그리고 제출 → 그 작업은 inFlightFences[0]에 묶임.
2) 몇 프레임 뒤 currentFrame == 1이 되고, 다시 이미지 0을 받음.
3) 이때 맨 앞 대기는 **inFlightFences[1]**만 대기. **inFlightFences[0]**이 아직 안 끝났어도, 슬롯 1만 비었으면 통과할 수 있음. 

---

## 4. imagesInFlight (이미지 인덱스 기반 fence 추적)
### 4.1 아이디어
- `imagesInFlight[imageIndex]`에
  - “이 이미지가 마지막으로 사용된 submit의 fence”를 저장한다.
- 다음에 같은 imageIndex를 다시 받으면:
  - 그 fence를 기다려서 “이 이미지 관련 GPU 작업이 끝났는지” 확인 후 재사용.

### 4.2 의사코드
```cpp
wait(inFlightFence[cur]);

imageIndex = acquire(imageAvailable[cur]);

if (imagesInFlight[imageIndex] != VK_NULL_HANDLE)
    wait(imagesInFlight[imageIndex]);

imagesInFlight[imageIndex] = inFlightFence[cur];

reset(inFlightFence[cur]);
reset(cmd[cur]);
record(cmd[cur], imageIndex);

submit(
  wait = imageAvailable[cur],
  signal = renderFinished[imageIndex],
  fence = inFlightFence[cur]
);

present(
  wait = renderFinished[imageIndex],
  imageIndex
);

cur = (cur + 1) % MAX;
```

---

## 5. drawFrame 동기화 요약

이 장의 렌더링 루프는 **`MAX_FRAMES_IN_FLIGHT`개의 프레임 슬롯**을 돌려 쓰며, GPU가 한 번에 너무 많은 프레임을 앞서 처리하지 않도록 자원과 지연을 묶어 둔다. 동기화는 대략 다음 조건을 따른다.

1. **프레임 슬롯 fence (`inFlightFences[currentFrame]`)**  
   CPU는 이전에 이 슬롯에 묶여 제출된 작업이 **GPU에서 실행까지 끝났는지**를 기다린다.  
   (`vkQueueSubmit`이 반환된 것은 “큐에 기록됨”이지 GPU 완료가 아니다.)

2. **`imagesInFlight[imageIndex]`**  
   이번에 `acquire`로 받은 **스왑 이미지 인덱스**가, 예전에 **다른 프레임 슬롯**에서 이미 그려진 적이 있으면, 그때 걸었던 fence까지 기다린다.  
   맨 앞의 슬롯 fence만으로는 “지금 고른 이미지가 아직 GPU에서 쓰이는 중”을 보장할 수 없기 때문이다.

3. **`renderFinished`를 이미지 인덱스별로 둠**  
   Fence는 CPU가 제출 단위 GPU 완료를 보는 용도이고, **프레젠트 완료까지**를 직접 보장하지는 않는다.  
   `Present`는 “이번에 내보낼 **그** 스왑 이미지에 대한 렌더가 끝났다”는 **GPU 쪽 의존성**이 필요하므로, `renderFinished[imageIndex]`처럼 **이미지와 제출·프레젠트를 1:1로 맞춰** 세마포어를 쓰면 잘못된 대기/신호 조합을 피할 수 있다.

**한 줄로:** 프레임 슬롯 단위 fence로 **슬롯 자원 재사용**을, 이미지 단위 fence·세마포어로 **스왑 이미지와 Present 연결**을 각각 맞춘다.

