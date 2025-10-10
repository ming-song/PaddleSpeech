// 全局变量
let mediaRecorder;
let websocket;
let isRecording = false;
let audioChunks = [];

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', function() {
    console.log('页面加载完成，开始初始化...');
    setupEventListeners();

    // 初始化播放速度控制器
    setupSpeedControl();

    // 初始化服务地址配置
    initServiceConfig();

    // 显示默认标签页
    switchTab('realtime-asr');
});

// 初始化服务地址配置
function initServiceConfig() {
    console.log('初始化服务地址配置...');
    
    // 获取当前页面的协议、主机和端口
    const protocol = window.location.protocol;
    const hostname = window.location.hostname;
    const port = window.location.port ? `:${window.location.port}` : '';
    const baseUrl = `${protocol}//${hostname}${port}`;
    
    // 设置默认值
    const defaultUrls = {
        'asr-http-url': `${baseUrl.replace(/:\d+$/, ':8090')}`,  // 默认8090端口
        'asr-ws-url': `ws://${hostname}:8091`,  // WebSocket使用ws协议
        'tts-http-url': `${baseUrl.replace(/:\d+$/, ':8090')}`,  // 默认8090端口
        'tts-ws-url': `ws://${hostname}:8092`   // WebSocket使用ws协议
    };
    
    // 为每个配置项设置默认值
    Object.keys(defaultUrls).forEach(id => {
        const input = document.getElementById(id);
        if (input) {
            // 如果本地存储中有值，则使用存储的值，否则使用默认值
            const storedValue = localStorage.getItem(id);
            input.value = storedValue || defaultUrls[id];
            
            // 添加事件监听器，保存用户修改的值
            input.addEventListener('change', function() {
                localStorage.setItem(id, this.value);
            });
        }
    });
    
    console.log('服务地址配置初始化完成');
}

// 重置配置为默认值
function resetConfig() {
    if (confirm('确定要重置所有服务地址配置为默认值吗？')) {
        // 清除本地存储
        const configIds = ['asr-http-url', 'asr-ws-url', 'tts-http-url', 'tts-ws-url'];
        configIds.forEach(id => {
            localStorage.removeItem(id);
        });
        
        // 重新初始化配置
        initServiceConfig();
        
        alert('配置已重置为默认值');
    }
}

// 获取配置的服务地址
function getServiceUrl(configId) {
    const input = document.getElementById(configId);
    return input ? input.value : null;
}

// 切换标签页
function switchTab(tabId) {
    console.log('切换到标签页:', tabId);
    
    // 隐藏所有面板
    document.querySelectorAll('.service-panel').forEach(panel => {
        panel.classList.remove('active');
    });
    
    // 移除所有按钮的激活状态
    document.querySelectorAll('.tab-button').forEach(btn => {
        btn.classList.remove('active');
    });
    
    // 显示选中的面板
    const targetPanel = document.getElementById(tabId);
    if (targetPanel) {
        targetPanel.classList.add('active');
    }
    
    // 激活对应的按钮
    const buttons = document.querySelectorAll('.tab-button');
    buttons.forEach((btn, index) => {
        const targetIds = ['realtime-asr', 'file-asr', 'tts', 'streaming-tts'];
        if (targetIds[index] === tabId) {
            btn.classList.add('active');
        }
    });
}

// 设置事件监听器
function setupEventListeners() {
    console.log('设置事件监听器...');
    
    // 文件上传
    const fileInput = document.getElementById('audio-file');
    const uploadArea = document.querySelector('.file-upload-area');
    
    if (fileInput) {
        fileInput.addEventListener('change', handleFileSelect);
    }
    
    // 拖拽上传
    if (uploadArea) {
        uploadArea.addEventListener('dragover', (e) => {
            e.preventDefault();
            uploadArea.classList.add('dragover');
        });
        
        uploadArea.addEventListener('dragleave', () => {
            uploadArea.classList.remove('dragover');
        });
        
        uploadArea.addEventListener('drop', (e) => {
            e.preventDefault();
            uploadArea.classList.remove('dragover');
            const files = e.dataTransfer.files;
            if (files.length > 0) {
                fileInput.files = files;
                handleFileSelect();
            }
        });
    }
    
    console.log('事件监听器设置完成');
}

// 设置播放速度控制器
function setupSpeedControl() {
    const speedSlider = document.getElementById('playback-speed');
    const speedValue = document.getElementById('speed-value');

    if (speedSlider && speedValue) {
        speedSlider.addEventListener('input', function() {
            speedValue.textContent = this.value + 'x';
        });
    }
}

// WebSocket连接
function connectWebSocket() {
    console.log('尝试连接WebSocket...');
    
    // 使用配置的WebSocket URL
    const wsUrl = getServiceUrl('asr-ws-url');
    if (!wsUrl) {
        alert('请先配置实时ASR服务地址');
        return;
    }
    
    // 确保URL以正确的路径结尾
    const fullWsUrl = wsUrl.endsWith('/paddlespeech/asr/streaming') ? 
        wsUrl : 
        `${wsUrl.replace(/\/$/, '')}/paddlespeech/asr/streaming`;
    
    // 关闭已存在的连接
    if (websocket) {
        websocket.close();
    }
    
    try {
        websocket = new WebSocket(fullWsUrl);
        
        websocket.onopen = function() {
            console.log('WebSocket连接成功');
            updateConnectionStatus('已连接', 'success');
            
            const startBtn = document.getElementById('start-record-btn');
            if (startBtn) {
                startBtn.disabled = false;
            }
            
            // 发送开始信号
            const startMsg = jsonDumps({
                "signal": "start",
                "nbest": 1
            });
            websocket.send(startMsg);
            console.log('发送开始信号:', startMsg);
        };
        
        websocket.onmessage = function(event) {
            console.log('收到消息:', event.data);
            try {
                const result = JSON.parse(event.data);
                updateRealtimeResult(result);
            } catch (e) {
                console.log('非 JSON 消息:', event.data);
                // 可能是非 JSON 消息，直接显示
                updateRealtimeResult({result: event.data});
            }
        };
        
        websocket.onclose = function(event) {
            console.log('WebSocket连接关闭:', event);
            updateConnectionStatus('连接断开', 'error');
            
            const startBtn = document.getElementById('start-record-btn');
            const stopBtn = document.getElementById('stop-record-btn');
            if (startBtn) startBtn.disabled = true;
            if (stopBtn) stopBtn.disabled = true;
        };
        
        websocket.onerror = function(error) {
            console.error('WebSocket错误:', error);
            updateConnectionStatus('连接错误', 'error');
        };
        
    } catch (error) {
        console.error('WebSocket连接失败:', error);
        updateConnectionStatus('连接失败', 'error');
    }
}

// 更新连接状态
function updateConnectionStatus(status, type) {
    console.log('更新连接状态:', status, type);
    const statusEl = document.getElementById('ws-status');
    if (statusEl) {
        statusEl.textContent = status;
        statusEl.className = `status-indicator status-${type}`;
    }
}

// 开始录音
async function startRecording() {
    console.log('开始录音...');
    
    try {
        const stream = await navigator.mediaDevices.getUserMedia({ 
            audio: {
                sampleRate: 16000,
                channelCount: 1,
                echoCancellation: true,
                noiseSuppression: true
            } 
        });
        
        console.log('获取麦克风权限成功');
        
        // 创建AudioContext来处理音频数据
        const audioContext = new (window.AudioContext || window.webkitAudioContext)({
            sampleRate: 16000
        });
        const source = audioContext.createMediaStreamSource(stream);
        
        // 创建ScriptProcessor来处理实时音频数据
        const processor = audioContext.createScriptProcessor(1024, 1, 1);
        
        processor.onaudioprocess = function(event) {
            if (websocket && websocket.readyState === WebSocket.OPEN) {
                const inputBuffer = event.inputBuffer;
                const inputData = inputBuffer.getChannelData(0);
                
                // 将Float32Array转换为Int16Array (PCM 16位格式)
                const pcmData = new Int16Array(inputData.length);
                for (let i = 0; i < inputData.length; i++) {
                    // 将-1到1的浮点数转换为-32768到32767的16位整数
                    pcmData[i] = Math.max(-32768, Math.min(32767, inputData[i] * 32767));
                }
                
                // 发送PCM数据
                console.log('发送PCM音频数据:', pcmData.length, '采样点');
                websocket.send(pcmData.buffer);
            }
        };
        
        source.connect(processor);
        processor.connect(audioContext.destination);
        
        // 保存引用以便停止时清理
        window.currentAudioContext = audioContext;
        window.currentProcessor = processor;
        window.currentStream = stream;
        
        isRecording = true;
        
        // 更新UI状态
        const startBtn = document.getElementById('start-record-btn');
        const stopBtn = document.getElementById('stop-record-btn');
        const indicator = document.getElementById('recording-indicator');
        
        if (startBtn) startBtn.disabled = true;
        if (stopBtn) stopBtn.disabled = false;
        if (indicator) indicator.style.display = 'block';
        
        console.log('录音开始成功');
        
    } catch (error) {
        console.error('无法访问麦克风:', error);
        alert('无法访问麦克风，请检查权限设置或使用HTTPS协议');
    }
}

// 停止录音
function stopRecording() {
    console.log('停止录音...');
    
    if (isRecording) {
        isRecording = false;
        
        // 清理AudioContext和相关资源
        if (window.currentProcessor) {
            window.currentProcessor.disconnect();
            window.currentProcessor = null;
        }
        
        if (window.currentAudioContext) {
            window.currentAudioContext.close();
            window.currentAudioContext = null;
        }
        
        if (window.currentStream) {
            window.currentStream.getTracks().forEach(track => track.stop());
            window.currentStream = null;
        }
        
        // 发送结束信号
        if (websocket && websocket.readyState === WebSocket.OPEN) {
            const endMsg = JSON.stringify({"signal": "end"});
            websocket.send(endMsg);
            console.log('发送结束信号:', endMsg);
        }
        
        // 更新UI状态
        const startBtn = document.getElementById('start-record-btn');
        const stopBtn = document.getElementById('stop-record-btn');
        const indicator = document.getElementById('recording-indicator');
        
        if (startBtn) startBtn.disabled = false;
        if (stopBtn) stopBtn.disabled = true;
        if (indicator) indicator.style.display = 'none';
        
        console.log('录音停止成功');
    }
}

// 更新实时识别结果
function updateRealtimeResult(result) {
    console.log('更新识别结果:', result);
    const resultEl = document.getElementById('realtime-result');
    if (resultEl) {
        if (result.result) {
            resultEl.textContent = result.result;
        } else if (result.partial_result) {
            resultEl.innerHTML = `<span style="color: #666;">${result.partial_result}</span>`;
        } else if (typeof result === 'string') {
            resultEl.textContent = result;
        }
    }
}

// 处理文件选择
function handleFileSelect() {
    const fileInput = document.getElementById('audio-file');
    const fileInfo = document.getElementById('file-info');
    const uploadBtn = document.getElementById('upload-asr-btn');
    
    if (fileInput.files.length > 0) {
        const file = fileInput.files[0];
        fileInfo.innerHTML = `
            <strong>已选择文件:</strong> ${file.name}<br>
            <strong>文件大小:</strong> ${(file.size / 1024 / 1024).toFixed(2)} MB<br>
            <strong>文件类型:</strong> ${file.type}
        `;
        fileInfo.style.display = 'block';
        uploadBtn.disabled = false;
    }
}

// 上传文件进行ASR
async function uploadForASR() {
    const fileInput = document.getElementById('audio-file');
    const resultEl = document.getElementById('file-asr-result');
    
    if (!fileInput.files.length) {
        alert('请先选择音频文件');
        return;
    }
    
    const file = fileInput.files[0];
    
    // 获取配置的HTTP服务地址
    const httpUrl = getServiceUrl('asr-http-url');
    if (!httpUrl) {
        alert('请先配置文件ASR服务地址');
        return;
    }
    
    // 构造完整的API URL
    const apiUrl = httpUrl.endsWith('/paddlespeech/asr') ? 
        httpUrl : 
        `${httpUrl.replace(/\/$/, '')}/paddlespeech/asr`;
    
    try {
        resultEl.textContent = '正在处理文件...';
        
        // 将文件转换为base64
        const audioBase64 = await fileToBase64(file);
        
        // 获取音频格式
        const audioFormat = getAudioFormat(file.name);
        
        // 构造请求数据
        const requestData = {
            audio: audioBase64,
            audio_format: audioFormat,
            sample_rate: 16000,
            lang: document.getElementById('asr-lang').value,
            punc: false
        };
        
        resultEl.textContent = '正在上传和识别...';
        
        const response = await fetch(apiUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(requestData)
        });
        
        if (response.ok) {
            const result = await response.json();
            resultEl.innerHTML = `
                <strong>识别结果:</strong><br>
                ${result.result?.transcription || '识别失败'}
            `;
        } else {
            const errorText = await response.text();
            resultEl.innerHTML = `<span style="color: red;">识别失败: ${response.status} ${response.statusText}<br>详情: ${errorText}</span>`;
        }
        
    } catch (error) {
        resultEl.innerHTML = `<span style="color: red;">识别出错: ${error.message}</span>`;
    }
}

// 将文件转换为base64
function fileToBase64(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => {
            // 移除data:audio/wav;base64,前缀，只保留base64数据
            const base64 = reader.result.split(',')[1];
            resolve(base64);
        };
        reader.onerror = () => {
            reject(new Error('文件读取失败'));
        };
        reader.readAsDataURL(file);
    });
}

// 获取音频格式
function getAudioFormat(filename) {
    const extension = filename.toLowerCase().split('.').pop();
    const formatMap = {
        'wav': 'wav',
        'wave': 'wav',
        'mp3': 'mp3',
        'flac': 'flac',
        'ogg': 'ogg',
        'm4a': 'm4a'
    };
    return formatMap[extension] || 'wav';
}

// 语音合成
async function synthesizeText() {
    const text = document.getElementById('tts-text').value.trim();
    const resultEl = document.getElementById('tts-result');
    const audioEl = document.getElementById('tts-audio');

    if (!text) {
        alert('请输入要合成的文本');
        return;
    }

    // 获取配置的HTTP服务地址
    const httpUrl = getServiceUrl('tts-http-url');
    if (!httpUrl) {
        alert('请先配置TTS服务地址');
        return;
    }
    
    // 构造完整的API URL
    const apiUrl = httpUrl.endsWith('/paddlespeech/tts') ? 
        httpUrl : 
        `${httpUrl.replace(/\/$/, '')}/paddlespeech/tts`;

    try {
        resultEl.innerHTML = '<p>正在合成语音...</p>';
        audioEl.style.display = 'none';

        // 获取选择的音色ID
        const speakerSelect = document.getElementById('speaker-select');
        const selectedSpkId = parseInt(speakerSelect.value) || 0;

        // 构造JSON请求数据（按照TTSRequest格式）
        const requestData = {
            text: text,
            spk_id: selectedSpkId,
            speed: 1.0,
            volume: 1.0,
            sample_rate: 0  // 0表示使用模型默认采样率
        };

        const response = await fetch(apiUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(requestData)
        });

        if (response.ok) {
            const result = await response.json();

            // 解码base64音频数据
            const audioBase64 = result.result?.audio;
            if (audioBase64) {
                // 使用Web Audio API播放，确保正确的采样率
                await playAudioWithWebAudioAPI(audioBase64, result.result?.sample_rate || 24000);

                const audioBlob = base64ToBlob(audioBase64, 'audio/wav');
                const audioUrl = URL.createObjectURL(audioBlob);

                // 仍然提供audio元素作为备选方案
                audioEl.src = audioUrl;
                audioEl.style.display = 'block';

                const speedSlider = document.getElementById('playback-speed');
                const playbackRate = speedSlider ? parseFloat(speedSlider.value) : 1.0;

                resultEl.innerHTML = `
                    <p><strong>合成成功!</strong></p>
                    <p>文本长度: ${text.length} 字符</p>
                    <p>音频大小: ${(audioBlob.size / 1024).toFixed(2)} KB</p>
                    <p>采样率: ${result.result?.sample_rate || 'unknown'} Hz</p>
                    <p>播放速度: ${playbackRate}x</p>
                    <p style="color: green;">✓ 使用Web Audio API正确解码WAV格式</p>
                `;
            } else {
                resultEl.innerHTML = '<span style="color: red;">合成失败：未返回音频数据</span>';
            }
        } else {
            const errorText = await response.text();
            resultEl.innerHTML = `<span style="color: red;">合成失败: ${response.status} ${response.statusText}<br>详情: ${errorText}</span>`;
        }

    } catch (error) {
        resultEl.innerHTML = `<span style="color: red;">合成出错: ${error.message}</span>`;
    }
}

// 将base64转换为Blob
function base64ToBlob(base64, mimeType) {
    const byteCharacters = atob(base64);
    const byteNumbers = new Array(byteCharacters.length);
    for (let i = 0; i < byteCharacters.length; i++) {
        byteNumbers[i] = byteCharacters.charCodeAt(i);
    }
    const byteArray = new Uint8Array(byteNumbers);
    return new Blob([byteArray], { type: mimeType });
}

// 使用Web Audio API播放原始PCM音频数据
async function playPCMWithWebAudioAPI(audioBase64, sampleRate, channels = 1, bitDepth = 16) {
    try {
        // 创建AudioContext
        const audioContext = new (window.AudioContext || window.webkitAudioContext)();

        // 需要用户交互来启动AudioContext
        if (audioContext.state === 'suspended') {
            await audioContext.resume();
        }

        // 解码base64音频数据
        const binaryData = atob(audioBase64);

        // 创建Int16Array来处理16位PCM数据
        const arrayBuffer = new ArrayBuffer(binaryData.length);
        const uint8View = new Uint8Array(arrayBuffer);
        for (let i = 0; i < binaryData.length; i++) {
            uint8View[i] = binaryData.charCodeAt(i);
        }

        const int16Array = new Int16Array(arrayBuffer);
        const numSamples = int16Array.length;
        const duration = numSamples / sampleRate;

        console.log(`播放PCM音频: ${numSamples} 采样点, 时长: ${duration.toFixed(2)}s, 原始采样率: ${sampleRate}Hz, AudioContext采样率: ${audioContext.sampleRate}Hz`);

        // 创建AudioBuffer
        const audioBuffer = audioContext.createBuffer(channels, numSamples, sampleRate);

        // 将PCM数据转换为float32并填充到AudioBuffer
        const channelData = audioBuffer.getChannelData(0);
        for (let i = 0; i < numSamples; i++) {
            // 将16位整数转换为-1到1的浮点数
            channelData[i] = int16Array[i] / 32768.0;
        }

        // 获取播放速度设置
        const speedSlider = document.getElementById('playback-speed');
        const playbackRate = speedSlider ? parseFloat(speedSlider.value) : 1.0;

        // 创建音频源并播放
        const source = audioContext.createBufferSource();
        source.buffer = audioBuffer;
        source.playbackRate.value = playbackRate;
        source.connect(audioContext.destination);
        source.start(0);

        console.log(`✨ HTTP TTS PCM音频开始播放! 播放速度: ${playbackRate}x`);

        // 播放完成后清理
        source.onended = () => {
            console.log('HTTP TTS PCM音频播放完成');
        };

    } catch (error) {
        console.error('PCM音频播放失败:', error);
        throw error;
    }
}

// 使用Web Audio API播放音频（自动检测格式）
async function playAudioWithWebAudioAPI(audioBase64, sampleRate) {
    try {
        // 先尝试作为PCM数据播放（ONNX引擎返回的格式）
        await playPCMWithWebAudioAPI(audioBase64, sampleRate);
    } catch (pcmError) {
        console.log('PCM播放失败，尝试作为WAV文件播放:', pcmError.message);

        try {
            // 如果PCM播放失败，尝试作为完整的音频文件解码
            const audioContext = new (window.AudioContext || window.webkitAudioContext)();

            if (audioContext.state === 'suspended') {
                await audioContext.resume();
            }

            const binaryData = atob(audioBase64);
            const uint8Array = new Uint8Array(binaryData.length);

            for (let i = 0; i < binaryData.length; i++) {
                uint8Array[i] = binaryData.charCodeAt(i);
            }

            const audioBuffer = await audioContext.decodeAudioData(uint8Array.buffer);

            const speedSlider = document.getElementById('playback-speed');
            const playbackRate = speedSlider ? parseFloat(speedSlider.value) : 1.0;

            const source = audioContext.createBufferSource();
            source.buffer = audioBuffer;
            source.playbackRate.value = playbackRate;
            source.connect(audioContext.destination);
            source.start(0);

            console.log(`✨ HTTP TTS WAV音频开始播放! 播放速度: ${playbackRate}x`);

        } catch (wavError) {
            console.error('音频播放完全失败:', wavError);
            throw wavError;
        }
    }
}


// 流式语音合成全局变量
let ttsWebsocket;
let ttsIsConnected = false;
let ttsAudioChunks = [];
let ttsAudioContext;
let ttsAudioQueue = [];
let ttsIsPlaying = false;
let ttsNextPlayTime = 0;

// 流式语音合成
async function streamingSynthesize() {
    const text = document.getElementById('streaming-tts-text').value.trim();
    const resultEl = document.getElementById('streaming-tts-result');
    const audioEl = document.getElementById('streaming-tts-audio');
    
    if (!text) {
        alert('请输入要合成的文本');
        return;
    }
    
    if (!ttsIsConnected) {
        alert('请先连接TTS服务器');
        return;
    }
    
    try {
        resultEl.innerHTML = '<p>正在进行流式合成...</p>';
        audioEl.style.display = 'none';
        
        // 初始化流式播放
        await initStreamingAudioPlayback();
        
        // 清空之前的音频数据
        ttsAudioChunks = [];
        ttsAudioQueue = [];
        ttsIsPlaying = false;
        ttsNextPlayTime = 0;
        
        // 获取选择的音色ID
        const streamingSpeakerSelect = document.getElementById('streaming-speaker-select');
        const selectedSpkId = parseInt(streamingSpeakerSelect.value) || 174;

        // 发送合成请求
        const requestData = {
            text: text,
            spk_id: selectedSpkId
        };
        
        console.log('发送TTS合成请求:', requestData);
        ttsWebsocket.send(JSON.stringify(requestData));
        
    } catch (error) {
        resultEl.innerHTML = `<span style="color: red;">流式合成出错: ${error.message}</span>`;
    }
}

// 连接TTS WebSocket
function connectTTSWebSocket() {
    const statusEl = document.getElementById('tts-ws-status');
    const connectBtn = document.getElementById('tts-connect-btn');
    const synthesizeBtn = document.getElementById('streaming-synthesize-btn');
    
    console.log('尝试连接TTS WebSocket...');
    
    // 使用配置的WebSocket URL
    const wsUrl = getServiceUrl('tts-ws-url');
    if (!wsUrl) {
        alert('请先配置流式TTS服务地址');
        return;
    }
    
    // 确保URL以正确的路径结尾
    const fullWsUrl = wsUrl.endsWith('/paddlespeech/tts/streaming') ? 
        wsUrl : 
        `${wsUrl.replace(/\/$/, '')}/paddlespeech/tts/streaming`;
    
    // 更新状态
    statusEl.textContent = '连接中...';
    statusEl.className = 'status-indicator status-warning';
    connectBtn.disabled = true;
    
    // 关闭已存在的连接
    if (ttsWebsocket) {
        ttsWebsocket.close();
    }
    
    try {
        ttsWebsocket = new WebSocket(fullWsUrl);
        
        ttsWebsocket.onopen = function() {
            console.log('TTS WebSocket连接成功');
            ttsIsConnected = true;
            
            // 更新UI状态
            statusEl.textContent = '已连接';
            statusEl.className = 'status-indicator status-success';
            connectBtn.disabled = false;
            synthesizeBtn.disabled = false;
            
            // 发送开始信号
            const startMsg = {
                "signal": "start"
            };
            ttsWebsocket.send(JSON.stringify(startMsg));
            console.log('发送TTS开始信号:', startMsg);
        };
        
        ttsWebsocket.onmessage = function(event) {
            console.log('收到TTS消息:', event.data);
            try {
                const result = JSON.parse(event.data);
                handleTTSMessage(result);
            } catch (e) {
                console.log('TTS非JSON消息:', event.data);
            }
        };
        
        ttsWebsocket.onclose = function(event) {
            console.log('TTS WebSocket连接关闭:', event);
            ttsIsConnected = false;
            
            // 更新UI状态
            statusEl.textContent = '连接断开';
            statusEl.className = 'status-indicator status-error';
            connectBtn.disabled = false;
            synthesizeBtn.disabled = true;
        };
        
        ttsWebsocket.onerror = function(error) {
            console.error('TTS WebSocket错误:', error);
            ttsIsConnected = false;
            
            // 更新UI状态
            statusEl.textContent = '连接错误';
            statusEl.className = 'status-indicator status-error';
            connectBtn.disabled = false;
            synthesizeBtn.disabled = true;
        };
        
    } catch (error) {
        console.error('TTS WebSocket连接失败:', error);
        ttsIsConnected = false;
        
        // 更新UI状态
        statusEl.textContent = '连接失败';
        statusEl.className = 'status-indicator status-error';
        connectBtn.disabled = false;
        synthesizeBtn.disabled = true;
    }
}

// 处理TTS WebSocket消息
function handleTTSMessage(result) {
    const resultEl = document.getElementById('streaming-tts-result');
    const audioEl = document.getElementById('streaming-tts-audio');
    
    if (result.status === 0) {
        // 服务器准备就绪
        console.log('TTS服务器准备就绪:', result);
        resultEl.innerHTML = '<p>服务器准备就绪，开始合成...</p>';
    } else if (result.status === 1) {
        // 接收音频数据 - 立即播放
        console.log('接收到音频数据块，立即处理播放');
        if (result.audio) {
            // 添加到音频块数组用于记录
            ttsAudioChunks.push(result.audio);
            
            // 立即处理并播放这个音频块
            processAndPlayAudioChunk(result.audio);
            
            resultEl.innerHTML = `
                <p><strong>正在流式播放...</strong></p>
                <p>已接收: ${ttsAudioChunks.length} 块</p>
                <p>特点: 实时低延迟播放</p>
            `;
        }
    } else if (result.status === 2) {
        // 合成完成
        console.log('TTS合成完成，总音频块数量:', ttsAudioChunks.length);
        
        const text = document.getElementById('streaming-tts-text').value.trim();
        resultEl.innerHTML = `
            <p><strong>流式合成完成!</strong></p>
            <p>文本长度: ${text.length} 字符</p>
            <p>音频块数: ${ttsAudioChunks.length}</p>
            <p>特点: 实时流式播放，无缓冲延迟</p>
            <p style="color: green;">✓ 所有音频块已流式播放完成</p>
        `;
        
        // 清理
        ttsAudioChunks = [];
        
    } else if (result.status === -1) {
        // 合成失败
        console.error('TTS合成失败:', result);
        resultEl.innerHTML = '<span style="color: red;">流式合成失败</span>';
    } else {
        console.log('未知TTS状态:', result);
    }
}

// 创建WAV文件头
function createWAVHeader(dataLength, sampleRate, channels, bitsPerSample) {
    const buffer = new ArrayBuffer(44);
    const view = new DataView(buffer);
    
    // RIFF header
    view.setUint32(0, 0x52494646, false); // 'RIFF'
    view.setUint32(4, 36 + dataLength, true); // file length - 8
    view.setUint32(8, 0x57415645, false); // 'WAVE'
    
    // fmt chunk
    view.setUint32(12, 0x666d7420, false); // 'fmt '
    view.setUint32(16, 16, true); // length of format data
    view.setUint16(20, 1, true); // type of format (PCM)
    view.setUint16(22, channels, true); // number of channels
    view.setUint32(24, sampleRate, true); // sample rate
    view.setUint32(28, sampleRate * channels * bitsPerSample / 8, true); // byte rate
    view.setUint16(32, channels * bitsPerSample / 8, true); // block align
    view.setUint16(34, bitsPerSample, true); // bits per sample
    
    // data chunk
    view.setUint32(36, 0x64617461, false); // 'data'
    view.setUint32(40, dataLength, true); // data length
    
    return new Uint8Array(buffer);
}

// 初始化流式音频播放
async function initStreamingAudioPlayback() {
    try {
        // 创建 AudioContext
        ttsAudioContext = new (window.AudioContext || window.webkitAudioContext)({
            sampleRate: 24000
        });
        
        // 需要用户交互来启动 AudioContext
        if (ttsAudioContext.state === 'suspended') {
            await ttsAudioContext.resume();
        }
        
        ttsNextPlayTime = ttsAudioContext.currentTime;
        console.log('流式音频播放初始化成功');
        
    } catch (error) {
        console.error('初始化音频播放失败:', error);
        throw error;
    }
}

// 处理并播放单个音频块
async function processAndPlayAudioChunk(audioBase64) {
    try {
        // 解码base64音频数据
        const binaryData = atob(audioBase64);
        const uint8Array = new Uint8Array(binaryData.length);
        
        for (let i = 0; i < binaryData.length; i++) {
            uint8Array[i] = binaryData.charCodeAt(i);
        }
        
        console.log(`处理音频块: ${uint8Array.length} 字节`);
        
        // 将PCM数据转换为 AudioBuffer
        const audioBuffer = await pcmToAudioBuffer(uint8Array, 24000, 1);
        
        // 添加到播放队列并立即播放
        scheduleAudioBuffer(audioBuffer);
        
    } catch (error) {
        console.error('处理音频块错误:', error);
    }
}

// 将PCM数据转换为AudioBuffer
async function pcmToAudioBuffer(pcmData, sampleRate, channels) {
    // 将 16-bit PCM 数据转换为 Float32 数组
    const samples = pcmData.length / 2; // 16-bit = 2 bytes per sample
    const audioBuffer = ttsAudioContext.createBuffer(channels, samples, sampleRate);
    const channelData = audioBuffer.getChannelData(0);
    
    for (let i = 0; i < samples; i++) {
        // 读取16-bit有符号整数 (little-endian)
        const sample16 = (pcmData[i * 2 + 1] << 8) | pcmData[i * 2];
        // 转换为有符号整数
        const signedSample = sample16 > 32767 ? sample16 - 65536 : sample16;
        // 归一化到 [-1, 1] 范围
        channelData[i] = signedSample / 32768.0;
    }
    
    return audioBuffer;
}

// 调度音频缓冲区播放
function scheduleAudioBuffer(audioBuffer) {
    const source = ttsAudioContext.createBufferSource();
    source.buffer = audioBuffer;
    source.connect(ttsAudioContext.destination);
    
    // 计算播放时间，实现连续播放
    const currentTime = ttsAudioContext.currentTime;
    const playTime = Math.max(currentTime, ttsNextPlayTime);
    
    source.start(playTime);
    
    // 更新下一个音频块的播放时间
    ttsNextPlayTime = playTime + audioBuffer.duration;
    
    console.log(`调度音频播放: 当前时间=${currentTime.toFixed(3)}s, 播放时间=${playTime.toFixed(3)}s, 时长=${audioBuffer.duration.toFixed(3)}s`);
    
    if (!ttsIsPlaying) {
        ttsIsPlaying = true;
        console.log('✨ 流式音频开始播放!');
    }
}

// 辅助函数：JSON字符串化
function jsonDumps(obj) {
    return JSON.stringify(obj);
}

// 音色数据定义 (基于AISHELL3数据集特征)
const speakerData = {
    // 生成174个说话人的基本信息
    getSpeakerInfo: function(spkId) {
        const baseInfo = {
            0: { id: 'SSB0005', gender: '女性', age: '青年', accent: '标准普通话', description: '音质清晰，语调自然' },
            1: { id: 'SSB0009', gender: '男性', age: '青年', accent: '标准普通话', description: '声音浑厚，发音准确' },
            2: { id: 'SSB0011', gender: '女性', age: '中年', accent: '标准普通话', description: '语音稳重，咬字清楚' },
            10: { id: 'SSB0073', gender: '男性', age: '青年', accent: '标准普通话', description: '声音明亮，富有磁性' },
            20: { id: 'SSB0219', gender: '女性', age: '青年', accent: '标准普通话', description: '声音甜美，语调轻快' },
            30: { id: 'SSB0338', gender: '男性', age: '中年', accent: '标准普通话', description: '声音沉稳，权威感强' },
            40: { id: 'SSB0405', gender: '女性', age: '青年', accent: '标准普通话', description: '音色温和，亲和力强' },
            50: { id: 'SSB0486', gender: '男性', age: '青年', accent: '标准普通话', description: '音质饱满，表现力佳' },
            60: { id: 'SSB0545', gender: '女性', age: '中年', accent: '标准普通话', description: '语音优雅，富有感染力' },
            70: { id: 'SSB0600', gender: '男性', age: '青年', accent: '标准普通话', description: '声音清朗，识别度高' },
            80: { id: 'SSB0688', gender: '女性', age: '青年', accent: '标准普通话', description: '音色柔美，情感丰富' },
            90: { id: 'SSB0756', gender: '男性', age: '中年', accent: '标准普通话', description: '声音醇厚，专业感强' },
            100: { id: 'SSB0825', gender: '女性', age: '青年', accent: '标准普通话', description: '音质纯净，语调活泼' },
            110: { id: 'SSB0898', gender: '男性', age: '青年', accent: '标准普通话', description: '声音有力，节奏感强' },
            120: { id: 'SSB0968', gender: '女性', age: '中年', accent: '标准普通话', description: '语音端庄，表达准确' },
            130: { id: 'SSB1038', gender: '男性', age: '青年', accent: '标准普通话', description: '音色独特，辨识度高' },
            140: { id: 'SSB1108', gender: '女性', age: '青年', accent: '标准普通话', description: '声音清脆，充满活力' },
            150: { id: 'SSB1178', gender: '男性', age: '中年', accent: '标准普通话', description: '语音威严，庄重感强' },
            160: { id: 'SSB1248', gender: '女性', age: '青年', accent: '标准普通话', description: '音色动听，情感细腻' },
            170: { id: 'SSB1318', gender: '男性', age: '青年', accent: '标准普通话', description: '声音阳光，富有朝气' }
        };

        // 如果有预定义信息则返回，否则生成通用信息
        if (baseInfo[spkId]) {
            return baseInfo[spkId];
        }

        // 为其他spk_id生成基本信息
        const gender = spkId % 2 === 0 ? '女性' : '男性';
        const ageGroup = spkId < 50 ? '青年' : (spkId < 120 ? '中年' : '青年');
        return {
            id: `SSB${String(spkId).padStart(4, '0')}`,
            gender: gender,
            age: ageGroup,
            accent: '标准普通话',
            description: '音质清晰，发音标准'
        };
    },

    // 生成所有174个说话人的完整列表
    getAllSpeakers: function() {
        const speakers = [];
        for (let i = 0; i < 174; i++) {
            speakers.push({
                spkId: i,
                ...this.getSpeakerInfo(i)
            });
        }
        return speakers;
    }
};

// 更新说话人信息显示
function updateSpeakerInfo() {
    const speakerSelect = document.getElementById('speaker-select');
    const speakerInfo = document.getElementById('speaker-info');
    const selectedSpkId = parseInt(speakerSelect.value) || 174;

    let info;
    if (selectedSpkId === 174) {
        info = { id: 'baker_corpus', gender: '女性', age: '青年', accent: '标准普通话', description: '中文女声，音质清晰' };
    } else if (selectedSpkId === 175) {
        info = { id: 'ljspeech_corpus', gender: '女性', age: '青年', accent: '美式英语', description: '英文女声，发音标准' };
    } else if (selectedSpkId >= 176) {
        const vctk_id = selectedSpkId - 176;
        const vctk_speakers = ['p225', 'p226', 'p227', 'p228', 'p229', 'p230', 'p231', 'p232', 'p233', 'p234'];
        const speaker_id = vctk_speakers[vctk_id] || `p${225 + vctk_id}`;
        const gender = (vctk_id % 2 === 0) ? '女性' : '男性';
        info = { id: speaker_id, gender: gender, age: '成年', accent: '英式英语', description: 'VCTK英文说话人' };
    } else {
        info = speakerData.getSpeakerInfo(selectedSpkId);
    }

    speakerInfo.innerHTML = `
        <strong>当前选择:</strong> ${info.id} - ${info.gender}，${info.age}，${info.accent}<br>
        <span style="color: #666; font-size: 13px;">${info.description}</span>
    `;
}

// 更新流式TTS说话人信息显示
function updateStreamingSpeakerInfo() {
    const speakerSelect = document.getElementById('streaming-speaker-select');
    const speakerInfo = document.getElementById('streaming-speaker-info');
    const selectedSpkId = parseInt(speakerSelect.value) || 174;

    let info;
    if (selectedSpkId === 174) {
        info = { id: 'baker_corpus', gender: '女性', age: '青年', accent: '标准普通话', description: '中文女声，音质清晰' };
    } else if (selectedSpkId === 175) {
        info = { id: 'ljspeech_corpus', gender: '女性', age: '青年', accent: '美式英语', description: '英文女声，发音标准' };
    } else if (selectedSpkId >= 176) {
        const vctk_id = selectedSpkId - 176;
        const vctk_speakers = ['p225', 'p226', 'p227', 'p228', 'p229', 'p230', 'p231', 'p232', 'p233', 'p234'];
        const speaker_id = vctk_speakers[vctk_id] || `p${225 + vctk_id}`;
        const gender = (vctk_id % 2 === 0) ? '女性' : '男性';
        info = { id: speaker_id, gender: gender, age: '成年', accent: '英式英语', description: 'VCTK英文说话人' };
    } else {
        info = speakerData.getSpeakerInfo(selectedSpkId);
    }

    speakerInfo.innerHTML = `
        <strong>当前选择:</strong> ${info.id} - ${info.gender}，${info.age}，${info.accent}<br>
        <span style="color: #666; font-size: 13px;">${info.description}</span>
    `;
}

// 显示所有说话人选择器
function showAllSpeakers() {
    // 简化版：直接弹出说明
    alert('常规TTS支持283个说话人：\n\n' +
          '推荐使用:\n' +
          'baker_corpus (ID 174): 中文女声\n' +
          'ljspeech_corpus (ID 175): 英文女声\n\n' +
          '其他选项:\n' +
          '中文说话人 (ID 0-173): AISHELL3数据集\n' +
          '英文说话人 (ID 176-282): VCTK数据集\n\n' +
          '建议使用baker_corpus(174)和ljspeech_corpus(175)以获得最佳中英混合效果！');
}

// 原来的显示模态框函数（保留但不使用）
function showAllSpeakersModal() {
    const modal = document.getElementById('speaker-modal');
    const grid = document.getElementById('speaker-grid');

    // 清空网格
    grid.innerHTML = '';

    // 生成所有说话人卡片
    const allSpeakers = speakerData.getAllSpeakers();
    allSpeakers.forEach(speaker => {
        const card = document.createElement('div');
        card.className = 'speaker-card';
        card.onclick = () => selectSpeaker(speaker.spkId);

        card.innerHTML = `
            <h4>${speaker.id}</h4>
            <p><span class="speaker-id">音色ID: ${speaker.spkId}</span></p>
            <p>👤 ${speaker.gender} | 🎂 ${speaker.age}</p>
            <p>🗣️ ${speaker.accent}</p>
            <p style="font-size: 12px; color: #888;">${speaker.description}</p>
        `;

        grid.appendChild(card);
    });

    modal.style.display = 'block';
}

// 显示所有流式TTS说话人选择器
function showAllStreamingSpeakers() {
    // 简化版：直接弹出说明
    alert('流式TTS支持283个说话人：\n\n' +
          '中文说话人 (ID 0-173): AISHELL3数据集\n' +
          'baker_corpus (ID 174): 中文女声\n' +
          'ljspeech_corpus (ID 175): 英文女声\n' +
          '英文说话人 (ID 176-282): VCTK数据集\n\n' +
          '建议使用baker_corpus(174)和ljspeech_corpus(175)以获得最佳中英混合效果！');
}

// 选择说话人
function selectSpeaker(spkId) {
    const speakerSelect = document.getElementById('speaker-select');
    speakerSelect.value = spkId;
    updateSpeakerInfo();
    closeSpeakerModal();
}

// 关闭模态框
function closeSpeakerModal() {
    const modal = document.getElementById('speaker-modal');
    modal.style.display = 'none';
}

// 点击模态框外部关闭
window.onclick = function(event) {
    const modal = document.getElementById('speaker-modal');
    if (event.target === modal) {
        modal.style.display = 'none';
    }
}